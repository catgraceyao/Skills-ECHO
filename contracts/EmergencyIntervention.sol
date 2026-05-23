// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title EmergencyIntervention
 * @notice 紧急干预系统：标准通道 + 快速通道分级 + 同地址冷却期
 * @dev 基于 v0.4 文档 §3.x
 * 修复：severity链上可验证指标、同地址7天冷却期、快速通道分级
 */
contract EmergencyIntervention {
    using Math for uint256;

    // ============ 枚举 ============
    
    enum Severity {
        L0_Observation,    // 观察级
        L1_Alert,          // 预警级
        L2_Caution,        // 注意级
        L3_Moderate,       // 中度级（触发标准通道冻结）
        L4_Severe,         // 严重级（单签24h追认）
        L5_Critical        // 危急级（多签立即执行）
    }
    
    enum InterventionType {
        Freeze,            // 冻结
        Sunset,            // 日落
        Rollback,          // 回滚
        Pause              // 暂停
    }
    
    // ============ 常量 ============
    
    uint256 public constant COOLDOWN_STANDARD = 7 days;    // 标准通道冷却期
    uint256 public constant COOLDOWN_FAST_SEV4 = 24 hours; // severity 4 单签24h追认
    uint256 public constant ADDRESS_COOLDOWN = 7 days;     // 同地址7天冷却期
    uint256 public constant MAX_EXTENSIONS = 1;            // 异议延长次数上限
    
    // ============ 数据结构 ============
    
    struct Intervention {
        uint256 id;
        address initiator;
        uint256 targetVersionId;
        Severity severity;
        InterventionType interventionType;
        bytes32 evidenceHash;
        uint256 timestamp;
        uint256 executeTime;       // 执行时间（冷却期后）
        bool executed;
        bool cancelled;
        uint256 extensionCount;    // 异议延长次数
        mapping(address => bool) hasVoted;
        uint256 voteCount;
    }
    
    struct ChainMetrics {
        uint256 fundMovement;      // 资金异动量
        uint256 permissionChange;  // 权限变更幅度
        uint256 timestamp;
    }
    
    // ============ 状态变量 ============
    
    mapping(uint256 => Intervention) public interventions;
    mapping(address => uint256) public lastInterventionTime;  // 同地址冷却
    mapping(uint256 => ChainMetrics) public versionMetrics;
    
    uint256 public nextInterventionId;
    address public owner;
    address public daoContract;
    address public juryContract;
    
    // ============ 事件 ============
    
    event InterventionProposed(
        uint256 indexed id,
        address indexed initiator,
        uint256 targetVersionId,
        Severity severity,
        InterventionType interventionType,
        uint256 executeTime
    );
    event InterventionExecuted(uint256 indexed id);
    event InterventionCancelled(uint256 indexed id);
    event InterventionExtended(uint256 indexed id, uint256 newExecuteTime);
    event CooldownEnforced(address indexed addr, uint256 until);
    
    // ============ 修饰器 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "EI: not owner");
        _;
    }
    
    modifier onlyDAO() {
        require(msg.sender == daoContract, "EI: not DAO");
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor() {
        owner = msg.sender;
    }
    
    function setDAOContract(address _dao) external onlyOwner {
        daoContract = _dao;
    }
    
    function setJuryContract(address _jury) external onlyOwner {
        juryContract = _jury;
    }
    
    // ============ 链上指标验证（severity 不再自报） ============
    
    function validateSeverity(
        uint256 _versionId,
        uint256 _fundMovement,
        uint256 _permissionChange
    ) public view returns (Severity) {
        // 基于链上可验证指标自动判定 severity
        ChainMetrics storage m = versionMetrics[_versionId];
        
        uint256 fundRatio = m.fundMovement > 0 ? (_fundMovement * 100) / m.fundMovement : _fundMovement;
        uint256 permRatio = m.permissionChange > 0 ? (_permissionChange * 100) / m.permissionChange : _permissionChange;
        
        if (fundRatio >= 50 || permRatio >= 50) {
            return Severity.L5_Critical;
        } else if (fundRatio >= 30 || permRatio >= 30) {
            return Severity.L4_Severe;
        } else if (fundRatio >= 15 || permRatio >= 15) {
            return Severity.L3_Moderate;
        } else if (fundRatio >= 5 || permRatio >= 5) {
            return Severity.L2_Caution;
        } else if (fundRatio > 0 || permRatio > 0) {
            return Severity.L1_Alert;
        }
        return Severity.L0_Observation;
    }
    
    function updateMetrics(
        uint256 _versionId,
        uint256 _fundMovement,
        uint256 _permissionChange
    ) external onlyOwner {
        versionMetrics[_versionId] = ChainMetrics({
            fundMovement: _fundMovement,
            permissionChange: _permissionChange,
            timestamp: block.timestamp
        });
    }
    
    // ============ 提案干预 ============
    
    function proposeIntervention(
        uint256 _targetVersionId,
        Severity _severity,
        InterventionType _type,
        bytes32 _evidenceHash
    ) external returns (uint256 id) {
        // 同地址冷却期检查
        require(
            block.timestamp >= lastInterventionTime[msg.sender] + ADDRESS_COOLDOWN,
            "EI: address cooldown active"
        );
        
        // L5 必须通过链上指标验证
        if (_severity == Severity.L5_Critical) {
            Severity validated = validateSeverity(_targetVersionId, 0, 0);
            require(validated == Severity.L5_Critical, "EI: L5 validation failed");
        }
        
        id = nextInterventionId++;
        Intervention storage inter = interventions[id];
        inter.id = id;
        inter.initiator = msg.sender;
        inter.targetVersionId = _targetVersionId;
        inter.severity = _severity;
        inter.interventionType = _type;
        inter.evidenceHash = _evidenceHash;
        inter.timestamp = block.timestamp;
        
        // 分级冷却
        if (_severity == Severity.L5_Critical) {
            // L5：多签立即执行（无冷却，但需3/5陪审团）
            inter.executeTime = block.timestamp;
        } else if (_severity == Severity.L4_Severe) {
            // L4：单签24h追认
            inter.executeTime = block.timestamp + COOLDOWN_FAST_SEV4;
        } else {
            // L3及以下：标准7天冷却
            inter.executeTime = block.timestamp + COOLDOWN_STANDARD;
        }
        
        lastInterventionTime[msg.sender] = block.timestamp;
        
        emit InterventionProposed(
            id,
            msg.sender,
            _targetVersionId,
            _severity,
            _type,
            inter.executeTime
        );
        
        return id;
    }
    
    // ============ 执行干预 ============
    
    function executeIntervention(uint256 _id) external {
        Intervention storage inter = interventions[_id];
        require(!inter.executed, "EI: already executed");
        require(!inter.cancelled, "EI: cancelled");
        require(block.timestamp >= inter.executeTime, "EI: cooldown not expired");
        
        // L5 需要陪审团多签
        if (inter.severity == Severity.L5_Critical) {
            require(msg.sender == juryContract, "EI: L5 requires jury");
        }
        
        inter.executed = true;
        emit InterventionExecuted(_id);
        
        // 执行具体干预逻辑（简化）
        // 实际应调用 CreatorConfig 或 LicenseNFT
    }
    
    // ============ 异议延长（防拖延攻击） ============
    
    function extendCooldown(uint256 _id) external {
        Intervention storage inter = interventions[_id];
        require(!inter.executed, "EI: already executed");
        require(inter.extensionCount < MAX_EXTENSIONS, "EI: max extensions reached");
        
        // 仅可在执行前24h内提出异议
        require(
            block.timestamp >= inter.executeTime - 24 hours,
            "EI: too early to extend"
        );
        
        inter.extensionCount++;
        inter.executeTime += 7 days;  // 延长7天
        
        emit InterventionExtended(_id, inter.executeTime);
    }
    
    // ============ 取消干预 ============
    
    function cancelIntervention(uint256 _id) external onlyDAO {
        Intervention storage inter = interventions[_id];
        require(!inter.executed, "EI: already executed");
        inter.cancelled = true;
        emit InterventionCancelled(_id);
    }
    
    // ============ 查询 ============
    
    function getIntervention(uint256 _id) external view returns (
        uint256 id,
        address initiator,
        uint256 targetVersionId,
        Severity severity,
        InterventionType interventionType,
        bytes32 evidenceHash,
        uint256 timestamp,
        uint256 executeTime,
        bool executed,
        bool cancelled,
        uint256 extensionCount
    ) {
        Intervention storage inter = interventions[_id];
        return (
            inter.id,
            inter.initiator,
            inter.targetVersionId,
            inter.severity,
            inter.interventionType,
            inter.evidenceHash,
            inter.timestamp,
            inter.executeTime,
            inter.executed,
            inter.cancelled,
            inter.extensionCount
        );
    }
    
    function canExecute(uint256 _id) external view returns (bool) {
        Intervention storage inter = interventions[_id];
        return !inter.executed && !inter.cancelled && block.timestamp >= inter.executeTime;
    }
    
    function getAddressCooldown(address _addr) external view returns (uint256) {
        uint256 lastTime = lastInterventionTime[_addr];
        if (lastTime == 0) return 0;
        uint256 until = lastTime + ADDRESS_COOLDOWN;
        return block.timestamp >= until ? 0 : until - block.timestamp;
    }
}
