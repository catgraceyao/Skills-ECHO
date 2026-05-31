// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BronzeAmbassadorConfig
 * @notice ECHO 青铜大使审查员配置合约 v0.1
 * @dev 存储青铜大使所有参数，Owner 可更新（需 DAO 投票后执行）
 * 
 * 参数来源：2026-05-31 雨娃拍板锁定
 * - 1 MEER 固定奖励（不随币价波动）
 * - 0.1% 审查费按日汇总
 * - 30 天滚动准确率窗口
 */
contract BronzeAmbassadorConfig {
    
    // ============ 核心参数 ============
    
    /// @notice 单次有效标记奖励（wei）
    /// @dev 1 MEER = 1e18 wei
    uint256 public constant REWARD_PER_VALID_MARK = 1 ether;
    
    /// @notice 审查费费率（基点，10000 = 100%）
    /// @dev 0.1% = 10 基点
    uint256 public constant REVIEW_FEE_BPS = 10;
    
    /// @notice 准确率统计窗口（秒）
    /// @dev 30 天 = 30 * 86400
    uint256 public constant ACCURACY_WINDOW_SECONDS = 30 days;
    
    // ============ 晋级与惩罚参数 ============
    
    /// @notice 晋级 Silver 门槛：累计有效标记数
    uint256 public promotionThreshold = 50;
    
    /// @notice 晋级要求：窗口期内最低准确率（基点，10000 = 100%）
    /// @dev 80% = 8000 基点
    uint256 public promotionMinAccuracyBps = 8000;
    
    /// @notice 标记冷却期（秒）
    /// @dev 同一节点 24h 限 1 次
    uint256 public markCooldownSeconds = 1 days;
    
    /// @notice 恶意惩罚触发：连续无效标记次数
    uint256 public maliciousConsecutiveThreshold = 3;
    
    /// @notice 恶意惩罚：冻结时长（秒）
    /// @dev 72h = 3 天
    uint256 public freezeDurationSeconds = 3 days;
    
    /// @notice 恶意判定准确率阈值（基点）
    /// @dev 准确率 < 20% 触发
    uint256 public maliciousAccuracyThresholdBps = 2000;
    
    // ============ 结算参数 ============
    
    /// @notice 奖励结算延迟（秒）
    /// @dev T+1 = 1 天
    uint256 public settlementDelaySeconds = 1 days;
    
    /// @notice 审查费汇总周期（秒）
    /// @dev 按日汇总
    uint256 public feeAggregationPeriod = 1 days;
    
    // ============ 审查范围参数 ============
    
    /// @notice 审查范围：Potency 排名后 X% 的节点
    /// @dev 50 = 后 50%
    uint256 public reviewScopePercentile = 50;
    
    // ============ 状态变量 ============
    
    address public owner;
    
    /// @notice 配置版本号，每次更新递增
    uint256 public configVersion;
    
    /// @notice 参数更新时间戳
    uint256 public lastUpdatedAt;
    
    /// @notice 紧急暂停开关
    bool public paused;
    
    // ============ 事件 ============
    
    event ParameterUpdated(
        string paramName,
        uint256 oldValue,
        uint256 newValue,
        uint256 version,
        uint256 timestamp
    );
    
    event ConfigLocked(uint256 version, uint256 timestamp);
    event ConfigUnlocked(uint256 version, uint256 timestamp);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EmergencyPaused(uint256 timestamp);
    event EmergencyUnpaused(uint256 timestamp);
    
    // ============ 修饰符 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "PAUSED");
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor() {
        owner = msg.sender;
        configVersion = 1;
        lastUpdatedAt = block.timestamp;
    }
    
    // ============ 参数更新函数 ============
    
    /// @notice 更新晋级门槛
    function setPromotionThreshold(uint256 _threshold) external onlyOwner whenNotPaused {
        require(_threshold > 0, "INVALID_THRESHOLD");
        uint256 old = promotionThreshold;
        promotionThreshold = _threshold;
        emit ParameterUpdated("promotionThreshold", old, _threshold, ++configVersion, block.timestamp);
        lastUpdatedAt = block.timestamp;
    }
    
    /// @notice 更新晋级最低准确率
    function setPromotionMinAccuracyBps(uint256 _bps) external onlyOwner whenNotPaused {
        require(_bps <= 10000, "INVALID_BPS");
        uint256 old = promotionMinAccuracyBps;
        promotionMinAccuracyBps = _bps;
        emit ParameterUpdated("promotionMinAccuracyBps", old, _bps, ++configVersion, block.timestamp);
        lastUpdatedAt = block.timestamp;
    }
    
    /// @notice 更新标记冷却期
    function setMarkCooldownSeconds(uint256 _seconds) external onlyOwner whenNotPaused {
        require(_seconds > 0, "INVALID_COOLDOWN");
        uint256 old = markCooldownSeconds;
        markCooldownSeconds = _seconds;
        emit ParameterUpdated("markCooldownSeconds", old, _seconds, ++configVersion, block.timestamp);
        lastUpdatedAt = block.timestamp;
    }
    
    /// @notice 更新恶意判定阈值
    function setMaliciousConsecutiveThreshold(uint256 _threshold) external onlyOwner whenNotPaused {
        require(_threshold > 0, "INVALID_THRESHOLD");
        uint256 old = maliciousConsecutiveThreshold;
        maliciousConsecutiveThreshold = _threshold;
        emit ParameterUpdated("maliciousConsecutiveThreshold", old, _threshold, ++configVersion, block.timestamp);
        lastUpdatedAt = block.timestamp;
    }
    
    /// @notice 更新冻结时长
    function setFreezeDurationSeconds(uint256 _seconds) external onlyOwner whenNotPaused {
        require(_seconds > 0, "INVALID_DURATION");
        uint256 old = freezeDurationSeconds;
        freezeDurationSeconds = _seconds;
        emit ParameterUpdated("freezeDurationSeconds", old, _seconds, ++configVersion, block.timestamp);
        lastUpdatedAt = block.timestamp;
    }
    
    /// @notice 更新恶意准确率阈值
    function setMaliciousAccuracyThresholdBps(uint256 _bps) external onlyOwner whenNotPaused {
        require(_bps <= 10000, "INVALID_BPS");
        uint256 old = maliciousAccuracyThresholdBps;
        maliciousAccuracyThresholdBps = _bps;
        emit ParameterUpdated("maliciousAccuracyThresholdBps", old, _bps, ++configVersion, block.timestamp);
        lastUpdatedAt = block.timestamp;
    }
    
    /// @notice 更新结算延迟
    function setSettlementDelaySeconds(uint256 _seconds) external onlyOwner whenNotPaused {
        uint256 old = settlementDelaySeconds;
        settlementDelaySeconds = _seconds;
        emit ParameterUpdated("settlementDelaySeconds", old, _seconds, ++configVersion, block.timestamp);
        lastUpdatedAt = block.timestamp;
    }
    
    /// @notice 更新审查费汇总周期
    function setFeeAggregationPeriod(uint256 _seconds) external onlyOwner whenNotPaused {
        require(_seconds > 0, "INVALID_PERIOD");
        uint256 old = feeAggregationPeriod;
        feeAggregationPeriod = _seconds;
        emit ParameterUpdated("feeAggregationPeriod", old, _seconds, ++configVersion, block.timestamp);
        lastUpdatedAt = block.timestamp;
    }
    
    /// @notice 更新审查范围百分比
    function setReviewScopePercentile(uint256 _percentile) external onlyOwner whenNotPaused {
        require(_percentile > 0 && _percentile <= 100, "INVALID_PERCENTILE");
        uint256 old = reviewScopePercentile;
        reviewScopePercentile = _percentile;
        emit ParameterUpdated("reviewScopePercentile", old, _percentile, ++configVersion, block.timestamp);
        lastUpdatedAt = block.timestamp;
    }
    
    // ============ 紧急控制 ============
    
    /// @notice 紧急暂停所有参数更新
    function pause() external onlyOwner {
        paused = true;
        emit EmergencyPaused(block.timestamp);
    }
    
    /// @notice 解除暂停
    function unpause() external onlyOwner {
        paused = false;
        emit EmergencyUnpaused(block.timestamp);
    }
    
    // ============ 所有权管理 ============
    
    /// @notice 转移所有权
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "INVALID_ADDRESS");
        address oldOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(oldOwner, _newOwner);
    }
    
    // ============ 批量更新 ============
    
    /// @notice 一次性更新多个参数（用于初始化或 DAO 投票后批量生效）
    function batchUpdate(
        uint256 _promotionThreshold,
        uint256 _promotionMinAccuracyBps,
        uint256 _markCooldownSeconds,
        uint256 _maliciousConsecutiveThreshold,
        uint256 _freezeDurationSeconds,
        uint256 _maliciousAccuracyThresholdBps,
        uint256 _settlementDelaySeconds,
        uint256 _feeAggregationPeriod,
        uint256 _reviewScopePercentile
    ) external onlyOwner whenNotPaused {
        require(_promotionThreshold > 0, "INVALID_THRESHOLD");
        require(_promotionMinAccuracyBps <= 10000, "INVALID_ACCURACY_BPS");
        require(_markCooldownSeconds > 0, "INVALID_COOLDOWN");
        require(_maliciousConsecutiveThreshold > 0, "INVALID_MALICIOUS_THRESHOLD");
        require(_freezeDurationSeconds > 0, "INVALID_FREEZE_DURATION");
        require(_maliciousAccuracyThresholdBps <= 10000, "INVALID_MALICIOUS_BPS");
        require(_feeAggregationPeriod > 0, "INVALID_FEE_PERIOD");
        require(_reviewScopePercentile > 0 && _reviewScopePercentile <= 100, "INVALID_PERCENTILE");
        
        promotionThreshold = _promotionThreshold;
        promotionMinAccuracyBps = _promotionMinAccuracyBps;
        markCooldownSeconds = _markCooldownSeconds;
        maliciousConsecutiveThreshold = _maliciousConsecutiveThreshold;
        freezeDurationSeconds = _freezeDurationSeconds;
        maliciousAccuracyThresholdBps = _maliciousAccuracyThresholdBps;
        settlementDelaySeconds = _settlementDelaySeconds;
        feeAggregationPeriod = _feeAggregationPeriod;
        reviewScopePercentile = _reviewScopePercentile;
        
        configVersion++;
        lastUpdatedAt = block.timestamp;
        
        emit ConfigLocked(configVersion, block.timestamp);
    }
    
    // ============ 查询函数 ============
    
    /// @notice 获取所有核心参数（常量）
    function getCoreParams() external pure returns (
        uint256 rewardPerValidMark,
        uint256 reviewFeeBps,
        uint256 accuracyWindowSeconds
    ) {
        return (REWARD_PER_VALID_MARK, REVIEW_FEE_BPS, ACCURACY_WINDOW_SECONDS);
    }
    
    /// @notice 获取所有可变参数
    function getVariableParams() external view returns (
        uint256 _promotionThreshold,
        uint256 _promotionMinAccuracyBps,
        uint256 _markCooldownSeconds,
        uint256 _maliciousConsecutiveThreshold,
        uint256 _freezeDurationSeconds,
        uint256 _maliciousAccuracyThresholdBps,
        uint256 _settlementDelaySeconds,
        uint256 _feeAggregationPeriod,
        uint256 _reviewScopePercentile
    ) {
        return (
            promotionThreshold,
            promotionMinAccuracyBps,
            markCooldownSeconds,
            maliciousConsecutiveThreshold,
            freezeDurationSeconds,
            maliciousAccuracyThresholdBps,
            settlementDelaySeconds,
            feeAggregationPeriod,
            reviewScopePercentile
        );
    }
    
    /// @notice 获取完整配置摘要
    function getConfigSummary() external view returns (
        uint256 version,
        uint256 lastUpdate,
        bool isPaused,
        address currentOwner
    ) {
        return (configVersion, lastUpdatedAt, paused, owner);
    }
}
