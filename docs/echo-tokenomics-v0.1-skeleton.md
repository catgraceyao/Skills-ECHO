# ECHO 全周期 Tokenomics 骨架设计 v0.1

> 写给合约实现用的经济模型骨架。不求完美，先求可编码。
> 版本：v0.1 骨架 | 日期：2026-05-31
> 交付目标：06-03 前初稿，骨架完整即可编码

---

## 一、发行曲线（Token Issuance Curve）

### 1.1 代币定义

| 属性 | 值 |
|------|-----|
| 代币符号 | ECHO（游戏内积分）/ MEER（原生 gas） |
| 总量上限 | ECHO: 无硬顶，动态发行 / MEER: Qitmeer 原生，不控制 |
| 初始发行 | 第一轮启动时注入 1000 MEER 作为种子奖池 |
| 发行主体 | 游戏合约自动铸造（玩家投注 + 系统释放） |

### 1.2 ECHO 发行曲线（游戏积分）

**双轨发行**：

```
轨道A：投注驱动（玩家投入 MEER → 合约铸造等值 ECHO 进入流通）
轨道B：势位释放（高势位节点每日释放固定量 ECHO 到奖池）
```

**发行公式**：

```
每日总发行 = 投注流入 × 1.0 + 势位释放量

势位释放量 = Σ(节点势位 × 释放系数)
释放系数 = 0.001 × (1 - 当前流通量 / 软顶)

软顶 = 100,000 ECHO（可调节，DAO治理）
```

**发行衰减**：当流通量超过软顶 80% 时，释放系数自动衰减：

```
衰减后系数 = 基础系数 × (1 - 流通量比例)^2
流通量比例 = 当前流通量 / 软顶
```

### 1.3 种子奖池启动

| 阶段 | 注入量 | 来源 |
|------|--------|------|
| 第0轮 | 1000 MEER | 协议启动资金 |
| 第1-10轮 | 每轮 100 MEER | 协议持续注入 |
| 第11轮+ | 0 | 靠投注自给自足 |

---

## 二、通胀机制（Inflation Control）

### 2.1 通胀率目标

| 阶段 | 目标通胀率 | 控制手段 |
|------|-----------|---------|
| 启动期（1-30轮） | ≤ 50%/月 | 软顶限制 + 投注门槛 |
| 成长期（31-100轮） | ≤ 20%/月 | 自动衰减 + 燃烧机制 |
| 稳定期（101轮+） | ≤ 5%/月 | DAO 参数调节 |

### 2.2 燃烧机制（Burn）

**自动燃烧触发条件**：

```solidity
// 每轮结算时自动执行
function autoBurn() internal {
    uint256 burnAmount = totalBet * BURN_RATE / 10000;
    
    // 燃烧来源优先级：
    // 1. 平台手续费抽成部分（100%燃烧）
    // 2. 反虹吸税（100%燃烧）
    // 3. 囤卡惩罚（100%燃烧）
    // 4. 争议裁决罚没（50%燃烧，50%给反证者）
    
    _burn(address(this), burnAmount);
    emit Burn(block.timestamp, burnAmount, reason);
}
```

**燃烧率参数**：

| 场景 | 燃烧率 | 说明 |
|------|--------|------|
| 平台手续费 | 100% | 抽成的 3-5% 全部燃烧 |
| 反虹吸税 | 100% | 前10%卡额外扣的 5% 全部燃烧 |
| 囤卡惩罚 | 100% | 7天不打掉的排名对应价值燃烧 |
| 争议罚没 | 50% | 恶意创作者罚没的 50% 燃烧 |

### 2.3 通缩调节阀

**当通胀率连续3轮超过目标时，自动触发**：

```
调节动作：
1. 提高最低投注门槛（0.1 → 0.2 MEER）
2. 降低势位释放系数（×0.8）
3. 提高软顶（×1.2）
4. 增加燃烧加成（+10%）

恢复条件：连续5轮通胀率低于目标50%时，逐步回调
```

---

## 三、质押与罚没（Staking & Slashing）

### 3.1 质押场景

| 角色 | 质押量 | 质押目的 | 解锁周期 |
|------|--------|---------|---------|
| 创作者（铸卡） | 10 MEER | 防止垃圾卡 | 卡注销后 7 天 |
| 大使 | 50 MEER | 身份担保 | 退出后 30 天 |
| 审查员 | 100 MEER | 审查质量担保 | 退出后 14 天 |
| 节点运营 | 500 MEER | 网络稳定性 | 持续质押 |

### 3.2 罚没规则

```solidity
enum ViolationType {
    SPAM_CARD,        // 垃圾卡：无真实劳动成果
    DUPLICATE_FORK,   // 刷 fork：同一地址多次 fork
    SYBIL_ATTACK,     // 女巫攻击：多账号协同
    RANK_MANIPULATION,// 操纵排名：自买自卖
    REVIEW_FRAUD,     // 审查欺诈：通过违规皮肤
    COLLUSION         // 串谋：创作者与玩家串通
}

mapping(ViolationType => uint256) public slashRatio;

// 初始化罚没比例
constructor() {
    slashRatio[SPAM_CARD] = 10000;        // 100% 罚没
    slashRatio[DUPLICATE_FORK] = 5000;    // 50% 罚没
    slashRatio[SYBIL_ATTACK] = 10000;     // 100% 罚没
    slashRatio[RANK_MANIPULATION] = 8000;   // 80% 罚没
    slashRatio[REVIEW_FRAUD] = 5000;        // 50% 罚没
    slashRatio[COLLUSION] = 10000;          // 100% 罚没
}
```

**罚没分配**：

```
罚没总额 = 质押量 × slashRatio

分配：
- 50% 燃烧销毁
- 30% 给举报者（发现违规的人）
- 20% 给受影响用户（如买了垃圾皮肤的玩家）
```

### 3.3 争议仲裁流程

```
1. 举报：任何人可举报，需支付 0.05 MEER 反证质押
2. 审查：3名随机审查员72小时内审查
3. 裁决：
   - 2/3 同意 = 违规成立，执行罚没
   - 1/3 或 0/3 = 违规不成立，举报者质押没收
4. 上诉：创作者可在 7 天内上诉，需追加 0.1 MEER
5. 终审：5人陪审团，3/5 决定为终局
```

---

## 四、等级晋升数学模型（Level-up Math）

### 4.1 玩家等级（对战相关）

**经验值公式**：

```
XP_gain = 基础XP × 势位差倍率 × 连胜加成 × 时间衰减

基础XP = 投注额 / 0.1 MEER × 10 XP
势位差倍率 = 1 + (对手势位 - 自己势位) / 1000 （上限 3.0）
连胜加成 = 1 + 连胜次数 × 0.1 （上限 2.0，上限5连胜）
时间衰减 = 1 - (今日对战次数 - 50) / 100 （超过50场衰减，下限 0.5）
```

**等级表**：

| 等级 | XP 需求 | 解锁特权 |
|------|---------|---------|
| 青铜 | 0 | 基础对战 |
| 白银 | 1000 | 日上限 +20% |
| 黄金 | 5000 | 可使用史诗皮肤 |
| 铂金 | 20000 | 手续费 9 折 |
| 钻石 | 50000 | 可创建自定义卡牌 |
| 大师 | 100000 | 手续费 8 折 + 优先匹配 |
| 传说 | 200000 | 专属称号 + 手续费 7 折 |

### 4.2 创作者等级（势位相关）

**势位计算公式**：

```
势位 = (攻击力 × 0.3 + 技能数 × 0.25 + 生命值 × 0.25 + 收益倍率 × 0.2) × 时间衰减因子

攻击力 = Σ(调用次数 × 衰减权重)
衰减权重 = exp(-λ × 天数)，λ = ln(2)/30 （半衰期30天）

技能数 = 不同 fork 者数量 × 质量系数
质量系数 = fork 者平均势位 / 1000 （上限 2.0）

生命值 = 活跃贡献者数 × 连接节点数 / 100

收益倍率 = min(实际收益 / 100 MEER, 3.0)
```

**创作者等级**：

| 等级 | 势位要求 | 解锁特权 |
|------|---------|---------|
| 新手 | 0-100 | 铸卡，基础分润 |
| 进阶 | 100-500 | 皮肤市场权限 |
| 专家 | 500-2000 | 自定义分润比例 |
| 大师 | 2000-5000 | 优先推荐位 |
| 宗师 | 5000+ | 协议治理投票权 |

### 4.3 大使等级（邀请相关）

**邀请质量分**：

```
质量分 = Σ(被邀请者贡献值 × 留存系数)

留存系数：
- 3轮内活跃：1.0
- 7轮内活跃：0.7
- 30轮内活跃：0.4
- 超过30轮未活跃：0.1
```

**大使等级**：

| 等级 | 邀请人数 | 质量分 | 特权 |
|------|---------|--------|------|
| 青铜 | 31 | ≥ 50 | 手续费 9 折 |
| 白银 | 50 | ≥ 100 | 手续费 8.5 折 |
| 黄金 | 100 | ≥ 200 | 手续费 8 折 + 专属卡 |
| 铂金 | 200 | ≥ 500 | 手续费 7.5 折 + 优先客服 |
| 钻石 | 500 | ≥ 1000 | 手续费 7 折 + 治理提案权 |
| 荣誉 | 1000 | ≥ 2000 | 永久大使 + 手续费 6 折 |

**自动降级**：连续 90 天质量分低于阈值，自动降一级。

---

## 五、参数速查表

| 参数 | 值 | 可调 | 说明 |
|------|-----|------|------|
| 种子奖池 | 1000 MEER | ❌ | 启动资金，一次性 |
| 最低投注 | 0.1 MEER | ✅ | 通胀高时自动上调 |
| 封顶投注 | 10 MEER | ✅ | DAO 治理调节 |
| 平台抽成 | 3-5% | ✅ | 默认 3%，异常时 5% |
| 赢家分成 | 55% | ❌ | 固定 |
| 输家分成 | 25% | ❌ | 固定 |
| 创造者分成 | 15% | ❌ | 赢家7.5% + 输家7.5% |
| 技能原作者 | 5% | ❌ | 固定 |
| 反虹吸税 | 5% | ✅ | 前10%卡额外扣 |
| 日对战上限 | 50 | ✅ | 等级提升后增加 |
| 铸卡质押 | 10 MEER | ✅ | 防止垃圾卡 |
| 大使质押 | 50 MEER | ✅ | 身份担保 |
| 审查员质押 | 100 MEER | ✅ | 审查质量担保 |
| 争议举报质押 | 0.05 MEER | ❌ | 反证成本 |
| 争议上诉追加 | 0.1 MEER | ❌ | 终审成本 |
| 软顶 | 100,000 ECHO | ✅ | 通胀调节 |
| 衰减半衰期 | 30天 | ✅ | 势位计算参数 |
| 连胜加成上限 | 5连胜 | ❌ | 防止无限刷 |
| 囤卡惩罚周期 | 7天 | ✅ | 不打掉排名 |

---

## 六、待确认问题（需哪吒/团队拍板）

### 🔴 最高优先级
1. **ECHO 代币必要性**：是否需要独立 ECHO 代币，还是纯 MEER 循环足够？
2. **软顶数值**：100,000 ECHO 是否合理？需要模拟测算。
3. **罚没比例**：当前 50%-100% 是否过重？是否有法律风险？

### 🟡 高优先级
4. **通胀调节自动化**：自动调节阀是否过于激进？需要人工 override 机制？
5. **创作者等级治理权**：宗师级（5000+势位）获得投票权，门槛是否合理？
6. **大使退出机制**：荣誉大使不可退出，是否会导致利益固化？

### 🟢 中优先级
7. **燃烧率动态调整**：当前燃烧率固定，是否需要根据市场情况动态调整？
8. **时间衰减参数**：30天半衰期是否合理？不同领域（代码/文章/设计）是否应有不同衰减？
9. **多链扩展**：tokenomics 是否预留跨链扩展空间？

---

## 七、编码接口预留

### 7.1 合约接口清单

```solidity
// 发行控制
function setSoftCap(uint256 newCap) external onlyDAO;
function setBurnRate(uint256 newRate) external onlyDAO;
function setBaseCoefficient(uint256 newCoeff) external onlyDAO;

// 质押管理
function stake(uint256 amount, StakeType stakeType) external;
function unstake(uint256 stakeId) external;
function slash(address target, ViolationType violation) external onlyJury;

// 等级查询
function getPlayerLevel(address player) external view returns (uint256);
function getCreatorPotential(address creator) external view returns (uint256);
function getAmbassadorTier(address ambassador) external view returns (uint256);

// 经济参数
function getInflationRate() external view returns (uint256); // 万分比
function getCirculatingSupply() external view returns (uint256);
function getBurnedAmount() external view returns (uint256);
```

### 7.2 事件定义

```solidity
event Issuance(uint256 round, uint256 amount, uint256 source);
event Burn(uint256 timestamp, uint256 amount, string reason);
event Slash(address indexed target, uint256 amount, ViolationType violation);
event LevelUp(address indexed user, uint256 newLevel, uint256 xp);
event Stake(address indexed user, uint256 amount, StakeType stakeType);
event Unstake(address indexed user, uint256 stakeId, uint256 amount);
```

---

*骨架完成，待团队 review 后填充细节。*
