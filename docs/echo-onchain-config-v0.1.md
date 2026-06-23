# ECHO 链上配置参数 - 推进版 v0.1
## 生成时间：2026-05-31 01:59 CST
## 来源：雨娃模拟拍板（团队可调整）

---

## 一、审查员激励机制（推进版 v0.1）

### 基础奖励
- **日审 ≥ 10 条**：0.1 MEER/条
- **日审 ≥ 50 条 + 准确率 > 95%**：0.3 MEER/条（3倍加成）
- **违规惩罚**：被申诉成功 → 扣除当日全部奖励 + 停权 24h
- **申诉窗口**：48 小时

### 收益测算（参考）
- 日审 50 条且准确率 95% = 15 MEER/日
- 假设 MEER ≈ $0.5 → 日收入 $7.5，月 $225
- 高于东南亚审核员均值，低于欧美

### 链上参数名建议
```solidity
uint256 public constant REVIEWER_BASE_REWARD = 0.1 ether; // MEER/条
uint256 public constant REVIEWER_BONUS_MULTIPLIER = 3; // 3倍
uint256 public constant REVIEWER_BONUS_THRESHOLD = 50; // 日审50条
uint256 public constant REVIEWER_ACCURACY_THRESHOLD = 9500; // 95%（basis points）
uint256 public constant REVIEWER_APPEAL_WINDOW = 48 hours;
```

---

## 二、荣誉大使分级（推进版 v0.1）

### 青铜大使
- **门槛**：邀请 ≥ 3 人激活
- **权益**：皮肤折扣 5%
- **义务**：月活 ≥ 1 次

### 白银大使
- **门槛**：邀请 ≥ 10 人 + 月活
- **权益**：折扣 10% + 专属标识
- **义务**：月活 ≥ 3 次

### 黄金大使
- **门槛**：邀请 ≥ 50 人 + 季度贡献
- **权益**：折扣 15% + 早期功能体验权（新皮肤优先试用、新功能内测、专属客服通道）
- **义务**：季度活跃

### 降级机制
- **条件**：3 个月不满足义务
- **结果**：自动降级一级

### 链上参数名建议
```solidity
uint256 public constant BRONZE_REFERRAL_MIN = 3;
uint256 public constant SILVER_REFERRAL_MIN = 10;
uint256 public constant GOLD_REFERRAL_MIN = 50;
uint256 public constant BRONZE_DISCOUNT = 500; // 5%（basis points）
uint256 public constant SILVER_DISCOUNT = 1000; // 10%
uint256 public constant GOLD_DISCOUNT = 1500; // 15%
uint256 public constant DEMOTION_PERIOD = 90 days; // 3个月
```

---

## 三、青铜大使门槛写死

### 说明
青铜大使门槛（邀请 ≥ 3 人激活）为最低准入标准，**写死为不可升级参数**。

### 理由
- 青铜是入门级别，门槛过低会导致大使泛滥，门槛过高则冷启动困难
- 3 人是最小社交单元（可以是一个小组/一个宿舍/一个办公室），有传播意义但不至于太难
- 写死防止后期被恶意降低（刷量攻击）或恶意提高（排除新人）

### 合约层建议
```solidity
// 写死参数，不可通过治理修改
uint256 public immutable BRONZE_REFERRAL_MIN;

constructor() {
    BRONZE_REFERRAL_MIN = 3; // 写死
}
```

---

## 四、备注

- 本参数表为**推进版**，团队可在运行后根据实际数据调整
- 调整需通过 DAO 治理流程（提案 → 7天公示 → 投票）
- 写死参数（青铜门槛）如需调整，需合约升级

---

**写入 Agent**：猫先森
**写入时间**：2026-05-31 01:59 CST
**状态**：待执行 → 已写入本地，今晚同步 Wiki
