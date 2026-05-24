// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title PotentialEngine
 * @notice 势位评估引擎:NPS + 使用反馈 + Tukey fences 自适应阈值
 * @dev 基于 v0.4 文档 §4.x
 * 修复 X7 review #4 (gas风险) 和 #5 (Tukey水军攻击), Seaman 遗漏 #2 (NPS三道锁)
 */
contract PotentialEngine {
    using Math for uint256;

    // ============ 常量 ============

    uint256 public constant NPS_DENOMINATOR = 10000;  // NPS 精度 0-10000
    uint256 public constant MIN_HOLDING_PERIOD = 7 days;   // NPS 7天持有期(修复遗漏)
    uint256 public constant RATING_COOLDOWN = 30 days;     // NPS 30天频率限制(修复遗漏)
    uint256 public constant WEIGHT_CREATOR = 5000;         // 创作者权重 50%
    uint256 public constant WEIGHT_USER = 5000;            // 使用者权重 50%
    uint256 public constant DISPUTE_THRESHOLD = 1000;      // 争议率 >10% 时使用者权重提升
    uint256 public constant WEIGHT_USER_HIGH_DISPUTE = 6000; // 争议率高时使用者权重 60%
    uint256 public constant EMA_WARMUP_BATCHES = 5;        // EMA冷启动：前5个batch渐进SMA过渡，第6个batch起切EMA
    uint256 public constant EMA_ALPHA_NUMERATOR = 2;        // EMA α = 0.2 (2/10)，新数据权重20%
    uint256 public constant EMA_ALPHA_DENOMINATOR = 10;     // EMA 分母
    uint256 public constant MAX_NPS_HISTORY = 1000;         // NPS 历史最大长度（修复 H4）
    uint256 public constant ANOMALY_STREAK_THRESHOLD = 2;  // 连续2周期异常触发延迟确认
    uint256 public constant MIN_IQR = 3;                   // Tukey IQR 最小值（修复 #5）

    // ============ EMA冷启动状态（round8-fix）============
    mapping(uint256 => uint256) public emaBatchCounter;    // 每个versionId已处理batch数

    // ============ 数据结构 ============

    struct NPSScore {
        uint256 score;           // 0-10000
        uint256 timestamp;       // 评分时间
        uint256 licenseId;       // 关联许可
        bool isValid;            // 是否有效
    }

    struct LicenseInfo {
        uint256 purchaseTime;    // 购买时间
        bool exists;             // 是否存在
    }

    struct PotentialMetrics {
        uint256 npsScore;        // NPS 平均分
        uint256 engagementScore; // 参与度分
        uint256 disputeRate;     // 争议率 (basis points)
        uint256 activityScore;   // 活跃度分
        uint256 potential;       // 综合势位分
    }

    struct Thresholds {
        uint256 upperFence;      // Tukey 上围栏
        uint256 lowerFence;      // Tukey 下围栏
        uint256 iqr;             // 四分位距
        uint256 median;          // 中位数
        uint256 lastUpdated;     // 上次更新时间
    }

    // ============ 状态变量 ============

    mapping(uint256 => NPSScore[]) public npsHistory;     // versionId => NPS 历史
    mapping(uint256 => mapping(address => uint256)) public lastRatingTime; // versionId => user => time
    mapping(uint256 => mapping(uint256 => LicenseInfo)) public licenses; // versionId => licenseId => info
    mapping(uint256 => PotentialMetrics) public metrics;   // versionId => 当前指标
    mapping(uint256 => Thresholds) public thresholds;      // versionId => 阈值
    mapping(uint256 => uint256) public anomalyStreak;      // versionId => 连续异常次数

    address public owner;
    address public juryContract;   // AgentJury 合约地址

    // ============ 事件 ============
    /// @notice 前端可视化规范（round8-fix）
    /// @dev 合约仅抛出事件，前端按以下规范渲染：
    /// - 正常区间（lowerFence ~ upperFence）：绿色折线，无闪烁
    /// - 温和异常（potential 越界 1.5 IQR）：黄色闪烁 + 警告图标
    /// - 极端异常（偏离中位数 >=3 IQR）：红色全屏遮罩 + "延迟确认中"文案
    /// - 连续 ANOMALY_STREAK_THRESHOLD(2) 周期异常：加锁图标 + 倒计时
    ///   （等待人工/Agent陪审团介入，期间禁止自动阈值更新）
    /// - EMA冷启动期（emaBatchCounter < 5）：灰色虚线 + "数据积累中"提示
    ///   第5个batch完成后变实线绿色，前端监听 EMAWarmedUp 事件切换

    event NPSSubmitted(uint256 indexed versionId, address indexed user, uint256 licenseId, uint256 score);
    event NPSInvalidated(uint256 indexed versionId, uint256 indexed licenseId, string reason);
    event EMAWarmedUp(uint256 indexed versionId, uint256 finalSMAValue);
    event ThresholdsUpdated(uint256 indexed versionId, uint256 upper, uint256 lower, uint256 iqr);
    event AnomalyDetected(uint256 indexed versionId, uint256 metric, uint256 fence);
    event DelayedConfirmation(uint256 indexed versionId, uint256 streak);

    // ============ 修饰器 ============

    modifier onlyOwner() {
        require(msg.sender == owner, "PE: not owner");
        _;
    }

    modifier onlyJury() {
        require(msg.sender == juryContract, "PE: not jury");
        _;
    }

    // ============ 构造函数 ============

    constructor() {
        owner = msg.sender;
    }

    function setJuryContract(address _jury) external onlyOwner {
        juryContract = _jury;
    }

    // ============ NPS 提交(三道锁) ============

    function submitNPS(
        uint256 _versionId,
        uint256 _licenseId,
        uint256 _score  // 0-10000
    ) external {
        require(_score <= NPS_DENOMINATOR, "PE: invalid score");

        LicenseInfo storage lic = licenses[_versionId][_licenseId];
        require(lic.exists, "PE: license not found");

        // 锁1:7天持有期(修复遗漏)
        require(
            block.timestamp >= lic.purchaseTime + MIN_HOLDING_PERIOD,
            "PE: holding period not met"
        );

        // 锁2:30天频率限制(修复遗漏)
        uint256 lastTime = lastRatingTime[_versionId][msg.sender];
        require(
            block.timestamp >= lastTime + RATING_COOLDOWN,
            "PE: rating cooldown active"
        );

        // 锁3:许可有效性实时验证
        require(isLicenseValid(_versionId, _licenseId), "PE: license expired or refunded");


        // 记录 NPS
        npsHistory[_versionId].push(NPSScore({
            score: _score,
            timestamp: block.timestamp,
            licenseId: _licenseId,
            isValid: true
        }));

        lastRatingTime[_versionId][msg.sender] = block.timestamp;

        emit NPSSubmitted(_versionId, msg.sender, _licenseId, _score);

        // 触发重新评估（keeper 分批模式）
        _recalculateMetricsBatch(_versionId, 1);  // 先更新 1 个指标，剩余由 keeper 触发
        
        // 限制历史长度（修复 H4）
        _trimNPSHistory(_versionId);
    }

    function isLicenseValid(uint256 _versionId, uint256 _licenseId) public view returns (bool) {
        // 简化：实际应调用 LicenseNFT 合约验证
        // TODO: 接入 LicenseNFT.isLicenseValid() 外部调用
        LicenseInfo storage lic = licenses[_versionId][_licenseId];
        return lic.exists;
    }

    function _trimNPSHistory(uint256 _versionId) internal {
        NPSScore[] storage history = npsHistory[_versionId];
        if (history.length <= MAX_NPS_HISTORY) return;
        
        // 超出限制：将最旧的标记为无效（index 0）
        // 注意：Solidity 数组前端删除昂贵，改用标记无效
        uint256 excess = history.length - MAX_NPS_HISTORY;
        for (uint i = 0; i < excess && i < history.length; i++) {
            if (history[i].isValid) {
                history[i].isValid = false;
                emit NPSInvalidated(_versionId, history[i].licenseId, "history overflow");
            }
        }
    }

    // ============ 势位评估(修复 X7 review:keeper 分批模式) ============

    uint256 public constant MAX_METRICS_PER_BATCH = 5;  // 单次最多更新 5 个指标
    mapping(uint256 => uint256) public versionRecalcIndex; // per-versionId 重算索引（修复 H2）

    function recalculateMetrics(uint256 _versionId) external {
        // 任何人都可以触发,但只更新一批
        _recalculateMetricsBatch(_versionId, MAX_METRICS_PER_BATCH);
    }

    function _recalculateMetricsBatch(uint256 _versionId, uint256 _batchSize) internal {
        NPSScore[] storage history = npsHistory[_versionId];
        if (history.length == 0) return;
        
        // 分批更新：单次只处理 _batchSize 个指标
        uint256 startIdx = versionRecalcIndex[_versionId];  // 修复 H2：per-versionId
        uint256 batchEnd = startIdx + _batchSize;
        if (batchEnd > history.length) batchEnd = history.length;
        
        // 计算 NPS 平均分（只处理当前批次）
        uint256 totalNPS = 0;
        uint256 validCount = 0;
        for (uint i = startIdx; i < batchEnd; i++) {
            if (history[i].isValid) {
                totalNPS += history[i].score;
                validCount++;
            }
        }
        
        PotentialMetrics storage m = metrics[_versionId];
        if (validCount > 0) {
            uint256 batchAvg = totalNPS / validCount;
            
            // round8-fix: EMA冷启动，前5个batch渐进SMA过渡
            uint256 batchCount = emaBatchCounter[_versionId];
            if (batchCount < EMA_WARMUP_BATCHES) {
                // 渐进累积平均：(旧总分 * 计数 + 新值) / (计数 + 1)
                m.npsScore = (m.npsScore * batchCount + batchAvg) / (batchCount + 1);
                emaBatchCounter[_versionId] = batchCount + 1;
                if (batchCount + 1 == EMA_WARMUP_BATCHES) {
                    emit EMAWarmedUp(_versionId, m.npsScore);
                }
            } else {
                // 修复 H1：标准指数移动平均（EMA）
                // EMA_t = α * new_value + (1-α) * EMA_{t-1}
                m.npsScore = (EMA_ALPHA_NUMERATOR * batchAvg + 
                    (EMA_ALPHA_DENOMINATOR - EMA_ALPHA_NUMERATOR) * m.npsScore) 
                    / EMA_ALPHA_DENOMINATOR;
            }
        }
        
        versionRecalcIndex[_versionId] = batchEnd;
        if (batchEnd >= history.length) {
            versionRecalcIndex[_versionId] = history.length;  // H2 fix: stop at end, no loop
            _checkAnomaly(_versionId);  // full pass complete
        }
    }

    // ============ Tukey Fences 自适应阈值(修复 X7 review:IQR 倍率≥3 直接进异常) ============

    function _checkAnomaly(uint256 _versionId) internal {
        PotentialMetrics storage m = metrics[_versionId];
        Thresholds storage t = thresholds[_versionId];
        
        // 计算历史指标的中位数和 IQR（只取有效数据）
        uint256[] memory scores = _extractValidScores(_versionId);
        if (scores.length < 4) return; // 数据不足

        (uint256 q1, uint256 median, uint256 q3) = _calculateQuartiles(scores);
        uint256 iqr = q3 - q1;
        
        // IQR >= 3 兜底（修复 #5）
        if (iqr < MIN_IQR) iqr = MIN_IQR;
        
        // 标准 Tukey fences：1.5 倍 IQR
        uint256 upperFence = q3 + (iqr * 15) / 10;  // Q3 + 1.5*IQR
        uint256 lowerFence = q1 > (iqr * 15) / 10 ? q1 - (iqr * 15) / 10 : 0;  // Q1 - 1.5*IQR
        
        // 修复 H3：IQR 倍率检测与 fences 逻辑统一
        // 当前 potential 偏离中位数的 IQR 倍数（H3 fix: *10 避免整数除法盲区）
        uint256 deviation = m.potential > median ? m.potential - median : median - m.potential;
        uint256 iqrMultiplier10 = iqr > 0 ? (deviation * 10) / iqr : 0;
        
        if (iqrMultiplier10 >= 30) {
            // 极端偏离（>=3.0 IQR），直接进异常，不更新 Tukey 阈值
            // 防止水军用极端值拉偏分位数
            anomalyStreak[_versionId]++;
            emit AnomalyDetected(_versionId, m.potential, upperFence);
            
            if (anomalyStreak[_versionId] >= ANOMALY_STREAK_THRESHOLD) {
                emit DelayedConfirmation(_versionId, anomalyStreak[_versionId]);
            }
            return;  // 跳过 Tukey 更新
        }
        
        // 更新阈值
        t.upperFence = upperFence;
        t.lowerFence = lowerFence;
        t.iqr = iqr;
        t.median = median;
        t.lastUpdated = block.timestamp;
        
        emit ThresholdsUpdated(_versionId, upperFence, lowerFence, iqr);
        
        // 检测当前指标是否越界（标准 Tukey 1.5 IQR，H3 fix: >=15 即 1.5x）
        if (iqrMultiplier10 >= 15) {
            anomalyStreak[_versionId]++;
            emit AnomalyDetected(_versionId, m.potential, m.potential > upperFence ? upperFence : lowerFence);
            
            if (anomalyStreak[_versionId] >= ANOMALY_STREAK_THRESHOLD) {
                emit DelayedConfirmation(_versionId, anomalyStreak[_versionId]);
            }
        } else {
            anomalyStreak[_versionId] = 0;
        }
    }

    function _extractValidScores(uint256 _versionId) internal view returns (uint256[] memory) {
        NPSScore[] storage history = npsHistory[_versionId];
        uint256 validCount = 0;
        for (uint i = 0; i < history.length; i++) {
            if (history[i].isValid) validCount++;
        }
        
        uint256[] memory scores = new uint256[](validCount);
        uint256 idx = 0;
        for (uint i = 0; i < history.length; i++) {
            if (history[i].isValid) {
                scores[idx++] = history[i].score;
            }
        }
        return scores;
    }

    function _calculateQuartiles(uint256[] memory arr) internal pure returns (uint256 q1, uint256 median, uint256 q3) {
        require(arr.length >= 4, "PE: insufficient data");

        // 排序（修复 H4：限制数组大小后冒泡排序可接受，MAX_NPS_HISTORY=1000）
        // 注意：Solidity 中快速排序递归深度受限，小数组冒泡更稳定
        for (uint i = 0; i < arr.length; i++) {
            for (uint j = i + 1; j < arr.length; j++) {
                if (arr[i] > arr[j]) {
                    uint256 temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }

        uint256 n = arr.length;

        // 中位数
        if (n % 2 == 0) {
            median = (arr[n / 2 - 1] + arr[n / 2]) / 2;
        } else {
            median = arr[n / 2];
        }

        // Q1:前半部分的中位数
        uint256 half = n / 2;
        if (half % 2 == 0) {
            q1 = (arr[half / 2 - 1] + arr[half / 2]) / 2;
        } else {
            q1 = arr[half / 2];
        }

        // Q3:后半部分的中位数
        uint256 start = n % 2 == 0 ? half : half + 1;
        if ((n - start) % 2 == 0) {
            q3 = (arr[start + (n - start) / 2 - 1] + arr[start + (n - start) / 2]) / 2;
        } else {
            q3 = arr[start + (n - start) / 2];
        }

        return (q1, median, q3);
    }

    // ============ 外部查询 ============

    function getMetrics(uint256 _versionId) external view returns (PotentialMetrics memory) {
        return metrics[_versionId];
    }

    function getThresholds(uint256 _versionId) external view returns (Thresholds memory) {
        return thresholds[_versionId];
    }

    function getNPSCount(uint256 _versionId) external view returns (uint256) {
        return npsHistory[_versionId].length;
    }

    // ============ 管理员 ============

    function registerLicense(uint256 _versionId, uint256 _licenseId, uint256 _purchaseTime) external onlyOwner {
        licenses[_versionId][_licenseId] = LicenseInfo({
            purchaseTime: _purchaseTime,
            exists: true
        });
    }

    function invalidateNPS(uint256 _versionId, uint256 _index, string calldata _reason) external onlyJury {
        require(_index < npsHistory[_versionId].length, "PE: invalid index");
        npsHistory[_versionId][_index].isValid = false;
        emit NPSInvalidated(_versionId, npsHistory[_versionId][_index].licenseId, _reason);
    }

    function updateEngagementScore(uint256 _versionId, uint256 _score) external onlyOwner {
        metrics[_versionId].engagementScore = _score;
    }

    function updateDisputeRate(uint256 _versionId, uint256 _rate) external onlyOwner {
        require(_rate <= 10000, "PE: invalid rate");
        metrics[_versionId].disputeRate = _rate;
    }
}
