# P1 Deliverable — 里程碑集成接口草案（v0.1-P1）

**版本**: v0.1-P1  
**网络**: Qitmeer QNG (Chain ID 813)  
**用途**: P0 合约已上链，P1 扩展 MilestoneEscrow 与 DeadlockInspector，使其与六相状态机衔接，并补充模块上链后的扩权/衍权兼容性检查。

---

## 1. 六相状态机定义

| 相位 | 编码 | 名称 | 含义 |
|------|------|------|------|
| 0 | 肇始 | Initiation | Node 铸造，权利初始化 |
| 1 | 通变 | Transformation | 资金锁定/里程碑设定，项目启动 |
| 2 | 流行 | Circulation | 作品流通，里程碑释放 |
| 3 | 差等 | Differentiation | 势位评估，收益差等化 |
| 4 | 继述 | Inheritance | 衍生/扩展，权利传递 |
| 5 | 性命 | Destiny |  sunset/退出，生命周期终结 |

---

## 2. 新增事件：PhaseTransition

供索引器与前端统一追踪每个 Node 的六相生命周期。

```solidity
/// @dev Node 从当前相位过渡到下一个相位
event PhaseTransition(
    bytes32 indexed nodeId,      // 发生过渡的 Node
    uint8 indexed fromPhase,     // 原相位 (0-5)
    uint8 indexed toPhase,       // 目标相位 (0-5)
    uint256 timestamp,           // 过渡时间戳
    uint8 reasonCode             // 触发原因编码：1=lock 2=released 3=deadlock_cleared 4=sunrise 5=sunset (预留0=undefined, 6-255=扩展)
);
```

**topic0**: `0x9c...`（待部署后实测确认）

**触发场景映射**:
- `lockMilestone` → PhaseTransition(nodeId, 0, 1, ...)
- `releaseMilestone` → PhaseTransition(nodeId, 1, 2, ...)
- `approveAssembly` → PhaseTransition(nodeId, 2, 4, ...)
- `sunsetNode` → PhaseTransition(nodeId, 4, 5, ...)

---

## 3. IMilestoneEscrow P1 扩展

在 P0 基础上增加六相状态关联字段。

```solidity
interface IMilestoneEscrow {
    // P0 已有事件
    event MilestoneLocked(...);
    event MilestoneReleased(...);
    
    // P1 新增：里程碑与六相状态绑定
    event MilestonePhaseBound(
        bytes32 indexed projectId,
        uint8 indexed milestone,
        uint8 targetPhase          // 该里程碑达成后 Node 应进入的相位
    );

    // P0 已有函数
    function lockMilestone(bytes32 projectId, uint256 amount) external payable;
    function releaseMilestone(bytes32 projectId, uint8 milestone) external;
    
    // P1 新增：为里程碑绑定目标相位（仅 governance 可设）
    function bindMilestonePhase(
        bytes32 projectId,
        uint8 milestone,
        uint8 targetPhase
    ) external;
    
    // P1 新增：查询某 milestone 绑定的目标相位
    function getMilestonePhase(bytes32 projectId, uint8 milestone)
        external view returns (uint8 targetPhase);
}
```

---

## 4. IDeadlockInspector P1 扩展

在 P0 基础上增加**上链后扩权/衍权兼容性检查**。

```solidity
interface IDeadlockInspector {
    // P0 已有事件
    event AssemblyApproved(...);
    event AssemblyRejected(...);
    
    // P1 新增：上链后权限漂移检查事件
    event PostDeploymentRightsChecked(
        bytes32 indexed nodeId,
        bool expandOk,              // 扩权兼容性是否通过
        bool deriveOk,              // 衍权兼容性是否通过
        string reason
    );

    // P0 已有函数
    function checkModuleComposability(bytes32 nodeId) external view returns (bool ok);
    function checkAssemblyDeadlock(bytes32[] calldata nodeIds)
        external view returns (bool ok, string memory reason);
    
    // P1 新增：单个 Node 上链后扩权/衍权兼容性检查
    function checkPostDeploymentRights(bytes32 nodeId)
        external view returns (bool expandOk, bool deriveOk, string memory reason);
    
    // P1 新增：批量检查 Assembly 中所有 Node 的上链后权限
    function checkAssemblyPostDeploymentRights(bytes32[] calldata nodeIds)
        external view returns (bool allOk, string memory reason);
}
```

---

## 5. 检查流程（伪代码）

### 5.1 上链后兼容性检查

```solidity
function checkPostDeploymentRights(bytes32 nodeId)
    external view returns (bool expandOk, bool deriveOk, string memory reason)
{
    // 1. 从 NodeRegistry 读取四象限
    (uint8 usage, uint8 derive, uint8 expand, uint8 benefit) =
        nodeRegistry.getQuadrant(nodeId);
    
    // 2. 扩权检查：expandRight 必须 > 0（否则无法被组装）
    expandOk = expand > 0;
    
    // 3. 衍权检查：deriveRight 必须匹配 CreatorConfig 中的预设值
    (uint8 expectedDerive, , ) = creatorConfig.getExpectedRights(nodeId);
    deriveOk = derive == expectedDerive;
    
    // 4. 组装失败原因
    if (!expandOk) reason = "expandRight=0, module not composable";
    else if (!deriveOk) reason = "deriveRight drifted from expected";
    else reason = "";
}
```

### 5.2 Assembly 前完整检查流程

```
链下预计算 → 链上 Merkle 验证（P0 已有）
    ↓
P1 新增：上链后权限检查
    ├─ checkPostDeploymentRights(nodeId) → expandOk + deriveOk
    ├─ checkAssemblyPostDeploymentRights(nodeIds[]) → allOk
    ↓
P0 已有：死锁检查
    ├─ checkModuleComposability → expand > 0
    ├─ checkAssemblyDeadlock → 无循环引用
    ↓
PhaseTransition 事件触发（P1 新增）
    → PhaseTransition(nodeId, 2, 4, reasonHash="deadlock_cleared")
```

---

## 6. 前端联调要点

| Mock 切真实地址 | 时机 | 操作 |
|----------------|------|------|
| NodeRegistry | 已部署 | 切真实地址 |
| MilestoneEscrow | P1 部署后 | 切真实地址 + 绑定 PhaseTransition 监听 |
| DeadlockInspector | P1 部署后 | 切真实地址 + 增加 PostDeploymentRightsChecked 监听 |

---

## 7. 会议待对齐项

1. `PhaseTransition` 的 `reasonHash` 枚举值是否够用？需不需要加 `reasonString`？
2. `bindMilestonePhase` 是否允许创作者自行修改，还是必须 governance？
3. `checkPostDeploymentRights` 中 `deriveRight` 的 "expected" 来源：CreatorConfig 的初始值还是 EdgeDeclaration 的声明值？
4. 事件新增是否影响索引器已有的 schema（Seaman_bot 确认）

---

**状态**: P1 合约编译通过，22:00 前部署上链。接口契约已锁定。
