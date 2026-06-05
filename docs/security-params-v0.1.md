# ECHO 安全参数定义 v0.1

> 版本：v0.1  
> 更新日期：2026-06-05  
> 状态：草案（基于 06-05 会议共识）  
> 定位：前端和合约层的「工具书」——快速查阅，不重复读 v0.4 全文  
> 作者：猫先森（主导）+ Seaman_bot（合约层）+ Talus（前端参数表）

---

## 使用说明

本文档是 `echo-game-economy-v0.4.md` 安全参数章节的**详细展开**。

- v0.4 安全章节 = 摘要 + 上下文 + 引用本文档
- 本文档 = 纯参数定义，无背景解释

---

## 1. 标记阈值（MARK_THRESHOLD）

| 属性 | 值 |
|------|-----|
| 常量名 | `MARK_THRESHOLD` |
| 值 | `3` |
| 类型 | `uint8` |
| 单位 | 次数 |
| 触发条件 | 连续检测到异常 3 次 |
| 后果 | 自动进入仲裁池，触发 `ArbitrationTriggered` |
| 重置条件 | 24h 无新标记 或 5 局无参与 |

### 1.1 标记计数器规则

```solidity
// 伪代码
uint8 public constant MARK_THRESHOLD = 3;
mapping(address => uint8) public markCount;
mapping(address => uint256) public lastMarkTime;

function _checkAndMark(address player) internal {
    if (isSuspicious(player)) {
        markCount[player]++;
        lastMarkTime[player] = block.timestamp;
        
        if (markCount[player] >= MARK_THRESHOLD) {
            emit ArbitrationTriggered(...);
        } else {
            emit ScoreMarked(player, markCount[player], 0, block.timestamp);
        }
    }
}
```

### 1.2 前端展示规则

| 标记次数 | 前端显示 | 状态 | 动作 |
|----------|----------|------|------|
| 1 | ⚠️ 警告 (1/3) | 不进仲裁 | 提示用户 |
| 2 | ⚠️ 警告 (2/3) | 不进仲裁 | 提示用户 |
| 3 | 🚨 进入仲裁池 | 触发仲裁 | 锁定操作 |

---

## 2. 阶梯衰减（MARK_DECAY_STEPS）

| 属性 | 值 |
|------|-----|
| 常量名 | `MARK_DECAY_STEPS` |
| 值 | `[10000, 7000, 4000]` |
| 类型 | `uint16[]` |
| 单位 | basis points（10000 = 100%） |
| 含义 | 标记后势位保留比例 |

### 2.1 衰减表

| 标记次数 | 保留比例 | 衰减比例 | 前端显示 |
|----------|----------|----------|----------|
| 0（无标记） | 100% | 0% | 正常 |
| 1 | 100% | 0% | ⚠️ 警告（仅提示） |
| 2 | 70% | 30% | ⚠️ 警告（势位下降） |
| 3 | 40% | 60% | 🚨 仲裁（势位腰斩） |

### 2.2 计算公式

```solidity
// 伪代码
uint16[] public MARK_DECAY_STEPS = [10000, 7000, 4000];

function getAttenuatedPotential(address player) public view returns (uint256) {
    uint256 base = basePotential[player];
    uint8 marks = markCount[player];
    
    if (marks >= MARK_DECAY_STEPS.length) {
        marks = uint8(MARK_DECAY_STEPS.length - 1);
    }
    
    uint16 retention = MARK_DECAY_STEPS[marks];
    return (base * retention) / 10000;
}
```

### 2.3 前端展示规则

- 标记 1：显示原始势位，加 ⚠️ badge（不显示衰减）
- 标记 2：显示衰减后势位（70%），加 ⚠️ badge
- 标记 3：显示衰减后势位（40%），加 🚨 badge，操作锁定

---

## 3. 冷却期（COOLDOWN_HOURS）

| 属性 | 值 |
|------|-----|
| 常量名 | `COOLDOWN_HOURS` |
| 值 | `24` |
| 类型 | `uint256` |
| 单位 | 小时 |
| 含义 | 每次标记后观察期，无新标记则清零 |

### 3.1 冷却规则

```solidity
// 伪代码
uint256 public constant COOLDOWN_HOURS = 24;
uint256 public constant COOLDOWN_SECONDS = 24 * 3600; // 86400

function checkCooldown(address player) public {
    uint256 timeSinceLastMark = block.timestamp - lastMarkTime[player];
    
    if (timeSinceLastMark >= COOLDOWN_SECONDS && markCount[player] > 0) {
        markCount[player] = 0;
        emit CooldownReset(player, block.timestamp);
    }
}
```

### 3.2 前端展示规则

- 显示「冷却期剩余 X 小时 Y 分钟」
- 倒计时结束时自动刷新状态
- 冷却清零后恢复正常显示

---

## 4. 重置窗口（RESET_WINDOW）

| 属性 | 值 |
|------|-----|
| 常量名 | `RESET_WINDOW` |
| 值 | `5` |
| 类型 | `uint8` |
| 单位 | 局数 |
| 含义 | 连续 5 局无参与 → 标记计数器归零 |

### 4.1 重置规则

```solidity
// 伪代码
uint8 public constant RESET_WINDOW = 5;
mapping(address => uint8) public consecutiveNoPlay;

function recordParticipation(address player, bool participated) internal {
    if (!participated) {
        consecutiveNoPlay[player]++;
        if (consecutiveNoPlay[player] >= RESET_WINDOW) {
            markCount[player] = 0;
            consecutiveNoPlay[player] = 0;
        }
    } else {
        consecutiveNoPlay[player] = 0;
    }
}
```

---

## 5. 事件定义（详细版）

### 5.1 ScoreMarked

```solidity
event ScoreMarked(
    bytes32 indexed nodeId,      // 节点标识
    address indexed target,       // 被标记地址
    uint8 markCount,              // 当前标记次数 (1/2/3)
    uint8 riskLevel,              // 0=warning, 1=flagged
    uint256 timestamp             // 标记时间
);
```

| 属性 | 值 |
|------|-----|
| 触发条件 | 检测到异常立即 emit |
| 实时性 | 实时 |
| 当前状态 | 已有 |
| 前端订阅 | WebSocket / HTTP polling |
| 前端展示 | ⚠️ 警告 badge |

### 5.2 PotentialAttenuated

```solidity
event PotentialAttenuated(
    bytes32 indexed nodeId,      // 节点标识
    uint256 oldPotential,        // 衰减前势位
    uint256 newPotential,        // 衰减后势位
    uint8 attenuationLevel,       // 0=clear, 1=light, 2=heavy
    uint256 timestamp             // 衰减时间
);
```

| 属性 | 值 |
|------|-----|
| 触发条件 | 用户调用 `getPotential()` 或 `calculatePotential()` 时自动检查并 emit |
| 实时性 | 准实时（用户交互时） |
| 当前状态 | **无**，Phase 2 新增 |
| 前端订阅 | 用户交互时拉取 |
| 前端展示 | 衰减后势位数值 |

### 5.3 ArbitrationTriggered

```solidity
event ArbitrationTriggered(
    bytes32 indexed nodeId,      // 节点标识
    address indexed trigger,      // 触发者（自动=合约地址，手动=举报者）
    uint8 reason,                 // 1=mark threshold, 2=manual report
    uint256 stakeAmount,          // 触发者质押（手动举报时）
    uint256 deadlineBlock         // 仲裁超时区块
);
```

| 属性 | 值 |
|------|-----|
| 触发条件 | N=3 自动触发 或 用户手动举报 |
| 实时性 | 实时 |
| 当前状态 | **无**，Phase 2 新增 |
| 前端订阅 | WebSocket |
| 前端展示 | 🚨 仲裁池列表 |

### 5.4 CooldownReset

```solidity
event CooldownReset(
    bytes32 indexed nodeId,      // 节点标识
    uint256 resetTimestamp      // 清零时间
);
```

| 属性 | 值 |
|------|-----|
| 触发条件 | 外部调用 `checkCooldown()` 且满足 24h 无标记 |
| 实时性 | 被动（外部调用触发） |
| 当前状态 | **无**，Phase 2 新增 |
| 前端订阅 | 用户访问时调用 / indexer 定时扫描 |
| 前端展示 | 冷却倒计时清零 |

### 5.5 SybilCheckResult

```solidity
event SybilCheckResult(
    bytes32 indexed nodeId,      // 节点标识
    uint8 riskLevel,              // 0=clear, 1=suspect, 2=confirmed
    uint256 timestamp             // 验证时间
);
```

| 属性 | 值 |
|------|-----|
| 触发条件 | 链下图谱验证完成后 emit |
| 实时性 | 准实时 |
| 当前状态 | **无**，Phase 2 新增 |
| 前端订阅 | 准实时推送 |
| 前端展示 | 验证状态徽章 |

### 5.6 CommitSubmitted

```solidity
event CommitSubmitted(
    bytes32 indexed battleId,    // 对战 ID
    bytes32 indexed hash,        // keccak256(choice + nonce)
    address indexed player,       // 提交者
    uint256 blockNumber         // 提交区块
);
```

| 属性 | 值 |
|------|-----|
| 触发条件 | 用户提交 commit hash |
| 实时性 | 实时 |
| 当前状态 | 已有 |
| 前端订阅 | WebSocket |
| 前端展示 | "等待 reveal" 状态 |

### 5.7 RevealSubmitted

```solidity
event RevealSubmitted(
    bytes32 indexed battleId,    // 对战 ID
    uint256 choice,              // 明文选择
    address indexed player,       // 提交者
    uint256 blockNumber         // 揭示区块
);
```

| 属性 | 值 |
|------|-----|
| 触发条件 | 用户提交 reveal 明文 |
| 实时性 | 实时 |
| 当前状态 | 已有 |
| 前端订阅 | WebSocket |
| 前端展示 | "已 reveal" 状态 |

---

## 6. 前端配置表（src/config/anti-abuse.ts）

### 6.1 常量定义

```typescript
// src/config/anti-abuse.ts

export const ANTI_SYBIL_CONFIG = {
  // 标记阈值
  MARK_THRESHOLD: 3,
  
  // 阶梯衰减（basis points）
  MARK_DECAY_STEPS: [10000, 7000, 4000] as const,
  
  // 冷却期
  COOLDOWN_HOURS: 24,
  COOLDOWN_SECONDS: 24 * 3600,
  
  // 重置窗口
  RESET_WINDOW: 5,
  
  // 显示映射
  DISPLAY: {
    0: { badge: '', color: 'green' },
    1: { badge: '⚠️', color: 'yellow', text: '警告 (1/3)' },
    2: { badge: '⚠️', color: 'orange', text: '警告 (2/3)' },
    3: { badge: '🚨', color: 'red', text: '进入仲裁池' },
  } as const,
  
  // 衰减显示映射
  ATTENUATION_DISPLAY: {
    0: { retention: '100%', decay: '0%' },
    1: { retention: '100%', decay: '0%' },
    2: { retention: '70%', decay: '30%' },
    3: { retention: '40%', decay: '60%' },
  } as const,
};

// 事件订阅配置
export const EVENT_SUBSCRIPTION = {
  ScoreMarked: {
    name: 'ScoreMarked',
    fields: ['nodeId', 'target', 'markCount', 'riskLevel', 'timestamp'],
    display: (data: any) => `${ANTI_SYBIL_CONFIG.DISPLAY[data.markCount].badge} ${ANTI_SYBIL_CONFIG.DISPLAY[data.markCount].text}`,
  },
  PotentialAttenuated: {
    name: 'PotentialAttenuated',
    fields: ['nodeId', 'oldPotential', 'newPotential', 'attenuationLevel', 'timestamp'],
    display: (data: any) => `势位: ${data.newPotential} (原 ${data.oldPotential})`,
  },
  ArbitrationTriggered: {
    name: 'ArbitrationTriggered',
    fields: ['nodeId', 'trigger', 'reason', 'stakeAmount', 'deadlineBlock'],
    display: (data: any) => `🚨 仲裁触发 (原因: ${data.reason})`,
  },
  CooldownReset: {
    name: 'CooldownReset',
    fields: ['nodeId', 'resetTimestamp'],
    display: (data: any) => '✅ 冷却清零',
  },
  SybilCheckResult: {
    name: 'SybilCheckResult',
    fields: ['nodeId', 'riskLevel', 'timestamp'],
    display: (data: any) => `验证结果: ${['通过', '可疑', '确认'][data.riskLevel]}`,
  },
  CommitSubmitted: {
    name: 'CommitSubmitted',
    fields: ['battleId', 'hash', 'player', 'blockNumber'],
    display: (data: any) => '⏳ 等待 reveal',
  },
  RevealSubmitted: {
    name: 'RevealSubmitted',
    fields: ['battleId', 'choice', 'player', 'blockNumber'],
    display: (data: any) => '✅ 已 reveal',
  },
};
```

### 6.2 前端状态机

```typescript
// 用户安全状态
export type UserSafetyStatus = 
  | 'clean'        // 无标记
  | 'warning-1'    // 1 次标记
  | 'warning-2'    // 2 次标记
  | 'arbitration'  // 3 次标记，进入仲裁
  | 'cooldown';    // 冷却期

// 状态转换
export function getSafetyStatus(
  markCount: number,
  lastMarkTime: number,
  currentTime: number
): UserSafetyStatus {
  if (markCount === 0) return 'clean';
  
  const timeSinceMark = currentTime - lastMarkTime;
  if (timeSinceMark >= ANTI_SYBIL_CONFIG.COOLDOWN_SECONDS) {
    return 'cooldown'; // 冷却中，即将清零
  }
  
  if (markCount === 1) return 'warning-1';
  if (markCount === 2) return 'warning-2';
  return 'arbitration';
}
```

---

## 7. commit-reveal 详细规范

### 7.1 状态机

```
[Idle] --commit()--> [Committed] --reveal()--> [Revealed] --settle()--> [Settled]
                    |                    |
                    |--超时(3区块)-->   |--超时(3区块)-->
                    [Expired]            [Expired]
```

### 7.2 函数接口

```solidity
interface ICommitReveal {
    // 提交阶段
    function commit(bytes32 battleId, bytes32 commitment) external payable;
    
    // 揭示阶段
    function reveal(bytes32 battleId, uint256 choice, uint256 nonce) external;
    
    // 查询状态
    function getCommitment(bytes32 battleId, address player) external view returns (bytes32);
    function getReveal(bytes32 battleId, address player) external view returns (uint256 choice, uint256 nonce);
    function getBattleState(bytes32 battleId) external view returns (BattleState);
    
    // 事件
    event CommitSubmitted(bytes32 indexed battleId, bytes32 indexed hash, address indexed player, uint256 blockNumber);
    event RevealSubmitted(bytes32 indexed battleId, uint256 choice, address indexed player, uint256 blockNumber);
    event BattleExpired(bytes32 indexed battleId, uint256 blockNumber);
}

enum BattleState {
    Idle,       // 未开始
    Committed,  // 已提交，等待揭示
    Revealed,   // 已揭示，等待结算
    Settled,    // 已结算
    Expired     // 超时
}
```

### 7.3 验证逻辑

```solidity
function reveal(bytes32 battleId, uint256 choice, uint256 nonce) external {
    // 1. 检查状态
    require(battleState[battleId] == BattleState.Committed, "Not committed");
    
    // 2. 检查时间窗口
    require(block.number <= commitBlock[battleId] + REVEAL_WINDOW, "Reveal window expired");
    
    // 3. 验证 hash
    bytes32 commitment = commitments[battleId][msg.sender];
    require(commitment == keccak256(abi.encodePacked(choice, nonce)), "Invalid reveal");
    
    // 4. 记录揭示
    reveals[battleId][msg.sender] = Reveal(choice, nonce);
    battleState[battleId] = BattleState.Revealed;
    
    emit RevealSubmitted(battleId, choice, msg.sender, block.number);
}
```

### 7.4 前端状态显示

| 状态 | 前端显示 | 用户动作 |
|------|----------|----------|
| Idle | "准备投注" | 输入 choice，提交 commit |
| Committed | "⏳ 等待 reveal（X 区块剩余）" | 等待或提交 reveal |
| Revealed | "✅ 已 reveal，等待结算" | 等待 |
| Settled | "已结算，收益 XX MEER" | 查看结果 |
| Expired | "❌ 超时，投注作废" | 重新投注 |

---

## 8. 参数汇总表

| 参数名 | 值 | 类型 | 单位 | 所在合约 | 状态 |
|--------|-----|------|------|----------|------|
| MARK_THRESHOLD | 3 | uint8 | 次数 | AntiSybilValidator | Phase 2 新增 |
| MARK_DECAY_STEPS | [10000,7000,4000] | uint16[] | basis points | AntiSybilValidator | Phase 2 新增 |
| COOLDOWN_HOURS | 24 | uint256 | 小时 | AntiSybilValidator | Phase 2 新增 |
| RESET_WINDOW | 5 | uint8 | 局数 | AntiSybilValidator | Phase 2 新增 |
| MAX_BET | 10 MEER | uint256 | MEER | BattleGame | 已有 |
| MIN_BET | 0.1 MEER | uint256 | MEER | BattleGame | 已有 |
| LOCKUP_PERIOD | 90 天 | uint256 | 秒 | CardMinting | 已有 |
| EARLY_EXIT_PENALTY | 50% | uint16 | basis points | CardMinting | 已有 |
| DERIVE_DISCOUNT_BPS | 5000 | uint16 | basis points | CardMinting | 已有 |
| REVEAL_WINDOW | 3 区块 | uint8 | 区块数 | BattleGame | 已有 |
| COMMIT_BLOCK_DELTA | 3 区块 | uint8 | 区块数 | BattleGame | 已有 |

---

## 9. 待办事项

- [ ] Seaman_bot 确认 solidity 定义与实际合约一致（6/5 20:00 前）
- [ ] Seaman_bot 确认 emit 时机和触发条件（6/5 20:00 前）
- [ ] Talus 确认前端配置表可落地（6/6 09:00 UTC 起 review）
- [ ] 测试网部署后验证事件触发和前端显示一致性
- [ ] 主网前补充 ZKP 验证（可选升级）

---

*本文档由猫先森主导整理，Seaman_bot 补充合约层，Talus 补充前端参数表。*
*与 v0.4 主文档配合使用：v0.4 读上下文，本文档查参数。*
