// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EdgeDeclaration.sol";

/**
 * @title DeadlockInspector
 * @dev ECHO协议 - 死锁预检与循环引用检测合约
 * P0 MVP 版本，支持模块可组合性检查和组装死锁检测
 */
contract DeadlockInspector {
    
    // ============ Structs ============
    
    struct AssemblyResult {
        bool ok;
        string reason;
    }
    
    // ============ Events ============
    
    event AssemblyApproved(
        bytes32 indexed assemblyId,
        string reason
    );
    
    event AssemblyRejected(
        bytes32 indexed assemblyId,
        string reason
    );
    
    // ============ State ============
    
    EdgeDeclaration public edgeDeclaration;
    
    // ============ Constructor ============
    
    constructor(address _edgeDeclaration) {
        edgeDeclaration = EdgeDeclaration(_edgeDeclaration);
    }
    
    // ============ External Functions ============
    
    /**
     * @notice 检查单个节点是否允许被组合（expandRight > 0）
     * @param nodeId 节点ID
     * @return ok true 表示该节点可被扩展/组合
     */
    function checkModuleComposability(bytes32 nodeId) 
        external 
        view 
        returns (bool ok) 
    {
        CreatorConfig creatorConfig = edgeDeclaration.creatorConfig();
        if (!creatorConfig.exists(nodeId)) {
            return false;
        }
        (,, uint8[4] memory rights) = creatorConfig.getNode(nodeId);
        // rights[2] = expandRight
        return rights[2] > 0;
    }
    
    /**
     * @notice 检查一批节点能否无死锁地组合成 Assembly
     * @param nodeIds 参与组合的全部节点ID（无序数组，长度 >= 2）
     * @return ok true 表示通过检查，可安全组合
     * @return reason 未通过时的具体原因
     */
    function checkAssemblyDeadlock(bytes32[] calldata nodeIds) 
        external 
        view 
        returns (bool ok, string memory reason) 
    {
        if (nodeIds.length < 2) {
            return (false, "Assembly requires at least 2 nodes");
        }
        
        CreatorConfig creatorConfig = edgeDeclaration.creatorConfig();
        
        // 检查所有节点是否存在且可组合
        for (uint i = 0; i < nodeIds.length; i++) {
            if (!creatorConfig.exists(nodeIds[i])) {
                return (false, "Node does not exist");
            }
            
            (,, uint8[4] memory rights) = creatorConfig.getNode(nodeIds[i]);
            if (rights[2] == 0) {
                return (false, "Node not composable (expandRight = 0)");
            }
        }
        
        // 检查循环引用（简化版：检查2跳循环 A->B->A）
        for (uint i = 0; i < nodeIds.length; i++) {
            EdgeDeclaration.Edge[] memory outgoing = edgeDeclaration.getEdges(nodeIds[i]);
            
            for (uint j = 0; j < outgoing.length; j++) {
                bytes32 targetNode = outgoing[j].toNode;
                
                // 检查 targetNode 是否在 assembly 中
                bool inAssembly = false;
                for (uint k = 0; k < nodeIds.length; k++) {
                    if (nodeIds[k] == targetNode) {
                        inAssembly = true;
                        break;
                    }
                }
                
                if (inAssembly) {
                    // 检查是否存在反向边（targetNode -> nodeIds[i]）
                    if (edgeDeclaration.hasEdge(targetNode, nodeIds[i])) {
                        return (false, "Circular reference detected");
                    }
                }
            }
        }
        
        return (true, "");
    }
    
    /**
     * @notice 生成 Assembly ID（keccak256 哈希）
     * @param nodeIds 节点ID数组
     * @return assemblyId 确定性 Assembly ID
     */
    function generateAssemblyId(bytes32[] calldata nodeIds) 
        external 
        pure 
        returns (bytes32 assemblyId) 
    {
        return keccak256(abi.encodePacked(nodeIds));
    }
    
    /**
     * @notice 完整 Assembly 检查并触发事件（payable 用于链上记录）
     * @param nodeIds 节点ID数组
     */
    function approveAssembly(bytes32[] calldata nodeIds) external {
        (bool ok, string memory reason) = this.checkAssemblyDeadlock(nodeIds);
        bytes32 assemblyId = this.generateAssemblyId(nodeIds);
        
        if (ok) {
            emit AssemblyApproved(assemblyId, reason);
        } else {
            emit AssemblyRejected(assemblyId, reason);
        }
    }
}
