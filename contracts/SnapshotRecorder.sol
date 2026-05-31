// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SnapshotRecorder
 * @notice ECHO 链上快照基线记录合约 v0.1
 * @dev 定期记录网络关键状态，形成链上存证，便于追溯和审计
 * 
 * 使用场景：
 * - 06-01 联调前建立链上基线
 * - 日常监控数据上链存证
 * - 与链下监控报告交叉验证
 */
contract SnapshotRecorder {
    
    // ============ 类型定义 ============
    
    struct Snapshot {
        uint256 id;              // 快照序号
        uint256 blockNumber;   // 记录时的区块高度
        uint256 timestamp;     // 记录时间戳
        uint256 blockTimeDelta; // 距上一个快照的出块时间（秒）
        
        // AgentJury 摘要
        address agentJury;     // 合约地址
        uint256 agentJuryBalance; // 余额（wei）
        uint256 nextCaseId;    // 下一个案件 ID
        address agentJuryOwner; // Owner
        
        // GovernanceDAO 摘要
        address governanceDAO; // 合约地址
        uint256 governanceDAOBalance; // 余额（wei）
        address governanceDAOOwner; // Owner
        
        // 网络状态
        uint256 networkGasPrice; // 当前 gas price
        uint256 networkDifficulty; // 当前难度（如可用）
        
        // 记录者
        address recorder;        // 谁记录了这个快照
        string memo;           // 备注（如"06-01 基线"、"日常监控"）
    }
    
    // ============ 状态变量 ============
    
    address public owner;
    
    /// @notice 所有快照
    Snapshot[] public snapshots;
    
    /// @notice 快照 ID => 索引
    mapping(uint256 => uint256) public snapshotIndex;
    
    /// @notice 被授权的自动化记录者（bot 地址）
    mapping(address => bool) public authorizedRecorders;
    
    /// @notice AgentJury 合约地址
    address public agentJury;
    
    /// @notice GovernanceDAO 合约地址
    address public governanceDAO;
    
    /// @notice 最小记录间隔（秒）
    uint256 public minRecordInterval = 1 hours;
    
    /// @notice 上一次记录时间
    uint256 public lastRecordTime;
    
    /// @notice 紧急暂停
    bool public paused;
    
    // ============ 事件 ============
    
    event SnapshotRecorded(
        uint256 indexed id,
        uint256 blockNumber,
        uint256 timestamp,
        address indexed recorder,
        string memo
    );
    
    event RecorderAuthorized(address indexed recorder);
    event RecorderRevoked(address indexed recorder);
    event ContractAddressesUpdated(address agentJury, address governanceDAO);
    event MinIntervalUpdated(uint256 oldInterval, uint256 newInterval);
    
    // ============ 修饰符 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }
    
    modifier onlyAuthorized() {
        require(msg.sender == owner || authorizedRecorders[msg.sender], "UNAUTHORIZED");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "PAUSED");
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor(address _agentJury, address _governanceDAO) {
        require(_agentJury != address(0), "INVALID_AGENT_JURY");
        require(_governanceDAO != address(0), "INVALID_GOVERNANCE_DAO");
        owner = msg.sender;
        agentJury = _agentJury;
        governanceDAO = _governanceDAO;
    }
    
    // ============ 核心功能：记录快照 ============
    
    /// @notice 记录一个快照（Owner 或授权者）
    function recordSnapshot(string calldata memo) external onlyAuthorized whenNotPaused returns (uint256 snapshotId) {
        require(block.timestamp >= lastRecordTime + minRecordInterval, "TOO_FREQUENT");
        
        uint256 id = snapshots.length;
        uint256 blockTimeDelta = id > 0 
            ? block.timestamp - snapshots[id - 1].timestamp 
            : 0;
        
        Snapshot memory snap = Snapshot({
            id: id,
            blockNumber: block.number,
            timestamp: block.timestamp,
            blockTimeDelta: blockTimeDelta,
            agentJury: agentJury,
            agentJuryBalance: _getBalance(agentJury),
            nextCaseId: _getNextCaseId(),
            agentJuryOwner: _getOwner(agentJury),
            governanceDAO: governanceDAO,
            governanceDAOBalance: _getBalance(governanceDAO),
            governanceDAOOwner: _getOwner(governanceDAO),
            networkGasPrice: tx.gasprice,
            networkDifficulty: block.difficulty,
            recorder: msg.sender,
            memo: memo
        });
        
        snapshots.push(snap);
        snapshotIndex[id] = id;
        lastRecordTime = block.timestamp;
        
        emit SnapshotRecorded(id, block.number, block.timestamp, msg.sender, memo);
        
        return id;
    }
    
    /// @notice 批量记录（用于初始化或补偿遗漏）
    function batchRecord(
        uint256[] calldata blockNumbers,
        uint256[] calldata timestamps,
        string[] calldata memos
    ) external onlyOwner whenNotPaused {
        require(blockNumbers.length == timestamps.length && timestamps.length == memos.length, "LENGTH_MISMATCH");
        
        for (uint i = 0; i < blockNumbers.length; i++) {
            uint256 id = snapshots.length;
            uint256 blockTimeDelta = id > 0 
                ? timestamps[i] - snapshots[id - 1].timestamp 
                : 0;
            
            snapshots.push(Snapshot({
                id: id,
                blockNumber: blockNumbers[i],
                timestamp: timestamps[i],
                blockTimeDelta: blockTimeDelta,
                agentJury: agentJury,
                agentJuryBalance: 0, // 批量记录不查实时余额
                nextCaseId: 0,
                agentJuryOwner: address(0),
                governanceDAO: governanceDAO,
                governanceDAOBalance: 0,
                governanceDAOOwner: address(0),
                networkGasPrice: 0,
                networkDifficulty: 0,
                recorder: msg.sender,
                memo: memos[i]
            }));
            
            snapshotIndex[id] = id;
            emit SnapshotRecorded(id, blockNumbers[i], timestamps[i], msg.sender, memos[i]);
        }
        
        if (timestamps.length > 0) {
            lastRecordTime = timestamps[timestamps.length - 1];
        }
    }
    
    // ============ 管理功能 ============
    
    function authorizeRecorder(address recorder) external onlyOwner {
        require(recorder != address(0), "INVALID_ADDRESS");
        authorizedRecorders[recorder] = true;
        emit RecorderAuthorized(recorder);
    }
    
    function revokeRecorder(address recorder) external onlyOwner {
        authorizedRecorders[recorder] = false;
        emit RecorderRevoked(recorder);
    }
    
    function setContractAddresses(address _agentJury, address _governanceDAO) external onlyOwner {
        require(_agentJury != address(0), "INVALID_AGENT_JURY");
        require(_governanceDAO != address(0), "INVALID_GOVERNANCE_DAO");
        agentJury = _agentJury;
        governanceDAO = _governanceDAO;
        emit ContractAddressesUpdated(_agentJury, _governanceDAO);
    }
    
    function setMinRecordInterval(uint256 interval) external onlyOwner {
        emit MinIntervalUpdated(minRecordInterval, interval);
        minRecordInterval = interval;
    }
    
    function pause() external onlyOwner {
        paused = true;
    }
    
    function unpause() external onlyOwner {
        paused = false;
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "INVALID_ADDRESS");
        owner = newOwner;
    }
    
    // ============ 查询函数 ============
    
    function getSnapshot(uint256 id) external view returns (Snapshot memory) {
        require(id < snapshots.length, "NOT_FOUND");
        return snapshots[id];
    }
    
    function getSnapshotCount() external view returns (uint256) {
        return snapshots.length;
    }
    
    function getLatestSnapshot() external view returns (Snapshot memory) {
        require(snapshots.length > 0, "NO_SNAPSHOTS");
        return snapshots[snapshots.length - 1];
    }
    
    function getSnapshotsInRange(uint256 startId, uint256 endId) external view returns (Snapshot[] memory) {
        require(endId >= startId, "INVALID_RANGE");
        require(endId < snapshots.length, "OUT_OF_RANGE");
        
        uint256 count = endId - startId + 1;
        Snapshot[] memory result = new Snapshot[](count);
        for (uint i = 0; i < count; i++) {
            result[i] = snapshots[startId + i];
        }
        return result;
    }
    
    function getAverageBlockTime(uint256 count) external view returns (uint256 avgSeconds) {
        require(snapshots.length >= 2, "INSUFFICIENT_DATA");
        if (count == 0 || count > snapshots.length) count = snapshots.length;
        
        uint256 total = 0;
        uint256 validCount = 0;
        
        for (uint i = snapshots.length - count; i < snapshots.length; i++) {
            if (snapshots[i].blockTimeDelta > 0) {
                total += snapshots[i].blockTimeDelta;
                validCount++;
            }
        }
        
        return validCount > 0 ? total / validCount : 0;
    }
    
    // ============ 内部函数 ============
    
    function _getBalance(address addr) internal view returns (uint256) {
        return addr.balance;
    }
    
    function _getOwner(address target) internal view returns (address) {
        // 尝试调用 owner() 函数（0x8da5cb5b）
        (bool success, bytes memory data) = target.staticcall(
            abi.encodeWithSelector(0x8da5cb5b)
        );
        if (success && data.length >= 32) {
            return abi.decode(data, (address));
        }
        return address(0);
    }
    
    function _getNextCaseId() internal view returns (uint256) {
        // 调用 AgentJury.nextCaseId() — 假设为 public 状态变量，自动生成 getter
        (bool success, bytes memory data) = agentJury.staticcall(
            abi.encodeWithSignature("nextCaseId()")
        );
        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }
        return 0;
    }
}
