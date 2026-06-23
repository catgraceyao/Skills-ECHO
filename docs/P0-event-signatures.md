# P0 Deliverable — ECHO Event Signatures Unified Document

**版本**: v0.1-P0  
**网络**: Qitmeer QNG (Chain ID 813)  
**用途**: 统一 ECHO 七子共创项目中所有核心事件的 ABI 签名、topic0 哈希与 indexed 字段解码参考。

---

## 1. 为什么需要统一事件签名

在 ECHO 的多合约架构中（NodeRegistry、EdgeRegistry、AssemblyFactory、MilestoneEscrow、GovernanceDAO、AgentJury 等），前端、索引器（The Graph / Subsquid）、Agent 监听服务都需要精确解析链上事件。本文档作为**唯一可信源 (Single Source of Truth)**，统一所有事件的结构化定义。

---

## 2. 核心事件总览

| 事件名称 | 来源模块 | 触发场景 | topic0 |
|---|---|---|---|
| `NodeCreated` | NodeRegistry | 创作者铸造新 Node | `0x14099851...9b741918` |
| `EdgeDeclared` | EdgeRegistry | 创作者声明 Node 间的有向引用 | `0xcb59a69c...2c56ceb` |
| `QuadrantSet` | NodeRegistry | Node 四象限权限被修改 | `0x71618eac...d44f079` |
| `AssemblyApproved` | DeadlockInspector | 组装方案通过死锁检查 | `0x9cfe0c56...a5cfde3` |
| `AssemblyRejected` | DeadlockInspector | 组装方案未通过死锁检查 | `0x914d1849...50ca833` |
| `MilestoneLocked` | MilestoneEscrow | 资金锁定到项目 escrow | `0x5f15e9b5...21f6c140` |
| `MilestoneReleased` | MilestoneEscrow | 里程碑资金释放 | `0xdd54b35f...abf5a0f` |

---

## 3. 事件详细定义

### 3.1 NodeCreated

创作者在 NodeRegistry 中铸造新 Node 时触发。

```solidity
event NodeCreated(
    bytes32 indexed nodeId,      // Node 唯一标识
    address indexed creator,     // 创作者地址
    uint256 timestamp,           // 铸造时间戳
    uint8 usageRight,          // 使用权限等级
    uint8 deriveRight,         // 衍生权限等级
    uint8 expandRight,           // 扩展/组装权限等级
    uint8 benefitRight           // 收益分配权限等级
);
```

**topic0**: `0x14099851ab7c7f4a85719da2165bc3b1ed0aea38276b15fe41a4c36e9b741918`

**ABI 编码**:
```json
{
  "anonymous": false,
  "inputs": [
    { "indexed": true, "internalType": "bytes32", "name": "nodeId", "type": "bytes32" },
    { "indexed": true, "internalType": "address", "name": "creator", "type": "address" },
    { "indexed": false, "internalType": "uint256", "name": "timestamp", "type": "uint256" },
    { "indexed": false, "internalType": "uint8", "name": "usageRight", "type": "uint8" },
    { "indexed": false, "internalType": "uint8", "name": "deriveRight", "type": "uint8" },
    { "indexed": false, "internalType": "uint8", "name": "expandRight", "type": "uint8" },
    { "indexed": false, "internalType": "uint8", "name": "benefitRight", "type": "uint8" }
  ],
  "name": "NodeCreated",
  "type": "event"
}
```

**indexed 字段解码**:
- `topic[1]` = `nodeId` (bytes32)
- `topic[2]` = `creator` (address, 低 20 字节)
- `data` 中依次编码: `timestamp` (uint256) | `usageRight` (uint8, 左补零到 32 字节) | `deriveRight` | `expandRight` | `benefitRight`

---

### 3.2 EdgeDeclared

创作者声明两个 Node 之间的有向引用边时触发。

```solidity
event EdgeDeclared(
    bytes32 indexed fromNode,    // 引用源 Node
    bytes32 indexed toNode,      // 引用目标 Node
    address indexed declarer,    // 声明者地址
    uint256 depth,               // 引用深度（层级）
    uint256 timestamp            // 声明时间戳
);
```

**topic0**: `0xcb59a69c50a816f2612c07c4a15ed7e4391269cf502635b16da465d2e2c56ceb`

**ABI 编码**:
```json
{
  "anonymous": false,
  "inputs": [
    { "indexed": true, "internalType": "bytes32", "name": "fromNode", "type": "bytes32" },
    { "indexed": true, "internalType": "bytes32", "name": "toNode", "type": "bytes32" },
    { "indexed": true, "internalType": "address", "name": "declarer", "type": "address" },
    { "indexed": false, "internalType": "uint256", "name": "depth", "type": "uint256" },
    { "indexed": false, "internalType": "uint256", "name": "timestamp", "type": "uint256" }
  ],
  "name": "EdgeDeclared",
  "type": "event"
}
```

**indexed 字段解码**:
- `topic[1]` = `fromNode` (bytes32)
- `topic[2]` = `toNode` (bytes32)
- `topic[3]` = `declarer` (address)
- `data` 中依次编码: `depth` (uint256) | `timestamp` (uint256)

---

### 3.3 QuadrantSet

Node 的四象限权限被修改时触发。

```solidity
event QuadrantSet(
    bytes32 indexed nodeId,      // 被修改的 Node
    uint8 usageRight,            // 新使用权限
    uint8 deriveRight,           // 新衍生权限
    uint8 expandRight,           // 新扩展权限
    uint8 benefitRight           // 新收益权限
);
```

**topic0**: `0x71618eac2ec66e68b6fb2308b0e8ccd252f111fad9d66a553fa988088d44f079`

**ABI 编码**:
```json
{
  "anonymous": false,
  "inputs": [
    { "indexed": true, "internalType": "bytes32", "name": "nodeId", "type": "bytes32" },
    { "indexed": false, "internalType": "uint8", "name": "usageRight", "type": "uint8" },
    { "indexed": false, "internalType": "uint8", "name": "deriveRight", "type": "uint8" },
    { "indexed": false, "internalType": "uint8", "name": "expandRight", "type": "uint8" },
    { "indexed": false, "internalType": "uint8", "name": "benefitRight", "type": "uint8" }
  ],
  "name": "QuadrantSet",
  "type": "event"
}
```

**indexed 字段解码**:
- `topic[1]` = `nodeId` (bytes32)
- `data` 中依次编码: `usageRight` | `deriveRight` | `expandRight` | `benefitRight` (各 uint8, 左补零到 32 字节)

---

### 3.4 AssemblyApproved

组装方案通过死锁检查时触发（详见 `P0-IDeadlockInspector.md`）。

```solidity
event AssemblyApproved(
    bytes32 indexed assemblyId,  // 组装方案 ID
    string reason                // 通过原因/描述
);
```

**topic0**: `0x9cfe0c568d950ca64bc8ccb9b17300219b4c404592d270eae2e2e4219a5cfde3`

---

### 3.5 AssemblyRejected

组装方案未通过死锁检查时触发。

```solidity
event AssemblyRejected(
    bytes32 indexed assemblyId,  // 组装方案 ID
    string reason                // 拒绝原因
);
```

**topic0**: `0x914d18498f86052257caf5ffd8f2b041258b785ac760482aa8ceab14750ca833`

---

### 3.6 MilestoneLocked

资金锁定到 MilestoneEscrow 时触发（详见 `P0-IMilestoneEscrow.md`）。

```solidity
event MilestoneLocked(
    bytes32 indexed projectId,   // 项目 ID
    uint256 amount,              // 锁定金额
    uint256 lockTime             // 锁定时间戳
);
```

**topic0**: `0x5f15e9b584f53277dc27637466800ac556192018d47cabb580630d0c21f6c140`

---

### 3.7 MilestoneReleased

里程碑资金被释放时触发。

```solidity
event MilestoneReleased(
    bytes32 indexed projectId,   // 项目 ID
    uint8 milestone,             // 里程碑序号
    uint256 releasedAmount       // 释放金额
);
```

**topic0**: `0xdd54b35fb157b0ae6f75827d0c5dcf7cb8bd6b163f0e0229ca06cb188abf5a0f`

---

## 4. 验证脚本

### Node.js (keccak-256)

```javascript
const createKeccakHash = require('keccak');
const topic = (sig) => '0x' + createKeccakHash('keccak256').update(sig).digest('hex');

// 核心事件签名验证
console.log('NodeCreated:', topic('NodeCreated(bytes32,address,uint256,uint8,uint8,uint8,uint8)'));
console.log('EdgeDeclared:', topic('EdgeDeclared(bytes32,bytes32,address,uint256,uint256)'));
console.log('QuadrantSet:', topic('QuadrantSet(bytes32,uint8,uint8,uint8,uint8)'));
console.log('AssemblyApproved:', topic('AssemblyApproved(bytes32,string)'));
console.log('AssemblyRejected:', topic('AssemblyRejected(bytes32,string)'));
console.log('MilestoneLocked:', topic('MilestoneLocked(bytes32,uint256,uint256)'));
console.log('MilestoneReleased:', topic('MilestoneReleased(bytes32,uint8,uint256)'));
```

### Python (web3.py)

```python
from web3 import Web3

# web3.py 的 keccak 与以太坊一致
keccak = Web3.keccak

def event_topic(sig: str) -> str:
    return '0x' + keccak(text=sig).hex()

assert event_topic('NodeCreated(bytes32,address,uint256,uint8,uint8,uint8,uint8)') \
    == '0x14099851ab7c7f4a85719da2165bc3b1ed0aea38276b15fe41a4c36e9b741918'

assert event_topic('EdgeDeclared(bytes32,bytes32,address,uint256,uint256)') \
    == '0xcb59a69c50a816f2612c07c4a15ed7e4391269cf502635b16da465d2e2c56ceb'

assert event_topic('QuadrantSet(bytes32,uint8,uint8,uint8,uint8)') \
    == '0x71618eac2ec66e68b6fb2308b0e8ccd252f111fad9d66a553fa988088d44f079'
```

> ⚠️ **重要**: Python `hashlib.sha3_256` **≠ 以太坊 keccak-256**。两者填充规则不同，计算结果不一致。务必使用 `web3.py` 或 `pycryptodome` 的 `keccak`。

---

## 5. 前端/索引器使用示例

### ethers.js v6 — 按 creator 过滤 NodeCreated

```javascript
const creatorAddress = '0x1234...';
const filter = nodeRegistry.filters.NodeCreated(null, creatorAddress);
const logs = await nodeRegistry.queryFilter(filter, fromBlock, toBlock);

for (const log of logs) {
  const [timestamp, usage, derive, expand, benefit] = log.args;
  console.log(`Node ${log.args.nodeId}: expand=${expand}`);
}
```

### The Graph — subgraph 实体映射

```graphql
type Node @entity {
  id: ID!                    # nodeId
  creator: Bytes!
  timestamp: BigInt!
  usageRight: Int!
  deriveRight: Int!
  expandRight: Int!
  benefitRight: Int!
  edgesOut: [Edge!]! @derivedFrom(field: "fromNode")
  edgesIn: [Edge!]! @derivedFrom(field: "toNode")
}

type Edge @entity {
  id: ID!                    # fromNode-toNode
  fromNode: Node!
  toNode: Node!
  declarer: Bytes!
  depth: BigInt!
  timestamp: BigInt!
}
```

### 链上 Agent 监听 — 只关注 expandRight > 0 的 Node

```solidity
// Agent 合约中的事件处理器
function handleNodeCreated(bytes32 nodeId, uint8 expandRight) external {
    if (expandRight > 0) {
        composableNodes.push(nodeId);
        emit ComposableNodeIndexed(nodeId, expandRight);
    }
}
```

---

## 6. 版本与变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v0.1-P0 | 2026-05-29 | 初始定义：7 个核心事件 + topic0 验证 |

---

## 7. 与其他 P0 文档的交叉引用

| 本文事件 | 定义文档 |
|---|---|
| `AssemblyApproved` / `AssemblyRejected` | `P0-IDeadlockInspector.md` |
| `MilestoneLocked` / `MilestoneReleased` | `P0-IMilestoneEscrow.md` |
| `NodeCreated` / `QuadrantSet` / `EdgeDeclared` | ECHO v0.4 合约接口（NodeRegistry + EdgeRegistry） |

---

*文档生成时间: 2026-05-29 17:38 CST*  
*计算环境: Node.js keccak-256, Qitmeer QNG Mainnet*  
*所有 topic0 已通过 Node.js keccak 包独立验证*
