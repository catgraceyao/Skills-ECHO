# ECHO 链上快照基线 — 2026-06-01

## 快照时间
- **执行时间**：2026-06-01 12:10 CST
- **网络**：Qitmeer QNG Mainnet
- **RPC**：https://qng.rpc.qitmeer.io

## 区块基线

| 指标 | 值 |
|------|-----|
| 当前区块高度 | 2708491 (0x29540b) |
| 平均出块时间 | ~50.2s |
| 出块时间范围 | 29s - 85s（波动较大） |
| 最近区块 tx 数 | 每块约 1 tx |

### 最近 5 个区块详情
| 区块 | Hash (前10位) | Timestamp | 间隔 |
|------|---------------|-----------|------|
| 2708491 | 0xf1c04ace... | 1780287007 | — |
| 2708490 | 0xa1615688... | 1780286978 | 29s |
| 2708489 | 0xb97d35b9... | 1780286926 | 52s |
| 2708488 | 0xdbac3338... | 1780286841 | 85s |
| 2708487 | 0x51f7fbb4... | 1780286806 | 35s |

## 合约部署验证

| 合约 | 地址 | 状态 | Code Size | 备注 |
|------|------|------|-----------|------|
| IncentiveDistributor | 0x2D39e53804278Bb0fCB582FCC1531df045dF78c2 | ✅ 已部署 | 16,198 bytes | 余额 10.0000 MEER |
| BronzeAmbassadorConfig | 0x44334705803e17051d8856adC4b130FBAB1C217a | ✅ 已部署 | 8,634 bytes | 2026-06-01 12:21 验证 |
| SnapshotRecorder | 0x75b71B57751a3331a7ED2CE967521DB2Fe1FA729 | ✅ 已部署 | 12,978 bytes | 2026-06-01 12:21 验证 |

## 资金状态
- **IncentiveDistributor 余额**：10.0000 MEER (10,000,000,000,000,000,000 wei)
- **目标**：15 MEER
- **缺口**：5 MEER（待听风确认第二笔 tx hash）

## 执行记录
- 执行者：猫先森
- 执行方式：curl 直调 Qitmeer RPC
- 验证方法：eth_blockNumber, eth_getBlockByNumber, eth_getCode, eth_getBalance

## 待补全
- [x] BronzeAmbassadorConfig 完整地址验证
- [x] SnapshotRecorder 完整地址验证
- [ ] 听风第二笔 5 MEER 转账确认
