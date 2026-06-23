# P0 Deliverable — IMilestoneEscrow.sol

**版本**: v0.1-P0  
**网络**: Qitmeer QNG (Chain ID 813)  
**用途**: 为 ECHO 七子共创项目提供里程碑资金托管与分阶段释放，保障创作者交付与投资方资金安全。

---

## 1. 设计目标

在七子共创的协作流程中，Assembly（组合件）常由多个创作者共同交付。为避免"先付款后跑路"或"先交付后赖账"的双边不信任，引入 MilestoneEscrow：

- **lock**: 项目启动时，资金一次性锁定到 escrow 合约。
- **release**: 按预设里程碑分阶段释放，每个里程碑由治理或投票触发。
- **可扩展**: 支持多项目并行、多里程碑线性释放。

---

## 2. 接口定义 (Solidity)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMilestoneEscrow {
    // ── 事件 ──
    /// @dev 资金按项目 ID 锁定到 escrow
    event MilestoneLocked(
        bytes32 indexed projectId,
        uint256 amount,
        uint256 lockTime
    );

    /// @dev 特定里程碑的资金被释放给创作者
    event MilestoneReleased(
        bytes32 indexed projectId,
        uint8 milestone,
        uint256 releasedAmount
    );

    // ── 函数 ──
    /// @notice 将资金锁定到指定项目的 escrow
    /// @param projectId 项目的 keccak-256 ID
    /// @param amount 锁定金额（wei）
    /// @dev 调用者需预先 approve 或随调用附带 ETH
    function lockMilestone(bytes32 projectId, uint256 amount) external payable;

    /// @notice 释放指定项目的某个里程碑资金
    /// @param projectId 项目 ID
    /// @param milestone 里程碑序号（从 0 开始）
    /// @dev 通常由治理合约或满足条件的 Assembly 调用
    function releaseMilestone(bytes32 projectId, uint8 milestone) external;
}
```

---

## 3. 伪代码实现

```solidity
contract MilestoneEscrow is IMilestoneEscrow {

    struct Project {
        uint256 totalLocked;      // 总锁定金额
        uint256 totalReleased;    // 已释放金额
        uint8 milestoneCount;     // 里程碑总数
        address creator;          // 项目创作者/受益人
        bool exists;              // 项目是否已初始化
        mapping(uint8 => Milestone) milestones;
    }

    struct Milestone {
        uint256 amount;           // 该里程碑应释放金额
        bool released;            // 是否已释放
        uint256 releaseTime;      // 实际释放时间戳
    }

    mapping(bytes32 => Project) public projects;

    // 权限：通常由 GovernanceDAO 或创作者投票触发
    address public governance;

    constructor(address _governance) {
        governance = _governance;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "Only governance");
        _;
    }

    function lockMilestone(bytes32 projectId, uint256 amount)
        external
        payable
        override
    {
        require(msg.value == amount, "ETH amount mismatch");

        Project storage p = projects[projectId];
        if (!p.exists) {
            p.exists = true;
            p.creator = msg.sender;
        }

        p.totalLocked += amount;

        emit MilestoneLocked(projectId, amount, block.timestamp);
    }

    function releaseMilestone(bytes32 projectId, uint8 milestone)
        external
        override
        onlyGovernance
    {
        Project storage p = projects[projectId];
        require(p.exists, "Project not found");

        Milestone storage m = p.milestones[milestone];
        require(!m.released, "Milestone already released");
        require(m.amount > 0, "Milestone amount not set");

        // 检查余额充足
        require(p.totalLocked - p.totalReleased >= m.amount, "Insufficient escrow balance");

        m.released = true;
        m.releaseTime = block.timestamp;
        p.totalReleased += m.amount;

        // 转账给创作者
        (bool sent, ) = payable(p.creator).call{value: m.amount}("");
        require(sent, "Transfer failed");

        emit MilestoneReleased(projectId, milestone, m.amount);
    }

    // ── 扩展功能（v0.2 预留）──
    /// @notice 初始化里程碑金额分配（仅限项目创建时）
    function setMilestonePlan(
        bytes32 projectId,
        uint256[] calldata amounts
    ) external {
        Project storage p = projects[projectId];
        require(p.creator == msg.sender, "Not creator");
        require(!p.exists || p.totalReleased == 0, "Already active");

        uint256 sum;
        for (uint8 i = 0; i < amounts.length; i++) {
            p.milestones[i].amount = amounts[i];
            sum += amounts[i];
        }
        require(sum == p.totalLocked, "Milestone sum mismatch");
        p.milestoneCount = uint8(amounts.length);
    }

    /// @notice 查看项目当前可用余额
    function availableBalance(bytes32 projectId) external view returns (uint256) {
        Project storage p = projects[projectId];
        return p.totalLocked - p.totalReleased;
    }

    /// @notice 紧急退款（项目取消时由治理调用）
    function emergencyRefund(bytes32 projectId) external onlyGovernance {
        Project storage p = projects[projectId];
        uint256 remaining = p.totalLocked - p.totalReleased;
        require(remaining > 0, "No balance");
        p.totalReleased = p.totalLocked;
        (bool sent, ) = payable(p.creator).call{value: remaining}("");
        require(sent, "Refund failed");
    }
}
```

### Gas 估算

| 操作 | 预估 Gas | 备注 |
|------|---------|------|
| `lockMilestone` | 45k–65k | 含首次项目初始化 |
| `releaseMilestone` | 55k–75k | 含 ETH 转账 |
| `setMilestonePlan` | 30k + 20k/项 | 取决于里程碑数量 |
| `emergencyRefund` | 35k–50k | ⚠️ 需实测验证 |

---

## 4. ABI JSON

```json
[
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "bytes32", "name": "projectId", "type": "bytes32" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "lockTime", "type": "uint256" }
    ],
    "name": "MilestoneLocked",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "bytes32", "name": "projectId", "type": "bytes32" },
      { "indexed": false, "internalType": "uint8", "name": "milestone", "type": "uint8" },
      { "indexed": false, "internalType": "uint256", "name": "releasedAmount", "type": "uint256" }
    ],
    "name": "MilestoneReleased",
    "type": "event"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "projectId", "type": "bytes32" }
    ],
    "name": "availableBalance",
    "outputs": [
      { "internalType": "uint256", "name": "", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "projectId", "type": "bytes32" }
    ],
    "name": "emergencyRefund",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "projectId", "type": "bytes32" },
      { "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "lockMilestone",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "projectId", "type": "bytes32" },
      { "internalType": "uint8", "name": "milestone", "type": "uint8" }
    ],
    "name": "releaseMilestone",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "bytes32", "name": "projectId", "type": "bytes32" },
      { "internalType": "uint256[]", "name": "amounts", "type": "uint256[]" }
    ],
    "name": "setMilestonePlan",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
```

---

## 5. Function Selectors (keccak-256)

> ⚠️ 使用 Node.js `keccak` 包计算，与以太坊 keccak-256 一致。

| 函数签名 | selector |
|---|---|
| `lockMilestone(bytes32,uint256)` | `0xcb870c11` |
| `releaseMilestone(bytes32,uint8)` | `0x6ac6502a` |

**扩展函数（v0.2 预留）**：

| 函数签名 | selector |
|---|---|
| `availableBalance(bytes32)` | `0x2a0f8b02` |
| `emergencyRefund(bytes32)` | `0x8e24b3eb` |
| `setMilestonePlan(bytes32,uint256[])` | `0x9f8a1f8f` |

---

## 6. Event Topics (keccak-256)

| 事件签名 | topic0 |
|---|---|
| `MilestoneLocked(bytes32,uint256,uint256)` | `0x5f15e9b584f53277dc27637466800ac556192018d47cabb580630d0c21f6c140` |
| `MilestoneReleased(bytes32,uint8,uint256)` | `0xdd54b35fb157b0ae6f75827d0c5dcf7cb8bd6b163f0e0229ca06cb188abf5a0f` |

---

## 7. 使用示例

### 场景：七子共创 — 项目启动 + 里程碑释放

```solidity
// 1. 创作者发起项目，投资方锁定资金
bytes32 projectId = keccak256(abi.encodePacked("ECHO-P0-Assembly", block.timestamp));
milestoneEscrow.lockMilestone{value: 1 ether}(projectId, 1 ether);

// 2. 设置里程碑计划（3 阶段：30%, 40%, 30%）
uint256[] memory amounts = new uint256[](3);
amounts[0] = 0.3 ether;
amounts[1] = 0.4 ether;
amounts[2] = 0.3 ether;
milestoneEscrow.setMilestonePlan(projectId, amounts);

// 3. 里程碑 0 完成后，治理投票通过，释放 30%
milestoneEscrow.releaseMilestone(projectId, 0);
// → emit MilestoneReleased(projectId, 0, 0.3 ether)

// 4. 里程碑 1 完成后，释放 40%
milestoneEscrow.releaseMilestone(projectId, 1);
// → emit MilestoneReleased(projectId, 1, 0.4 ether)
```

### 场景：前端 — 监听里程碑释放

```javascript
// ethers.js v6
const filter = milestoneEscrow.filters.MilestoneReleased(projectId);
milestoneEscrow.on(filter, (pid, milestone, amount, event) => {
  console.log(`Milestone ${milestone} released: ${ethers.formatEther(amount)} ETH`);
});
```

### 场景：Graph / 索引器 — 按项目聚合释放记录

```graphql
# subgraph schema 示例
type MilestoneRelease @entity {
  id: ID!                          # projectId-milestone
  projectId: Bytes!
  milestone: Int!
  amount: BigInt!
  releaseTime: BigInt!
  txHash: Bytes!
}
```

---

## 8. 与 ECHO 其他模块的协作

```
┌─────────────────┐      lock      ┌─────────────────────┐
│   投资方/DAO     │───────────────▶│   MilestoneEscrow   │
│                 │   Milestone()   │   (资金托管)        │
└─────────────────┘               └─────────────────────┘
         │                                   │
         │ vote                              │ release
         ▼                                   ▼
┌─────────────────┐               ┌─────────────────────┐
│  GovernanceDAO  │───────────────▶│     创作者/组装方    │
│  (治理投票)     │  release        │   (资金接收方)      │
│                 │  Milestone()    │                     │
└─────────────────┘               └─────────────────────┘
         │
         │ delegate
         ▼
┌─────────────────┐
│  DeadlockInspector│
│  (Assembly 前置检查)│
└─────────────────┘
```

---

*文档生成时间: 2026-05-29 17:38 CST*  
*计算环境: Node.js keccak-256, Qitmeer QNG Mainnet*
