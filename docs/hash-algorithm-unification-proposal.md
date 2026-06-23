# ECHO v0.4 Hash 算法统一清单

**作者**：猫先森  
**日期**：2026-06-23  
**用途**：今晚 20:00 拍板项 #1 — Hash 算法选型  
**依据**：v0.4 合约接口文档（2026-05-23）+ 今日群聊新增接口讨论

---

## 一、v0.4 文档中已有的 hash 字段

| 字段名 | 当前算法 | 用途 | 链上/链下 | Witness 尺寸 |
|--------|---------|------|----------|-------------|
| configHash | `keccak256(configJSON)` | 规则配置哈希 | 链上 | 32 bytes |
| contractHash | **未明确** ⚠️ | 合约字节码哈希 | 链上 | 32 bytes |
| runtimeHash | **未明确** ⚠️ | 运行时状态哈希 | 链上 | 32 bytes |
| ruleHash | **未明确** ⚠️ | 关系节点规则哈希 | 链上 | 32 bytes |
| ipfsHash | SHA256 (IPFS CID) | IPFS 内容标识 | 链下指针 | 32 bytes |
| arweaveHash | SHA256 (Arweave TX) | Arweave 交易标识 | 链下指针 | 32 bytes |
| merkleRoot | `keccak256` (文档明示) | Batch Merkle root | 链上 | 32 bytes |
| evidenceHash | **未明确** ⚠️ | 紧急干预证据哈希 | 链上 | 32 bytes |
| archiveHash | **未明确** ⚠️ | 归档状态哈希 | 链上 | 32 bytes |
| juryCommit.commitHash | `keccak256(vote+salt)` | 陪审团 commit | 链上 | 32 bytes |
| counterEvidence.evidenceHash | `keccak256` | 反证数据哈希 | 链上 | 32 bytes |

**⚠️ 未明确算法字段（5个）**：contractHash, runtimeHash, ruleHash, evidenceHash, archiveHash

---

## 二、今日群聊讨论新增字段（待写入文档）

| 字段名 | 用途 | 建议算法 | 备注 |
|--------|------|---------|------|
| contentId | 内容标识 | SHA256 (IPFS CID) | 与 ipfsHash 可统一 |
| usageHash | UsageProof 签名对象 | **待拍板** | 主链 keccak256 / 电路 Poseidon |
| edgeHash | 编排边标识 | **待拍板** | 主链 keccak256 / 电路 Poseidon |
| edge_weight | 势位权重（Q32.32） | N/A（非 hash） | PDE 源项计算 |
| usage_fee | 使用费（Q32.32） | N/A（非 hash） | 结算合约 |

**关键发现**：v0.4 文档（2026-05-23）中**没有 UsageProof / PDE / edge_weight 接口**。这些字段来自今日 15:53 Seaman_bot 提出的"接口层映射"讨论，尚未写入文档。

---

## 三、三种 hash 算法对比

| 算法 | 电路约束数/hash | EVM gas 成本 | ZK 友好度 | 适用场景 |
|------|---------------|-------------|----------|---------|
| **Keccak256** | ~25,000 | 低（预编译） | ❌ 差 | 主链存储、签名验证 |
| **Poseidon** | ~300 | 高（无预编译） | ✅ 极好 | ZK 电路内、Merkle tree |
| **SHA256** | ~25,000 | 中 | ⚠️ 一般 | 内容层（IPFS/Arweave 原生） |

**约束数差异**：Poseidon 是 Keccak256 的 **1/83**（300 vs 25,000）。如果 v0.4 全部 11 个 hash 字段上电路：
- 全 Keccak256：11 × 25,000 = **~275,000 约束**
- 全 Poseidon：11 × 300 = **~3,300 约束**
- 混合方案（主链 Keccak256 + 电路 Poseidon）：需额外加 "hash of hash" 转换电路

---

## 四、算法选型建议（分层方案）

### 方案 A：三层分离（推荐）

| 层级 | 算法 | 字段 | 理由 |
|------|------|------|------|
| **主链层** | Keccak256 | configHash, contractHash, runtimeHash, ruleHash, evidenceHash, archiveHash, usageHash（主链侧） | EVM 原生预编译，gas 最优 |
| **ZK 电路层** | Poseidon | usageHash（电路侧）, edgeHash（电路侧）, merkleRoot（若上电路） | 约束数低 83 倍，ZK 证明生成快 |
| **内容/IPFS 层** | SHA256 | ipfsHash, arweaveHash, contentId | IPFS/Arweave 生态标准，无需转换 |

**优点**：各层用最适合的算法，不强行统一。  
**缺点**：跨层验证时需要 "hash of hash" 转换（如电路内验证主链 Keccak256 hash，需额外约束）。

### 方案 B：全局统一 Keccak256

所有 hash 字段统一用 Keccak256，包括电路内。

**优点**：简单，无跨层转换问题。  
**缺点**：电路约束数爆炸（~275,000），ZK 证明生成慢。

### 方案 C：全局统一 Poseidon

所有 hash 字段统一用 Poseidon，包括主链存储。

**优点**：电路最轻。  
**缺点**：主链 gas 高（无预编译），与以太坊生态不兼容。

---

## 五、阻塞项清单

| # | 问题 | 影响 | 建议拍板 |
|---|------|------|---------|
| 1 | 5 个 hash 字段算法未明确（contractHash, runtimeHash, ruleHash, evidenceHash, archiveHash）| 文档不完整，实现歧义 | 统一选 Keccak256 |
| 2 | UsageProof / PDE 接口不在 v0.4 文档中 | 今日讨论的新接口无文档锚定 | 会后会后补充进 v0.4+ |
| 3 | usageHash / edgeHash 是否上电路 | 直接决定选 Keccak256 还是 Poseidon | 今晚拍板 |
| 4 | 若分层，跨层 hash 转换电路谁负责 | 接口层职责 | Seaman_bot / X7 |

---

## 六、今晚拍板建议

**建议拍板内容：**
1. **未明确的 5 个 hash 字段统一用 Keccak256**（兼容 EVM，无争议）
2. **contentId 与 ipfsHash 统一**（都是内容标识，用 SHA256）
3. **usageHash / edgeHash 的算法分场景**：
   - 主链存储/签名验证：Keccak256
   - 若上 ZK 电路：Poseidon（需额外 "hash of hash" 转换电路）
4. **是否上电路？** 如果 UsageProof 需要 ZK 验证，必须选 Poseidon；如果只在主链验证，Keccak256 足够

**10 分钟可改接口的条件**：拍板后只需在 v0.4 文档中补一行算法说明 + 在 UsageProof 接口定义中指定 hash 字段。

---

*文档版本：2026-06-23 | 猫先森 | 供今晚 20:00 拍板参考*
