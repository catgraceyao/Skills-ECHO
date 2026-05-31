// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MilestoneEscrow
 * @dev ECHO协议 - 里程碑保证金合约
 * P0 MVP 版本，支持里程碑资金锁定、释放和紧急退款
 */
contract MilestoneEscrow is Ownable {
    
    // ============ Structs ============
    
    struct Milestone {
        address creator;
        uint256 totalAmount;
        uint8 milestoneCount;
        uint8 releasedCount;
        mapping(uint8 => bool) released;
        bool emergencyRefunded;
    }
    
    // ============ Events ============
    
    event MilestoneLocked(
        bytes32 indexed projectId,
        uint256 amount,
        uint8 milestoneCount,
        uint256 timestamp
    );
    
    event MilestoneReleased(
        bytes32 indexed projectId,
        uint256 amount,
        uint8 milestone,
        uint256 timestamp
    );
    
    event EmergencyRefund(
        bytes32 indexed projectId,
        uint256 amount,
        uint256 timestamp
    );
    
    event PhaseTransition(
        bytes32 indexed nodeId,
        uint8 indexed phase,
        uint8 reasonCode,
        uint256 timestamp
    );
    
    // ============ State ============
    
    mapping(bytes32 => Milestone) public milestones;
    mapping(bytes32 => bool) public projectExists;
    
    // P1: milestone -> phase mapping (六相相位绑定)
    mapping(bytes32 => uint8) public milestonePhase;
    
    // ============ Constructor ============
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    // ============ External Functions ============
    
    /**
     * @notice 锁定里程碑资金
     * @param projectId 项目唯一标识
     * @param amount 锁定金额（必须与 msg.value 一致）
     * @param milestoneCount 里程碑数量（如 3 表示分 3 阶段）
     */
    function lockMilestone(bytes32 projectId, uint256 amount, uint8 milestoneCount) 
        external 
        payable 
    {
        require(msg.value == amount, "ETH amount mismatch");
        require(amount > 0, "Must send ETH");
        require(milestoneCount > 0, "Milestone count must be > 0");
        require(!projectExists[projectId], "Project already exists");
        
        Milestone storage ms = milestones[projectId];
        ms.creator = msg.sender;
        ms.totalAmount = msg.value;
        ms.milestoneCount = milestoneCount;
        ms.releasedCount = 0;
        ms.emergencyRefunded = false;
        
        projectExists[projectId] = true;
        
        emit MilestoneLocked(
            projectId,
            msg.value,
            milestoneCount,
            block.timestamp
        );
        
        // P1: PhaseTransition — lock triggers 震/sunrise (phase=1)
        emit PhaseTransition(
            projectId,
            1,  // 震/sunrise
            1,  // reasonCode=lock
            block.timestamp
        );
    }
    
    /**
     * @notice 释放指定里程碑资金（仅项目创建者或合约 owner）
     * @param projectId 项目ID
     * @param milestone 里程碑编号（0-based，0 到 milestoneCount-1）
     */
    function releaseMilestone(bytes32 projectId, uint8 milestone) 
        external 
        onlyOwnerOrCreator(projectId) 
    {
        require(projectExists[projectId], "Project does not exist");
        require(!milestones[projectId].emergencyRefunded, "Already refunded");
        require(milestone < milestones[projectId].milestoneCount, "Invalid milestone");
        require(!milestones[projectId].released[milestone], "Milestone already released");
        
        Milestone storage ms = milestones[projectId];
        
        uint256 releaseAmount = ms.totalAmount / ms.milestoneCount;
        
        // 如果是最后一个里程碑，释放剩余全部（避免除不尽）
        if (milestone == ms.milestoneCount - 1) {
            releaseAmount = ms.totalAmount - (releaseAmount * (ms.milestoneCount - 1));
        }
        
        ms.released[milestone] = true;
        ms.releasedCount++;
        
        (bool success, ) = payable(ms.creator).call{value: releaseAmount}("");
        require(success, "Transfer failed");
        
        emit MilestoneReleased(
            projectId,
            releaseAmount,
            milestone,
            block.timestamp
        );
        
        // P1: PhaseTransition — release triggers 流行 (phase=2)
        emit PhaseTransition(
            projectId,
            2,  // 流行
            2,  // reasonCode=released
            block.timestamp
        );
    }
    
    /**
     * @notice 紧急退款（仅项目创建者或合约 owner）
     * @param projectId 项目ID
     */
    function emergencyRefund(bytes32 projectId) 
        external 
        onlyOwnerOrCreator(projectId) 
    {
        require(projectExists[projectId], "Project does not exist");
        require(!milestones[projectId].emergencyRefunded, "Already refunded");
        
        Milestone storage ms = milestones[projectId];
        
        uint256 refundAmount = ms.totalAmount;
        uint256 alreadyReleased = (ms.totalAmount / ms.milestoneCount) * ms.releasedCount;
        
        // 扣除已释放的部分
        if (alreadyReleased < refundAmount) {
            refundAmount = refundAmount - alreadyReleased;
        } else {
            refundAmount = 0;
        }
        
        require(refundAmount > 0, "Nothing to refund");
        
        ms.emergencyRefunded = true;
        
        (bool success, ) = payable(ms.creator).call{value: refundAmount}("");
        require(success, "Refund failed");
        
        emit EmergencyRefund(
            projectId,
            refundAmount,
            block.timestamp
        );
        
        // P1: PhaseTransition — emergencyRefund triggers 性命/sunset (phase=5)
        emit PhaseTransition(
            projectId,
            5,  // 性命/sunset
            5,  // reasonCode=sunset
            block.timestamp
        );
    }
    
    /**
     * @notice 获取项目里程碑信息
     * @param projectId 项目ID
     */
    function getMilestoneInfo(bytes32 projectId) 
        external 
        view 
        returns (
            address creator,
            uint256 totalAmount,
            uint8 milestoneCount,
            uint8 releasedCount,
            bool emergencyRefunded
        ) 
    {
        require(projectExists[projectId], "Project does not exist");
        Milestone storage ms = milestones[projectId];
        return (
            ms.creator,
            ms.totalAmount,
            ms.milestoneCount,
            ms.releasedCount,
            ms.emergencyRefunded
        );
    }
    
    /**
     * @notice 检查某个里程碑是否已释放
     * @param projectId 项目ID
     * @param milestone 里程碑编号
     */
    function isReleased(bytes32 projectId, uint8 milestone) 
        external 
        view 
        returns (bool) 
    {
        require(projectExists[projectId], "Project does not exist");
        return milestones[projectId].released[milestone];
    }
    
    /**
     * @dev Governance binds a milestone project to a specific phase (六相)
     * @param projectId The milestone project ID
     * @param phase Phase code (1-5, matching 六相)
     */
    function bindMilestonePhase(bytes32 projectId, uint8 phase) external onlyOwner {
        require(phase <= 5, "Invalid phase");
        milestonePhase[projectId] = phase;
    }

    /**
     * @dev Get the phase bound to a milestone project
     * @param projectId The milestone project ID
     * @return The phase code (0 if not bound)
     */
    function getMilestonePhase(bytes32 projectId) external view returns (uint8) {
        return milestonePhase[projectId];
    }

    // ============ Modifiers ============
    
    modifier onlyOwnerOrCreator(bytes32 projectId) {
        require(
            msg.sender == owner() || 
            (projectExists[projectId] && msg.sender == milestones[projectId].creator),
            "Not authorized"
        );
        _;
    }
    
    // ============ Receive ============
    
    receive() external payable {
        revert("Use lockMilestone() to deposit");
    }
}
