// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CreatorConfig.sol";

/**
 * @title EdgeDeclaration
 * @dev ECHO协议 - 边声明合约，构建有向无环图（DAG）
 * P0 MVP 版本，支持节点间有向边声明
 */
contract EdgeDeclaration {
    
    // ============ Structs ============
    
    struct Edge {
        bytes32 toNode;
        address declarer;
        uint256 depth;
        uint256 timestamp;
    }
    
    // ============ Events ============
    
    event EdgeDeclared(
        bytes32 indexed fromNode,
        bytes32 indexed toNode,
        address indexed declarer,
        uint256 depth,
        uint256 timestamp
    );
    
    // ============ State ============
    
    CreatorConfig public creatorConfig;
    
    // fromNode => edges array
    mapping(bytes32 => Edge[]) public edges;
    
    // fromNode => toNode => exists (prevent duplicate edges)
    mapping(bytes32 => mapping(bytes32 => bool)) public edgeExists;
    
    // ============ Constructor ============
    
    constructor(address _creatorConfig) {
        creatorConfig = CreatorConfig(_creatorConfig);
    }
    
    // ============ External Functions ============
    
    /**
     * @notice 声明从 fromNode 到 toNode 的有向边
     * @param fromNode 源节点ID
     * @param toNode 目标节点ID
     * @param depth 边的深度/权重
     */
    function declareEdge(
        bytes32 fromNode, 
        bytes32 toNode, 
        uint256 depth
    ) external {
        // 两个节点都必须存在
        require(creatorConfig.exists(fromNode), "From node does not exist");
        require(creatorConfig.exists(toNode), "To node does not exist");
        
        // 防止自环
        require(fromNode != toNode, "Self-loop not allowed");
        
        // 防止重复边
        require(!edgeExists[fromNode][toNode], "Edge already exists");
        
        edges[fromNode].push(Edge({
            toNode: toNode,
            declarer: msg.sender,
            depth: depth,
            timestamp: block.timestamp
        }));
        
        edgeExists[fromNode][toNode] = true;
        
        emit EdgeDeclared(
            fromNode,
            toNode,
            msg.sender,
            depth,
            block.timestamp
        );
    }
    
    /**
     * @notice 获取某个节点的所有出边
     * @param fromNode 源节点ID
     * @return Edge[] 出边数组
     */
    function getEdges(bytes32 fromNode) external view returns (Edge[] memory) {
        return edges[fromNode];
    }
    
    /**
     * @notice 获取某个节点的出边数量
     * @param fromNode 源节点ID
     */
    function getEdgeCount(bytes32 fromNode) external view returns (uint256) {
        return edges[fromNode].length;
    }
    
    /**
     * @notice 检查两个节点之间是否存在边
     * @param fromNode 源节点ID
     * @param toNode 目标节点ID
     */
    function hasEdge(bytes32 fromNode, bytes32 toNode) 
        external 
        view 
        returns (bool) 
    {
        return edgeExists[fromNode][toNode];
    }
}
