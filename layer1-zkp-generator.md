# ZKP Generator 详细设计文档

> **版本**: v1.0  
> **产品**: ECHO 原生分布式价值网络 - 创作者工具矩阵 (Layer 1)  
> **定位**: 零知识证明生成器  
> **设计日期**: 2026-04-19  
> **参考**: zk-SNARKs (Groth16), zk-STARKs, Circom, Noir, Bulletproofs

---

## 文档结构

| 章节 | 内容概要 |
|------|----------|
| 1. 产品定位与核心概念 | 目标用户、应用场景、证明类型 |
| 2. 核心证明类型设计 | 四种核心证明的详细设计 |
| 3. 技术架构 | ZK 方案选择、电路设计、验证合约 |
| 4. SDK 架构 | 多语言支持、核心模块设计 |
| 5. 开发者体验 | CLI 工具、编程接口、调试工具 |
| 6. 安全与隐私 | 可信设置、可链接性、防重放、密钥管理 |
| 7. 核心工作流程 | 初始化、生成证明、批量证明、验证流程 |
| 8. 性能指标 | 生成时间、验证成本、存储需求 |
| 9. 功能清单 | 完整功能矩阵 |
| 10. 开发计划 | 工作量估算与里程碑 |

---

## 1. 产品定位与核心概念

### 1.1 目标用户

| 用户类型 | 技术能力 | 核心诉求 | 使用场景 |
|----------|----------|----------|----------|
| **自建沙箱开发者** | 高 | 保护核心逻辑、可验证使用 | 模型/算法沙箱，证明调用发生但不暴露权重 |
| **隐私敏感企业** | 中高 | 合规审计、数据隐私 | 金融/医疗场景，证明交易合规但不暴露金额/病历 |
| **衍生作品创作者** | 中 | 引用证明、版权合规 | 证明使用了某资产但不暴露具体引用细节 |
| **收益分配节点** | 中高 | 计算正确性、可审计 | 证明分润计算正确但不暴露全部账本 |
| **ECHO 协议开发者** | 高 | 集成 ZKP 能力到协议 | 构建去中心化验证基础设施 |

### 1.2 零知识证明在 ECHO 中的应用场景

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ZKP 在 ECHO 网络中的位置                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────┐      ZKP 证明      ┌─────────────┐                    │
│   │  自建沙箱    │ ───────────────→ │  ECHO 网络   │                    │
│   │  (私有执行)  │    (公开验证)     │  (链上验证)  │                    │
│   └─────────────┘                    └─────────────┘                    │
│          ↑                                    ↓                        │
│          └──────── 不暴露执行细节 ────────────┘                        │
│                                                                         │
│   核心原则: 可验证 ≠ 可查看                                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**具体应用场景：**

1. **沙箱使用证明**
   - 场景：某用户调用了创作者小李的"古风诗词生成器"
   - 隐私：不暴露用户的输入 prompt、生成的具体内容
   - 验证：链上可验证"确实发生了一次调用"，触发收益分配

2. **资产持有证明**
   - 场景：用户证明拥有某高级 Skill 的使用权
   - 隐私：不暴露购买时间、持有数量、购买价格
   - 验证：可验证"有权使用"，进入对应沙箱

3. **衍生引用证明**
   - 场景：某视频作品使用了3个音乐片段、5个字体、2个音效
   - 隐私：不暴露具体引用时间点、编辑方式、混音比例
   - 验证：可验证"确实引用了这些资产"，触发自动分润

4. **收益计算证明**
   - 场景：季度收益分配，计算下游分润
   - 隐私：不暴露全部交易明细、用户身份信息
   - 验证：可验证"分配计算正确"，审计方可验证

### 1.3 证明类型总览

| 证明类型 | 简称 | 证明目标 | 隐私保护 | 验证方 |
|----------|------|----------|----------|--------|
| **使用证明** | PoU | 某时某地发生了使用 | 使用内容、使用者身份 | 链上合约 |
| **持有证明** | PoH | 拥有某资产的使用权 | 持有数量、获得时间 | 沙箱准入系统 |
| **衍生证明** | PoD | 新作品引用了上游资产 | 引用细节、创作过程 | 链上合约 |
| **收益证明** | PoR | 收益分配计算正确 | 完整账本、交易明细 | 审计方 |

---

## 2. 核心证明类型设计

### 2.1 使用证明 (Proof of Usage, PoU)

#### 2.1.1 概念定义

证明某人在某时使用了某资产，不暴露具体使用内容、使用者身份。

#### 2.1.2 电路输入输出

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PoU 电路结构                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  私密输入 (Witness)                                                      │
│  ├── user_id: Field      ← 用户内部标识 (哈希后公开)                     │
│  ├── asset_id: Field     ← 资产标识                                     │
│  ├── timestamp: u64      ← 使用时间戳                                   │
│  ├── nonce: Field        ← 防重放随机数                                 │
│  ├── usage_hash: Field   ← 使用内容哈希 (prompt+output)                │
│  └── auth_sig: Signature ← 沙箱授权签名                                 │
│                                                                         │
│  公开输入 (Public Input)                                                 │
│  ├── asset_id_pub: Field  ← 公开的资产标识 (与私密输入一致)              │
│  ├── timestamp_pub: u64  ← 公开时间戳范围                                │
│  ├── nullifier: Field     ← 唯一标识符 (防止双重证明)                      │
│  └── merkle_root: Field   ← 授权用户集合的根                              │
│                                                                         │
│  约束条件                                                                │
│  1. asset_id == asset_id_pub                                            │
│  2. timestamp 在有效范围内                                                │
│  3. nullifier = hash(user_id, asset_id, nonce)                           │
│  4. verify_merkle_proof(user_id, merkle_root) == true                   │
│  5. verify_signature(auth_sig, usage_hash, asset_owner_pubkey) == true  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 2.1.3 Circom 伪代码

```circom
pragma circom 2.1.6;

include "circomlib/poseidon.circom";
include "circomlib/merkletree.circom";
include "circomlib/eddsaposeidon.circom";

template ProofOfUsage(levels) {
    // 公开输入
    signal input asset_id_pub;
    signal input timestamp_min;
    signal input timestamp_max;
    signal input nullifier;
    signal input merkle_root;
    signal input asset_owner_pubkey[2];
    
    // 私密输入
    signal input user_id;
    signal input asset_id;
    signal input timestamp;
    signal input nonce;
    signal input usage_hash;
    signal input auth_sig[3]; // R8, S components
    signal input merkle_path[levels];
    signal input merkle_path_index[levels];
    
    // 1. 验证 asset_id 一致性
    asset_id === asset_id_pub;
    
    // 2. 验证时间戳范围
    component gte = GreaterEqThan(64);
    gte.in[0] <== timestamp;
    gte.in[1] <== timestamp_min;
    gte.out === 1;
    
    component lte = LessEqThan(64);
    lte.in[0] <== timestamp;
    lte.in[1] <== timestamp_max;
    lte.out === 1;
    
    // 3. 计算并验证 nullifier
    component nullifier_hasher = Poseidon(3);
    nullifier_hasher.inputs[0] <== user_id;
    nullifier_hasher.inputs[1] <== asset_id;
    nullifier_hasher.inputs[2] <== nonce;
    nullifier === nullifier_hasher.out;
    
    // 4. 验证 Merkle 证明 (用户在白名单中)
    component merkle_proof = MerkleTreeChecker(levels);
    merkle_proof.leaf <== user_id;
    merkle_proof.root <== merkle_root;
    for (var i = 0; i < levels; i++) {
        merkle_proof.pathElements[i] <== merkle_path[i];
        merkle_proof.pathIndices[i] <== merkle_path_index[i];
    }
    
    // 5. 验证资产所有者签名
    component sig_verifier = EdDSAPoseidonVerifier();
    sig_verifier.enabled <== 1;
    sig_verifier.Ax <== asset_owner_pubkey[0];
    sig_verifier.Ay <== asset_owner_pubkey[1];
    sig_verifier.S <== auth_sig[2];
    sig_verifier.R8x <== auth_sig[0];
    sig_verifier.R8y <== auth_sig[1];
    sig_verifier.M <== usage_hash;
    
    // 6. 证明使用内容哈希的完整性 (与公开记录关联)
    component usage_hasher = Poseidon(4);
    usage_hasher.inputs[0] <== user_id;
    usage_hasher.inputs[1] <== asset_id;
    usage_hasher.inputs[2] <== timestamp;
    usage_hasher.inputs[3] <== nonce;
    signal computed_usage_hash;
    computed_usage_hash <== usage_hasher.out;
    
    // usage_hash 必须匹配计算值或沙箱提供的哈希
    // 这里使用约束确保沙箱确实处理了这些输入
    usage_hash === computed_usage_hash;
}

component main {public [
    asset_id_pub, timestamp_min, timestamp_max, 
    nullifier, merkle_root, asset_owner_pubkey
]} = ProofOfUsage(20);
```

### 2.2 持有证明 (Proof of Holding, PoH)

#### 2.2.1 概念定义

证明某人持有某资产的使用权，不暴露持有数量、获得时间、交易细节。

#### 2.2.2 电路输入输出

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PoH 电路结构                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  私密输入 (Witness)                                                      │
│  ├── user_id: Field           ← 用户标识                                 │
│  ├── asset_id: Field          ← 资产标识                               │
│  ├── token_ids: Field[]       ← 持有的具体 Token ID 列表                │
│  ├── purchase_txs: Tx[]       ← 购买交易记录 (加密)                      │
│  ├── balance: u64             ← 实际持有数量                             │
│  └── expiration: u64          ← 最早过期时间                             │
│                                                                         │
│  公开输入 (Public Input)                                                 │
│  ├── asset_id_pub: Field      ← 公开资产标识                              │
│  ├── min_balance: u64         ← 最小持有数量要求                          │
│  ├── current_time: u64        ← 当前时间                                  │
│  ├── commitment: Field        ← 持有状态承诺                              │
│  └── merkle_root: Field       ← 资产所有权证明的 Merkle 根                │
│                                                                         │
│  约束条件                                                                │
│  1. asset_id == asset_id_pub                                            │
│  2. balance >= min_balance                                                │
│  3. expiration > current_time                                             │
│  4. 每个 token_id 都有效且未被使用                                        │
│  5. commitment = hash(asset_id, balance_range, expiration_range)         │
│  6. 验证链上所有权记录存在                                                │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 2.2.3 Noir 伪代码

```rust
// proof_of_holding.nr
use dep::std;
use dep::poseidon;

fn main(
    // 公开输入
    asset_id_pub: Field,
    min_balance: u64,
    current_time: u64,
    commitment: Field,
    merkle_root: Field,
    
    // 私密输入
    user_id: Field,
    asset_id: Field,
    balance: u64,
    expiration: u64,
    token_ids: [Field; 10],  // 假设最多持有10个
    merkle_paths: [[Field; 20]; 10], // 每个token的merkle路径
    merkle_indices: [[bool; 20]; 10],
) -> pub Field {
    // 1. 验证 asset_id 一致性
    assert(asset_id == asset_id_pub);
    
    // 2. 验证持有数量
    assert(balance >= min_balance);
    
    // 3. 验证未过期
    assert(expiration > current_time);
    
    // 4. 验证每个 token 的所有权
    let mut valid_count: u64 = 0;
    for i in 0..10 {
        if token_ids[i] != 0 {
            // 验证 Merkle 证明
            let leaf = poseidon::hash([user_id, token_ids[i], asset_id]);
            let computed_root = verify_merkle_proof(
                leaf, 
                merkle_paths[i], 
                merkle_indices[i]
            );
            assert(computed_root == merkle_root);
            valid_count += 1;
        }
    }
    
    // 5. 验证有效token数量与声称的balance一致
    // 注意：这里使用范围证明，实际balance可能大于验证的token数量
    // 因为可能持有未完全列出的其他token
    assert(valid_count <= balance);
    
    // 6. 计算并验证 commitment
    let balance_range = balance / 10; // 数量范围证明 (范围大小为10)
    let expiration_range = expiration / 86400; // 按天取整
    
    let computed_commitment = poseidon::hash([
        asset_id,
        std::field::from_u64(balance_range),
        std::field::from_u64(expiration_range),
    ]);
    
    assert(computed_commitment == commitment);
    
    // 返回 nullifier 用于防止重复证明
    poseidon::hash([user_id, asset_id, std::field::from_u64(current_time)])
}

fn verify_merkle_proof(
    leaf: Field, 
    path: [Field; 20], 
    indices: [bool; 20]
) -> Field {
    let mut current = leaf;
    for i in 0..20 {
        let (left, right) = if indices[i] {
            (path[i], current)
        } else {
            (current, path[i])
        };
        current = poseidon::hash([left, right]);
    }
    current
}
```

### 2.3 衍生证明 (Proof of Derivative, PoD)

#### 2.3.1 概念定义

证明新作品确实引用了上游资产，不暴露具体引用比例、创作细节、编辑过程。

#### 2.3.2 电路输入输出

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PoD 电路结构                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  私密输入 (Witness)                                                      │
│  ├── derivative_id: Field       ← 衍生作品标识                             │
│  ├── source_assets: Asset[]     ← 引用的源资产列表                        │
│  │   ├── asset_id: Field                                                │
│  │   ├── usage_type: u8      (1=完整使用, 2=部分引用, 3=灵感启发)          │
│  │   ├── contribution_hash: Field  ← 贡献度承诺                           │
│  │   └── license_proof: Proof   ← 授权证明                               │
│  ├── derivation_graph: Graph    ← 衍生关系图 (加密)                      │
│  │   ├── nodes: 创作步骤                                                │
│  │   └── edges: 引用关系                                                │
│  └── creation_timestamp: u64      ← 创作时间戳                             │
│                                                                         │
│  公开输入 (Public Input)                                                 │
│  ├── derivative_id_pub: Field   ← 公开作品标识                            │
│  ├── source_count: u8           ← 引用的源资产数量                        │
│  ├── source_commitments: Field[]← 源资产的承诺列表                        │
│  ├── total_contribution: u64    ← 总贡献度声明                            │
│  └── compliance_flags: u8       ← 合规标记                                │
│                                                                         │
│  约束条件                                                                │
│  1. derivative_id == derivative_id_pub                                    │
│  2. source_assets 数量 == source_count                                    │
│  3. 每个 source_asset 的贡献度在合理范围内                                  │
│  4. 所有 contribution_hash 的聚合 == total_contribution                   │
│  5. 所有 license_proof 都有效                                             │
│  6. 创作时间不早于任何源资产的发布时间                                       │
│  7. 符合 ECHO 协议的衍生权规则                                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 2.3.3 Gnark 伪代码 (Go)

```go
// proof_of_derivative.go
package pod

import (
    "github.com/consensys/gnark/frontend"
    "github.com/consensys/gnark/std/hash/poseidon"
    "github.com/consensys/gnark/std/signature/eddsa"
)

const MaxSourceAssets = 20
const MaxDerivationSteps = 100

type SourceAsset struct {
    AssetID           frontend.Variable
    UsageType         frontend.Variable // 1, 2, or 3
    ContributionHash  frontend.Variable
    LicenseProof      [3]frontend.Variable // R8x, R8y, S
    LicensePubKey     [2]frontend.Variable // Ax, Ay
}

type ProofOfDerivativeCircuit struct {
    // 公开输入
    DerivativeIDPub     frontend.Variable `gnark:",public"`
    SourceCount         frontend.Variable `gnark:",public"`
    SourceCommitments   [MaxSourceAssets]frontend.Variable `gnark:",public"`
    TotalContribution   frontend.Variable `gnark:",public"`
    ComplianceFlags     frontend.Variable `gnark:",public"`
    
    // 私密输入
    DerivativeID        frontend.Variable
    SourceAssets        [MaxSourceAssets]SourceAsset
    SourceAssetCount    frontend.Variable
    DerivationSteps     [MaxDerivationSteps]frontend.Variable
    CreationTimestamp   frontend.Variable
    
    // 辅助数据
    SourceTimestamps    [MaxSourceAssets]frontend.Variable
}

func (circuit *ProofOfDerivativeCircuit) Define(api frontend.API) error {
    // 1. 验证 derivative_id 一致性
    api.AssertIsEqual(circuit.DerivativeID, circuit.DerivativeIDPub)
    
    // 2. 验证引用的源资产数量
    api.AssertIsEqual(circuit.SourceAssetCount, circuit.SourceCount)
    
    // 3. 初始化 Poseidon 哈希器
    poseidonHasher := poseidon.NewPoseidon(api)
    
    // 4. 验证每个源资产的贡献度和授权
    var totalWeight frontend.Variable = 0
    var validCount frontend.Variable = 0
    
    for i := 0; i < MaxSourceAssets; i++ {
        asset := circuit.SourceAssets[i]
        
        // 检查是否是非零资产 (有效资产)
        isNonZero := api.IsZero(api.Sub(asset.AssetID, 0))
        isNonZero = api.Xor(isNonZero, 1) // 取反：非零为1
        
        // 验证授权签名
        sigVerifier := eddsa.New(api)
        err := sigVerifier.Verify(
            asset.LicensePubKey,
            asset.LicenseProof[:],
            asset.AssetID,
        )
        if err != nil {
            return err
        }
        
        // 计算贡献度权重
        // usage_type 1 = 高贡献(30), 2 = 中贡献(15), 3 = 低贡献(5)
        var weight frontend.Variable
        isType1 := api.IsZero(api.Sub(asset.UsageType, 1))
        isType2 := api.IsZero(api.Sub(asset.UsageType, 2))
        
        weight = api.Select(isType1, 30, 
               api.Select(isType2, 15, 5))
        
        // 累加权重 (只有有效资产才累加)
        weighted := api.Mul(weight, isNonZero)
        totalWeight = api.Add(totalWeight, weighted)
        validCount = api.Add(validCount, isNonZero)
    }
    
    // 5. 验证总数一致
    api.AssertIsEqual(validCount, circuit.SourceCount)
    api.AssertIsEqual(totalWeight, circuit.TotalContribution)
    
    // 6. 验证每个源资产的 commitment
    for i := 0; i < MaxSourceAssets; i++ {
        asset := circuit.SourceAssets[i]
        
        // 重新计算 commitment
        poseidonHasher.Reset()
        poseidonHasher.Write(asset.AssetID)
        poseidonHasher.Write(asset.UsageType)
        poseidonHasher.Write(asset.ContributionHash)
        computedCommitment := poseidonHasher.Sum()
        
        // 验证与公开 commitment 一致
        api.AssertIsEqual(computedCommitment, circuit.SourceCommitments[i])
    }
    
    // 7. 验证创作时间不早于源资产 (简化约束)
    for i := 0; i < MaxSourceAssets; i++ {
        // creation_timestamp >= source_timestamps[i]
        diff := api.Sub(circuit.CreationTimestamp, circuit.SourceTimestamps[i])
        isNonZero := api.IsZero(api.Sub(circuit.SourceAssets[i].AssetID, 0))
        isNonZero = api.Xor(isNonZero, 1)
        
        // 如果是有效资产，验证时间顺序
        // 使用 api.Cmp 比较
        diff = api.Mul(diff, isNonZero) // 无效资产差异置0
        api.AssertIsEqual(api.IsZero(diff), 0) // diff 应该 >= 0
    }
    
    // 8. 计算衍生作品的整体 commitment
    poseidonHasher.Reset()
    poseidonHasher.Write(circuit.DerivativeID)
    poseidonHasher.Write(circuit.SourceCount)
    poseidonHasher.Write(circuit.TotalContribution)
    poseidonHasher.Write(circuit.CreationTimestamp)
    derivativeCommitment := poseidonHasher.Sum()
    
    // 这个 commitment 会被记录在链上，用于后续收益分配
    _ = derivativeCommitment
    
    return nil
}
```

### 2.4 收益证明 (Proof of Revenue, PoR)

#### 2.4.1 概念定义

证明收益分配计算正确，可审计但隐私保护，不暴露全部账本和交易明细。

#### 2.4.2 电路输入输出

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PoR 电路结构                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  私密输入 (Witness)                                                      │
│  ├── period_start: u64          ← 结算周期开始                           │
│  ├── period_end: u64            ← 结算周期结束                             │
│  ├── transactions: Tx[]         ← 交易明细 (加密)                          │
│  │   ├── tx_id: Field                                                   │
│  │   ├── amount: u64                                                    │
│  │   ├── asset_id: Field                                                │
│  │   └── revenue_type: u8    (1=使用费, 2=分润, 3=订阅)                  │
│  ├── allocations: Allocation[]  ← 收益分配明细                            │
│  │   ├── recipient: Field      (哈希后的接收者标识)                        │
│  │   ├── amount: u64                                                    │
│  │   └── reason_hash: Field    (分配原因承诺)                             │
│  └── upstream_proofs: Proof[]  ← 上游资产的收益证明 (用于验证分润链)        │
│                                                                         │
│  公开输入 (Public Input)                                                 │
│  ├── period_pub: [u64; 2]       ← 公开周期                                │
│  ├── total_revenue: u64         ← 总收益声明                                │
│  ├── allocation_count: u16      ← 分配条目数                                │
│  ├── total_allocated: u64       ← 总分配金额                                │
│  ├── merkle_root: Field         ← 交易摘要的 Merkle 根                      │
│  └── audit_anchor: Field        ← 审计锚点                                │
│                                                                         │
│  约束条件                                                                │
│  1. period_start == period_pub[0] && period_end == period_pub[1]        │
│  2. sum(transactions.amount) == total_revenue                           │
│  3. sum(allocations.amount) == total_allocated                           │
│  4. total_allocated <= total_revenue                                    │
│  5. 验证每个 allocation 的合理性 (基于 ECHO 分润规则)                       │
│  6. merkle_root 正确计算自 transactions                                    │
│  7. 上游证明验证 (确保分润计算链条完整)                                     │
│  8. audit_anchor 绑定所有计算参数                                          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 2.4.3 Circom 伪代码

```circom
pragma circom 2.1.6;

include "circomlib/poseidon.circom";
include "circomlib/comparators.circom";

template ProofOfRevenue(maxTx, maxAllocations) {
    // 公开输入
    signal input period_pub[2];
    signal input total_revenue;
    signal input allocation_count;
    signal input total_allocated;
    signal input merkle_root;
    signal input audit_anchor;
    
    // 私密输入
    signal input period_start;
    signal input period_end;
    signal input tx_count;
    signal input transactions[maxTx][4]; // [tx_id, amount, asset_id, revenue_type]
    signal input tx_merkle_paths[maxTx][10];
    signal input tx_merkle_indices[maxTx][10];
    
    signal input alloc_count;
    signal input allocations[maxAllocations][3]; // [recipient_hash, amount, reason_hash]
    
    signal input upstream_proof_roots[5]; // 最多5个上游证明
    
    // 1. 验证周期
    period_start === period_pub[0];
    period_end === period_pub[1];
    
    // 2. 计算交易总额
    signal sum_revenue[maxTx+1];
    sum_revenue[0] <== 0;
    
    for (var i = 0; i < maxTx; i++) {
        // 检查是否为有效交易
        signal is_valid;
        is_valid <== GreaterThan(64)([transactions[i][1], 0]); // amount > 0
        
        // 累加 (无效交易加0)
        signal addend;
        addend <== transactions[i][1] * is_valid;
        sum_revenue[i+1] <== sum_revenue[i] + addend;
    }
    
    // 总收益应等于计算值
    total_revenue === sum_revenue[maxTx];
    
    // 3. 计算分配总额
    signal sum_alloc[maxAllocations+1];
    sum_alloc[0] <== 0;
    
    for (var i = 0; i < maxAllocations; i++) {
        signal is_valid;
        is_valid <== GreaterThan(64)([allocations[i][1], 0]);
        
        signal addend;
        addend <== allocations[i][1] * is_valid;
        sum_alloc[i+1] <== sum_alloc[i] + addend;
    }
    
    total_allocated === sum_alloc[maxAllocations];
    
    // 4. 验证分配不超过收益
    component lte = LessEqThan(128);
    lte.in[0] <== total_allocated;
    lte.in[1] <== total_revenue;
    lte.out === 1;
    
    // 5. 验证计数一致
    tx_count === allocation_count; // 简化：假设每笔交易对应一条分配
    alloc_count === allocation_count;
    
    // 6. 计算 Merkle 根 (简化版本)
    signal computed_root;
    component merkle_hasher = Poseidon(maxTx);
    for (var i = 0; i < maxTx; i++) {
        signal tx_hash;
        component tx_hasher = Poseidon(4);
        for (var j = 0; j < 4; j++) {
            tx_hasher.inputs[j] <== transactions[i][j];
        }
        tx_hash <== tx_hasher.out;
        merkle_hasher.inputs[i] <== tx_hash;
    }
    computed_root <== merkle_hasher.out;
    computed_root === merkle_root;
    
    // 7. 验证上游证明根 (简化：假设已预处理)
    for (var i = 0; i < 5; i++) {
        // 上游证明不应为零 (如果存在)
        // 实际实现需要验证上游证明的结构
    }
    
    // 8. 计算并验证 audit_anchor
    component anchor_hasher = Poseidon(6);
    anchor_hasher.inputs[0] <== period_pub[0];
    anchor_hasher.inputs[1] <== period_pub[1];
    anchor_hasher.inputs[2] <== total_revenue;
    anchor_hasher.inputs[3] <== total_allocated;
    anchor_hasher.inputs[4] <== merkle_root;
    anchor_hasher.inputs[5] <== allocation_count;
    
    anchor_hasher.out === audit_anchor;
}

component main {public [
    period_pub, total_revenue, allocation_count, 
    total_allocated, merkle_root, audit_anchor
]} = ProofOfRevenue(100, 100);
```

---

## 3. 技术架构

### 3.1 ZK 方案选择

| 方案 | 技术特点 | 适用场景 | 选择理由 |
|------|----------|----------|----------|
| **zk-SNARKs (Groth16)** | 证明小(~200B)、验证快(~1.5ms)、需可信设置 | PoU、PoH、PoD | 适合高频验证，证明小便于链上提交 |
| **zk-STARKs** | 无需可信设置、量子安全、证明大(~50KB) | PoR、批量证明 | 适合审计场景，安全性要求更高 |
| **Bulletproofs** | 无需可信设置、适合范围证明、证明中等(~1KB) | PoH 数量证明 | 适合隐私交易中的范围证明 |

**ECHO ZKP Generator 采用混合架构：**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      ZK 方案混合架构                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   证明类型          推荐方案              备选方案                          │
│   ──────────────────────────────────────────────                          │
│   PoU (使用证明)    Groth16              STARKs                           │
│   PoH (持有证明)    Groth16 + Bulletproofs  STARKs                      │
│   PoD (衍生证明)    Groth16              STARKs (高价值作品)             │
│   PoR (收益证明)    STARKs               Groth16 (低频次)                 │
│   批量证明          STARKs 聚合            Recursive SNARKs               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 电路设计工具链

| 工具 | 用途 | 支持方案 | 输出格式 |
|------|------|----------|----------|
| **Circom** | 算术电路设计 | Groth16, PLONK | R1CS, WASM |
| **Noir** | 通用ZK编程 | UltraPLONK, STARKs | ACIR |
| **Gnark** | Go语言电路 | Groth16, PLONK | Go约束系统 |
| **Cairo** | STARKs专用 | STARKs | Cairo字节码 |

**工具选择策略：**
- 标准场景 (PoU/PoH): Circom (生态成熟，证明小)
- 复杂逻辑 (PoD): Noir (开发友好，易审计)
- 集成系统 (SDK): Gnark (Go生态，性能可控)
- 审计场景 (PoR): Cairo/STARKs (透明可验证)

### 3.3 证明生成流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      证明生成流程                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   阶段 1: 输入准备 (Input Preparation)                                    │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│   │  原始数据   │ ──→ │  数据标准化  │ ──→ │  字段转换   │              │
│   │  (JSON/DB) │     │  (Schema)   │     │  (Field元素) │              │
│   └─────────────┘     └─────────────┘     └─────────────┘              │
│                                                                         │
│   阶段 2: 见证生成 (Witness Generation)                                 │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│   │  加载电路   │ ──→ │  计算中间值  │ ──→ │  完整见证   │              │
│   │  (R1CS)    │     │  (约束满足) │     │  (Witness) │              │
│   └─────────────┘     └─────────────┘     └─────────────┘              │
│                                                                         │
│   阶段 3: 证明计算 (Proof Computation)                                    │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│   │  加载证明密钥│ ──→ │  多项式计算 │ ──→ │  生成证明   │              │
│   │  (Proving Key)    │ (MSM/FFT)   │     │  (Proof)   │              │
│   └─────────────┘     └─────────────┘     └─────────────┘              │
│                                                                         │
│   阶段 4: 验证准备 (Verification Prep)                                  │
│   ┌─────────────┐     ┌─────────────┐                                   │
│   │  提取公开输入│ ──→ │  格式化输出  │                                   │
│   │  (Public Inputs)  │ (JSON/Hex)  │                                   │
│   └─────────────┘     └─────────────┘                                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.4 验证合约架构

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IZKPVerifier {
    // 验证使用证明
    function verifyUsageProof(
        bytes calldata proof,
        uint256[6] calldata publicInputs, // asset_id, time_min, time_max, nullifier, merkle_root, pubkey[0]
        uint256[2] calldata pubkey // pubkey[1], pubkey[2]
    ) external view returns (bool);
    
    // 验证持有证明
    function verifyHoldingProof(
        bytes calldata proof,
        uint256[5] calldata publicInputs,
        uint256 nullifier
    ) external view returns (bool);
    
    // 验证衍生证明
    function verifyDerivativeProof(
        bytes calldata proof,
        uint256[5] calldata publicInputs
    ) external view returns (bool);
    
    // 验证收益证明
    function verifyRevenueProof(
        bytes calldata proof,
        uint256[6] calldata publicInputs
    ) external view returns (bool);
    
    // 批量验证 (节省 gas)
    function batchVerify(
        bytes[] calldata proofs,
        bytes32 merkleRoot,
        uint8 proofType
    ) external view returns (bool[] memory results);
}

// Groth16 验证器实现
contract Groth16Verifier is IZKPVerifier {
    // Groth16 验证密钥
    struct VerifyingKey {
        uint256[2] alpha1;
        uint256[2][2] beta2;
        uint256[2][2] gamma2;
        uint256[2][2] delta2;
        uint256[2][] ic; // 公开输入对应的 G1 点
    }
    
    VerifyingKey public vk;
    
    // 防止 nullifier 重用
    mapping(bytes32 => bool) public nullifierHashes;
    
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[] memory input
    ) public view returns (bool) {
        // 使用预编译合约进行配对检查
        // address(8): alt_bn128_pairing
        // ...
        return true; // 简化
    }
    
    function verifyUsageProof(
        bytes calldata proof,
        uint256[6] calldata publicInputs,
        uint256[2] calldata pubkey
    ) external view returns (bool) {
        // 解码证明 (a, b, c)
        (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) = 
            decodeProof(proof);
        
        // 构造完整输入数组
        uint256[] memory inputs = new uint256[](8);
        for (uint i = 0; i < 6; i++) {
            inputs[i] = publicInputs[i];
        }
        inputs[6] = pubkey[0];
        inputs[7] = pubkey[1];
        
        // 检查 nullifier 未被使用
        bytes32 nullifierHash = keccak256(abi.encodePacked(publicInputs[3]));
        require(!nullifierHashes[nullifierHash], "Nullifier already used");
        
        // 验证证明
        bool valid = verifyProof(a, b, c, inputs);
        return valid;
    }
    
    // 记录已使用的 nullifier (由调用者合约执行)
    function markNullifierUsed(bytes32 nullifierHash) external {
        nullifierHashes[nullifierHash] = true;
    }
    
    // 其他验证函数实现...
    
    function decodeProof(bytes calldata proof) 
        internal pure 
        returns (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) 
    {
        // Groth16 证明格式: 32*2 + 32*2*2 + 32*2 = 256 bytes
        require(proof.length == 256, "Invalid proof length");
        
        // 解码逻辑...
        assembly {
            // 使用 calldatacopy 高效读取
        }
    }
    
    function batchVerify(
        bytes[] calldata proofs,
        bytes32 merkleRoot,
        uint8 proofType
    ) external view returns (bool[] memory results) {
        results = new bool[](proofs.length);
        
        for (uint i = 0; i < proofs.length; i++) {
            // 根据 proofType 调用对应验证器
            // 批量优化：共享部分计算
            results[i] = _verifySingle(proofs[i], merkleRoot, proofType);
        }
        
        return results;
    }
    
    function _verifySingle(bytes calldata proof, bytes32 root, uint8 pType) 
        internal view returns (bool) 
    {
        // 内部验证逻辑
        return true;
    }
}
```

---

## 4. SDK 架构

### 4.1 整体架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      ZKP Generator SDK 架构                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                     语言绑定层 (Language Bindings)                 │  │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │  │
│   │  │   JS/TS  │ │  Python  │ │   Rust   │ │    Go    │           │  │
│   │  │ (Web/Node)│ │ (ML/Data)│ │ (HighPerf)│ │ (Backend)│           │  │
│   │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │  │
│   │       └─────────────┴─────────────┴─────────────┘                │  │
│   │                    ↓ FFI/WASM/GRPC                               │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                              ↓                                         │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                     核心引擎层 (Core Engine)                     │  │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │  │
│   │  │  Circuit    │ │   Witness   │ │   Proof     │               │  │
│   │  │  Compiler   │ │  Generator  │ │  Generator  │               │  │
│   │  └─────────────┘ └─────────────┘ └─────────────┘               │  │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │  │
│   │  │   Key       │ │   Cache     │ │  Parallel   │               │  │
│   │  │  Manager    │ │   Engine    │ │  Scheduler  │               │  │
│   │  └─────────────┘ └─────────────┘ └─────────────┘               │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                              ↓                                         │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                     后端适配层 (Backend Adapters)                │  │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │  │
│   │  │ Circom   │ │  Noir    │ │  Gnark   │ │  Cairo   │           │  │
│   │  │  SnarkJS │ │  Barretenberg│ │  Native  │ │  Stone    │           │  │
│   │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2 JavaScript/TypeScript SDK API

```typescript
// @echo-protocol/zkp-generator
// JavaScript/TypeScript SDK API 定义

// ==================== 核心类型 ====================

interface ProofConfig {
  proofType: 'PoU' | 'PoH' | 'PoD' | 'PoR';
  zkScheme: 'groth16' | 'stark' | 'bulletproofs';
  circuitPreset?: string; // 预设电路模板
  customCircuit?: string;   // 自定义电路路径
}

interface ProofInput {
  privateInputs: Record<string, FieldElement | FieldElement[]>;
  publicInputs: Record<string, FieldElement | FieldElement[]>;
}

interface FieldElement {
  type: 'field';
  value: string; // 大整数字符串
}

interface Proof {
  type: string;
  data: Uint8Array;
  publicInputs: FieldElement[];
  scheme: string;
  timestamp: number;
}

interface VerificationResult {
  valid: boolean;
  nullifier?: string;
  metadata?: Record<string, unknown>;
}

// ==================== 主类定义 ====================

export class ZKPGenerator {
  private config: ProofConfig;
  private backend: ZKBackend;
  private keyManager: KeyManager;
  private cache: ProofCache;

  constructor(config: ProofConfig);
  
  // 初始化 SDK
  async initialize(): Promise<void>;
  
  // 生成证明
  async generateProof(input: ProofInput): Promise<Proof>;
  
  // 验证证明 (本地验证)
  async verifyProof(proof: Proof): Promise<VerificationResult>;
  
  // 批量生成证明
  async batchGenerate(inputs: ProofInput[]): Promise<Proof[]>;
  
  // 导出验证密钥
  exportVerifyingKey(): Promise<Uint8Array>;
  
  // 获取电路信息
  getCircuitInfo(): CircuitInfo;
  
  // 销毁资源
  dispose(): Promise<void>;
}

// 预配置生成器工厂
export class ZKPGeneratorFactory {
  // 使用证明生成器
  static createUsageGenerator(options: UsageProofOptions): Promise<ZKPGenerator>;
  
  // 持有证明生成器
  static createHoldingGenerator(options: HoldingProofOptions): Promise<ZKPGenerator>;
  
  // 衍生证明生成器
  static createDerivativeGenerator(options: DerivativeProofOptions): Promise<ZKPGenerator>;
  
  // 收益证明生成器
  static createRevenueGenerator(options: RevenueProofOptions): Promise<ZKPGenerator>;
}

// ==================== 证明类型特定选项 ====================

interface UsageProofOptions {
  assetId: string;
  merkleTreeDepth?: number; // 默认 20
  trustedSetupArtifact?: string; // 可信设置产物路径
  enableParallel?: boolean;
}

interface HoldingProofOptions {
  assetId: string;
  maxTokens?: number; // 默认 10
  useRangeProof?: boolean; // 使用 Bulletproofs 范围证明
}

interface DerivativeProofOptions {
  maxSources?: number; // 默认 20
  maxDerivationSteps?: number; // 默认 100
  requireLicenseVerification?: boolean;
}

interface RevenueProofOptions {
  maxTransactions?: number; // 默认 100
  maxAllocations?: number; // 默认 100
  auditMode?: 'full' | 'summary';
}

// ==================== 工具类 ====================

export class KeyManager {
  // 加载证明密钥
  async loadProvingKey(path: string): Promise<ProvingKey>;
  
  // 加载验证密钥
  async loadVerifyingKey(path: string): Promise<VerifyingKey>;
  
  // 生成新密钥对 (仅用于开发测试)
  generateKeys(circuit: Circuit): Promise<KeyPair>;
  
  // 从远程下载密钥
  async downloadKeys(url: string): Promise<void>;
}

export class ProofCache {
  // 缓存证明结果
  set(key: string, proof: Proof, ttl?: number): Promise<void>;
  
  // 获取缓存的证明
  get(key: string): Promise<Proof | null>;
  
  // 清除缓存
  clear(): Promise<void>;
}

export class CircuitCompiler {
  // 编译电路
  compile(source: string, lang: 'circom' | 'noir'): Promise<Circuit>;
  
  // 从模板生成电路
  generateFromTemplate(
    template: string, 
    params: Record<string, number>
  ): Promise<string>;
}

// ==================== 实用函数 ====================

// 快速生成使用证明
export async function generateUsageProof(
  params: {
    userId: string;
    assetId: string;
    timestamp: number;
    usageData: unknown;
    merkleProof: MerkleProof;
    authSignature: Signature;
  },
  options?: { 
    backend?: 'wasm' | 'native';
    parallel?: boolean;
  }
): Promise<Proof>;

// 验证链上证明
export async function verifyOnChain(
  proof: Proof,
  contractAddress: string,
  provider: ethers.Provider
): Promise<VerificationResult>;

// 生成 Merkle 证明辅助
export function generateMerkleProof(
  leaves: string[],
  leaf: string,
  depth: number
): MerkleProof;

// 转换为链上格式
export function toChainFormat(proof: Proof): {
  a: [string, string];
  b: [[string, string], [string, string]];
  c: [string, string];
  inputs: string[];
};
```

### 4.3 Python SDK API

```python
# echo_zkp/generator.py
"""ECHO ZKP Generator Python SDK"""

from typing import Dict, List, Optional, Union, TypedDict
from dataclasses import dataclass
from enum import Enum
import numpy as np

class ProofType(Enum):
    USAGE = "PoU"
    HOLDING = "PoH"
    DERIVATIVE = "PoD"
    REVENUE = "PoR"

class ZKScheme(Enum):
    GROTH16 = "groth16"
    STARK = "stark"
    BULLETPROOF = "bulletproofs"

@dataclass
class FieldElement:
    """有限域元素"""
    value: int
    
    def to_bytes(self) -> bytes:
        return self.value.to_bytes(32, 'big')
    
    @classmethod
    def from_bytes(cls, data: bytes) -> "FieldElement":
        return cls(int.from_bytes(data, 'big'))

@dataclass
class Proof:
    """证明结构"""
    proof_type: ProofType
    data: bytes
    public_inputs: List[FieldElement]
    scheme: ZKScheme
    timestamp: float
    
    def to_json(self) -> dict:
        return {
            "type": self.proof_type.value,
            "data": self.data.hex(),
            "publicInputs": [str(pi.value) for pi in self.public_inputs],
            "scheme": self.scheme.value,
            "timestamp": self.timestamp
        }

@dataclass  
class MerkleProof:
    """Merkle 路径证明"""
    leaf: FieldElement
    path: List[FieldElement]
    indices: List[bool]  # True = 右侧, False = 左侧
    root: FieldElement

class ZKPGenerator:
    """ZKP 生成器主类"""
    
    def __init__(
        self,
        proof_type: ProofType,
        scheme: ZKScheme = ZKScheme.GROTH16,
        circuit_path: Optional[str] = None,
        use_cache: bool = True
    ):
        self.proof_type = proof_type
        self.scheme = scheme
        self.circuit_path = circuit_path
        self._backend = None
        self._key_manager = KeyManager()
        self._cache = ProofCache() if use_cache else None
        
    async def initialize(self) -> None:
        """初始化生成器，加载电路和密钥"""
        # 加载底层库
        if self.scheme == ZKScheme.GROTH16:
            from ._native import Groth16Backend
            self._backend = Groth16Backend()
        elif self.scheme == ZKScheme.STARK:
            from ._native import StarkBackend  
            self._backend = StarkBackend()
        
        await self._backend.load_circuit(self.circuit_path)
        
    async def generate(
        self,
        private_inputs: Dict[str, Union[int, str, List]],
        public_inputs: Dict[str, Union[int, str, List]],
        options: Optional[dict] = None
    ) -> Proof:
        """生成零知识证明"""
        
        # 检查缓存
        cache_key = self._compute_cache_key(private_inputs, public_inputs)
        if self._cache:
            cached = await self._cache.get(cache_key)
            if cached:
                return cached
        
        # 转换输入为 FieldElement
        pi_private = self._convert_inputs(private_inputs)
        pi_public = self._convert_inputs(public_inputs)
        
        # 生成见证
        witness = await self._backend.generate_witness(
            pi_private, pi_public
        )
        
        # 生成证明
        proof_data = await self._backend.prove(witness)
        
        proof = Proof(
            proof_type=self.proof_type,
            data=proof_data,
            public_inputs=pi_public,
            scheme=self.scheme,
            timestamp=time.time()
        )
        
        # 缓存结果
        if self._cache:
            await self._cache.set(cache_key, proof)
        
        return proof
    
    async def verify(self, proof: Proof) -> bool:
        """本地验证证明"""
        return await self._backend.verify(
            proof.data, 
            proof.public_inputs
        )
    
    async def batch_generate(
        self,
        inputs_list: List[tuple]
    ) -> List[Proof]:
        """批量生成证明"""
        # 并行生成
        import asyncio
        tasks = [
            self.generate(priv, pub) 
            for priv, pub in inputs_list
        ]
        return await asyncio.gather(*tasks)
    
    def _convert_inputs(
        self, 
        inputs: Dict[str, Union[int, str, List]]
    ) -> Dict[str, FieldElement]:
        """转换输入为 FieldElement"""
        result = {}
        for key, value in inputs.items():
            if isinstance(value, int):
                result[key] = FieldElement(value)
            elif isinstance(value, str):
                # 假设是十六进制或十进制字符串
                if value.startswith('0x'):
                    result[key] = FieldElement(int(value, 16))
                else:
                    result[key] = FieldElement(int(value))
            elif isinstance(value, list):
                # 数组输入，转换为列表
                result[key] = [FieldElement(int(v)) for v in value]
        return result
    
    def _compute_cache_key(self, *args) -> str:
        """计算缓存键"""
        import hashlib
        data = str(args).encode()
        return hashlib.sha256(data).hexdigest()

class UsageProofGenerator(ZKPGenerator):
    """使用证明专用生成器"""
    
    def __init__(
        self,
        asset_id: str,
        merkle_depth: int = 20,
        **kwargs
    ):
        super().__init__(ProofType.USAGE, ZKScheme.GROTH16, **kwargs)
        self.asset_id = asset_id
        self.merkle_depth = merkle_depth
        
    async def generate_usage_proof(
        self,
        user_id: str,
        timestamp: int,
        usage_data: bytes,
        merkle_proof: MerkleProof,
        auth_signature: tuple  # (r, s)
    ) -> Proof:
        """便捷的生成使用证明方法"""
        
        # 计算 usage_hash
        import hashlib
        usage_hash = hashlib.sha256(usage_data).hexdigest()
        
        # 计算 nullifier
        nullifier_input = f"{user_id}:{self.asset_id}:{timestamp}".encode()
        nonce = int(hashlib.sha256(nullifier_input).hexdigest(), 16)
        
        private_inputs = {
            "user_id": user_id,
            "asset_id": self.asset_id,
            "timestamp": timestamp,
            "nonce": nonce,
            "usage_hash": usage_hash,
            "auth_sig": auth_signature,
            "merkle_path": [p.value for p in merkle_proof.path],
            "merkle_path_index": merkle_proof.indices
        }
        
        public_inputs = {
            "asset_id_pub": self.asset_id,
            "timestamp_min": timestamp - 300,  # 5分钟窗口
            "timestamp_max": timestamp + 300,
            "nullifier": hashlib.sha256(
                f"{user_id}:{self.asset_id}:{nonce}".encode()
            ).hexdigest(),
            "merkle_root": merkle_proof.root.value
        }
        
        return await self.generate(private_inputs, public_inputs)

class ProofCache:
    """证明缓存"""
    
    def __init__(self, max_size: int = 1000):
        self._cache: Dict[str, Proof] = {}
        self._max_size = max_size
        
    async def get(self, key: str) -> Optional[Proof]:
        return self._cache.get(key)
    
    async def set(self, key: str, proof: Proof, ttl: Optional[int] = None):
        if len(self._cache) >= self._max_size:
            # LRU 清理
            oldest = min(self._cache.keys(), 
                         key=lambda k: self._cache[k].timestamp)
            del self._cache[oldest]
        self._cache[key] = proof

class KeyManager:
    """密钥管理"""
    
    async def download_from_registry(
        self,
        asset_id: str,
        proof_type: ProofType,
        registry_url: str = "https://keys.echo.network"
    ) -> tuple:
        """从 ECHO 密钥注册表下载验证密钥"""
        import aiohttp
        
        url = f"{registry_url}/{asset_id}/{proof_type.value}/vk"
        async with aiohttp.ClientSession() as session:
            async with session.get(url) as resp:
                vk_data = await resp.read()
                
        return vk_data

# 实用函数

def generate_merkle_proof(
    leaves: List[str],
    target_leaf: str,
    depth: int = 20
) -> MerkleProof:
    """生成 Merkle 路径证明"""
    # 实现细节...
    pass

def field_to_int(value: Union[int, str, bytes]) -> int:
    """转换为域元素整数"""
    if isinstance(value, int):
        return value
    elif isinstance(value, str):
        if value.startswith('0x'):
            return int(value, 16)
        return int(value)
    elif isinstance(value, bytes):
        return int.from_bytes(value, 'big')
    raise ValueError(f"Cannot convert {type(value)} to field element")

# 导出主要接口
__all__ = [
    'ZKPGenerator',
    'UsageProofGenerator',
    'ProofType',
    'ZKScheme',
    'Proof',
    'MerkleProof',
    'FieldElement',
    'generate_merkle_proof'
]
```

### 4.4 Rust SDK API

```rust
// echo-zkp/src/lib.rs
//! ECHO ZKP Generator - Rust SDK
//! 
//! 高性能零知识证明生成器，适用于生产环境

use ark_bn254::{Bn254, Fr, FrParameters};
use ark_ec::PairingEngine;
use ark_ff::PrimeField;
use ark_groth16::{Groth16, Proof as Groth16Proof, ProvingKey, VerifyingKey};
use ark_snark::SNARK;
use serde::{Deserialize, Serialize};
use thiserror::Error;
use std::sync::Arc;
use rayon::prelude::*;

pub mod circuits;
pub mod backends;
pub mod keys;
pub mod cache;
pub mod utils;

/// 证明类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProofType {
    Usage,
    Holding,
    Derivative,
    Revenue,
}

/// ZK 方案
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ZKScheme {
    Groth16,
    Stark,
    Bulletproofs,
}

/// 域元素
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct FieldElement(pub Fr);

impl FieldElement {
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, ZKPError> {
        let mut repr = <Fr as PrimeField>::BigInt::default();
        // 转换逻辑...
        Ok(Self(Fr::from_repr(repr).unwrap()))
    }
    
    pub fn to_bytes(&self) -> Vec<u8> {
        self.0.into_repr().to_bytes_be()
    }
}

/// 证明结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Proof {
    pub proof_type: ProofType,
    pub scheme: ZKScheme,
    pub data: Vec<u8>,
    pub public_inputs: Vec<FieldElement>,
    pub timestamp: u64,
}

/// 证明输入
#[derive(Debug, Clone)]
pub struct ProofInput {
    pub private: Vec<(String, FieldElement)>,
    pub public: Vec<(String, FieldElement)>,
}

/// 错误类型
#[derive(Error, Debug)]
pub enum ZKPError {
    #[error("Circuit error: {0}")]
    CircuitError(String),
    
    #[error("Backend error: {0}")]
    BackendError(String),
    
    #[error("Key error: {0}")]
    KeyError(String),
    
    #[error("Verification failed")]
    VerificationFailed,
    
    #[error("Invalid input: {0}")]
    InvalidInput(String),
    
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
}

/// ZKP 生成器配置
#[derive(Debug, Clone)]
pub struct GeneratorConfig {
    pub proof_type: ProofType,
    pub scheme: ZKScheme,
    pub circuit_path: Option<std::path::PathBuf>,
    pub proving_key_path: Option<std::path::PathBuf>,
    pub use_cache: bool,
    pub parallel_workers: usize,
}

impl Default for GeneratorConfig {
    fn default() -> Self {
        Self {
            proof_type: ProofType::Usage,
            scheme: ZKScheme::Groth16,
            circuit_path: None,
            proving_key_path: None,
            use_cache: true,
            parallel_workers: num_cpus::get(),
        }
    }
}

/// ZKP 生成器
pub struct ZKPGenerator {
    config: GeneratorConfig,
    backend: Box<dyn ZKBackend>,
    key_manager: Arc<keys::KeyManager>,
    cache: Option<cache::ProofCache>,
}

impl ZKPGenerator {
    /// 创建新的生成器
    pub fn new(config: GeneratorConfig) -> Result<Self, ZKPError> {
        let backend: Box<dyn ZKBackend> = match config.scheme {
            ZKScheme::Groth16 => Box::new(backends::Groth16Backend::new()?),
            ZKScheme::Stark => Box::new(backends::StarkBackend::new()?),
            ZKScheme::Bulletproofs => Box::new(backends::BulletproofBackend::new()?),
        };
        
        let cache = if config.use_cache {
            Some(cache::ProofCache::new(1000))
        } else {
            None
        };
        
        Ok(Self {
            config,
            backend,
            key_manager: Arc::new(keys::KeyManager::new()),
            cache,
        })
    }
    
    /// 初始化生成器
    pub async fn initialize(&mut self) -> Result<(), ZKPError> {
        if let Some(ref path) = self.config.circuit_path {
            self.backend.load_circuit(path).await?;
        }
        
        if let Some(ref path) = self.config.proving_key_path {
            let pk = self.key_manager.load_proving_key(path).await?;
            self.backend.set_proving_key(pk)?;
        }
        
        Ok(())
    }
    
    /// 生成证明
    pub async fn generate(&self, input: ProofInput) -> Result<Proof, ZKPError> {
        // 检查缓存
        if let Some(ref cache) = self.cache {
            let cache_key = self.compute_cache_key(&input);
            if let Some(proof) = cache.get(&cache_key).await {
                return Ok(proof);
            }
        }
        
        // 生成见证
        let witness = self.backend.generate_witness(&input).await?;
        
        // 生成证明
        let proof_data = self.backend.prove(&witness).await?;
        
        let proof = Proof {
            proof_type: self.config.proof_type,
            scheme: self.config.scheme,
            data: proof_data,
            public_inputs: input.public.iter()
                .map(|(_, v)| *v)
                .collect(),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
        };
        
        // 缓存结果
        if let Some(ref cache) = self.cache {
            let cache_key = self.compute_cache_key(&input);
            cache.set(cache_key, proof.clone()).await;
        }
        
        Ok(proof)
    }
    
    /// 验证证明
    pub async fn verify(&self, proof: &Proof) -> Result<bool, ZKPError> {
        // 验证证明类型匹配
        if proof.proof_type != self.config.proof_type {
            return Err(ZKPError::InvalidInput(
                "Proof type mismatch".to_string()
            ));
        }
        
        self.backend.verify(&proof.data, &proof.public_inputs).await
    }
    
    /// 批量生成证明
    pub async fn batch_generate(
        &self, 
        inputs: Vec<ProofInput>
    ) -> Result<Vec<Proof>, ZKPError> {
        // 使用 Rayon 并行生成
        let proofs: Result<Vec<_>, _> = inputs
            .into_par_iter()
            .map(|input| {
                // 注意：需要处理 async 在并行环境中的问题
                // 这里使用 tokio::runtime 或 async-std
                tokio::runtime::Handle::current()
                    .block_on(self.generate(input))
            })
            .collect();
        
        proofs
    }
    
    /// 计算缓存键
    fn compute_cache_key(&self, input: &ProofInput) -> String {
        use sha2::{Sha256, Digest};
        
        let mut hasher = Sha256::new();
        // 哈希输入...
        format!("{:x}", hasher.finalize())
    }
}

/// ZK 后端 trait
#[async_trait::async_trait]
pub trait ZKBackend: Send + Sync {
    async fn load_circuit(&mut self, path: &std::path::Path) -> Result<(), ZKPError>;
    async fn generate_witness(&self, input: &ProofInput) -> Result<Vec<u8>, ZKPError>;
    async fn prove(&self, witness: &[u8]) -> Result<Vec<u8>, ZKPError>;
    async fn verify(&self, proof: &[u8], public_inputs: &[FieldElement]) -> Result<bool, ZKPError>;
    fn set_proving_key(&mut self, pk: keys::ProvingKey) -> Result<(), ZKPError>;
}

/// Groth16 后端实现
pub mod backends {
    use super::*;
    
    pub struct Groth16Backend {
        pk: Option<keys::ProvingKey>,
        vk: Option<keys::VerifyingKey>,
        r1cs: Option<circuits::R1CS>,
    }
    
    impl Groth16Backend {
        pub fn new() -> Result<Self, ZKPError> {
            Ok(Self {
                pk: None,
                vk: None,
                r1cs: None,
            })
        }
    }
    
    #[async_trait::async_trait]
    impl ZKBackend for Groth16Backend {
        async fn load_circuit(&mut self, path: &std::path::Path) -> Result<(), ZKPError> {
            // 加载 R1CS
            let r1cs = circuits::R1CS::from_file(path)?;
            self.r1cs = Some(r1cs);
            Ok(())
        }
        
        async fn generate_witness(&self, input: &ProofInput) -> Result<Vec<u8>, ZKPError> {
            // 生成见证
            let r1cs = self.r1cs.as_ref().ok_or(ZKPError::CircuitError(
                "Circuit not loaded".to_string()
            ))?;
            
            r1cs.generate_witness(input)
        }
        
        async fn prove(&self, witness: &[u8]) -> Result<Vec<u8>, ZKPError> {
            let pk = self.pk.as_ref().ok_or(ZKPError::KeyError(
                "Proving key not set".to_string()
            ))?;
            
            // 使用 ark-groth16 生成证明
            let proof = Groth16::<Bn254>::prove(
                &pk.0,
                witness,
                &mut rand::thread_rng()
            ).map_err(|e| ZKPError::BackendError(e.to_string()))?;
            
            // 序列化证明
            let proof_bytes = bincode::serialize(&proof)
                .map_err(|e| ZKPError::BackendError(e.to_string()))?;
            
            Ok(proof_bytes)
        }
        
        async fn verify(
            &self, 
            proof: &[u8], 
            public_inputs: &[FieldElement]
        ) -> Result<bool, ZKPError> {
            let vk = self.vk.as_ref().ok_or(ZKPError::KeyError(
                "Verifying key not set".to_string()
            ))?;
            
            // 反序列化证明
            let proof: Groth16Proof<Bn254> = bincode::deserialize(proof)
                .map_err(|e| ZKPError::BackendError(e.to_string()))?;
            
            // 转换公开输入
            let inputs: Vec<Fr> = public_inputs.iter()
                .map(|f| f.0)
                .collect();
            
            // 验证
            let valid = Groth16::<Bn254>::verify(
                &vk.0,
                &inputs,
                &proof
            ).map_err(|e| ZKPError::VerificationFailed)?;
            
            Ok(valid)
        }
        
        fn set_proving_key(&mut self, pk: keys::ProvingKey) -> Result<(), ZKPError> {
            self.pk = Some(pk);
            Ok(())
        }
    }
    
    // STARKs 和 Bulletproofs 后端类似实现...
    pub struct StarkBackend;
    pub struct BulletproofBackend;
}

/// 使用证明专用生成器
pub struct UsageProofGenerator {
    inner: ZKPGenerator,
    asset_id: String,
}

impl UsageProofGenerator {
    pub fn new(asset_id: String, config: Option<GeneratorConfig>) -> Result<Self, ZKPError> {
        let mut cfg = config.unwrap_or_default();
        cfg.proof_type = ProofType::Usage;
        cfg.scheme = ZKScheme::Groth16;
        
        Ok(Self {
            inner: ZKPGenerator::new(cfg)?,
            asset_id,
        })
    }
    
    pub async fn generate_usage_proof(
        &self,
        user_id: FieldElement,
        timestamp: u64,
        usage_data: &[u8],
        merkle_proof: &utils::MerkleProof,
        auth_sig: &(FieldElement, FieldElement, FieldElement),
    ) -> Result<Proof, ZKPError> {
        use sha2::{Sha256, Digest};
        
        // 计算 usage_hash
        let mut hasher = Sha256::new();
        hasher.update(usage_data);
        let usage_hash = hasher.finalize();
        let usage_hash_fe = FieldElement::from_bytes(&usage_hash)?;
        
        // 计算 nonce
        let nonce_input = format!("{}:{}:{}", 
            hex::encode(user_id.to_bytes()), 
            self.asset_id, 
            timestamp
        );
        let mut hasher = Sha256::new();
        hasher.update(nonce_input.as_bytes());
        let nonce = FieldElement::from_bytes(&hasher.finalize())?;
        
        // 计算 nullifier
        let nullifier_input = format!("{}:{}:{}",
            hex::encode(user_id.to_bytes()),
            self.asset_id,
            hex::encode(nonce.to_bytes())
        );
        let mut hasher = Sha256::new();
        hasher.update(nullifier_input.as_bytes());
        let nullifier = FieldElement::from_bytes(&hasher.finalize())?;
        
        let input = ProofInput {
            private: vec![
                ("user_id".to_string(), user_id),
                ("asset_id".to_string(), FieldElement(Fr::from(0))), // 需要转换
                ("timestamp".to_string(), FieldElement(Fr::from(timestamp))),
                ("nonce".to_string(), nonce),
                ("usage_hash".to_string(), usage_hash_fe),
                ("auth_sig_r8x".to_string(), auth_sig.0),
                ("auth_sig_r8y".to_string(), auth_sig.1),
                ("auth_sig_s".to_string(), auth_sig.2),
            ],
            public: vec![
                ("asset_id_pub".to_string(), FieldElement(Fr::from(0))),
                ("timestamp_min".to_string(), FieldElement(Fr::from(timestamp - 300))),
                ("timestamp_max".to_string(), FieldElement(Fr::from(timestamp + 300))),
                ("nullifier".to_string(), nullifier),
                ("merkle_root".to_string(), merkle_proof.root),
            ],
        };
        
        self.inner.generate(input).await
    }
}

// 导出
pub use circuits::{R1CS, Circuit};
pub use keys::{KeyManager, ProvingKey, VerifyingKey};
pub use cache::ProofCache;
pub use utils::{MerkleProof, generate_merkle_proof};
```

---

## 5. 开发者体验

### 5.1 CLI 工具

```bash
#!/bin/bash
# ECHO ZKP Generator CLI
# zkp-cli - 零知识证明命令行工具

# ==================== 全局命令 ====================

# 查看版本
zkp-cli --version
# 输出: zkp-cli 1.0.0 (echo-protocol)

# 查看帮助
zkp-cli --help

# ==================== 初始化命令 ====================

# 初始化项目配置
zkp-cli init --project my-zkp-project
# 创建配置文件: zkp-config.json

# 下载预设电路
zkp-cli circuit download --type usage --asset-id asset_abc123
# 从 ECHO 注册表下载预编译电路

# 生成新的电路 (从模板)
zkp-cli circuit generate --template usage --params '{"merkleDepth": 20}'

# ==================== 密钥管理命令 ====================

# 下载验证密钥
zkp-cli key download --asset-id asset_abc123 --type verifying

# 导入本地密钥
zkp-cli key import --proving-key ./pk.key --verifying-key ./vk.key

# 导出密钥 (用于备份)
kp-cli key export --output ./backup/

# 执行可信设置 (仅电路开发者)
zkp-cli trusted-setup --circuit ./circuit.circom --output ./setup/

# ==================== 证明生成命令 ====================

# 生成使用证明 (交互式)
zkp-cli prove usage --asset-id asset_abc123 --interactive

# 生成使用证明 (批处理，从文件)
zkp-cli prove usage --asset-id asset_abc123 --input ./usage_input.json --output ./proof.json

# usage_input.json 示例:
# {
#   "private": {
#     "user_id": "0x1234...",
#     "timestamp": 1713456789,
#     "usage_hash": "0xabcd...",
#     "nonce": "0x5678...",
#     "merkle_path": ["0x...", "0x..."],
#     "merkle_indices": [0, 1, 0]
#   },
#   "public": {
#     "asset_id_pub": "asset_abc123",
#     "timestamp_min": 1713456489,
#     "timestamp_max": 1713457089,
#     "merkle_root": "0xdead..."
#   }
# }

# 生成持有证明
zkp-cli prove holding --asset-id asset_abc123 --input ./holding_input.json

# 生成衍生证明
zkp-cli prove derivative --derivative-id work_xyz789 --sources ./sources.json

# 生成收益证明
zkp-cli prove revenue --period 2024-Q1 --transactions ./txs.json --allocations ./alloc.json

# ==================== 批量证明命令 ====================

# 批量生成证明
zkp-cli batch prove --type usage --inputs-dir ./inputs/ --outputs-dir ./proofs/

# 批量验证证明
zkp-cli batch verify --proofs-dir ./proofs/ --results ./results.json

# 聚合证明 (将多个证明聚合成一个)
zkp-cli aggregate --proofs ./proofs/*.json --output ./aggregated_proof.json

# ==================== 验证命令 ====================

# 本地验证证明
zkp-cli verify --proof ./proof.json --type usage

# 链上验证 (通过 RPC)
kp-cli verify --proof ./proof.json --type usage --on-chain --rpc https://rpc.echo.network

# ==================== 调试工具命令 ====================

# 电路可视化
zkp-cli debug visualize --circuit ./circuit.circom --output ./circuit.html

# 约束分析
zkp-cli debug analyze --circuit ./circuit.circom --output ./analysis.json

# 见证检查 (检查约束满足情况)
zkp-cli debug witness --circuit ./circuit.circom --witness ./witness.json

# 性能分析
zkp-cli debug profile --circuit ./circuit.circom --iterations 10

# ==================== 配置命令 ====================

# 设置默认后端
zkp-cli config set backend groth16

# 设置并行度
zkp-cli config set parallel_workers 8

# 设置缓存目录
zkp-cli config set cache_dir ~/.echo/zkp/cache

# 查看当前配置
zkp-cli config get
```

### 5.2 配置模板

```json
{
  "_comment": "ECHO ZKP Generator 配置文件模板",
  "version": "1.0.0",
  
  "project": {
    "name": "my-zkp-project",
    "description": "自定义沙箱的 ZKP 配置"
  },
  
  "backend": {
    "default": "groth16",
    "options": {
      "groth16": {
        "curve": "bn254",
        "provingSystem": "arkworks",
        "ceremonyUrl": "https://ceremony.echo.network"
      },
      "stark": {
        "field": "goldilocks",
        "prover": "stone"
      },
      "bulletproofs": {
        "curve": "secp256k1"
      }
    }
  },
  
  "circuits": {
    "presets": {
      "usage_standard": {
        "template": "PoU",
        "params": {
          "merkleDepth": 20,
          "timeWindow": 600
        },
        "registryUrl": "https://circuits.echo.network/pou/standard"
      },
      "holding_premium": {
        "template": "PoH",
        "params": {
          "maxTokens": 100,
          "useRangeProof": true
        },
        "registryUrl": "https://circuits.echo.network/poh/premium"
      },
      "derivative_complex": {
        "template": "PoD",
        "params": {
          "maxSources": 50,
          "maxDerivationSteps": 500
        }
      },
      "revenue_audit": {
        "template": "PoR",
        "params": {
          "maxTransactions": 1000,
          "auditMode": "full"
        },
        "scheme": "stark"
      }
    }
  },
  
  "keys": {
    "source": "registry",
    "registryUrl": "https://keys.echo.network",
    "localPath": "./keys",
    "autoDownload": true
  },
  
  "performance": {
    "parallelWorkers": 8,
    "memoryLimit": "8GB",
    "cacheSize": "2GB",
    "useGpu": false,
    "gpuDevice": null
  },
  
  "verification": {
    "chain": {
      "rpcUrl": "https://rpc.echo.network",
      "contractAddress": "0x...",
      "confirmations": 1
    },
    "localCache": true
  },
  
  "logging": {
    "level": "info",
    "format": "json",
    "output": "stdout"
  }
}
```

### 5.3 调试工具

```python
# debug_tools.py - 调试工具集
"""ZKP Generator 调试工具"""

import json
import graphviz
from typing import Dict, List, Tuple
import matplotlib.pyplot as plt
import numpy as np

class CircuitVisualizer:
    """电路可视化工具"""
    
    def __init__(self, circuit_file: str):
        self.circuit_file = circuit_file
        self.constraints = self._parse_circuit()
        
    def _parse_circuit(self) -> List[Dict]:
        """解析电路文件"""
        # 实现 R1CS 解析逻辑
        pass
    
    def to_dot(self, output_file: str):
        """生成 Graphviz 图"""
        dot = graphviz.Digraph(comment='ZKP Circuit')
        
        # 添加信号节点
        for signal in self._get_signals():
            dot.node(signal['id'], signal['name'], 
                    shape='ellipse' if signal['is_public'] else 'box')
        
        # 添加约束边
        for constraint in self.constraints:
            # A * B = C 约束
            for input_var in constraint['a']:
                dot.edge(input_var, constraint['id'], label='A')
            for input_var in constraint['b']:
                dot.edge(input_var, constraint['id'], label='B')
            for output_var in constraint['c']:
                dot.edge(constraint['id'], output_var, label='C')
        
        dot.render(output_file, format='png')
    
    def constraint_heatmap(self, output_file: str):
        """生成约束密度热图"""
        # 计算每层的约束数量
        constraint_counts = self._compute_constraint_density()
        
        plt.figure(figsize=(12, 6))
        plt.bar(range(len(constraint_counts)), constraint_counts)
        plt.xlabel('Circuit Layer')
        plt.ylabel('Constraint Count')
        plt.title('Circuit Constraint Density')
        plt.savefig(output_file)
        plt.close()

class ConstraintAnalyzer:
    """约束分析工具"""
    
    def analyze(self, circuit_file: str) -> Dict:
        """分析电路约束"""
        return {
            "total_constraints": 0,
        }
```

### 5.4 性能优化

```javascript
// performance.js - 性能优化模块

class ProofCache {
  constructor(maxSize = 1000) {
    this.cache = new Map();
    this.maxSize = maxSize;
    this.accessOrder = [];
  }
  
  get(key) {
    if (this.cache.has(key)) {
      // 更新访问顺序
      this.updateAccessOrder(key);
      return this.cache.get(key);
    }
    return null;
  }
  
  set(key, value) {
    if (this.cache.size >= this.maxSize) {
      // LRU 淘汰
      const oldest = this.accessOrder.shift();
      this.cache.delete(oldest);
    }
    this.cache.set(key, value);
    this.accessOrder.push(key);
  }
  
  computeKey(inputs) {
    // 使用确定性哈希
    return crypto.createHash('sha256')
      .update(JSON.stringify(inputs))
      .digest('hex');
  }
}

class ParallelProver {
  constructor(workerCount = 4) {
    this.workerCount = workerCount;
    this.workers = [];
  }
  
  async initialize() {
    // 初始化 Worker 池
    for (let i = 0; i < this.workerCount; i++) {
      const worker = new Worker('./prover-worker.js');
      this.workers.push(worker);
    }
  }
  
  async batchProve(inputs) {
    // 将任务分配给 workers
    const chunkSize = Math.ceil(inputs.length / this.workerCount);
    const chunks = [];
    
    for (let i = 0; i < inputs.length; i += chunkSize) {
      chunks.push(inputs.slice(i, i + chunkSize));
    }
    
    const promises = chunks.map((chunk, index) => 
      this.proveChunk(chunk, this.workers[index])
    );
    
    const results = await Promise.all(promises);
    return results.flat();
  }
  
  async proveChunk(inputs, worker) {
    return new Promise((resolve) => {
      worker.postMessage({ type: 'prove', inputs });
      worker.onmessage = (e) => resolve(e.data);
    });
  }
}
```

---

## 6. 安全与隐私

### 6.1 可信设置策略

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      可信设置 (Trusted Setup) 策略                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   方案选择矩阵                                                          │
│   ┌─────────────────┬─────────────────┬─────────────────────────────┐ │
│   │     场景        │    推荐方案      │         说明               │ │
│   ├─────────────────┼─────────────────┼─────────────────────────────┤ │
│   │ 高频标准电路     │ 全局可信仪式     │ 社区多参与方 MPC 仪式        │ │
│   │                 │ (Perpetual Powers│ 支持 Perpetual Powers of Tau│ │
│   │                 │  of Tau)         │ 可复用积累的安全性             │ │
│   ├─────────────────┼─────────────────┼─────────────────────────────┤ │
│   │ 资产专用电路     │ 资产发行者仪式   │ 资产创建时生成，参与者:        │ │
│   │                 │ (Asset-Specific) │ 创作者 + 审计方 + 社区代表    │ │
│   ├─────────────────┼─────────────────┼─────────────────────────────┤ │
│   │ 高频无需设置     │ STARKs /         │ 牺牲证明大小换取无需设置       │ │
│   │                 │ Bulletproofs     │ 适合审计类低频场景             │ │
│   ├─────────────────┼─────────────────┼─────────────────────────────┤ │
│   │ 自定义电路       │ 通用参考字符串   │ 基于现有 SRS 派生专用密钥       │ │
│   │                 │ (SRS Derivation) │ 减少仪式开销                   │ │
│   └─────────────────┴─────────────────┴─────────────────────────────┘ │
│                                                                         │
│   ECHO 仪式基础设施                                                      │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    ECHO Trusted Setup Ceremony                   │  │
│   │                                                                 │  │
│   │   Phase 1: Powers of Tau (通用)                                 │  │
│   │   ├── 开源社区贡献 (Ethereum, Filecoin 等复用)                   │  │
│   │   └── 支持电路无关的初始熵                                      │  │
│   │                                                                 │  │
│   │   Phase 2: 电路特定 (Circuit-Specific)                         │  │
│   │   ├── 针对 ECHO 四种证明类型的标准电路                          │  │
│   │   ├── 资产创建者可选择加入自定义参数仪式                          │  │
│   │   └── 贡献者: 创作者 + 节点运营者 + 审计机构 + 随机社区用户        │  │
│   │                                                                 │  │
│   │   仪式验证:                                                      │  │
│   │   ├── 公开可验证的 transcript                                    │  │
│   │   ├── 第三方审计报告                                             │  │
│   │   └── 链上记录贡献哈希                                           │  │
│   │                                                                 │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.2 证明的可链接性控制

```rust
// linkability.rs - 可链接性控制

/// 控制同一用户多次证明之间的关联性
pub enum LinkabilityLevel {
    /// 完全不可链接 - 每次证明使用全新随机数
    /// 用途：最高隐私场景
    Unlinkable,
    
    /// 单次会话内可链接 - 同一 session 内的证明可识别为同一用户
    /// 用途：防重复调用，但不暴露跨 session 身份
    SessionLinkable { session_id: FieldElement },
    
    /// 资产级别可链接 - 同一资产的使用证明可识别为同一用户
    /// 用途：资产的配额管理
    AssetLinkable { asset_id: FieldElement },
    
    /// 完全可链接 - 所有证明都可识别为同一用户
    /// 用途：KYC/AML 合规场景，用户明确同意
    FullyLinkable { identity_commitment: FieldElement },
}

pub struct NullifierManager {
    used_nullifiers: HashSet<FieldElement>,
    linkability_config: LinkabilityLevel,
}

impl NullifierManager {
    /// 生成 nullifier，根据可链接性级别调整计算方式
    pub fn generate_nullifier(
        &self,
        user_id: &FieldElement,
        asset_id: &FieldElement,
        nonce: &FieldElement,
        context: &NullifierContext,
    ) -> FieldElement {
        match &self.linkability_config {
            LinkabilityLevel::Unlinkable => {
                // nullifier = hash(user_id, asset_id, random_nonce)
                // 每次使用全新随机 nonce，无法关联
                poseidon_hash(&[user_id, asset_id, nonce])
            }
            
            LinkabilityLevel::SessionLinkable { session_id } => {
                // nullifier = hash(user_id, asset_id, session_id)
                // 同 session 内 nullifier 相同，跨 session 不同
                poseidon_hash(&[user_id, asset_id, session_id])
            }
            
            LinkabilityLevel::AssetLinkable { asset_id: _ } => {
                // nullifier = hash(user_id, asset_id, fixed_secret)
                // 同一用户对同一资产总是产生相同 nullifier
                let fixed_secret = derive_secret(user_id, asset_id);
                poseidon_hash(&[user_id, asset_id, &fixed_secret])
            }
            
            LinkabilityLevel::FullyLinkable { identity_commitment } => {
                // nullifier = hash(identity_commitment, asset_id, nonce)
                // 所有证明都通过 identity_commitment 关联
                poseidon_hash(&[identity_commitment, asset_id, nonce])
            }
        }
    }
    
    /// 检查 nullifier 是否已使用 (防重放)
    pub fn is_nullifier_used(&self, nullifier: &FieldElement) -> bool {
        self.used_nullifiers.contains(nullifier)
    }
    
    /// 标记 nullifier 已使用
    pub fn mark_nullifier_used(&mut self, nullifier: FieldElement) {
        self.used_nullifiers.insert(nullifier);
    }
}
```

### 6.3 防重放攻击机制

```solidity
// ReplayProtection.sol
pragma solidity ^0.8.19;

contract ReplayProtection {
    // Nullifier 记录 (已使用的证明)
    mapping(bytes32 => bool) public spentNullifiers;
    
    // 时间窗口限制
    uint256 public constant PROOF_TIME_WINDOW = 10 minutes;
    
    // 资产特定的证明计数 (用于速率限制)
    mapping(bytes32 => uint256) public assetProofCount;
    mapping(bytes32 => uint256) public assetLastProofTime;
    
    event NullifierSpent(bytes32 indexed nullifier, bytes32 indexed assetId);
    
    /// @notice 验证并记录 nullifier
    function verifyAndRecordNullifier(
        bytes32 nullifier,
        bytes32 assetId,
        uint256 timestamp,
        uint256[2] calldata timeRange
    ) external returns (bool) {
        // 1. 检查 nullifier 未被使用
        require(!spentNullifiers[nullifier], "Nullifier already spent");
        
        // 2. 检查时间戳在有效范围内
        require(timestamp >= timeRange[0], "Timestamp too old");
        require(timestamp <= timeRange[1], "Timestamp too new");
        require(timestamp >= block.timestamp - PROOF_TIME_WINDOW, "Proof expired");
        
        // 3. 检查速率限制 (防止洪水攻击)
        require(
            block.timestamp >= assetLastProofTime[assetId] + 1 minutes ||
            assetProofCount[assetId] < 100,
            "Rate limit exceeded"
        );
        
        // 4. 记录 nullifier 已使用
        spentNullifiers[nullifier] = true;
        
        // 5. 更新资产证明计数
        assetProofCount[assetId]++;
        assetLastProofTime[assetId] = block.timestamp;
        
        emit NullifierSpent(nullifier, assetId);
        
        return true;
    }
    
    /// @notice 批量验证 (gas 优化)
    function batchVerifyNullifiers(
        bytes32[] calldata nullifiers,
        bytes32[] calldata assetIds,
        uint256[] calldata timestamps,
        bytes32 merkleRoot
    ) external returns (bool[] memory results) {
        require(
            nullifiers.length == assetIds.length &&
            nullifiers.length == timestamps.length,
            "Array length mismatch"
        );
        
        results = new bool[](nullifiers.length);
        
        for (uint i = 0; i < nullifiers.length; i++) {
            // 批量检查
            if (spentNullifiers[nullifiers[i]]) {
                results[i] = false;
                continue;
            }
            
            // 通过 Merkle 证明批量验证
            // ...
            
            spentNullifiers[nullifiers[i]] = true;
            results[i] = true;
        }
        
        return results;
    }
}
```

### 6.4 密钥管理

```typescript
// key_management.ts - 密钥管理模块

interface KeyHierarchy {
  // 主密钥 (由可信硬件/多方计算生成)
  masterKey: {
    type: 'mpc' | 'hsm' | 'shamir';
    shares: number;
    threshold: number;
  };
  
  // 电路密钥 (从主密钥派生)
  circuitKeys: {
    provingKey: ProvingKey;
    verifyingKey: VerifyingKey;
    derivedFrom: string; // 主密钥哈希
    rotationSchedule: string;
  };
  
  // 资产特定密钥
  assetKeys: Map<string, {
    provingKey?: ProvingKey; // 可选，使用全局密钥时为 null
    verifyingKey: VerifyingKey;
    customizationProof: string; // 证明密钥是从可信设置派生
  }>;
}

class SecureKeyManager {
  private storage: KeyStorage;
  private encryption: AEADEncryption;
  
  constructor(config: KeyManagerConfig) {
    this.storage = new HSMKeyStorage(config.hsmConfig);
    this.encryption = new AES256GCM();
  }
  
  // 从可信设置导入密钥
  async importFromTrustedSetup(
    ceremonyId: string,
    circuitType: ProofType,
    verification: CeremonyVerification
  ): Promise<KeyPair> {
    // 1. 验证仪式 transcript
    const isValid = await this.verifyCeremonyTranscript(
      ceremonyId, 
      verification
    );
    if (!isValid) {
      throw new Error('Ceremony verification failed');
    }
    
    // 2. 从安全存储获取密钥
    const encryptedKeys = await this.storage.retrieve(
      `ceremony:${ceremonyId}:${circuitType}`
    );
    
    // 3. 解密并验证完整性
    const keys = await this.decryptAndVerify(encryptedKeys);
    
    // 4. 本地安全存储
    await this.secureLocalStore(keys, ceremonyId);
    
    return keys;
  }
  
  // 派生资产特定密钥
  async deriveAssetKey(
    baseKey: ProvingKey,
    assetId: string,
    customization: CircuitParams
  ): Promise<ProvingKey> {
    // 使用 HKDF 派生
    const derivedKey = await hkdfSha256(
      baseKey.seed,
      Buffer.from(assetId),
      Buffer.from(JSON.stringify(customization))
    );
    
    // 验证派生密钥正确性
    const verification = await this.verifyKeyDerivation(
      baseKey,
      derivedKey,
      customization
    );
    
    if (!verification.valid) {
      throw new Error('Key derivation verification failed');
    }
    
    return {
      ...derivedKey,
      derivationProof: verification.proof,
      parentKeyHash: hashKey(baseKey)
    };
  }
  
  // 密钥轮换
  async rotateKeys(
    oldKeys: KeyPair,
    newCeremonyId: string,
    transitionPeriod: number // 天数
  ): Promise<KeyRotationResult> {
    // 1. 获取新密钥
    const newKeys = await this.importFromTrustedSetup(
      newCeremonyId,
      oldKeys.proofType,
      {} as CeremonyVerification
    );
    
    // 2. 设置双密钥并行期
    await this.enableDualKeyMode(oldKeys, newKeys, transitionPeriod);
    
    // 3. 逐步迁移
    this.scheduleKeyMigration(oldKeys.id, newKeys.id, transitionPeriod);
    
    return {
      newKeys,
      transitionDeadline: Date.now() + transitionPeriod * 86400000,
      migrationStatus: 'scheduled'
    };
  }
  
  // 安全擦除
  async secureDelete(keyId: string): Promise<void> {
    // 覆盖写入
    await this.storage.overwrite(keyId, randomBytes(4096));
    // 删除引用
    await this.storage.delete(keyId);
    // 日志记录
    this.auditLog.record({ action: 'secure_delete', keyId });
  }
}
```

---

## 7. 核心工作流程

### 7.1 初始化流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      ZKP Generator 初始化流程                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────┐                                                       │
│   │   开始      │                                                       │
│   └──────┬──────┘                                                       │
│          ↓                                                              │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │ 1. 配置加载                                                      │  │
│   │    ├── 读取 zkp-config.json                                     │  │
│   │    ├── 验证配置完整性                                            │  │
│   │    └── 应用默认参数                                              │  │
│   └────────────────┬────────────────────────────────────────────────┘  │
│                    ↓                                                    │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │ 2. 后端初始化                                                    │  │
│   │    ├── 加载 WASM/Native 模块                                    │  │
│   │    ├── 检测硬件能力 (GPU/SIMD)                                  │  │
│   │    └── 初始化并行线程池                                          │  │
│   └────────────────┬────────────────────────────────────────────────┘  │
│                    ↓                                                    │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │ 3. 电路获取/编译                                                 │  │
│   │    ├── 检查本地缓存电路                                          │  │
│   │    ├── 无缓存: 从注册表下载或本地编译                             │  │
│   │    └── 验证电路哈希                                              │  │
│   └────────────────┬────────────────────────────────────────────────┘  │
│                    ↓                                                    │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │ 4. 密钥获取                                                      │  │
│   │    ├── 检查本地密钥                                              │  │
│   │    ├── 无密钥: 从 ECHO 密钥服务下载                               │  │
│   │    ├── 验证密钥完整性                                            │  │
│   │    └── 解密到安全内存                                            │  │
│   └────────────────┬────────────────────────────────────────────────┘  │
│                    ↓                                                    │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │ 5. 验证设置                                                      │  │
│   │    ├── 执行测试证明                                              │  │
│   │    ├── 验证证明能通过验证                                         │  │
│   │    └── 确认链上验证合约兼容                                       │  │
│   └────────────────┬────────────────────────────────────────────────┘  │
│                    ↓                                                    │
│   ┌─────────────┐                                                       │
│   │  初始化完成  │                                                       │
│   │  (Ready)    │                                                       │
│   └─────────────┘                                                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 生成使用证明流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      生成使用证明 (PoU) 流程                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   沙箱环境                           ZKP Generator                      │
│   ┌─────────────┐                   ┌─────────────┐                    │
│   │  使用事件   │                   │  等待输入   │                    │
│   │  (触发)    │ ─────────────────→│              │                    │
│   └──────┬──────┘                   └─────────────┘                    │
│          ↓                                                              │
│   ┌─────────────┐                                                       │
│   │  收集数据   │  ← 使用内容哈希、时间戳、用户ID、资产ID              │
│   │             │  ← 获取 Merkle 证明 (证明用户在白名单)                │
│   │             │  ← 获取沙箱授权签名                                  │
│   └──────┬──────┘                                                       │
│          ↓                                                              │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │  构造证明输入                                                    │  │
│   │  Private: {user_id, asset_id, timestamp, usage_hash, nonce,     │  │
│   │            merkle_path, merkle_indices, auth_sig}               │  │
│   │  Public:  {asset_id_pub, timestamp_range, nullifier,            │  │
│   │            merkle_root, asset_owner_pubkey}                     │  │
│   └────────────────┬────────────────────────────────────────────────┘  │
│                    ↓                                                    │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │  生成见证 (Witness)                                              │  │
│   │  ├── 将输入映射到电路信号                                        │  │
│   │  ├── 计算中间约束变量                                            │  │
│   │  └── 验证约束满足                                                │  │
│   └────────────────┬────────────────────────────────────────────────┘  │
│                    ↓                                                    │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │  生成证明                                                        │  │
│   │  ├── 加载证明密钥                                                │  │
│   │  ├── 执行 MSM (多标量乘法)                                       │  │
│   │  ├── 执行 FFT (快速傅里叶变换)                                   │  │
│   │  └── 输出证明 (a, b, c)                                          │  │
│   └────────────────┬────────────────────────────────────────────────┘  │
│                    ↓                                                    │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │  格式化输出                                                      │  │
│   │  ├── 序列化证明                                                  │  │
│   │  ├── 附加公开输入                                                │  │
│   │  └── 生成链上提交格式                                            │  │
│   └────────────────┬────────────────────────────────────────────────┘  │
│                    ↓                                                    │
│   ┌─────────────┐                   ┌─────────────┐                    │
│   │  返回证明   │←──────────────────│  完成       │                    │
│   │             │                   │             │                    │
│   └──────┬──────┘                   └─────────────┘                    │
│          ↓                                                              │
│   ┌─────────────┐                                                       │
│   │  提交链上   │  → 调用 ECHO 合约 verifyUsageProof()                 │
│   │             │  → 触发收益分配                                      │
│   └─────────────┘                                                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.3 批量证明流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      批量证明聚合流程                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   场景：某沙箱在1小时内产生了 1000 次使用，需要批量提交证明              │
│                                                                         │
│   方式 1: 并行独立证明 (高吞吐量，高验证成本)                            │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐         ┌─────────┐            │
│   │ Proof 1 │ │ Proof 2 │ │ Proof 3 │   ...     │ Proof N │            │
│   └────┬────┘ └────┬────┘ └────┬────┘         └────┬────┘            │
│        └───────────┴───────────┴───────────────────┘                    │
│                        ↓ 并行生成 (N workers)                           │
│        ┌───────────────────────────────────────────┐                    │
│        │          批量提交到链上                    │                    │
│        │  for each proof: verifyUsageProof()      │                    │
│        │  Gas: N * 250K ≈ 250M gas (1000 proofs)   │                    │
│        └───────────────────────────────────────────┘                    │
│                                                                         │
│   方式 2: 递归聚合 (ZK-Aggregation)                                      │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐         ┌─────────┐            │
│   │ Proof 1 │ │ Proof 2 │ │ Proof 3 │   ...     │ Proof N │            │
│   └────┬────┘ └────┬────┘ └────┬────┘         └────┬────┘            │
│        └───────────┴───────────┴───────────────────┘                    │
│                        ↓ 并行生成                                       │
│        ┌───────────────────────────────────────────┐                    │
│        │         层级聚合 (递归 SNARKs)           │                    │
│        │  Level 1: 聚合 10 个 → 1 个聚合证明       │                    │
│        │  Level 2: 聚合 10 个 L1 → 1 个 L2       │                    │
│        │  ... 直到一个最终证明                      │                    │
│        └───────────────────┬───────────────────────┘                    │
│                            ↓                                            │
│        ┌───────────────────────────────────────────┐                    │
│        │         单次链上验证                       │                    │
│        │  verifyAggregatedProof()                  │                    │
│        │  Gas: ~300K (常数成本，与 N 无关)          │                    │
│        │  节省: 99.9%                              │                    │
│        └───────────────────────────────────────────┘                    │
│                                                                         │
│   方式 3: Merkle 树批量验证 (折中方案)                                    │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐         ┌─────────┐            │
│   │ Proof 1 │ │ Proof 2 │ │ Proof 3 │   ...     │ Proof N │            │
│   └────┬────┘ └────┬────┘ └────┬────┘         └────┬────┘            │
│        │           │           │                   │                    │
│        └───────────┴───────────┴───────────────────┘                    │
│                        ↓                                                │
│              ┌─────────────────┐                                        │
│              │   Merkle 树根    │ ← 所有证明哈希的 Merkle 根              │
│              │   Root = H(...) │                                        │
│              └────────┬────────┘                                        │
│                       ↓                                                 │
│              ┌─────────────────┐                                        │
│              │  链上批量验证    │                                        │
│              │  verifyBatch(root,│                                        │
│              │    indices,       │                                        │
│              │    proofs)        │                                        │
│              │  Gas: ~50K + 5K*N │                                        │
│              └─────────────────┘                                        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.4 验证流程

```solidity
// VerificationFlow.sol
pragma solidity ^0.8.19;

contract ZKPVerificationFlow {
    
    enum VerificationStatus {
        Pending,
        Verified,
        Rejected,
        Challenged
    }
    
    struct ProofRecord {
        bytes32 proofHash;
        ProofType proofType;
        bytes32 nullifier;
        bytes32 assetId;
        uint256 timestamp;
        VerificationStatus status;
        address submitter;
        uint256 rewardAmount;
    }
    
    // 证明记录
    mapping(bytes32 => ProofRecord) public proofs;
    
    // 已使用的 nullifiers
    mapping(bytes32 => bool) public spentNullifiers;
    
    // 验证器合约
    mapping(ProofType => address) public verifiers;
    
    event ProofSubmitted(
        bytes32 indexed proofHash,
        bytes32 indexed assetId,
        ProofType proofType
    );
    
    event ProofVerified(
        bytes32 indexed proofHash,
        uint256 rewardAmount
    );
    
    /// @notice 提交并验证证明
    function submitAndVerify(
        bytes calldata proof,
        bytes32 assetId,
        ProofType proofType,
        uint256[] calldata publicInputs
    ) external returns (bool) {
        // 1. 计算证明哈希
        bytes32 proofHash = keccak256(proof);
        
        // 2. 检查是否已提交
        require(proofs[proofHash].timestamp == 0, "Proof already submitted");
        
        // 3. 提取 nullifier (取决于证明类型)
        bytes32 nullifier = extractNullifier(proof, proofType);
        require(!spentNullifiers[nullifier], "Nullifier already spent");
        
        // 4. 调用对应验证器
        address verifier = verifiers[proofType];
        require(verifier != address(0), "Verifier not registered");
        
        bool isValid = IZKPVerifier(verifier).verify(
            proof,
            publicInputs
        );
        
        require(isValid, "Proof verification failed");
        
        // 5. 记录证明
        proofs[proofHash] = ProofRecord({
            proofHash: proofHash,
            proofType: proofType,
            nullifier: nullifier,
            assetId: assetId,
            timestamp: block.timestamp,
            status: VerificationStatus.Verified,
            submitter: msg.sender,
            rewardAmount: 0
        });
        
        // 6. 标记 nullifier
        spentNullifiers[nullifier] = true;
        
        // 7. 触发收益分配
        uint256 reward = IRewardsDistributor(rewardsContract)
            .distribute(assetId, proofType, publicInputs);
        
        proofs[proofHash].rewardAmount = reward;
        
        emit ProofSubmitted(proofHash, assetId, proofType);
        emit ProofVerified(proofHash, reward);
        
        return true;
    }
    
    /// @notice 挑战证明 (争议解决)
    function challengeProof(
        bytes32 proofHash,
        bytes calldata challengeEvidence
    ) external {
        ProofRecord storage record = proofs[proofHash];
        require(record.timestamp != 0, "Proof not found");
        require(record.status == VerificationStatus.Verified, "Already processed");
        
        // 进入挑战期
        record.status = VerificationStatus.Challenged;
        
        // 启动争议仲裁流程
        IArbitration(arbitrationContract).initiateChallenge(
            proofHash,
            challengeEvidence
        );
    }
    
    /// @notice 仲裁结果回调
    function arbitrationCallback(
        bytes32 proofHash,
        bool upheld
    ) external onlyArbitration {
        ProofRecord storage record = proofs[proofHash];
        
        if (upheld) {
            // 挑战失败，证明有效
            record.status = VerificationStatus.Verified;
        } else {
            // 挑战成功，证明无效
            record.status = VerificationStatus.Rejected;
            // 惩罚提交者
            // 恢复 nullifier
            spentNullifiers[record.nullifier] = false;
        }
    }
    
    function extractNullifier(
        bytes calldata proof,
        ProofType proofType
    ) internal pure returns (bytes32) {
        // 根据证明类型和格式提取 nullifier
        // 不同证明类型的 nullifier 位置可能不同
        if (proofType == ProofType.Usage) {
            return bytes32(proof[64:96]);
        } else if (proofType == ProofType.Holding) {
            return bytes32(proof[96:128]);
        }
        // ...
        return bytes32(0);
    }
}
```

---

## 8. 性能指标

### 8.1 证明生成时间

| 证明类型 | 电路规模 (约束数) | 标准设备* | 优化设备** | GPU 加速*** |
|----------|------------------|-----------|------------|-------------|
| PoU (使用证明) | 50K | 500ms | 200ms | 80ms |
| PoH (持有证明, 10 tokens) | 100K | 1.2s | 400ms | 150ms |
| PoD (衍生证明, 20 sources) | 500K | 5s | 1.5s | 600ms |
| PoR (收益证明, 100 txs) | 1M | 10s | 3s | 1.2s |
| 批量聚合 (100 proofs) | 递归 | 15s | 5s | 2s |

\* 标准设备: AMD Ryzen 7 5800X, 32GB RAM
\** 优化设备: AMD Ryzen 9 7950X, 64GB DDR5
\*** GPU: NVIDIA RTX 4090

### 8.2 验证成本 (链上 Gas)

| 证明类型 | 单次验证 | 批量验证 (10个) | 批量验证 (100个) | 递归聚合验证 |
|----------|---------|----------------|-----------------|-------------|
| PoU | 250K | 1.8M | 15M | 300K |
| PoH | 300K | 2.1M | 18M | 350K |
| PoD | 400K | 2.8M | 25M | 450K |
| PoR | 500K | 3.5M | 30M | 550K |

注：Gas 估算基于 Ethereum L1，使用 Layer 2 可降低成本 10-100x

### 8.3 存储需求

| 资源类型 | 大小 | 说明 |
|----------|------|------|
| 电路文件 (R1CS) | 5-50MB | 取决于电路复杂度 |
| 证明密钥 (Proving Key) | 10-200MB | 生成证明必需 |
| 验证密钥 (Verifying Key) | 1-5KB | 链上部署 |
| 单个证明 (Groth16) | 192 bytes | 极小的链上提交 |
| 单个证明 (STARKs) | 50-100KB | 适合审计场景 |
| 见证文件 (Witness) | 10-500MB | 临时生成，可删除 |

### 8.4 延迟指标

| 场景 | 端到端延迟 | 瓶颈 |
|------|-----------|------|
| 单次使用证明 (本地) | < 1s | 证明生成 |
| 单次使用证明 (提交+确认) | 3-15s | 区块链确认 |
| 批量 100 证明 (聚合) | 5-20s | 递归证明生成 |
| 批量 100 证明 (提交) | 3-15s | 单次链上验证 |

---

## 9. 功能清单

### 9.1 核心功能矩阵

| 功能类别 | 功能项 | 优先级 | 状态 | 版本 |
|----------|--------|--------|------|------|
| **证明类型** | | | | |
| | 使用证明 (PoU) | P0 | 设计中 | v1.0 |
| | 持有证明 (PoH) | P0 | 设计中 | v1.0 |
| | 衍生证明 (PoD) | P0 | 设计中 | v1.0 |
| | 收益证明 (PoR) | P1 | 设计中 | v1.1 |
| | 批量聚合证明 | P1 | 设计中 | v1.1 |
| **ZK 后端** | | | | |
| | Groth16 (arkworks) | P0 | 设计中 | v1.0 |
| | Groth16 (snarkjs) | P0 | 设计中 | v1.0 |
| | STARKs (Stone) | P1 | 设计中 | v1.1 |
| | Bulletproofs | P2 | 规划中 | v1.2 |
| **语言支持** | | | | |
| | JavaScript/TypeScript | P0 | 设计中 | v1.0 |
| | Python | P0 | 设计中 | v1.0 |
| | Rust | P0 | 设计中 | v1.0 |
| | Go | P1 | 设计中 | v1.1 |
| | Java | P2 | 规划中 | v1.2 |
| **CLI 工具** | | | | |
| | 证明生成命令 | P0 | 设计中 | v1.0 |
| | 验证命令 | P0 | 设计中 | v1.0 |
| | 批量处理 | P1 | 设计中 | v1.0 |
| | 电路可视化 | P2 | 规划中 | v1.1 |
| | 调试工具 | P2 | 规划中 | v1.1 |
| **开发者体验** | | | | |
| | 配置模板 | P0 | 设计中 | v1.0 |
| | 预设电路库 | P0 | 设计中 | v1.0 |
| | 类型安全 API | P0 | 设计中 | v1.0 |
| | 自动完成 | P1 | 规划中 | v1.1 |
| | 交互式向导 | P2 | 规划中 | v1.2 |
| **性能优化** | | | | |
| | 证明缓存 | P0 | 设计中 | v1.0 |
| | 并行生成 | P0 | 设计中 | v1.0 |
| | WASM 支持 | P0 | 设计中 | v1.0 |
| | GPU 加速 | P1 | 规划中 | v1.1 |
| | 递归聚合 | P1 | 规划中 | v1.1 |
| **安全** | | | | |
| | 可信设置集成 | P0 | 设计中 | v1.0 |
| | 密钥管理 | P0 | 设计中 | v1.0 |
| | Nullifier 管理 | P0 | 设计中 | v1.0 |
| | 可链接性控制 | P1 | 设计中 | v1.0 |
| | 形式化验证 | P2 | 规划中 | v1.2 |

### 9.2 电路模板库

| 模板名称 | 用途 | 参数化选项 | 状态 |
|----------|------|------------|------|
| pou-standard | 标准使用证明 | merkleDepth, timeWindow | 设计中 |
| pou-high-privacy | 高隐私使用证明 | 增加混淆层数 | 规划中 |
| poh-basic | 基本持有证明 | maxTokens | 设计中 |
| poh-tiered | 分级持有证明 | tiers[], thresholds[] | 规划中 |
| pod-simple | 简单衍生证明 | maxSources: 10 | 设计中 |
| pod-complex | 复杂衍生证明 | maxSources: 50, maxSteps: 500 | 设计中 |
| por-monthly | 月度收益证明 | maxTx: 1000 | 规划中 |
| por-quarterly | 季度收益证明 | maxTx: 10000 | 规划中 |

### 9.3 集成接口

| 接口类型 | 协议/格式 | 用途 | 状态 |
|----------|-----------|------|------|
| ECHO 沙箱 API | gRPC | 沙箱调用证明生成 | 设计中 |
| ECHO 链上合约 | Solidity | 链上验证 | 设计中 |
| REST API | HTTP/JSON | 通用集成 | 设计中 |
| WebSocket | Real-time | 流式证明 | 规划中 |

---

## 10. 开发计划

### 10.1 工作量估算

| 模块 | 人天 | 主要工作 |
|------|------|----------|
| **核心引擎** | | |
| 电路编译器集成 | 15 | Circom/Noir/Gnark 集成 |
| 证明生成引擎 | 20 | WASM + Native 双后端 |
| 见证生成器 | 10 | 输入处理、约束满足 |
| 密钥管理系统 | 12 | 安全存储、密钥派生 |
| **证明类型** | | |
| PoU 电路设计与实现 | 15 | 使用证明完整实现 |
| PoH 电路设计与实现 | 12 | 持有证明完整实现 |
| PoD 电路设计与实现 | 18 | 衍生证明完整实现 |
| PoR 电路设计与实现 | 15 | 收益证明完整实现 |
| **SDK 开发** | | |
| JavaScript/TypeScript SDK | 15 | 完整 JS API |
| Python SDK | 12 | 完整 Python API |
| Rust SDK | 15 | 完整 Rust API |
| Go SDK | 12 | 完整 Go API |
| **CLI 工具** | | |
| CLI 核心框架 | 8 | 命令解析、配置管理 |
| 证明命令 | 8 | prove/verify/batch |
| 调试工具 | 10 | visualize/analyze/profile |
| **智能合约** | | |
| 验证合约 | 10 | Groth16Verifier 等 |
| 批量验证优化 | 8 | 聚合验证 |
| 集成测试 | 8 | 完整测试套件 |
| **基础设施** | | |
| 可信设置基础设施 | 15 | 仪式管理、密钥分发 |
| 性能优化 | 12 | GPU、并行、缓存 |
| 文档与示例 | 10 | API 文档、教程 |
| **测试与审计** | | |
| 单元测试 | 10 | 全覆盖测试 |
| 集成测试 | 10 | 端到端测试 |
| 安全审计 | 20 | 第三方审计 |
| **总计** | **312 人天** | 约 15 人月 |

### 10.2 里程碑规划

| 里程碑 | 时间 | 交付物 | 关键特性 |
|--------|------|--------|----------|
| **M1: 核心原型** | 第 2 月末 | 技术原型 | • PoU 电路原型<br>• JS SDK 原型<br>• 本地验证 |
| **M2: MVP** | 第 4 月末 | 最小可用产品 | • PoU + PoH 完整实现<br>• JS + Python SDK<br>• 基础 CLI<br>• 测试网验证合约 |
| **M3: 功能完整** | 第 6 月末 | v1.0 | • 四种证明类型<br>• 四语言 SDK<br>• 完整 CLI<br>• 主网验证合约 |
| **M4: 优化阶段** | 第 8 月末 | v1.1 | • 批量聚合<br>• GPU 加速<br>• STARKs 后端<br>• 性能优化 |
| **M5: 生产就绪** | 第 10 月末 | v1.2 | • 安全审计完成<br>• 形式化验证<br>• 完整文档<br>• 开发者工具 |

### 10.3 团队配置建议

| 角色 | 人数 | 职责 |
|------|------|------|
| ZK 研究员 | 1 | 电路设计、方案选择 |
| ZK 工程师 | 2 | 电路实现、证明优化 |
| 后端工程师 | 2 | 多语言 SDK、CLI |
| 智能合约工程师 | 1 | 链上验证合约 |
| DevOps | 1 | 可信设置基础设施 |
| 技术文档 | 1 | 文档、示例、教程 |
| **总计** | **8 人** | |

---

## 11. 附录

### 11.1 参考资料

| 资源 | 链接 | 用途 |
|------|------|------|
| Circom Documentation | https://docs.circom.io | 电路设计参考 |
| Noir Documentation | https://noir-lang.org | 替代电路语言 |
| arkworks | https://arkworks.rs | Rust ZK 库 |
| snarkjs | https://github.com/iden3/snarkjs | JS 证明系统 |
| Groth16 Paper | https://eprint.iacr.org/2016/260.pdf | 理论基础 |
| ZK Hack | https://zkhack.dev | 学习资源 |

### 11.2 术语表

| 术语 | 解释 |
|------|------|
| R1CS | Rank-1 Constraint System，秩-1 约束系统 |
| CRS | Common Reference String，公共参考字符串 |
| SRS | Structured Reference String，结构化参考字符串 |
| MSM | Multi-Scalar Multiplication，多标量乘法 |
| FFT | Fast Fourier Transform，快速傅里叶变换 |
| Nullifier | 唯一标识符，用于防止证明重用 |
| Witness | 见证，满足电路约束的完整输入 |
| MPC | Multi-Party Computation，多方安全计算 |

### 11.3 设计参考

本设计参考了以下项目和设计理念：

- **Tornado Cash**: Merkle 树隐私设计、Nullifier 机制
- **zkSync**: 批量证明聚合、递归证明架构
- **Semaphore**: 零知识组成员证明
- **Noir**: 开发者友好的 ZK 编程语言设计
- **circomlib**: 标准电路组件库

---

**文档版本**: v1.0  
**最后更新**: 2026-04-19  
**设计状态**: 详细设计阶段
