// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CreatorConfig
 * @dev ECHO协议 - 节点创建与四权配置合约
 * P0 MVP 版本，支持节点创建和四权（usage/derive/expand/benefit）配置
 */
contract CreatorConfig is Ownable {
    
    // ============ Structs ============
    
    struct Node {
        address creator;
        uint256 timestamp;
        uint8[4] rights; // [usage, derive, expand, benefit]
    }
    
    // ============ Events ============
    
    event NodeCreated(
        bytes32 indexed nodeId,
        address indexed creator,
        uint256 timestamp,
        uint8 usageRight,
        uint8 deriveRight,
        uint8 expandRight,
        uint8 benefitRight
    );
    
    event QuadrantSet(
        bytes32 indexed nodeId,
        uint8 usageRight,
        uint8 deriveRight,
        uint8 expandRight,
        uint8 benefitRight
    );
    
    // ============ State ============
    
    mapping(bytes32 => Node) public nodes;
    mapping(bytes32 => bool) public nodeExists;
    
    // ============ Modifiers ============
    
    modifier onlyNodeCreator(bytes32 nodeId) {
        require(nodeExists[nodeId], "Node does not exist");
        require(nodes[nodeId].creator == msg.sender, "Not node creator");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    // ============ External Functions ============
    
    /**
     * @notice 创建新节点并设置四权
     * @param nodeId 节点的唯一标识（keccak256哈希）
     * @param rights 四权数组：[usage, derive, expand, benefit]，每个值 0-255
     */
    function createNode(bytes32 nodeId, uint8[4] calldata rights) external {
        require(!nodeExists[nodeId], "Node already exists");
        require(rights.length == 4, "Invalid rights array length");
        
        nodes[nodeId] = Node({
            creator: msg.sender,
            timestamp: block.timestamp,
            rights: rights
        });
        nodeExists[nodeId] = true;
        
        emit NodeCreated(
            nodeId,
            msg.sender,
            block.timestamp,
            rights[0],
            rights[1],
            rights[2],
            rights[3]
        );
    }
    
    /**
     * @notice 更新节点四权（仅节点创建者可调用）
     * @param nodeId 节点ID
     * @param rights 新的四权数组
     */
    function updateQuadrant(bytes32 nodeId, uint8[4] calldata rights) 
        external 
        onlyNodeCreator(nodeId) 
    {
        require(rights.length == 4, "Invalid rights array length");
        
        nodes[nodeId].rights = rights;
        
        emit QuadrantSet(
            nodeId,
            rights[0],
            rights[1],
            rights[2],
            rights[3]
        );
    }
    
    /**
     * @notice 获取节点信息
     * @param nodeId 节点ID
     * @return creator 创建者地址
     * @return timestamp 创建时间戳
     * @return rights 四权数组
     */
    function getNode(bytes32 nodeId) 
        external 
        view 
        returns (address creator, uint256 timestamp, uint8[4] memory rights) 
    {
        require(nodeExists[nodeId], "Node does not exist");
        Node memory node = nodes[nodeId];
        return (node.creator, node.timestamp, node.rights);
    }
    
    /**
     * @notice 检查节点是否存在
     * @param nodeId 节点ID
     */
    function exists(bytes32 nodeId) external view returns (bool) {
        return nodeExists[nodeId];
    }
}
