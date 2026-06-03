# ECHO 卡牌对战 · 经济模型规格（势位收益 / 对战分账）

> 前端联调专用版。所有参数精确到 basis points，可直接写入合约与前端配置。
> 版本：v0.1 | 日期：2026-06-03 | 由【猫先森】整理

---

## 一、核心分账比例（Basis Points = 万分之一）

单局对战总奖池 = 双方入场费之和（以主网 10 MEER × 2 = 20 MEER 为例）。

| 收款方 | 比例 | 20 MEER 局示例 | 说明 |
|---|---|---|---|
| **平台抽成（Protocol Fee）** | 300 bps = **3%** | 0.6 MEER | 进入协议国库，用于 gas 兜底、公共池、运营 |
| **赢家（Winner）** | 5500 bps = **55%** | 11 MEER | 对战胜者直接获得 |
| **输家（Loser）** | 2500 bps = **25%** | 5 MEER | 安慰奖，保证参与者不白打 |
| **赢家卡牌创造者（Winner Creator）** | 750 bps = **7.5%** | 1.5 MEER | 使用赢家卡牌的对战分红 |
| **输家卡牌创造者（Loser Creator）** | 750 bps = **7.5%** | 1.5 MEER | 使用输家卡牌的对战分红 |
| **技能原作者（Skill Origin）** | 500 bps = **5%** | 1.0 MEER | 若使用了 fork/remix 的技能，追溯给原作者 |

**校验**：3% + 55% + 25% + 7.5% + 7.5% + 5% = **100%** ✅

---

## 二、入场费参数（四阶段递进）

| 阶段 | 入场费（单人） | 总奖池（双人） | 平台抽成 | 适用期 |
|---|---|---|---|---|
| 测试网 | 0.001 MEER | 0.002 MEER | 3% | 开发调试 |
| 软启动 | 0.1 MEER | 0.2 MEER | 4% | 早期用户、口碑传播 |
| 增长期 | 1 MEER | 2 MEER | 3.5% | 用户增长阶段 |
| **主网** | **10 MEER** | **20 MEER** | **3%** | **正式运营（默认）** |

> ⚠️ 所有参数可通过 DAO 投票调整。调整生效后，**已创建的对局仍按旧费率执行**，新对局按新费率。

---

## 三、反虹吸税（Anti-Siphon Tax）

**触发条件**：使用排名全服 **前 10%** 的卡牌参战。

| 税种 | 税率 | 计算方式 | 去向 |
|---|---|---|---|
| 反虹吸税 | 500 bps = **5%** | 从该卡牌的创造者分红中额外扣除 | 直接进入公共池 |

**示例**：
- 玩家使用排名第 5 的卡（前 10%）获胜
- 创造者本应获得 7.5% = 1.5 MEER
- 反虹吸税后：创造者获得 1.5 × 95% = **1.425 MEER**
- 差额 0.075 MEER 进入公共池

> 设计意图：防止高排名卡牌被垄断性使用，给中低排名卡牌创造者留出空间。

---

## 四、收益倍率软顶（Soft Cap）

**参数**：`SOFT_CAP = 100,000 MEER`（单卡单局最大收益）

**与卦象系统的联动**：
- 基础收益倍率 = 卡牌收益权属性（封顶 3 倍）
- 兑卦加成：+10%（基础）或 ×2（兑+兑组合）
- 最终倍率 = 基础倍率 × 卦象修正

**软顶触发示例**：
```
基础收益 = 赢家池 11 MEER
基础倍率 = 2.5x（卡牌收益权）
兑+兑组合 = ×2
计算收益 = 11 × 2.5 × 2 = 55 MEER
软顶限制 = min(55, 100,000) = 55 MEER（未触发软顶）

极端情况：
基础倍率 = 3.0x
兑+兑 = ×2
天泽履组合额外 +15%
计算收益 = 11 × 3.0 × 2 × 1.15 = 75.9 MEER
仍远低于 100,000 MEER 软顶
```

**软顶生效后的溢出处理**：
- 溢出部分 = 计算收益 - SOFT_CAP
- 溢出部分 100% 进入「公共池」
- 公共池按周期（每周）分配给所有当周参战玩家，按对战次数加权

---

## 五、公共池（Public Pool）机制

**资金来源**：
1. 软顶溢出部分
2. 反虹吸税征收额
3. 协议预留的 0.5%（从平台抽成 3% 中拆分：2.5% 国库 + 0.5% 公共池）

**分配周期**：每周一 00:00 UTC 结算上一周

**分配权重**：
```
个人分配 = 公共池总额 × (个人当周对战次数 / 全服当周总对战次数)
```

> 最低分配门槛：当周对战 ≥ 3 局，否则份额滚入下周。

---

## 六、前端联调接口

### TypeScript 类型定义

```typescript
interface BattleEconomyConfig {
  entryFee: bigint;           // 入场费（wei）
  protocolFeeBps: number;     // 平台抽成 basis points
  antiSiphonBps: number;      // 反虹吸税 basis points
  softCap: bigint;            // 软顶（wei）
  phase: 'testnet' | 'softlaunch' | 'growth' | 'mainnet';
}

interface PayoutBreakdown {
  winner: bigint;
  loser: bigint;
  winnerCreator: bigint;
  loserCreator: bigint;
  skillOrigin: bigint;
  protocolFee: bigint;
  publicPoolContribution: bigint; // 反虹吸税 + 软顶溢出
}

// 分账计算函数
function calculatePayout(
  totalPool: bigint,
  winnerCardRankPercentile: number, // 0-100，用于判断是否前10%
  hasSkillOrigin: boolean
): PayoutBreakdown {
  const protocolFee = totalPool * 300n / 10000n;
  const winner = totalPool * 5500n / 10000n;
  const loser = totalPool * 2500n / 10000n;
  let winnerCreator = totalPool * 750n / 10000n;
  const loserCreator = totalPool * 750n / 10000n;
  const skillOrigin = hasSkillOrigin ? totalPool * 500n / 10000n : 0n;

  // 反虹吸税：前10%卡牌
  let publicPoolContribution = 0n;
  if (winnerCardRankPercentile <= 10) {
    const siphonTax = winnerCreator * 500n / 10000n;
    winnerCreator -= siphonTax;
    publicPoolContribution += siphonTax;
  }

  return {
    winner,
    loser,
    winnerCreator,
    loserCreator,
    skillOrigin,
    protocolFee,
    publicPoolContribution
  };
}
```

### 合约事件日志

```solidity
event BattleSettled(
    uint256 indexed battleId,
    address indexed winner,
    address indexed loser,
    uint256 totalPool,
    uint256 winnerPayout,
    uint256 loserPayout,
    uint256 winnerCreatorFee,
    uint256 loserCreatorFee,
    uint256 skillOriginFee,
    uint256 protocolFee,
    uint256 publicPoolContribution
);

event PublicPoolDistributed(
    uint256 indexed weekId,
    uint256 totalAmount,
    uint256 totalBattles,
    uint256 participantCount
);

event AntiSiphonTaxApplied(
    uint256 indexed battleId,
    address indexed creator,
    uint256 originalAmount,
    uint256 taxedAmount
);
```

### 关键合约函数签名

```solidity
// 计算单场对战分账
function previewPayout(uint256 battleId) external view returns (PayoutBreakdown memory);

// 查询公共池当前余额
function publicPoolBalance() external view returns (uint256);

// 查询某用户当周已结算收益
function weeklyEarnings(address player, uint256 weekId) external view returns (uint256);

// 手动触发公共池分配（仅DAO多签，或定时器自动执行）
function distributePublicPool(uint256 weekId) external onlyDAO;
```

---

## 七、Gas 估算（⚠️ 需实测验证）

| 操作 | 预估 Gas | 备注 |
|---|---|---|
| 创建对战（deposit） | ~65,000 | 双人 deposit，含事件发射 |
| 结算对战（settle） | ~120,000 | 含分账转账、事件发射、公共池更新 |
| 公共池分配（distribute） | ~180,000 × n | n = 参与者数量，批量操作建议 Merkle 空投 |
| 查询 previewPayout | ~8,000 | view 函数，无 gas |

> 优化方向：公共池分配建议用 Merkle 树空投，链上只存 root，用户自行 claim，可将 n 人分配降为固定 ~45,000 gas。

---

## 八、参数速查表（Phase 1 MVP）

| 参数名 | 值 | 单位 | 可调 |
|---|---|---|---|
| `PROTOCOL_FEE_BPS` | 300 | bps (3%) | DAO |
| `WINNER_BPS` | 5500 | bps (55%) | DAO |
| `LOSER_BPS` | 2500 | bps (25%) | DAO |
| `WINNER_CREATOR_BPS` | 750 | bps (7.5%) | DAO |
| `LOSER_CREATOR_BPS` | 750 | bps (7.5%) | DAO |
| `SKILL_ORIGIN_BPS` | 500 | bps (5%) | DAO |
| `ANTI_SIPHON_BPS` | 500 | bps (5%) | DAO |
| `SOFT_CAP` | 100,000 | MEER | DAO |
| `ENTRY_FEE_MAINNET` | 10 | MEER | DAO |
| `ENTRY_FEE_TESTNET` | 0.001 | MEER | DAO |
| `RANK_PERCENTILE_THRESHOLD` | 10 | % | DAO |
| `PUBLIC_POOL_SPLIT_FROM_PROTOCOL` | 50 | bps (0.5%) | DAO |
| `MIN_BATTLES_FOR_PUBLIC_POOL` | 3 | 局 | DAO |

---

*版本：v0.1（前端联调规格版）*
*更新日期：2026-06-03*
*由【猫先森】整理，基于《势位之战-人话版完整文档》v0.3 第三章*
