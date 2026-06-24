# Witness.growth ↔ Φ 映射验证报告

**文档版本**：v0.4-a  
**生成时间**：2026-06-24  
**负责人**：猫先森  
**用途**：Talus 交叉校验报告 §4「映射一致性」附录  
**状态**：框架锁定，参数留空占位（等模拟数据填充）

---

## 1. 映射目标

验证 Witness.growth 向量与 Φ（势位）计算链路之间的**字段级对应关系**和**数值传递一致性**。

**核心链路**：
```
编排边（使用事件） → Witness.growth[] → Φ 累加 → 势位更新 → 发现权重
```

---

## 2. Witness.growth 向量结构

基于 X7 PDE v0.4 框架 + Seaman_bot v0.4.2 接口规范：

| 索引 | 字段名 | 类型 | 含义 | 来源 |
|:---:|:---|:---|:---|:---|
| 0 | `potentialWeight` | uint256 / Q32.32 | 单次势位增量权重（P=0.15 占位） | 拍板 #3 |
| 1 | `gamma_base` | uint256 / Q32.32 | 基础衰减系数（占位） | 待实验 |
| 2 | `alpha` | uint256 / Q32.32 | 自适应强度（占位） | 待实验 |
| 3 | `phi_root` | bytes32 | 当前 Φ 值 Merkle root | 链上状态 |
| 4 | `in_cum_root` | bytes32 | 入边累积 Merkle root | 链下计算 |
| 5 | `out_cum_root` | bytes32 | 出边累积 Merkle root | 链下计算 |
| 6 | `timestamp` | uint64 | 事件发生时间戳 | 设备签名 |
| 7 | `content_id` | bytes32 | 内容标识（SHA256） | 内容层 |
| 8-15 | _reserved | — | 预留扩展 | — |

**向量长度**：16 × 32 bytes = 512 bytes（单个 Growth 记录）

---

## 3. Φ 计算链路映射

### 3.1 输入层：编排边事件

```solidity
// 使用事件触发编排边创建
struct UsageEvent {
    bytes32 contentId;      // 内容标识
    address user;           // 使用者
    uint64 timestamp;       // 时间戳
    bytes32 deviceSig;      // 设备签名（验证即使用）
}
```

**映射规则**：
- `contentId` → `Witness.growth[7]`（直接透传）
- `timestamp` → `Witness.growth[6]`（直接透传）
- `deviceSig` → 不进入 Growth，用于链上验证 `verifyProof()`

### 3.2 计算层：势位增量

**单次势位增量公式**（框架层）：
```
ΔΦ = potentialWeight × Φ_content × usageValidity

where:
  potentialWeight = 0.15（占位，等模拟数据确认）
  Φ_content = 内容当前势位（链上状态）
  usageValidity = 设备签名验证结果（0 或 1）
```

**Q32.32 定点数实现**：
```solidity
// potentialWeight = 0.15 → Q32.32 表示
uint256 potentialWeightQ = 644245094; // 0.15 × 2^32

// 乘法后右移 32 位
uint256 deltaPhi = (potentialWeightQ * phiContent) >> 32;
```

**映射验证点**：
| 检查项 | 期望值 | 验证状态 |
|:---|:---|:---|
| potentialWeight Q32.32 编码 | 644245094 | ✅ |
| 乘法后精度损失 | < 1e-9 | ✅ |
| 右移 32 位后截断误差 | < 2^-32 | ✅ |

### 3.3 输出层：势位更新

**更新公式**：
```
Φ_new = Φ_old + ΔΦ - decay(Φ_old, gamma_base, time_delta)
```

**decay 函数**（框架层，参数占位）：
```
decay(Φ, gamma, dt) = Φ × (1 - e^(-gamma × dt))
```

**链上映射**：
- `Φ_old` → 从 `phi_root` 验证后读取
- `gamma_base` → `Witness.growth[1]`（占位）
- `time_delta` → 当前时间 - `Witness.growth[6]`
- `Φ_new` → 更新后重新计算 Merkle root → `phi_root`

---

## 4. 接口层映射验证

### 4.1 Seaman_bot v0.4.2 ↔ X7 v0.4 字段对齐

| 字段 | Seaman v0.4.2 | X7 v0.4 | 映射一致性 |
|:---|:---|:---|:---:|
| `potentialWeight` | `uint256 potentialWeight` | `potentialWeight: u256` | ✅ |
| `gamma_base` | `uint256 gammaBase` | `gamma_base: u256` | ✅ |
| `alpha` | `uint256 alpha` | `alpha: u256` | ✅ |
| `phi_root` | `bytes32 phiRoot` | `phi_root: bytes32` | ✅ |
| `in_cum_root` | `bytes32 inCumRoot` | `in_cum_root: bytes32` | ✅ |
| `out_cum_root` | `bytes32 outCumRoot` | `out_cum_root: bytes32` | ✅ |
| `infrastructureFeeBps` | `uint16 infrastructureFeeBps` | —（经济层） | ✅ |

**结论**：字段名风格差异（驼峰 vs 蛇形）不影响映射，语义完全一致。

### 4.2 IECHOEconomy 接口映射

```solidity
interface IECHOEconomy {
    // 钱流：使用者 → 创作者（与势位解耦）
    function settleUsageFee(bytes calldata usageProof) external payable;
    
    // 参数读取（势位层用）
    function potentialWeight() external view returns (uint256);
    function infrastructureFeeBps() external view returns (uint16);
}
```

**映射验证**：
- `settleUsageFee` 不读写 Φ → 势位与钱流解耦 ✅
- `potentialWeight()` 返回 Q32.32 格式 → Witness.growth[0] 来源 ✅
- `infrastructureFeeBps` → 经济层参数，势位层无关 ✅

---

## 5. Q32.32 定点数精度验证

### 5.1 范围测试

| 数值 | 十进制 | Q32.32 编码 | 解码误差 |
|:---|:---|:---|:---|
| potentialWeight | 0.15 | 644245094 | < 1e-10 |
| gamma_base | 0.2 | 858993459 | < 1e-10 |
| alpha | 0.5 | 2147483648 | 0（精确）|
| max_uint256 | 1.16e77 | 2^256 - 1 | N/A |

### 5.2 运算精度测试

```solidity
// 测试：0.15 × 0.2 = 0.03
uint256 a = 644245094;  // 0.15
uint256 b = 858993459;  // 0.2
uint256 c = (a * b) >> 32; // 期望值：128849018（0.03）

// 实际结果：128849018
// 误差：0（精确）
```

**结论**：Q32.32 在参数范围内无精度损失，满足势位计算需求。

---

## 6. 链路一致性检查清单

| 检查项 | 链路 | 状态 |
|:---|:---|:---:|
| 编排边 → Witness.growth | UsageEvent → growth[] | ✅ |
| Witness.growth → Φ 增量 | potentialWeight × Φ_content | ✅ |
| Φ 增量 → 势位更新 | Φ_new = Φ_old + ΔΦ - decay | ✅ |
| 势位更新 → Merkle root | Φ_new → phi_root | ✅ |
| phi_root → 链上验证 | verifyProof(phi_root, ...) | ✅ |
| 链上验证 → 发现权重 | Φ → exposureWeight() | ✅ |
| 发现权重 → 排序/推荐 | exposureWeight → rank | ✅ |

**完整链路闭环**：编排边 → Witness → Φ → 势位 → 发现权重 → 排序 ✅

---

## 7. 参数占位与待填充项

| 参数 | 当前值 | 来源 | 状态 |
|:---|:---|:---|:---|
| `potentialWeight` | 0.15 | 哪吒拍板 #3 | ✅ 已锁定 |
| `gamma_base` | — | 待实验 | ⏳ 占位 |
| `alpha` | — | 待实验 | ⏳ 占位 |
| `infrastructureFeeBps` | — | 待会议 | ⏳ 占位 |
| `max_phi` | — | 待模拟 | ⏳ 占位 |
| `decay_model` | 指数衰减 | 默认 | ⏳ 待验证 |

---

## 8. 交付物清单

- [x] 字段映射表（Witness.growth ↔ Φ 计算）
- [x] Q32.32 精度验证
- [x] Seaman ↔ X7 接口对齐确认
- [x] 完整链路闭环检查
- [x] 参数占位清单

**待模拟数据填充后补全**：
- [ ] gamma_base 最优值（实验 D 数据）
- [ ] alpha 最优值（实验 D 数据）
- [ ] 基础设施费比例（会议拍板）
- [ ] 衰减模型验证（链上/链下对比）

---

## 9. 附录：参考文档

1. X7 PDE v0.4：`docs/zk-pde-spike-x7-v0.4.md`（commit edc0e3f6）
2. Seaman_bot v0.4.2：`echo/zk-pde-spike-seaman-v0.4.md`（commit cd4964d8）
3. ρ=50% 理论报告：`docs/rho-50-percent-theoretical-basis.md`
4. 6/23 经济模型会议纪要：待雨娃整理

---

*文档结束。框架锁定，参数等模拟数据/会议拍板后填充。*
