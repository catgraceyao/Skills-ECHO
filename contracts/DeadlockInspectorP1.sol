// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EdgeDeclaration.sol";

/**
 * @title DeadlockInspector
 * @dev ECHO协议 - 死锁预检与循环引用检测合约
 * P1 版本，新增：inspect + checkPostDeploymentRights + checkAssemblyPostDeploymentRights
 */
contract DeadlockInspectorP1 {
    
    struct AssemblyResult {
        bool ok;
        string reason;
    }
    
    event AssemblyApproved(bytes32 indexed assemblyId, string reason);
    event AssemblyRejected(bytes32 indexed assemblyId, string reason);
    
    EdgeDeclaration public edgeDeclaration;
    
    constructor(address _edgeDeclaration) {
        edgeDeclaration = EdgeDeclaration(_edgeDeclaration);
    }
    
    /**
     * @notice P1新增：深度检查节点死锁状态
     * @param nodeId 节点ID
     * @return isDeadlocked 是否死锁
     * @return blockingQuadrant 哪个四权阻塞（0=derive 1=expand 2=inherit 3=flower，4=无）
     * @return blockingEdges 导致阻塞的边
     */
    function inspect(bytes32 nodeId) 
        external 
        view 
        returns (
            bool isDeadlocked,
            uint8 blockingQuadrant,
            bytes32[] memory blockingEdges
        ) 
    {
        CreatorConfig creatorConfig = edgeDeclaration.creatorConfig();
        if (!creatorConfig.exists(nodeId)) {
            return (true, 4, new bytes32[](0));
        }
        
        (,, uint8[4] memory rights) = creatorConfig.getNode(nodeId);
        
        // 检查四权：derive=0, expand=1, inherit=2, flower=3
        for (uint8 i = 0; i < 4; i++) {
            if (rights[i] == 0) {
                return (true, i, new bytes32[](0));
            }
        }
        
        // 检查循环引用
        EdgeDeclaration.Edge[] memory edges = edgeDeclaration.getEdges(nodeId);
        bytes32[] memory cyclic = new bytes32[](edges.length);
        uint256 count = 0;
        
        for (uint i = 0; i < edges.length; i++) {
            if (edgeDeclaration.hasEdge(edges[i].toNode, nodeId)) {
                cyclic[count] = edges[i].toNode;  // 返回导致循环的target node
                count++;
            }
        }
        
        if (count > 0) {
            bytes32[] memory result = new bytes32[](count);
            for (uint i = 0; i < count; i++) {
                result[i] = cyclic[i];
            }
            return (true, 4, result);
        }
        
        return (false, 4, new bytes32[](0));
    }
    
    /**
     * @notice P1新增：检查节点部署后四权状态
     * @param nodeId 节点ID
     * @return expandOk 扩展权是否>0
     * @return deriveOk 衍生权是否>0
     * @return reason 未通过原因
     */
    function checkPostDeploymentRights(bytes32 nodeId) 
        external 
        view 
        returns (bool expandOk, bool deriveOk, string memory reason) 
    {
        CreatorConfig creatorConfig = edgeDeclaration.creatorConfig();
        if (!creatorConfig.exists(nodeId)) {
            return (false, false, "Node does not exist");
        }
        
        (,, uint8[4] memory rights) = creatorConfig.getNode(nodeId);
        expandOk = rights[2] > 0;  // expandRight
        deriveOk = rights[0] > 0;   // deriveRight
        
        if (!expandOk && !deriveOk) {
            reason = "Both expand and derive rights are 0";
        } else if (!expandOk) {
            reason = "expandRight is 0";
        } else if (!deriveOk) {
            reason = "deriveRight is 0";
        } else {
            reason = "";
        }
    }
    
    /**
     * @notice P1新增：批量检查 Assembly 中所有节点的四权
     * @param nodeIds 节点ID数组
     * @return allOk 是否全部通过
     * @return reason 未通过原因
     */
    function checkAssemblyPostDeploymentRights(bytes32[] calldata nodeIds) 
        external 
        view 
        returns (bool allOk, string memory reason) 
    {
        if (nodeIds.length < 2) {
            return (false, "Assembly requires at least 2 nodes");
        }
        
        CreatorConfig creatorConfig = edgeDeclaration.creatorConfig();
        
        for (uint i = 0; i < nodeIds.length; i++) {
            if (!creatorConfig.exists(nodeIds[i])) {
                return (false, "Node does not exist");
            }
            
            (,, uint8[4] memory rights) = creatorConfig.getNode(nodeIds[i]);
            if (rights[2] == 0) {  // expandRight
                return (false, "Node not expandable");
            }
            if (rights[0] == 0) {  // deriveRight
                return (false, "Node not derivable");
            }
        }
        
        return (true, "");
    }
    
    // P0 保留函数
    function checkModuleComposability(bytes32 nodeId) external view returns (bool ok) {
        CreatorConfig creatorConfig = edgeDeclaration.creatorConfig();
        if (!creatorConfig.exists(nodeId)) return false;
        (,, uint8[4] memory rights) = creatorConfig.getNode(nodeId);
        return rights[2] > 0;
    }
    
    function checkAssemblyDeadlock(bytes32[] calldata nodeIds) 
        external 
        view 
        returns (bool ok, string memory reason) 
    {
        if (nodeIds.length < 2) return (false, "Assembly requires at least 2 nodes");
        
        CreatorConfig creatorConfig = edgeDeclaration.creatorConfig();
        
        for (uint i = 0; i < nodeIds.length; i++) {
            if (!creatorConfig.exists(nodeIds[i])) return (false, "Node does not exist");
            (,, uint8[4] memory rights) = creatorConfig.getNode(nodeIds[i]);
            if (rights[2] == 0) return (false, "Node not composable (expandRight = 0)");
        }
        
        for (uint i = 0; i < nodeIds.length; i++) {
            EdgeDeclaration.Edge[] memory outgoing = edgeDeclaration.getEdges(nodeIds[i]);
            for (uint j = 0; j < outgoing.length; j++) {
                bytes32 targetNode = outgoing[j].toNode;
                bool inAssembly = false;
                for (uint k = 0; k < nodeIds.length; k++) {
                    if (nodeIds[k] == targetNode) { inAssembly = true; break; }
                }
                if (inAssembly && edgeDeclaration.hasEdge(targetNode, nodeIds[i])) {
                    return (false, "Circular reference detected");
                }
            }
        }
        
        return (true, "");
    }
    
    function generateAssemblyId(bytes32[] calldata nodeIds) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(nodeIds));
    }
    
    function approveAssembly(bytes32[] calldata nodeIds) external {
        (bool ok, string memory reason) = this.checkAssemblyDeadlock(nodeIds);
        bytes32 assemblyId = this.generateAssemblyId(nodeIds);
        if (ok) emit AssemblyApproved(assemblyId, reason);
        else emit AssemblyRejected(assemblyId, reason);
    }
}
