# ECHO 经济参数 v0.3 定稿

> 状态：已锁定，Phase 1 基线版本
> 日期：2026-06-04
> 负责人：猫先森（经济参数层验证）
> 关联：Talus 前端集成 v0.8 / Seaman_bot 合约部署 0x43Ce...879f

---

## 一、对战分账 7权单层（v0.3 定稿）

| shareType | 名称 | BPS | 百分比 | 说明 |
|-----------|------|-----|--------|------|
| 1 | CREATOR | 4500 | 45% | 牌组创作者（按 cardPotential/totalPotential 细分） |
| 2 | EDGE | 2500 | 25% | 编排者 |
| 3 | REVIEWER | 800 | 8% | 审查员 |
| 4 | PUBLIC_POOL | 800 | 8% | 公共池 |
| 5 | PLATFORM | 500 | 5% | 系统费 |
| 6 | AMBASSADOR | 500 | 5% | 大使 |
| 7 | RESERVE | 400 | 4% | 储备 |

**总和**：4500 + 2500 + 800 + 800 + 500 + 500 + 400 = **10000 bps = 100%**

**链上验证**：
- 合约地址：`0x43CeDEd545Dd40B17aec66C1831c3863a70B879f`（QNG Mainnet, Chain ID 813）
- 链上 getter：`CREATOR_SHARE_BPS` / `EDGE_SHARE_BPS` / `REVIEWER_SHARE_BPS` / `PUBLIC_POOL_BPS` / `PLATFORM_FEE_BPS` / `AMBASSADOR_BPS` / `RESERVE_BPS`
- Talus e2e 验证：7/7 全过，diff=0

---

## 二、投注范围

| 参数 | 值 | 说明 |
|------|-----|------|
| MIN_BET | 0.1 MEER | 最低投注 |
| MAX_BET | 10 MEER | 最高投注 |

---

## 三、势位互换规则（前端业务规则）

| 参数 | 值 | 说明 |
|------|-----|------|
| 触发条件 | 天地否（乾+坤） | hexagramA=1, hexagramB=2 |
| weakToStrongRatio | 30% | 弱者获得转移比例 |
| strongRetentionRatio | 70% | 强者保留比例 |
| 公式 | `weak += (strong - weak) × 0.30` | 弱者获得势位差值的30% |
| 合约层 | 无实现 | 前端/链下计算 |

**注**：此规则为前端业务逻辑，合约层 PotentialOracle.sol 只提供 6 档势位 + 衰减计算，不处理对换逻辑。

---

## 四、软上限 SoftCap

| 参数 | 值 | 说明 |
|------|-----|------|
| 值 | 100,000 MEER | 单卡单局最大收益 |
| 触发 | 收益组合 | 兑+兑（8+8）或 乾+兑（1+8）|
| 超额处理 | 进入公共池 | 超出部分截断后归入 PUBLIC_POOL |
| 合约层 | 无实现 | 前端/链下计算后截断 |

---

## 五、16卦数据 v0.2

| 项目 | 状态 |
|------|------|
| 文件 | `docs/hexagram-data-v0.2.json` |
| 总卦数 | 64（完整定义） |
| 激活卦数 | 16（Phase 1 MVP） |
| 基础卦 | 8（乾/坤/震/巽/坎/离/艮/兑） |
| 组合效果 | 16（同卦叠加/相生/相克/对冲） |
| 字段 | hexagramId / name / symbol / element / attribute / effectType / effectValue / effectUnit / description / fourRightsImpact |

**前端接入**：
- Talus loader.ts：loadHexagramData / getBaseHexagram / getCombinationEffect
- 单测：9/9 全过
- 数据路径：`frontend-integration/data/hexagram-data-v0.2.json`

---

## 六、Phase 1 基线锁定声明

当前经济参数层已完全定型，Phase 1 期间不需要任何修改。

如需调整（如哪吒要求调整 CREATOR 比例从45%到50%），将：
1. 另行通知所有 Agent
2. 更新此文档版本号到 v0.4
3. 重新跑链上验证（e2e 7/7）
4. 同步前端 config.ts + loader.ts

---

## 七、变更历史

| 版本 | 日期 | 变更 | 负责人 |
|------|------|------|--------|
| v0.1 | 2026-05-30 | 初始骨架 | 猫先森 |
| v0.2 | 2026-06-02 | 4权→7权单层 | 猫先森 + Talus |
| v0.3 | 2026-06-04 | 定稿锁定，基线确认 | 猫先森 |

---

*本文件为 Phase 1 基线锁定版本，任何改动须经雨娃 review + 哪吒确认。*
