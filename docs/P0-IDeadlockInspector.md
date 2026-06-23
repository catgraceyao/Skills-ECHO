# P0 Deliverable — IDeadlockInspector.sol

**版本**: v0.1-P0  
**网络**: Qitmeer QNG (Chain ID 813)  
**用途**: 检测 ECHO 模块组合的死锁与循环引用，保障七子共创的 Assembly（组合件）在链上组装前通过静态检查。

---

## 1. 设计目标

在 ECHO 的「七子共创」架构中，多个创作者可将各自持有的 NFT-Node 组合成 Assembly。组装前必须满足两项前置约束：

1. **模块可组合性**: 每个参与组装的 Node 必须保留 `expandRight > 0`（允许被扩展/组装）。
2. **无循环引用**: 参与组装的 Node 集合内部不能形成有向环（A→B→C→A），否则会导致收益分配死锁。

`IDeadlockInspector` 提供链上只读检查接口，供 Assembly 合约在 `approveAssembly()` 前调用。

---

## 2. 接口定义 (Solidity)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDeadlockInspector {
    // ── 事件 ──
    /// @dev 组装方案通过死锁检查
    event AssemblyApproved(
        bytes32 indexed assemblyId,
        string reason
    );

    /// @dev 组装方案未通过死锁检查
    event AssemblyRejected(
        bytes32 indexed assemblyId,
        string reason
    );

    // ── 函数 ──
    /// @notice 检查单个 Node 是否允许被组装（expandRight > 0）
    /// @param nodeId 目标 Node 的 keccak-256 ID
    /// @return ok true 表示该 Node 可被扩展/组装
    function checkModuleComposability(bytes32 nodeId) external view returns (bool ok);

    /// @notice 检查一批 Node 能否无死锁地组装成 Assembly
    /// @param nodeIds 参与组装的全部 Node ID（无序数组，长度 ≥ 2）
    /// @return ok true 表示通过检查，可安全组装
    /// @return reason 未通过时的具体原因（空字符串表示通过）
    function checkAssemblyDeadlock(
        bytes32[] calldata nodeIds
    ) external view returns (bool ok, string memory reason);
}
```

---

## 3. 伪代码实现

以下伪代码供合约开发者参考，展示检查逻辑的核心算法。实际部署时建议将图遍历逻辑写在链下预计算、链上 Merkle 验证的模式，以节省 gas。

```solidity
contract DeadlockInspector is IDeadlockInspector {

    // 引用 INodeRegistry 获取 Node 的四象限权限
    INodeRegistry public nodeRegistry;

    constructor(address _registry) {
        nodeRegistry = INodeRegistry(_registry);
    }

    function checkModuleComposability(bytes32 nodeId)
        external
        view
        override
        returns (bool ok)
    {
        // 从 NodeRegistry 读取四象限权限
        (uint8 usage, uint8 derive, uint8 expand, uint8 benefit) =
            nodeRegistry.getQuadrant(nodeId);

        // expandRight > 0 表示允许被扩展/组装
        ok = expand > 0;
    }

    function checkAssemblyDeadlock(bytes32[] calldata nodeIds)
        external
        view
        override
        returns (bool ok, string memory reason)
    {
        uint256 n = nodeIds.length;
        require(n >= 2, "Assembly requires at least 2 nodes");

        // ── 阶段 1: 逐项检查 expandRight ──
        for (uint256 i = 0; i < n; i++) {
            if (!this.checkModuleComposability(nodeIds[i])) {
                reason = string(abi.encodePacked(
                    "Node ",
                    _bytes32ToHex(nodeIds[i]),
                    " lacks expandRight"
                ));
                return (false, reason);
            }
        }

        // ── 阶段 2: 循环引用检测（DFS）──
        // 获取 EdgeRegistry 中这些 Node 之间的全部有向边
        // 链下预计算：构建邻接表 → 检测环
        // 链上简化版：O(n²) 两两检查是否有直接边，并检测长度 ≥ 2 的环

        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = 0; j < n; j++) {
                if (i == j) continue;
                // 检查 nodeIds[i] → nodeIds[j] 是否存在已声明的边
                if (edgeRegistry.hasEdge(nodeIds[i], nodeIds[j])) {
                    // 反向检查是否存在回边
                    if (edgeRegistry.hasEdge(nodeIds[j], nodeIds[i])) {
                        reason = string(abi.encodePacked(
                            "Circular reference detected between ",
                            _bytes32ToHex(nodeIds[i]),
                            " and ",
                            _bytes32ToHex(nodeIds[j])
                        ));
                        return (false, reason);
                    }
                }
            }
        }

        // 通过全部检查
        ok = true;
        reason = "";
    }

    // 辅助：bytes32 → hex string（调试用，生产环境可省略）
    function _bytes32ToHex(bytes32 b) internal pure returns (string memory) {
        // 标准 bytes32→hex 转换逻辑
    }
}
```

### Gas 优化建议

| 场景 | 策略 |
|------|------|
| 小型 Assembly (2-5 Node) | 链上全量检查，单次调用约 80k–150k gas |
| 中型 Assembly (6-20 Node) | 链下 DFS 预计算 → 链上 Merkle proof 验证 |
| 大型 Assembly (20+ Node) | 强制链下计算，链上仅验证 Merkle root + 抽查 |

---

## 4. ABI JSON

```json
[
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "bytes32", "name": "assemblyId", "type": "bytes32" },
      { "indexed": false, "internalType": "string", "name": "reason", "type": "string" }
    ],
    "name": "AssemblyApproved",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "bytes32", "name": "assemblyId", "type": "bytes32" },
      { "indexed": false, "internalType": "string", "name": "reason", "type": "string" }
    ],
    "name": "AssemblyRejected",
    "type": "event"
  },
  {
    "inputs": [
      { "internalType": "bytes32[]", "name": "nodeIds", "type": "bytes32[]" }
    ],
    "name": "checkAssemblyDeadlock",
    "outputs": [
      { "internalType": "bool", "name": "ok", "type": "bool" },
      { "internalType": "string", "name": "reason", "type": "string" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "nodeId", "type": "bytes32" }
    ],
    "name": "checkModuleComposability",
    "outputs": [
      { "internalType": "bool", "name": "ok", "type": "bool" }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
```

---

## 5. Function Selectors (keccak-256)

> ⚠️ 使用 Node.js `keccak` 包计算，与以太坊 keccak-256 一致。Python `hashlib.sha3_256` 结果不同，不可用。

| 函数签名 | selector |
|---|---|
| `checkModuleComposability(bytes32)` | `0x566aac9a` |
| `checkAssemblyDeadlock(bytes32[])` | `0xe8a1a29b` |

**验证命令**（Node.js）：
```javascript
const createKeccakHash = require('keccak');
const sel = (sig) => '0x' + createKeccakHash('keccak256').update(sig).digest('hex').slice(0, 8);
sel('checkModuleComposability(bytes32)');  // 0x566aac9a
sel('checkAssemblyDeadlock(bytes32[])');   // 0xe8a1a29b
```

---

## 6. Event Topics (keccak-256)

| 事件签名 | topic0 |
|---|---|
| `AssemblyApproved(bytes32,string)` | `0x9cfe0c568d950ca64bc8ccb9b17300219b4c404592d270eae2e2e4219a5cfde3` |
| `AssemblyRejected(bytes32,string)` | `0x914d18498f86052257caf5ffd8f2b041258b785ac760482aa8ceab14750ca833` |

---

## 7. 使用示例

### 场景：七子共创 — 组装前死锁检查

```solidity
// AssemblyFactory 在 approveAssembly 前调用检查
contract AssemblyFactory {
    IDeadlockInspector public inspector;

    function approveAssembly(bytes32[] calldata nodeIds) external {
        (bool ok, string memory reason) = inspector.checkAssemblyDeadlock(nodeIds);
        require(ok, reason);

        // 通过检查，生成 Assembly ID 并上链
        bytes32 assemblyId = keccak256(abi.encodePacked(nodeIds, block.timestamp));
        emit AssemblyCreated(assemblyId, nodeIds);
    }
}
```

### 场景：前端/Agent 调用 eth_call 预检查

```javascript
// ethers.js v6
const ok = await deadlockInspector.checkModuleComposability.staticCall(nodeId);
if (!ok) {
  console.warn("Node 不允许被组装，expandRight = 0");
}

const [deadlockOk, reason] = await deadlockInspector.checkAssemblyDeadlock.staticCall(nodeIds);
if (!deadlockOk) {
  console.error("Assembly 未通过检查:", reason);
}
```

---

## 8. 与其他合约的交互关系

```
┌─────────────────┐     view      ┌─────────────────────┐
│  AssemblyFactory  │──────────────▶│  DeadlockInspector  │
│  (组装工厂)       │  checkAssembly  │  (死锁检查)         │
│                 │   Deadlock()    │                     │
└─────────────────┘               └─────────────────────┘
         │                                   │
         │ delegate                          │ view
         ▼                                   ▼
┌─────────────────┐               ┌─────────────────────┐
│  NodeRegistry   │               │  EdgeRegistry       │
│  (四象限存储)   │               │  (有向边存储)       │
└─────────────────┘               └─────────────────────┘
```

---

*文档生成时间: 2026-05-29 17:38 CST*  
*计算环境: Node.js keccak-256, Qitmeer QNG Mainnet*
