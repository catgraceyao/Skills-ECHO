# 《势位之战》游戏经济模型设计文档 v3.0

**版本**: v3.0
**撰写**: 猫先森（Cat.zhou）
**日期**: 2026-05-30
**状态**: Draft → 待哪吒/Seaman Review
**变更**: 从 v0.1 游戏经济模型升级为 ECHO 协议整体经济模型，新增防攻击机制、参数治理、经济循环模型

---

## 1. 设计哲学

《势位之战》是一款基于 ECHO Protocol 的卡牌对战游戏。每张卡牌即一个「创造者节点」（Creator Node），其属性由创造者在上游网络（如 OpenClaw 工作流、GitHub 贡献、微博影响力等）的**四权凭证**（Usage / Derive / Expand / Benefit）决定。

> **核心原则**: 卡牌强度 = 链外真实贡献的数学映射。没有付费抽卡，没有随机开包——玩家的每一分战力，都来自他们在数字世界中的真实劳动。

> **v3.0 升级**: 从单一游戏经济模型扩展为 ECHO 协议生态经济模型，涵盖创造者经济、对战经济、协议治理经济三层。

---

## 2. 四权映射模型（v3.0 升级）

### 2.1 四权定义（ECHO Protocol 标准）

| 四权维度 | 符号 | 链外含义 | 卡牌属性映射 | 经济含义 |
|---------|------|---------|------------|---------|
| **Usage**（使用权） | $U$ | 被实际使用的次数、点击量、调用量 | **攻击力 (ATK)** | 创造者内容的实际使用价值 |
| **Derive**（衍生权） | $D$ | 被二次创作、Fork、引用、改编的次数 | **技能数 (SKILL)** | 创造者内容的衍生创新能力 |
| **Expand**（扩展权） | $E$ | 生态扩展度：贡献者数、节点数、社区规模 | **生命值 (HP)** | 创造者生态的扩展能力 |
| **Benefit**（收益权） | $B$ | 已产生的经济收益、打赏、赞助总额 | **收益倍率 (MULT)** | 创造者内容的商业验证 |

### 2.2 属性计算公式（v3.0 优化）

#### 攻击力（ATK）—— Usage 映射

$$ATK = \alpha_U \cdot \ln(1 + U) + \beta_U \cdot \sqrt{U_{recent}} + \gamma_U \cdot \frac{U_{weekly}}{U_{total}}$$

其中：
- $U$：创造者的累计 Usage 值（总调用次数）
- $U_{recent}$：近 30 天 Usage 增量
- $U_{weekly}$：近 7 天 Usage 增量
- $U_{total}$：累计 Usage 总量
- $\alpha_U = 10$（基础权重）
- $\beta_U = 5$（近期活跃度权重）
- $\gamma_U = 3$（周活跃占比权重，新增）

**v3.0 升级**: 增加周活跃占比权重，鼓励持续活跃而非一次性爆发。

#### 技能数（SKILL）—— Derive 映射

$$SKILL = \min\left( \lfloor \alpha_D \cdot \ln(1 + D) + \beta_D \cdot \sqrt{D_{unique}} \rfloor, SKILL_{max} \right)$$

其中：
- $D$：累计 Derive 值（被 Fork / 引用次数）
- $D_{unique}$：独立衍生者数量（新增，防刷量）
- $\alpha_D = 3$（技能转换系数）
- $\beta_D = 2$（独立衍生者权重，新增）
- $SKILL_{max} = 8$（单卡牌最大技能数）

**v3.0 升级**: 增加独立衍生者数量权重，防止同一用户多次 Fork 刷技能数。

#### 生命值（HP）—— Expand 映射

$$HP = \alpha_E \cdot \ln(1 + E) + \beta_E \cdot \sqrt{C_{community}} + \gamma_E \cdot \ln(1 + N_{edges})$$

其中：
- $E$：累计 Expand 值（生态扩展度量）
- $C_{community}$：创造者社区的活跃贡献者数
- $N_{edges}$：创造者节点的 Edge 声明数量（新增）
- $\alpha_E = 15$（基础权重）
- $\beta_E = 8$（社区活跃度权重）
- $\gamma_E = 5$（Edge 声明权重，新增）

**v3.0 升级**: 增加 Edge 声明数量权重，鼓励创造者在 ECHO 网络中建立连接。

#### 收益倍率（MULT）—— Benefit 映射

$$MULT = 1 + \alpha_B \cdot \tanh\left( \frac{B}{B_{scale}} \right) + \beta_B \cdot \frac{B_{stable}}{B_{total}}$$

其中：
- $B$：累计 Benefit 值（已产生经济收益，单位：ECHO Token）
- $B_{stable}$：近 30 天稳定收益（新增）
- $B_{total}$：累计总收益
- $\alpha_B = 2.0$（最大额外倍率）
- $\beta_B = 0.5$（稳定收益权重，新增）
- $B_{scale} = 1000$（收益标准化常数）
- $\tanh$ 将倍率限制在 $[1, 3]$ 区间

**v3.0 升级**: 增加稳定收益权重，鼓励持续收益而非一次性爆发。

### 2.3 参数汇总表（v3.0 更新）

| 参数 | 符号 | 默认值 | 可调范围 | 说明 |
|-----|------|--------|---------|------|
| Usage 基础权重 | $\alpha_U$ | 10 | [5, 20] | 控制攻击力整体水平 |
| Usage 近期权重 | $\beta_U$ | 5 | [2, 10] | 控制"近期活跃"影响力 |
| Usage 周活跃权重 | $\gamma_U$ | 3 | [1, 5] | 周活跃占比（v3.0 新增） |
| Derive 转换系数 | $\alpha_D$ | 3 | [2, 5] | 每 e 次 Fork 产生约 1 个技能 |
| Derive 独立者权重 | $\beta_D$ | 2 | [1, 4] | 独立衍生者数量（v3.0 新增） |
| 最大技能数 | $SKILL_{max}$ | 8 | [4, 12] | 单卡技能上限 |
| HP 基础权重 | $\alpha_E$ | 15 | [10, 25] | 控制生命值整体水平 |
| HP 社区权重 | $\beta_E$ | 8 | [4, 15] | 社区贡献者影响 |
| HP Edge 权重 | $\gamma_E$ | 5 | [2, 8] | Edge 声明数量（v3.0 新增） |
| 收益最大倍率 | $\alpha_B$ | 2.0 | [1.0, 4.0] | 收益倍率上限 = $1 + \alpha_B$ |
| 收益稳定权重 | $\beta_B$ | 0.5 | [0.2, 1.0] | 稳定收益占比（v3.0 新增） |
| 收益标准化常数 | $B_{scale}$ | 1000 | [500, 5000] | 收益曲线拐点 |

---

## 3. 势位与收益函数（v3.0 升级）

### 3.1 势位定义

「势位」（$S$）是一个动态排名指标，综合反映卡牌在当前游戏生态中的相对优势：

$$S_i = \frac{Rank_i}{N_{active}} \in [0, 1]$$

其中：
- $Rank_i$：卡牌 $i$ 的综合战力排名（1 = 最强）
- $N_{active}$：过去 7 天内有活跃记录的总卡牌数
- $S_i = 0$ 表示最强，$S_i = 1$ 表示最弱

### 3.2 综合战力评分（v3.0 优化）

$$Power_i = w_1 \cdot ATK_i + w_2 \cdot SKILL_i \cdot \overline{dmg}_{skill} + w_3 \cdot HP_i + w_4 \cdot MULT_i \cdot \overline{reward}$$

其中：
- $\overline{dmg}_{skill}$：技能平均伤害期望值（约 15）
- $\overline{reward}$：平均单局收益（约 50 ECHO）
- 权重：$w_1 = 1.0, w_2 = 1.0, w_3 = 0.6, w_4 = 0.4$

**v3.0 升级**: 增加权重治理机制，权重可通过 GovernanceDAO 调整。

### 3.3 势位收益函数（核心经济公式，v3.0 优化）

卡牌参与对战获得的收益倍率由势位决定：

$$R_i = R_{base} \cdot MULT_i \cdot \phi(S_i, S_{opponent})$$

其中 $\phi$ 是势位对战函数：

$$\phi(S_{self}, S_{opp}) = \underbrace{\gamma \cdot (1 - S_{self})}_{\text{强者保底}} + \underbrace{(1 - \gamma) \cdot \max(0, S_{opp} - S_{self})}_{\text{以下克上奖励}} + \underbrace{\delta \cdot \mathbb{1}_{[S_{self} > 0.8]} \cdot \mathbb{1}_{[S_{opp} < 0.2]}}_{\text{逆袭 bonus（v3.0 新增）}}$$

参数：
- $R_{base} = 100$ ECHO（单局基础收益）
- $\gamma = 0.6$（强者保底比例）
- $(1 - \gamma) = 0.4$（以下克上奖励比例）
- $\delta = 0.2$（逆袭 bonus，v3.0 新增）

#### 收益函数特性分析（v3.0 更新）

| 场景 | $S_{self}$ | $S_{opp}$ | $\phi$ 值 | 策略含义 |
|-----|-----------|-----------|-----------|---------|
| 强强对话 | 0.1 | 0.15 | $0.6 \cdot 0.9 + 0.4 \cdot 0.05 = 0.56$ | 高风险高回报 |
| 弱弱对话 | 0.8 | 0.85 | $0.6 \cdot 0.2 + 0.4 \cdot 0.05 = 0.14$ | 低风险低回报 |
| 以下克上 | 0.8 | 0.1 | $0.6 \cdot 0.2 + 0.4 \cdot 0.7 + 0.2 = 0.60$ | 弱者大奖励（v3.0 升级） |
| 强者碾压 | 0.1 | 0.8 | $0.6 \cdot 0.9 + 0.4 \cdot 0 = 0.54$ | 强者保底高 |
| 逆袭成功 | 0.85 | 0.05 | $0.6 \cdot 0.15 + 0.4 \cdot 0.8 + 0.2 = 0.61$ | 最大奖励（v3.0 新增） |

**v3.0 关键洞察**: 弱卡牌战胜强卡牌时，$\phi$ 跃升至 $0.60$（对比弱弱对话的 $0.14$），激励玩家发掘"潜力股"创造者。新增逆袭 bonus，让极端以下克上获得额外奖励。

### 3.4 连败保护机制（v3.0 优化）

为新手/弱势玩家提供保护：

$$R_{actual} = R_i \cdot \left( 1 + \sigma \cdot \min(loss_{streak}, 5) \right) \cdot \left( 1 + \tau \cdot \mathbb{1}_{[win_{streak} \geq 3]} \right) \quad \text{if } loss_{streak} > 2$$

- $\sigma = 0.1$（每连败一局 +10% 收益）
- $\tau = -0.05$（连胜 3 局以上 -5% 收益，v3.0 新增，防止刷连胜）
- 最大连败保护：5 连败后 +50%
- 获胜后 streak 重置

**v3.0 升级**: 增加连胜衰减，防止高排名玩家通过连胜垄断收益。

---

## 4. 对战分账算法（v3.0 升级）

### 4.1 对战结果模型

一局对战涉及：
- **玩家 A**: 使用创造者 $C_A$ 的卡牌（支付入场费 $F$）
- **玩家 B**: 使用创造者 $C_B$ 的卡牌（支付入场费 $F$）
- **平台**: 收取手续费率 $\theta$
- **奖池**: $P = 2F \cdot (1 - \theta)$

### 4.2 贡献权重计算（v3.0 优化）

#### 4.2.1 胜负贡献

$$W_{win} = 0.55, \quad W_{lose} = 0.25$$

胜利者获得 55% 奖池（v3.0 从 60% 下调），败者获得 25% 奖池（v3.0 从 20% 上调），剩余 20% 进入贡献者分配。

**v3.0 调整理由**: 降低胜者垄断，提高败者安慰奖，鼓励更多玩家参与。

#### 4.2.2 创造者贡献

$$W_{creator} = 0.15$$

对战双方卡牌的创造者各获得奖池的 7.5%（无论胜负）。

$$Reward_{creator} = P \cdot 0.075$$

**v3.0 新增**: 创造者收益与卡牌势位挂钩，高势位卡牌创造者获得额外 2.5% 奖励。

$$Reward_{creator,bonus} = P \cdot 0.025 \cdot (1 - S_{card})$$

#### 4.2.3 技能设计者贡献（Derive 链条，v3.0 优化）

$$W_{derive} = 0.05$$

分配方式（以技能 $k$ 为例）：

$$Reward_{derive,k} = P \cdot 0.05 \cdot \frac{dmg_k}{total_dmg} \cdot \frac{1}{depth_k}$$

其中 $depth_k$ 是技能 remix 链条深度（v3.0 新增），防止无限追溯导致收益稀释。

### 4.3 完整分账公式（v3.0 更新）

$$\text{Total Pool} = 2F$$

$$\text{Platform Fee} = 2F \cdot \theta$$

$$\text{Distributable} = 2F \cdot (1 - \theta) = P$$

| 接收方 | 权重 | 金额 | 触发条件 |
|-------|------|------|---------|
| 获胜玩家 | 0.55 | $P \cdot 0.55 \cdot \phi(S_{win}, S_{lose})$ | 对战结束 |
| 失败玩家 | 0.25 | $P \cdot 0.25$ | 对战结束（安慰奖）|
| 创造者 A | 0.075 | $P \cdot 0.075$ | 卡牌 $C_A$ 参与 |
| 创造者 B | 0.075 | $P \cdot 0.075$ | 卡牌 $C_B$ 参与 |
| 创造者 bonus | 0.025 | $P \cdot 0.025 \cdot (1 - S_{card})$ | 势位奖励（v3.0 新增）|
| Derive 链条 | 0.05 | $P \cdot 0.05 \cdot \frac{dmg_{fork}}{total} \cdot \frac{1}{depth}$ | 使用了 Fork 技能（v3.0 优化）|
| **合计** | **1.025** | **$P \cdot 1.025$** | |

**v3.0 说明**: 合计权重 > 1.0，因为创造者 bonus 和 Derive 链条深度折扣是乘法调整，实际总分配仍为 $P$。

### 4.4 实际收益计算（含 MULT 和连败保护，v3.0 优化）

$$R_{player} = base \cdot MULT_{card} \cdot \phi(S_{self}, S_{opp}) \cdot (1 + \sigma \cdot streak) \cdot (1 + \tau \cdot \mathbb{1}_{[win_{streak} \geq 3]})$$

$$Final = \min\left( R_{player}, P \cdot weight \right)$$

（上限保护：玩家收益不超过其权重对应的奖池份额）

---

## 5. 防攻击机制（v3.0 重大升级）

### 5.1 Whale 控盘攻击（v3.0 优化）

**攻击场景**: 大资本收购高排名卡牌，垄断对战、操控收益分配。

#### 防御机制（v3.0 升级）

| 机制 | 参数 | 说明 |
|-----|------|------|
| **MULT 收益上限** | $MULT_{max} = 3.0$ | 即使 Benefit 再高，倍率不超 3x |
| **对数增长瓶颈** | ATK/HP 使用 $\ln(1+x)$ | 资本投入边际收益递减 |
| **势位动态重算** | 每 24h 更新排名 | 资本优势不持续累积 |
| **战力膨胀控制** | $Power_{cap} = 1000$ | 绝对战力上限 |
| **新卡保护期** | 72h 内不参与排名 | 给新创造者公平起步 |
| **反虹吸税** | $top\_10\%$ 卡牌额外 $5\%$ 手续费 | 资本集中惩罚 |
| **持有上限** | 单地址最多持有 5 张卡牌 | 防止垄断（v3.0 新增） |
| **对战频率限制** | 单地址日对战上限 50 场 | 防止刷量（v3.0 新增） |
| **势位衰减** | 高势位卡牌 7 天未对战，势位 +0.1 | 防止囤卡（v3.0 新增） |

**链上实现（反虹吸税 + 持有上限，v3.0 升级）**:
```solidity
function resolveBattle(uint256 battleId) internal {
    Battle storage b = battles[battleId];
    uint256 totalPool = b.stake * 2;
    uint256 platformFee = totalPool * platformFeeRate / 10000;
    uint256 distributable = totalPool - platformFee;
    
    // 反虹吸税：检查 MULT ≥ 2.5（top 10% 阈值）
    uint256 multA = cardNFT.getCard(b.cardA).mult;
    uint256 multB = cardNFT.getCard(b.cardB).mult;
    uint256 antiWhaleFee = 0;
    
    if (multA >= 250 || multB >= 250) { // MULT 放大 100 倍，250 = 2.5
        antiWhaleFee = distributable * 500 / 10000; // 额外 5%
        distributable -= antiWhaleFee;
        publicPool += antiWhaleFee;
    }
    
    // 持有上限检查（v3.0 新增）
    require(balanceOf(b.playerA) <= 5, "Exceeds card holding limit");
    require(balanceOf(b.playerB) <= 5, "Exceeds card holding limit");
    
    // 对战频率限制（v3.0 新增）
    require(dailyBattleCount[b.playerA] < 50, "Daily battle limit reached");
    require(dailyBattleCount[b.playerB] < 50, "Daily battle limit reached");
    
    // 正常分账...
}
```

**参数阈值**:
- 当单地址持有卡牌总战力 > 全网 20% 时，触发「垄断预警」
- 当单卡牌 Benefit 增速 > 300% / 周时，触发「异常资本流入」审查
- 垄断地址的卡牌 MULT 衰减：$MULT_{effective} = MULT \cdot (1 - 0.1 \cdot \frac{hold_power}{total_power})$
- 单地址日对战 > 50 场 → 收益衰减 50%（v3.0 新增）
- 高势位卡牌 7 天未对战 → 势位 +0.1（v3.0 新增）

### 5.2 Sybil 刷分攻击（v3.0 优化）

**攻击场景**: 攻击者创建大量虚假创造者账号，伪造 Usage/Derive/Expand 数据，刷出高属性卡牌。

#### 防御机制（v3.0 升级）

| 机制 | 参数 | 说明 |
|-----|------|------|
| **创造者验证** | 最小 $D = 3$ 才能 mint 卡牌 | 需要真实被 Fork |
| **声誉门槛** | $U \geq 50$ 且 $E \geq 10$ | 新创造者不能立即参战 |
| **链外凭证锚定** | GitHub / 微博 OAuth 绑定 | 一人多号需多平台身份 |
| **异常检测** | $U$ 来自同一 IP 段 > 80% → 降权 | 刷量识别 |
| **经济成本** | Mint 费用 = $10 + 0.01 \cdot U^2$ ECHO | 批量造卡成本递增 |
| **冷却期** | 新卡 24h 内属性锁定 | 防止快速迭代测试 |
| **独立衍生者检查** | $D_{unique} < 2$ → 技能数封顶 3 | 防止自刷 Fork（v3.0 新增） |
| **行为模式检测** | 同一创造者日对战 > 30 场 → 标记 | 异常行为识别（v3.0 新增） |
| **社交图谱验证** | 创造者需在 ECHO 网络有 ≥2 条 Edge | 防止孤立账号（v3.0 新增） |

**参数阈值**:
- 同一 IP 段日新增创造者 > 10 个 → 标记审查
- 同一创造者日对战次数 > 30 场 → 收益衰减 50%（v3.0 从 100 下调）
- 新创造者首周 Benefit 增速 > 500% → 冻结收益 7 天
- 创造者被举报 > 3 次 → 进入「观察模式」，属性隐藏
- 独立衍生者 < 2 → 技能数封顶 3（v3.0 新增）
- 社交图谱 Edge < 2 → 无法参与对战（v3.0 新增）

### 5.3 MEV / 抢先跑攻击（v3.0 优化）

**攻击场景**: 矿工/搜索者在对战结果上链前，根据内存池信息提前操作卡牌属性或下注。

#### 防御机制（v3.0 升级）

| 机制 | 参数 | 说明 |
|-----|------|------|
| **对战盲签** | 对战参数用 VRF 加密提交 | 对手属性在揭示前不可见 |
| **提交-揭示机制** | Commit: hash(ATK, HP, nonce) | 先提交承诺，后揭示 |
| **揭示窗口** | 300 秒 | 超时不揭示判负 |
| **属性冻结** | 对战提交后锁定属性 600 秒 | 防止对战中途改卡 |
| **VRF 随机数** | 复用 ECHO v0.4 多源熵 | 无需 Chainlink，QNG 原生支持 |
| **批次结算** | 每 10 局批量结算 | 单笔操作影响降低 |
| **内存池隔离** | 对战提交后 60 秒内不可见 | 防止 MEV 扫描（v3.0 新增） |
| **随机延迟** | 揭示后 10-30 秒随机延迟上链 | 防止抢先跑（v3.0 新增） |

**VRF 实现（复用 ECHO v0.4 多源熵，v3.0 优化）**:
```solidity
function generateRandom(uint256 battleId, uint256 nonce) internal view returns (uint256) {
    // 多源熵：blockhash + timestamp + gasprice + nonce + 内存池哈希（v3.0 新增）
    return uint256(keccak256(abi.encodePacked(
        blockhash(block.number - 1),
        block.timestamp,
        tx.gasprice,
        nonce,
        battleId,
        mempoolHash() // v3.0 新增：内存池状态哈希
    )));
}
```

**参数阈值**:
- Commit 到 Reveal 最大间隔：300 秒
- Reveal 后上链确认窗口：150 秒
- 单区块内同地址对战提交上限：5 局
- 属性修改后冷却：600 秒（才能再次对战）
- 内存池隔离：60 秒（v3.0 新增）
- 随机延迟：10-30 秒（v3.0 新增）

### 5.4 其他攻击向量（v3.0 新增）

#### 5.4.1 合约重入攻击
- 所有收益分配使用 **Checks-Effects-Interactions** 模式
- 使用 ReentrancyGuard（OpenZeppelin）
- 收益先发事件日志，再转账

#### 5.4.2 预言机操纵
- 四权数据来自多个源：GitHub API、OpenClaw 工作流、微博 API
- 使用**中位数聚合**而非平均值：至少 3 个数据源
- 单源偏差 > 30% 时自动弃用
- **v3.0 新增**: 预言机数据延迟 1 小时，防止实时操纵

#### 5.4.3 Gas 攻击
- 分账计算链下完成，链上仅验证 Merkle Root
- 批量结算减少 Gas 消耗
- 紧急暂停机制：Owner 可冻结对战
- **v3.0 新增**: Gas 上限保护，单笔对战 Gas > 500,000 自动回滚

#### 5.4.4 刷连败保护攻击（v3.0 新增）
**攻击场景**: 故意连败触发连败保护，获得高收益后再赢一局。

**防御**:
- 连败保护只触发 3 次，之后重置
- 故意连败检测：连续 5 场对战时长 < 30 秒 → 标记为故意败
- 故意败收益衰减 90%

#### 5.4.5 卡牌租赁攻击（v3.0 新增）
**攻击场景**: 高排名玩家租赁低排名卡牌，利用逆袭 bonus 刷高收益。

**防御**:
- 卡牌租赁需 24 小时冷却期
- 租赁卡牌势位计算使用原持有者数据
- 租赁卡牌收益 50% 归原持有者

---

## 6. 合约接口设计（v3.0 升级）

### 6.1 CardNFT 合约（v3.0 优化）

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICardNFT {
    // ========== 数据结构 ==========
    
    struct CardAttributes {
        uint256 atk;           // 攻击力 (Usage 映射)
        uint256 skillCount;    // 技能数 (Derive 映射)
        uint256 hp;            // 生命值 (Expand 映射)
        uint256 mult;          // 收益倍率 (Benefit 映射, 放大 100 倍)
        uint256 usage;         // 原始 Usage 值
        uint256 derive;        // 原始 Derive 值
        uint256 expand;        // 原始 Expand 值
        uint256 benefit;       // 原始 Benefit 值
        uint256 uniqueDerive;  // 独立衍生者数量（v3.0 新增）
        uint256 edgeCount;     // Edge 声明数量（v3.0 新增）
        uint256 stableBenefit; // 近 30 天稳定收益（v3.0 新增）
        address creator;       // 创造者地址
        uint256 mintTime;      // 铸造时间
        uint256 lastUpdate;    // 最后更新时间
        bytes32 sourceId;      // 链外创造者 ID 哈希
        uint256 lastBattleTime; // 最后对战时间（v3.0 新增）
    }
    
    struct Skill {
        uint256 skillId;
        string name;
        uint256 baseDamage;
        uint256 effectType;    // 0=伤害, 1=治疗, 2=护盾, 3=Debuff
        address originCreator; // 技能原创造者（Derive 追溯）
        bytes32 deriveFrom;    // 父技能 ID（ remix 链条）
        uint256 depth;         // remix 链条深度（v3.0 新增）
    }
    
    // ========== 事件 ==========
    
    event CardMinted(
        uint256 indexed tokenId,
        address indexed creator,
        bytes32 sourceId,
        uint256 atk,
        uint256 skillCount,
        uint256 hp,
        uint256 mult
    );
    
    event CardAttributesUpdated(
        uint256 indexed tokenId,
        uint256 atk,
        uint256 skillCount,
        uint256 hp,
        uint256 mult,
        uint256 timestamp
    );
    
    event SkillAdded(
        uint256 indexed tokenId,
        uint256 indexed skillId,
        string name,
        address originCreator
    );
    
    // ========== 核心函数 ==========
    
    /// @notice 铸造新卡牌（需满足创造者门槛）
    /// @param sourceId 链外创造者 ID 哈希
    /// @param initialAttrs 初始四权值 [U, D, E, B]
    /// @return tokenId 新卡牌 ID
    function mintCard(
        bytes32 sourceId,
        uint256[4] calldata initialAttrs
    ) external payable returns (uint256 tokenId);
    
    /// @notice 更新卡牌属性（预言机调用，v3.0 优化）
    /// @param tokenId 卡牌 ID
    /// @param newAttrs 新四权值 [U, D, E, B]
    /// @param newUniqueDerive 新独立衍生者数量（v3.0 新增）
    /// @param newEdgeCount 新 Edge 声明数量（v3.0 新增）
    /// @param newStableBenefit 新稳定收益（v3.0 新增）
    function updateAttributes(
        uint256 tokenId,
        uint256[4] calldata newAttrs,
        uint256 newUniqueDerive,
        uint256 newEdgeCount,
        uint256 newStableBenefit
    ) external;
    
    /// @notice 获取卡牌完整属性
    function getCard(uint256 tokenId) 
        external 
        view 
        returns (CardAttributes memory);
    
    /// @notice 获取卡牌技能列表
    function getSkills(uint256 tokenId)
        external
        view
        returns (Skill[] memory);
    
    /// @notice 计算卡牌综合战力
    function calculatePower(uint256 tokenId)
        external
        view
        returns (uint256 power);
    
    /// @notice 检查卡牌是否在对战冷却中
    function isOnCooldown(uint256 tokenId) 
        external 
        view 
        returns (bool);
    
    /// @notice 获取卡牌势位（v3.0 新增）
    function getShiPosition(uint256 tokenId)
        external
        view
        returns (uint256 rank, uint256 totalActive);
    
    /// @notice 租赁卡牌（v3.0 新增）
    function rentCard(uint256 tokenId, address renter, uint256 duration) external;
    
    /// @notice 归还租赁卡牌（v3.0 新增）
    function returnRentedCard(uint256 tokenId) external;
    
    // ========== 管理函数 ==========
    
    function setAttributeWeights(
        uint256[7] calldata weights // v3.0 从 4 扩展到 7
    ) external;
    
    function setMintThreshold(
        uint256 minUsage,
        uint256 minDerive,
        uint256 minExpand,
        uint256 minUniqueDerive, // v3.0 新增
        uint256 minEdgeCount      // v3.0 新增
    ) external;
    
    function setCooldownPeriod(uint256 seconds_) external;
    function setHoldingLimit(uint256 limit) external; // v3.0 新增
    function setDailyBattleLimit(uint256 limit) external; // v3.0 新增
}
```

### 6.2 GamePool 合约（v3.0 优化）

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGamePool {
    // ========== 数据结构 ==========
    
    struct Battle {
        uint256 battleId;
        address playerA;
        address playerB;
        uint256 cardA;
        uint256 cardB;
        uint256 stake;           // 单局入场费
        bytes32 commitA;         // 玩家 A 承诺哈希
        bytes32 commitB;         // 玩家 B 承诺哈希
        uint256 revealA;         // 玩家 A 揭示 nonce
        uint256 revealB;         // 玩家 B 揭示 nonce
        uint256 startTime;
        uint256 commitDeadline;
        uint256 revealDeadline;
        uint256 mempoolIsolationEnd; // 内存池隔离结束时间（v3.0 新增）
        uint256 randomDelay;     // 随机延迟（v3.0 新增）
        BattleState state;
        BattleResult result;
        uint256[4] damageLog;    // [A技能1, A技能2, B技能1, B技能2]
    }
    
    enum BattleState {
        Pending,     // 等待对手加入
        Committed,   // 双方已提交承诺
        Revealed,    // 双方已揭示
        Resolved,    // 结果已计算
        Disputed,    // 争议状态
        MempoolIsolated // 内存池隔离（v3.0 新增）
    }
    
    enum BattleResult {
        Undecided,
        PlayerA_Win,
        PlayerB_Win,
        Draw,
        Timeout,     // 一方未按时揭示
        IntentionalLoss // 故意败（v3.0 新增）
    }
    
    struct Distribution {
        address recipient;
        uint256 amount;
        DistributionType distType;
    }
    
    enum DistributionType {
        Winner,
        LoserConsolation,
        CreatorFee,
        CreatorBonus, // v3.0 新增
        DeriveReward,
        PlatformFee
    }
    
    // ========== 事件（已确认部署版本） ==========
    
    event BattleCreated(
        uint256 indexed battleId,
        address indexed player1,
        address indexed player2,
        uint256 betAmount,
        uint256 param4,
        uint256 param5
    );
    
    event BattleResolved(
        uint256 indexed battleId,
        address indexed winner,
        uint256 payout
    );
    
    event BattleJoined(
        uint256 indexed battleId,
        address indexed playerB,
        uint256 cardB
    );
    
    event BattleCommitted(
        uint256 indexed battleId,
        address indexed player,
        bytes32 commitHash
    );
    
    event BattleRevealed(
        uint256 indexed battleId,
        address indexed player,
        uint256 nonce
    );
    
    event RewardDistributed(
        uint256 indexed battleId,
        address indexed recipient,
        uint256 amount,
        DistributionType distType
    );
    
    // ========== 核心函数 ==========
    
    /// @notice 创建对战（支付入场费）
    function createBattle(uint256 cardId) external payable returns (uint256 battleId);
    
    /// @notice 加入对战
    function joinBattle(uint256 battleId, uint256 cardId) external payable;
    
    /// @notice 提交承诺哈希
    function commitMove(uint256 battleId, bytes32 commitHash) external;
    
    /// @notice 揭示 nonce（校验承诺）
    function revealMove(uint256 battleId, uint256 nonce) external;
    
    /// @notice 结算对战（任何人可调用，按规则自动计算）
    function resolveBattle(uint256 battleId) external;
    
    /// @notice 批量结算（Gas 优化）
    function batchResolve(uint256[] calldata battleIds) external;
    
    /// @notice 领取累积收益
    function claimRewards() external;
    
    /// @notice 查询待领取收益
    function pendingRewards(address player) external view returns (uint256);
    
    /// @notice 报告故意败（v3.0 新增）
    function reportIntentionalLoss(uint256 battleId, string calldata evidence) external;
    
    // ========== 势位函数 ==========
    
    function getShiPosition(uint256 cardId) 
        external 
        view 
        returns (uint256 rank, uint256 totalActive);
    
    function calculateRewardMultiplier(
        uint256 cardA,
        uint256 cardB
    ) external view returns (uint256 multA, uint256 multB);
    
    // ========== 管理函数 ==========
    
    function setEntryFee(uint256 fee) external;
    function setPlatformFeeRate(uint256 basisPoints) external;
    function setDistributionWeights(
        uint256 winnerWeight,
        uint256 loserWeight,
        uint256 creatorWeight,
        uint256 creatorBonusWeight, // v3.0 新增
        uint256 deriveWeight
    ) external;
    function setMempoolIsolation(uint256 seconds_) external; // v3.0 新增
    function setRandomDelayRange(uint256 min, uint256 max) external; // v3.0 新增
    function emergencyPause() external;
    function emergencyUnpause() external;
}
```

### 6.3 ECHO 集成合约（ECHOBond 扩展，v3.0 优化）

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IECHOGameBond {
    // ========== ECHO 协议集成 ==========
    
    /// @notice 将 ECHO EdgeDeclaration 中的四权凭证绑定到卡牌
    function bindDeclaration(
        uint256 tokenId,
        uint256 declarationId
    ) external;
    
    /// @notice 从 MilestoneEscrow 提取收益并注入游戏奖池
    function injectMilestoneReward(
        uint256 escrowId,
        uint256 milestoneIndex
    ) external;
    
    /// @notice 将游戏收益反向注入创作者 MilestoneEscrow
    function feedCreatorEscrow(
        uint256 tokenId,
        uint256 amount
    ) external;
    
    /// @notice 查询卡牌绑定的 ECHO 凭证
    function getBoundDeclaration(uint256 tokenId)
        external
        view
        returns (
            uint256 declarationId,
            uint256 usage,
            uint256 derive,
            uint256 expand,
            uint256 benefit,
            uint256 uniqueDerive, // v3.0 新增
            uint256 edgeCount,    // v3.0 新增
            bool isActive
        );
    
    /// @notice 批量绑定声明（v3.0 新增，Gas 优化）
    function batchBindDeclarations(
        uint256[] calldata tokenIds,
        uint256[] calldata declarationIds
    ) external;
    
    // ========== 跨合约事件 ==========
    
    event DeclarationBound(
        uint256 indexed tokenId,
        uint256 indexed declarationId,
        uint256 usage,
        uint256 derive,
        uint256 expand,
        uint256 benefit
    );
    
    event MilestoneInjected(
        uint256 indexed escrowId,
        uint256 indexed milestoneIndex,
        uint256 amount,
        uint256 gamePoolBalance
    );
    
    event CreatorEscrowFed(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 amount,
        uint256 newBenefit
    );
    
    event BatchBindCompleted(
        uint256[] tokenIds,
        uint256[] declarationIds,
        uint256 timestamp
    ); // v3.0 新增
}
```

---

## 7. 与 ECHO 现有合约集成点（v3.0 升级）

### 7.1 CreatorConfig 集成

| ECHO 合约 | 集成方式 | 数据流向 |
|----------|---------|---------|
| **CreatorConfig** | 读取创造者注册信息 | CardNFT.mintCard() 时校验创造者是否在 CreatorConfig 注册 |
| | 验证创造者身份 | 绑定 `sourceId ↔ creatorAddress` 映射 |
| | 社交图谱验证 | 检查创造者 Edge 数量 ≥ 2（v3.0 新增） |

### 7.2 EdgeDeclaration 集成

| ECHO 合约 | 集成方式 | 数据流向 |
|----------|---------|---------|
| **EdgeDeclaration** | 读取四权凭证 | CardNFT.updateAttributes() 从 EdgeDeclaration 获取最新 U/D/E/B |
| | 技术债务声明 | 高 Derive 值卡牌需声明其 remix 来源 |
| | 独立衍生者统计 | 从 EdgeDeclaration 获取独立衍生者数量（v3.0 新增） |
| | Edge 数量统计 | 从 EdgeDeclaration 获取创造者 Edge 数量（v3.0 新增） |

### 7.3 MilestoneEscrow 集成

| ECHO 合约 | 集成方式 | 数据流向 |
|----------|---------|---------|
| **MilestoneEscrow** | 正向注入 | 游戏平台收益 → 创作者里程碑托管 |
| | 反向提取 | 里程碑达成奖励 → 游戏奖池注入 |
| | 稳定收益计算 | 从 MilestoneEscrow 获取近 30 天稳定收益（v3.0 新增） |

### 7.4 DeadlockInspectorP1 集成

| ECHO 合约 | 集成方式 | 数据流向 |
|----------|---------|---------|
| **DeadlockInspectorP1** | 争议仲裁 | 对战超时/争议提交 Inspector 裁决 |
| | 结果验证 | Inspector 裁决结果写入 GamePool |
| | 故意败审查 | 争议中涉及故意败的审查（v3.0 新增） |

---

## 8. 参数配置建议（分阶段，v3.0 更新）

### 8.1 测试网阶段（Qitmeer Testnet）

| 参数 | 测试网值 | 说明 |
|-----|---------|------|
| 入场费 $F$ | 0.001 MEER | 免费体验 |
| 平台费率 $\theta$ | 5% | 覆盖测试成本 |
| 属性更新间隔 | 1 小时 | 快速验证公式 |
| 对战冷却 | 60 秒 | 快速迭代 |
| Commit-Reveal 窗口 | 60 / 30 秒 | 短周期测试 |
| 最小门槛 | U ≥ 5, D ≥ 1 | 低门槛 |
| 收益上限 | MULT_max = 5.0 | 测试期放宽 |
| 持有上限 | 10 张 | 测试期宽松（v3.0 新增） |
| 日对战上限 | 100 场 | 测试期宽松（v3.0 新增） |

### 8.2 软启动阶段（QNG Mainnet - 低门槛）

| 参数 | 软启动值 | 说明 |
|-----|---------|------|
| 入场费 $F$ | 0.1 MEER | 低门槛吸引早期用户 |
| 平台费率 $\theta$ | 4% | 降低摩擦 |
| 属性更新间隔 | 6 小时 | 平衡实时性与 Gas |
| 对战冷却 | 300 秒 | 适度冷却 |
| Commit-Reveal 窗口 | 180 / 90 秒 | 中等周期 |
| 最小门槛 | U ≥ 20, D ≥ 2 | 轻度筛选 |
| 收益上限 | MULT_max = 4.0 | 过渡期 |
| 持有上限 | 5 张 | 防止垄断（v3.0 新增） |
| 日对战上限 | 50 场 | 防刷保护（v3.0 新增） |

### 8.3 增长阶段（QNG Mainnet - 中度）

| 参数 | 增长期值 | 说明 |
|-----|---------|------|
| 入场费 $F$ | 1 MEER | 中度门槛 |
| 平台费率 $\theta$ | 3.5% | 逐步降低 |
| 属性更新间隔 | 12 小时 | 接近主网节奏 |
| 对战冷却 | 450 秒 | 增加策略深度 |
| Commit-Reveal 窗口 | 240 / 120 秒 | 接近主网 |
| 最小门槛 | U ≥ 35, D ≥ 3 | 中度筛选 |
| 收益上限 | MULT_max = 3.5 | 接近主网 |
| 持有上限 | 5 张 | 防止垄断（v3.0 新增） |
| 日对战上限 | 50 场 | 防刷保护（v3.0 新增） |

### 8.4 主网阶段（QNG Mainnet - 成熟期）

| 参数 | 主网值 | 说明 |
|-----|--------|------|
| 入场费 $F$ | 10 ECHO | 成熟经济规模 |
| 平台费率 $\theta$ | 3% | 最低摩擦 |
| 属性更新间隔 | 24 小时 | 链外计算日更 |
| 对战冷却 | 600 秒 | 策略深度 |
| Commit-Reveal 窗口 | 300 / 150 秒 | 标准周期 |
| 最小门槛 | U ≥ 50, D ≥ 3, E ≥ 10 | 严格筛选 |
| 收益上限 | MULT_max = 3.0 | 防鲸控制 |
| 持有上限 | 5 张 | 防止垄断（v3.0 新增） |
| 日对战上限 | 50 场 | 防刷保护（v3.0 新增） |
| 批量结算 | 每 10 局 | Gas 优化 |

### 8.5 参数治理（v3.0 新增）

所有核心参数通过 **ECHO GovernanceDAO** 治理：
- 参数变更提案需持有 1000 ECHO 以上
- 投票周期 7 天
- 执行延迟 2 天（Timelock）
- 紧急参数（手续费率）Owner 可在 24h 内调整
- **v3.0 新增**: 参数变更需通过游戏内 A/B 测试验证（100 场对战数据）
- **v3.0 新增**: 参数治理委员会包含 1 名玩家代表（由玩家投票选出）

---

## 9. 经济循环模型（v3.0 升级）

```
                    ┌─────────────┐
                    │   创造者    │
                    │  创作内容   │
                    └──────┬──────┘
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
       ┌────────┐   ┌────────┐    ┌──────────┐
       │ Usage  │   │ Derive │    │  Expand  │
       │ 使用   │   │ 衍生   │    │  扩展    │
       └───┬────┘   └───┬────┘    └────┬─────┘
           │            │              │
           ▼            ▼              ▼
    ┌─────────────────────────────────────────┐
    │           EdgeDeclaration               │
    │      四权凭证上链声明                    │
    └─────────────────────────────────────────┘
                     │
                     ▼
              ┌──────────────┐
              │   CardNFT    │
              │  卡牌铸造    │
              │ ATK/HP/SKILL │
              └──────┬───────┘
                     │
                     ▼
              ┌──────────────┐
              │   GamePool   │
              │  对战 + 分账  │
              │ 玩家/创造者  │
              │   均获益    │
              └──────┬───────┘
                     │
          ┌─────────┴──────────┐
          ▼                    ▼
   ┌─────────────┐      ┌─────────────┐
   │   玩家收益   │      │ 创造者收益   │
   │  再投资/持有 │      │ Milestone   │
   └─────────────┘      │   Escrow    │
                        └──────┬──────┘
                               │
                               ▼
                        ┌─────────────┐
                        │  新里程碑   │
                        │  新创作激励  │
                        └─────────────┘
                        │
                        ▼
                 ┌─────────────┐
                 │  ECHO 协议   │
                 │  生态扩展    │
                 │  新创造者    │
                 └─────────────┘
```

**v3.0 升级**: 经济循环从"游戏内循环"扩展为"ECHO 协议生态循环"，包含：
1. 创造者经济：创作 → 四权凭证 → 卡牌铸造
2. 对战经济：对战 → 分账 → 玩家/创造者收益
3. 协议经济：收益 → MilestoneEscrow → 新创作 → 新创造者

---

## 10. 附录

### A. 关键公式速查（v3.0 更新）

| 公式 | 用途 | 位置 |
|-----|------|------|
| $ATK = 10\ln(1+U) + 5\sqrt{U_{recent}} + 3\cdot\frac{U_{weekly}}{U_{total}}$ | 攻击力计算 | §2.2 |
| $SKILL = \min(\lfloor 3\ln(1+D) + 2\sqrt{D_{unique}} \rfloor, 8)$ | 技能数计算 | §2.2 |
| $HP = 15\ln(1+E) + 8\sqrt{C} + 5\ln(1+N_{edges})$ | 生命值计算 | §2.2 |
| $MULT = 1 + 2\tanh(B/1000) + 0.5\cdot\frac{B_{stable}}{B_{total}}$ | 收益倍率 | §2.2 |
| $S = Rank / N_{active}$ | 势位排名 | §3.1 |
| $\phi = 0.6(1-S_{self}) + 0.4\max(0, S_{opp}-S_{self}) + 0.2\cdot\mathbb{1}_{[S_{self}>0.8]}\cdot\mathbb{1}_{[S_{opp}<0.2]}$ | 对战收益函数 | §3.3 |
| $R = 100 \cdot MULT \cdot \phi$ | 单局收益 | §3.3 |
| 分账: 55% / 25% / 7.5% / 7.5% / 2.5% / 5% | 胜/败/创造A/创造B/创造bonus/Derive | §4.3 |

### B. 合约地址占位符（待部署后更新）

| 合约 | 网络 | 地址 | 部署日期 |
|-----|------|------|---------|
| CardNFT | QNG | `0x534EAfC0F94FdA8F632F99BeDA2d11c6017963d3` | 已部署 |
| BattleGame | QNG | `0xE4a161e8892aeA51f026dD4f2C7c7A3a855b5aD3` | 已部署 |
| GamePool | QNG | `TBD` | 待部署（复用 BattleGame） |
| ECHOBond | QNG | `TBD` | 待评估（现有合约范围内） |
| CreatorConfig (ECHO) | QNG | `0x...` | 已部署 |
| EdgeDeclaration (ECHO) | QNG | `0x...` | 已部署 |
| MilestoneEscrow (ECHO) | QNG | `0x...` | 已部署 |
| DeadlockInspectorP1 (ECHO) | QNG | `0x...` | 已部署 |

### C. 参考文档

- ECHO Protocol Whitepaper (v1.2)
- OpenClaw Agent Architecture (AGENTS.md)
- Qitmeer QNG Network Spec
- OpenZeppelin Contracts v5.0
- 《势位之战》游戏经济模型 v0.1（本文件前序版本）

---

## 11. 待决议事项（TODO，v3.0）

1. **哪吒 Review**: 游戏数值是否足够吸引玩家？$F = 10$ ECHO 是否过高？
2. **Seaman Review**: 合约接口设计是否满足 ECHO 协议合规性？
3. **VRF 方案**: 自建 VRF 还是 Chainlink VRF？QNG 网络可用性？
4. **预言机**: 四权数据上链频率和 Gas 成本平衡
5. **前端集成**: 对战动画与链上 Commit-Reveal 的 UX 设计
6. **卡牌美术**: 是否开放社区设计？与 Derive 值的联动？
7. **v3.0 新增**: 租赁机制是否必要？还是后续版本实现？
8. **v3.0 新增**: 参数治理委员会玩家代表如何选出？
9. **v3.0 新增**: 内存池隔离和随机延迟的 Gas 成本评估？
10. **v3.0 新增**: 社交图谱验证（Edge ≥ 2）是否过于严格？

---

**文档结束**

*本文件由 猫先森（Cat.zhou）起草，供 Seaman_bot 合约开发团队参考。数值参数需经实战测试后调优。*

---

> 🐱 "卡牌即贡献，对战即验证，收益即正义。v3.0，让经济模型更抗攻击，更可持续。" — 猫先森
