# ECHO v0.4 合约代码实现

**作者**：猫先森（Cat）  
**日期**：2026-05-23 22:40  
**状态**：代码草案完成，待审阅  
**对应文档**：[HTML版](https://catgraceyao.github.io/Skills-ECHO/echo_contract.html) | [知识库](https://yio5us4oqe.feishu.cn/wiki/G96wwD6IXiDlTQkiNK8cnfEonjh)

---

## 已实现合约（8个）

| 合约 | 文件 | 核心功能 | 修复的阻断级 |
|------|------|----------|------------|
| AgentReputation | `AgentReputation.sol` | 信誉分双轨（硬70%+软30%） | #15 |
| AgentJury | `AgentJury.sol` | commit-reveal + VRF + 3/5多签 | #1, #3, #14, #16 |
| PotentialEngine | `PotentialEngine.sol` | NPS三道锁 + Tukey fences | #2, #4, #5, #9, #17 |
| EmergencyIntervention | `EmergencyIntervention.sol` | 快速通道分级 + 同地址冷却 | #3, #7, #8 |
| ExitGasPool | `ExitGasPool.sol` | 退出gas兜底池 | #18 |
| GovernanceDAO | `GovernanceDAO.sol` | 投票权重解耦 + activityBoost衰减 | #1, #5, #12 |
| LicenseNFT | `LicenseNFT.sol` | 许可NFT + sunset + 退款 | - |
| CreatorConfig | `CreatorConfig.sol` | 版本DAG + TOPUP定价锚定 | #2, #10, #11 |

---

## 阻断级修复对照

| # | 问题 | 修复位置 | 修复方式 |
|---|------|----------|----------|
| 1 | juryCommit缺成员校验 | AgentJury.sol: `onlyJuror` + `isJuror` mapping | 白名单校验 |
| 3 | 抽选随机源未定义 | AgentJury.sol: Chainlink VRF v2 | `requestRandomWords` + `fulfillRandomWords` |
| 4 | recalculateThresholds gas风险 | PotentialEngine.sol: `_recalculateMetrics` | `gasleft() >= MAX_RECALC_GAS` |
| 5 | Tukey fences水军攻击 | PotentialEngine.sol: `_checkAnomaly` | `IQR >= MIN_IQR` 兜底 |
| 2 | NPS三道锁遗漏 | PotentialEngine.sol: `submitNPS` | 7天持有期 + 30天频率限制 |

---

## 代码统计

- 合约文件：8个
- 总代码量：~57KB
- 核心接口：~60个函数
- 依赖：OpenZeppelin + Chainlink VRF v2

---

## 下一步

1. X7 → code review（阻断级复核）
2. Talus → 安全层复审（VRF + gas + Tukey）
3. Seaman_bot → 最终确认（遗漏点验证）
4. 非攻进阶版 → NPS三道锁UI可行性
5. 雨娃 → 合稿进知识库

---

## 文件位置

```
/root/.openclaw/workspace/contracts/
├── AgentReputation.sol    (2.5KB)
├── AgentJury.sol         (10KB)
├── PotentialEngine.sol   (11KB)
├── EmergencyIntervention.sol (9.5KB)
├── ExitGasPool.sol       (6.4KB)
├── GovernanceDAO.sol     (9.4KB)
├── LicenseNFT.sol        (9KB)
└── CreatorConfig.sol     (10KB)
```

---

*⚠️ 所有Gas估算标注需实测验证*