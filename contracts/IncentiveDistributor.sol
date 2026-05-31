// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BronzeAmbassadorConfig.sol";

/**
 * @title IncentiveDistributor
 * @notice ECHO 青铜大使激励发放合约 v0.1
 * @dev 按日汇总、批量打款、T+1 结算
 * 
 * 结算规则（2026-05-31 雨娃拍板）：
 * - 1 MEER 固定奖励 / 每次有效标记
 * - 0.1% 审查费按日汇总
 * - T+1 结算（标记后 1 天发放）
 * - 30 天滚动准确率窗口
 */
contract IncentiveDistributor {
    
    // ============ 类型定义 ============
    
    enum MarkStatus {
        Pending,    // 等待结算
        Settled,    // 已结算
        Rejected,   // 被判定无效
        Frozen      // 冻结中
    }
    
    struct MarkRecord {
        address reviewer;       // 审查员地址
        uint256 nodeId;         // 被标记节点 ID
        uint256 timestamp;      // 标记时间戳
        uint256 settleTime;     // 可结算时间（T+1）
        MarkStatus status;      // 状态
        bool isValid;           // 是否有效（裁决后）
        uint256 rewardAmount;   // 奖励金额（wei）
    }
    
    struct DailyBatch {
        uint256 date;           // 日期（UTC 0 点 timestamp）
        uint256[] markIds;      // 当日标记 ID 列表
        uint256 totalRewards;   // 当日总奖励
        uint256 totalFees;      // 当日总审查费
        bool processed;         // 是否已处理
        uint256 processedAt;    // 处理时间
    }
    
    // ============ 状态变量 ============
    
    /// @notice 配置合约地址
    BronzeAmbassadorConfig public config;
    
    /// @notice Owner
    address public owner;
    
    /// @notice 标记 ID 计数器
    uint256 public nextMarkId = 1;
    
    /// @notice 所有标记记录
    mapping(uint256 => MarkRecord) public marks;
    
    /// @notice 审查员 → 有效标记数
    mapping(address => uint256) public validMarkCount;
    
    /// @notice 审查员 → 总标记数
    mapping(address => uint256) public totalMarkCount;
    
    /// @notice 审查员 → 连续无效标记数
    mapping(address => uint256) public consecutiveInvalidMarks;
    
    /// @notice 审查员 → 冻结到期时间
    mapping(address => uint256) public freezeUntil;
    
    /// @notice 审查员 → 最近一次标记时间（冷却期检查）
    mapping(address => mapping(uint256 => uint256)) public lastMarkTime; // reviewer => nodeId => timestamp
    
    /// @notice 日期 → 批次
    mapping(uint256 => DailyBatch) public dailyBatches;
    
    /// @notice 已提取的审查费总额
    uint256 public totalFeesWithdrawn;
    
    /// @notice 授权裁决者
    mapping(address => bool) public authorizedArbitrators;
    
    /// @notice 所有有标记的日期列表
    uint256[] public allDates;
    
    /// @notice 合约总余额
    uint256 public totalDeposited;
    
    /// @notice 已发放总额
    uint256 public totalDistributed;
    
    /// @notice 紧急暂停
    bool public paused;
    
    /// @notice 审查费收款地址
    address public feeCollector;
    
    // ============ 事件 ============
    
    event MarkSubmitted(
        uint256 indexed markId,
        address indexed reviewer,
        uint256 indexed nodeId,
        uint256 timestamp,
        uint256 settleTime
    );
    
    event MarkSettled(
        uint256 indexed markId,
        address indexed reviewer,
        uint256 rewardAmount,
        uint256 settledAt
    );
    
    event MarkRejected(
        uint256 indexed markId,
        address indexed reviewer,
        string reason
    );
    
    event BatchProcessed(
        uint256 indexed date,
        uint256 markCount,
        uint256 totalRewards,
        uint256 totalFees,
        uint256 processedAt
    );
    
    event Deposited(address indexed sender, uint256 amount, uint256 newBalance);
    event ArbitratorAuthorized(address indexed arbitrator);
    event ArbitratorRevoked(address indexed arbitrator);
    event ReviewerFrozen(address indexed reviewer, uint256 until);
    event ReviewerUnfrozen(address indexed reviewer);
    
    // ============ 修饰符 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "PAUSED");
        _;
    }
    
    modifier onlyArbitrator() {
        require(msg.sender == owner || authorizedArbitrators[msg.sender], "NOT_ARBITRATOR");
        _;
    }
    
    modifier notFrozen() {
        require(block.timestamp >= freezeUntil[msg.sender], "FROZEN");
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor(address _config, address _feeCollector) {
        require(_config != address(0), "INVALID_CONFIG");
        require(_feeCollector != address(0), "INVALID_FEE_COLLECTOR");
        owner = msg.sender;
        config = BronzeAmbassadorConfig(_config);
        feeCollector = _feeCollector;
    }
    
    // ============ 存款 ============
    
    receive() external payable {
        deposit();
    }
    
    function deposit() public payable {
        require(msg.value > 0, "ZERO_VALUE");
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value, address(this).balance);
    }
    
    /// @notice 授权裁决者
    function authorizeArbitrator(address arbitrator) external onlyOwner {
        require(arbitrator != address(0), "INVALID_ADDRESS");
        authorizedArbitrators[arbitrator] = true;
        emit ArbitratorAuthorized(arbitrator);
    }
    
    /// @notice 撤销裁决者
    function revokeArbitrator(address arbitrator) external onlyOwner {
        authorizedArbitrators[arbitrator] = false;
        emit ArbitratorRevoked(arbitrator);
    }
    
    /// @notice 提交一次节点标记
    /// @param nodeId 被标记的节点 ID
    function submitMark(uint256 nodeId) external whenNotPaused notFrozen returns (uint256 markId) {
        address reviewer = msg.sender;
        
        // 检查冷却期
        uint256 lastTime = lastMarkTime[reviewer][nodeId];
        uint256 cooldown = config.markCooldownSeconds();
        require(block.timestamp >= lastTime + cooldown, "COOLDOWN_ACTIVE");
        
        // 更新冷却期记录
        lastMarkTime[reviewer][nodeId] = block.timestamp;
        
        // 获取核心参数
        (uint256 rewardPerMark, uint256 reviewFeeBps, ) = config.getCoreParams();
        
        // 计算 T+1 结算时间
        uint256 settleDelay = config.settlementDelaySeconds();
        uint256 settleTime = block.timestamp + settleDelay;
        
        // 创建标记记录
        markId = nextMarkId++;
        uint256 date = _getDate(block.timestamp);
        
        marks[markId] = MarkRecord({
            reviewer: reviewer,
            nodeId: nodeId,
            timestamp: block.timestamp,
            settleTime: settleTime,
            status: MarkStatus.Pending,
            isValid: false,
            rewardAmount: rewardPerMark
        });
        
        // 检查是否已有该日期的批次
        if (dailyBatches[date].markIds.length == 0) {
            allDates.push(date);
        }
        
        // 加入当日批次
        dailyBatches[date].date = date;
        dailyBatches[date].markIds.push(markId);
        dailyBatches[date].totalRewards += rewardPerMark;
        
        // 计算审查费（从奖励中扣除）
        uint256 fee = (rewardPerMark * reviewFeeBps) / 10000;
        dailyBatches[date].totalFees += fee;
        
        // 更新审查员统计
        totalMarkCount[reviewer]++;
        
        emit MarkSubmitted(markId, reviewer, nodeId, block.timestamp, settleTime);
        
        return markId;
    }
    
    // ============ 批量结算 ============
    
    /// @notice 处理指定日期的所有标记（T+1 后结算，只结算已裁决为有效的）
    /// @param date UTC 日期（0 点 timestamp）
    function processBatch(uint256 date) external whenNotPaused {
        DailyBatch storage batch = dailyBatches[date];
        require(!batch.processed, "ALREADY_PROCESSED");
        require(batch.markIds.length > 0, "EMPTY_BATCH");
        
        // 确保所有标记都已到 T+1
        for (uint i = 0; i < batch.markIds.length; i++) {
            uint256 markId = batch.markIds[i];
            require(block.timestamp >= marks[markId].settleTime, "SETTLEMENT_NOT_DUE");
        }
        
        uint256 totalRewardsPaid = 0;
        uint256 totalFeesCollected = 0;
        
        for (uint i = 0; i < batch.markIds.length; i++) {
            uint256 markId = batch.markIds[i];
            MarkRecord storage mark = marks[markId];
            
            if (mark.status != MarkStatus.Pending) continue;
            
            // 只结算已裁决为有效的标记
            if (!mark.isValid) continue;
            
            // 先更新状态（Checks-Effects-Interactions）
            mark.status = MarkStatus.Settled;
            
            // 更新审查员统计
            validMarkCount[mark.reviewer]++;
            consecutiveInvalidMarks[mark.reviewer] = 0;
            
            // 计算净奖励（扣除审查费）
            (uint256 rewardPerMark, uint256 reviewFeeBps, ) = config.getCoreParams();
            uint256 fee = (rewardPerMark * reviewFeeBps) / 10000;
            uint256 netReward = rewardPerMark - fee;
            
            // 再转账（防止重入）
            totalRewardsPaid += netReward;
            totalFeesCollected += fee;
            
            emit MarkSettled(markId, mark.reviewer, netReward, block.timestamp);
        }
        
        // 批量转账（减少外部调用次数）
        for (uint i = 0; i < batch.markIds.length; i++) {
            uint256 markId = batch.markIds[i];
            MarkRecord storage mark = marks[markId];
            if (mark.status != MarkStatus.Settled) continue;
            
            (uint256 rewardPerMark, uint256 reviewFeeBps, ) = config.getCoreParams();
            uint256 fee = (rewardPerMark * reviewFeeBps) / 10000;
            uint256 netReward = rewardPerMark - fee;
            
            (bool success, ) = mark.reviewer.call{value: netReward}("");
            require(success, "REWARD_TRANSFER_FAILED");
        }
        
        batch.processed = true;
        batch.processedAt = block.timestamp;
        totalDistributed += totalRewardsPaid;
        
        emit BatchProcessed(date, batch.markIds.length, totalRewardsPaid, totalFeesCollected, block.timestamp);
    }
    
    // ============ 裁决功能 ============
    
    /// @notice 裁决标记（Owner 或授权裁决者）
    function arbitrateMark(uint256 markId, bool isValid, string calldata reason) external onlyArbitrator {
        MarkRecord storage mark = marks[markId];
        require(mark.status == MarkStatus.Pending, "NOT_PENDING");
        
        mark.isValid = isValid;
        
        if (!isValid) {
            mark.status = MarkStatus.Rejected;
            // 更新连续无效计数
            consecutiveInvalidMarks[mark.reviewer]++;
            
            // 检查是否触发冻结
            uint256 threshold = config.maliciousConsecutiveThreshold();
            if (consecutiveInvalidMarks[mark.reviewer] >= threshold) {
                uint256 freezeDuration = config.freezeDurationSeconds();
                freezeUntil[mark.reviewer] = block.timestamp + freezeDuration;
                emit ReviewerFrozen(mark.reviewer, freezeUntil[mark.reviewer]);
            }
            
            emit MarkRejected(markId, mark.reviewer, reason);
        }
    }
    
    /// @notice 旧版裁决标记无效（保留兼容）
    function rejectMark(uint256 markId, string calldata reason) external onlyArbitrator {
        arbitrateMark(markId, false, reason);
    }
    
    /// @notice 手动解冻审查员
    function unfreezeReviewer(address reviewer) external onlyOwner {
        freezeUntil[reviewer] = 0;
        consecutiveInvalidMarks[reviewer] = 0;
        emit ReviewerUnfrozen(reviewer);
    }
    
    // ============ 资金管理 ============
    
    /// @notice 提取累积审查费
    function withdrawFees() external {
        require(msg.sender == feeCollector || msg.sender == owner, "UNAUTHORIZED");
        
        uint256 totalFees = 0;
        for (uint i = 0; i < allDates.length; i++) {
            uint256 date = allDates[i];
            if (dailyBatches[date].processed) {
                totalFees += dailyBatches[date].totalFees;
            }
        }
        
        uint256 available = totalFees - totalFeesWithdrawn;
        require(available > 0, "NO_FEES");
        
        totalFeesWithdrawn += available;
        
        (bool success, ) = feeCollector.call{value: available}("");
        require(success, "FEE_TRANSFER_FAILED");
        
        emit FeeWithdrawn(feeCollector, available);
    }
    
    /// @notice 紧急提取（Owner -only）
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "INSUFFICIENT_BALANCE");
        (bool success, ) = owner.call{value: amount}("");
        require(success, "WITHDRAW_FAILED");
    }
    
    // ============ 查询函数 ============
    
    /// @notice 获取指定日期的批次信息
    function getBatch(uint256 date) external view returns (
        uint256 markCount,
        uint256 totalRewards,
        uint256 totalFees,
        bool processed,
        uint256 processedAt
    ) {
        DailyBatch storage batch = dailyBatches[date];
        return (
            batch.markIds.length,
            batch.totalRewards,
            batch.totalFees,
            batch.processed,
            batch.processedAt
        );
    }
    
    /// @notice 获取审查员统计
    function getReviewerStats(address reviewer) external view returns (
        uint256 validMarks,
        uint256 totalMarks,
        uint256 invalidConsecutive,
        uint256 frozenUntil,
        uint256 accuracyBps
    ) {
        validMarks = validMarkCount[reviewer];
        totalMarks = totalMarkCount[reviewer];
        invalidConsecutive = consecutiveInvalidMarks[reviewer];
        frozenUntil = freezeUntil[reviewer];
        accuracyBps = totalMarks > 0 ? (validMarks * 10000) / totalMarks : 0;
    }
    
    /// @notice 获取待处理批次日期列表
    function getPendingDates() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint i = 0; i < allDates.length; i++) {
            if (!dailyBatches[allDates[i]].processed) {
                count++;
            }
        }
        
        uint256[] memory pending = new uint256[](count);
        uint256 idx = 0;
        for (uint i = 0; i < allDates.length; i++) {
            if (!dailyBatches[allDates[i]].processed) {
                pending[idx++] = allDates[i];
            }
        }
        return pending;
    }
    
    /// @notice 获取合约余额
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /// @notice 获取指定 mark 详情
    function getMark(uint256 markId) external view returns (MarkRecord memory) {
        return marks[markId];
    }
    
    // ============ 内部函数 ============
    
    /// @notice 获取 UTC 日期（当天 0 点 timestamp）
    function _getDate(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / 1 days) * 1 days;
    }
    
    /// @notice 获取已处理日期列表
    function getProcessedDates() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint i = 0; i < allDates.length; i++) {
            if (dailyBatches[allDates[i]].processed) {
                count++;
            }
        }
        
        uint256[] memory processed = new uint256[](count);
        uint256 idx = 0;
        for (uint i = 0; i < allDates.length; i++) {
            if (dailyBatches[allDates[i]].processed) {
                processed[idx++] = allDates[i];
            }
        }
        return processed;
    }
    
    /// @notice 更新配置合约地址
    function setConfig(address _config) external onlyOwner {
        require(_config != address(0), "INVALID_CONFIG");
        config = BronzeAmbassadorConfig(_config);
    }
    
    /// @notice 更新收费地址
    function setFeeCollector(address _feeCollector) external onlyOwner {
        require(_feeCollector != address(0), "INVALID_ADDRESS");
        feeCollector = _feeCollector;
    }
    
    /// @notice 紧急暂停
    function pause() external onlyOwner {
        paused = true;
    }
    
    function unpause() external onlyOwner {
        paused = false;
    }
    
    /// @notice 转移所有权
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "INVALID_ADDRESS");
        owner = _newOwner;
    }
}
