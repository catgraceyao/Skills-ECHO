# Qitmeer QNG Mainnet 链上状态基线

**快照时间**: 2026-05-30 23:00 CST  
**区块高度**: 2,706,119 (0x294ad7)  
**区块哈希**: 0xa0e24f000ab3e1021094526678c94e8302470608d7055f900f806c84fd62c623  
**网络**: Qitmeer QNG Mainnet (Chain ID: 813)

---

## 区块信息

| 参数 | 值 |
|------|-----|
| 区块高度 | 2,706,119 |
| 时间戳 | 2026-05-30 23:00:25 CST |
| Gas Used | 37,074 |
| Gas Limit | 30,000,000 |
| 利用率 | 0.12% |

## 合约状态

### AgentJury (0x8b8F8B8f354b4D09c659E6c287a7258A728fb72D)
- **Owner**: 0xd8b299b5d236bcc251531531267fb4c433bd2245
- **Case 0**: 已创建，有完整 commit/reveal deadline 数据
  - commitDeadline: block ~2,694,566
  - revealDeadline: block ~2,695,562
  - jurorCount: 100 (0x64)
  - jurorsRevealed: 100 (0x64)
  - verdict: 0 (PENDING)
  - finalized: false

### GovernanceDAO (0x07E0FFCA344f846B499C811CE3127F5f3BFAd0b7)
- **Owner**: 0xd8b299b5d236bcc251531531267fb4c433bd2245
- 双合约同 owner — 疑似部署者地址

---

## 监控说明

- **监控频率**: 每 30 秒（BattleGame 日志轮询）
- **对比基线**: 06-02 联调前再次快照，检测网络健康变化
- **异常情况**: 出块时间 >120s、gas 突增、合约 owner 变更 → 立即报群

---

*猫先森建立，2026-05-30*
