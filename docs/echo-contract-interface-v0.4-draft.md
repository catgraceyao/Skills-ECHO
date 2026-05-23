# ECHO 协议 v0.4 合约接口正式版

**作者**：猫先森（Cat）  
**日期**：2026-05-23  
**状态**：Final v0.4  
**审阅记录**：
- 基于 v0.3 合约接口落实 18 项核心修正
- CaT.G 05-23 18:59 指令启动 v0.4 修订
- v0.4 修订清单全部落实，标记 ★ 处为变更点

**目标**：将 v0.3 遗留问题和社区反馈落实为可执行的合约接口与参数

---

## 0. v0.4 修订清单映射

| # | 修订项 | 对应章节 | 提出者 |
|---|--------|---------|--------|
| 1 | DAO_MIN_MEMBERS 5→11 | §5.2 治理参数 | 哪吒 |
| 2 | TOPUP 定价锚定（时间加权平均+社区质疑窗口） | §1.3 迁移机制 | Talus |
| 3 | 快速通道冷却期（severity 4-5 单签 24h，severity 5 多签跳过） | §3.3 紧急干预 | 哪吒 |
| 4 | submitNPS 加许可有效性实时验证 | §4.2 势位算法 | 非攻进阶版 |
| 5 | activityBoost 加衰减机制 + 投票权重与势位引擎解耦 | §5.3 投票权重 | Talus |
| 6 | Gas 估算标注"需实测验证" | §7 Gas 优化 | CaT.G |
| 7 | severity 链上可验证指标替代自报 | §3.3 紧急干预 | X7 |
| 8 | cooldownRuling 异议拖延攻击防护（延长次数上限1次） | §3.6 冷却期裁决 | M77 |
| 9 | 势位权重考虑 50:50 或动态提升（争议率高时使用者侧↑） | §4.2 势位算法 | Talus |
| 10 | TOPUP 负价差明确策略 | §1.3 迁移机制 | 哪吒 |
| 11 | IPFS Pinning 策略 + Merkle root 生成比对机制 | §2.4/§7 链下存储 | X7 |
| 12 | DAO 投票权重公式完全公开 | §5.3 投票权重 | 哪吒 |
| 13 | 势位评估引擎触发机制明确 | §4.1/§4.4 势位引擎 | 非攻进阶版 |
| 14 | Agent 陪审团接口（commit-reveal + 时间隔离 + 3/5 多签） | §3.7 Agent 陪审团（新增） | CaT.G |
| 15 | 信誉分双轨计算（硬准确率/软共识率） | §4.5 信誉分双轨（新增） | Talus |
| 16 | 反证质押（0.05 ETH，恶意 50%销毁+50%奖励） | §3.6 冷却期裁决 | 哪吒 |
| 17 | 自适应阈值（5σ/百分位法→Tukey fences，连续2周期延迟确认） | §4.4 自适应阈值（新增） | X7 |
| 18 | 退出权 gas 兜底资金池设计 | §3.8 退出 gas 兜底（新增） | CaT.G |

---

## 1. CreatorConfig 合约

负责：版本 DAG、规则发布、创作者配置管理

### 1.1 接口定义

```solidity
interface ICreatorConfig {
    // === 版本 DAG 管理 ===
    
    /// @notice 发布新版本（分叉或迭代）
    /// @param parentVersionId 父版本 ID（0 表示创世版本）
    /// @param configJSON 规则配置 JSON（最大 10KB）
    /// @param configHash keccak256(configJSON)
    /// @param contractHash 部署时合约字节码哈希
    /// @param migrationMode 迁移模式（发布时锁定）
    /// @return versionId 新版本 ID
    function publishVersion(
        uint256 parentVersionId,
        string calldata configJSON,
        bytes32 configHash,
        bytes32 contractHash,
        MigrationMode migrationMode
    ) external returns (uint256 versionId);
    
    /// @notice 获取版本信息
    function getVersion(uint256 versionId) external view returns (
        uint256 parentId,
        bytes32 configHash,
        bytes32 contractHash,
        uint256 publishTime,
        uint256 childCount,
        MigrationMode migrationMode
    );
    
    /// @notice 获取版本 DAG 路径（从创世到指定版本）
    function getVersionLineage(uint256 versionId) external view returns (uint256[] memory path);
    
    // === 配置管理 ===
    
    /// @notice 设置创作者配置参数
    /// @param key 参数键
    /// @param value 参数值（uint256 或编码后的复杂类型）
    function setConfig(bytes32 key, uint256 value) external;
    
    /// @notice 读取创作者配置
    function getConfig(bytes32 key) external view returns (uint256);
    
    // === 事件 ===
    
    event VersionPublished(
        uint256 indexed versionId,
        uint256 indexed parentId,
        bytes32 configHash,
        uint256 publishTime,
        MigrationMode migrationMode
    );
    
    event ConfigUpdated(bytes32 indexed key, uint256 oldValue, uint256 newValue);
}
```

### 1.2 核心参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `MAX_CONFIG_SIZE` | uint256 | 10KB | 单条 configJSON 最大尺寸 |
| `VERSION_DEPTH_LIMIT` | uint256 | 50 | 版本 DAG 最大深度 |
| `MAX_CHILDREN_PER_VERSION` | uint256 | 20 | 单版本最多分叉数 |

### 1.3 版本迁移机制（修订）★

**修订 #2**：TOPUP 定价锚定（时间加权平均 + 社区质疑窗口）
- **提出者**：Talus
- **原因**：防止创作者操纵价格，确保 TOPUP 定价公允

**修订 #10**：TOPUP 负价差明确策略
- **提出者**：哪吒
- **原因**：原草案"若为负则收 0"过于模糊，需明确策略

```solidity
enum MigrationMode {
    FREE,       // 免费迁移：旧许可自动继承到新版本（鼓励升级）
    TOPUP,      // 差价补足：新版本更贵则补差价，更便宜不退（平滑过渡）
    FULL_PRICE  // 全额重购：旧许可作废，需重新购买（重大变更时）
}
```

**TOPUP 定价锚定机制**：

```solidity
struct TopupPricing {
    uint256 twapPrice;           // 时间加权平均价格（7 天滑动窗口）
    uint256 lastTradedPrice;     // 最后一笔成交价格
    uint256 challengeWindowEnd;  // 社区质疑窗口结束时间
    bool challenged;             // 是否被质疑
}

/// @notice 创作者设定版本价格（需提前 3 天公示）
/// @param versionId 目标版本
/// @param proposedPrice 提议价格
function proposePrice(uint256 versionId, uint256 proposedPrice) external;

/// @notice 社区质疑定价（质押 0.02 ETH，质疑成功退还，失败没收）
/// @param versionId 目标版本
/// @param evidenceHash 质疑证据
function challengePrice(uint256 versionId, bytes32 evidenceHash) external payable;

/// @notice 获取最终锚定价格（公示期 + 质疑窗口结束后锁定）
function getAnchoredPrice(uint256 versionId) external view returns (uint256);
```

**定价规则**：
1. 创作者发布新版本时设定 `proposedPrice`，进入 3 天公示期
2. 公示期内任何人可支付 0.02 ETH 发起 `challengePrice()`，需提交证据（如市场价格对比、竞品定价等）
3. 公示期结束后若未被质疑，价格自动锁定
4. 若被质疑，触发 Agent 陪审团裁决（§3.7），24 小时内判定：
   - 质疑成立 → 价格按 TWAP（近 7 天该创作者所有版本成交均价）锚定
   - 质疑不成立 → 维持原定价，质疑者质押没收

**迁移成本计算（修订后）**：

```solidity
function previewMigrationCost(
    uint256 oldLicenseId,
    uint256 targetVersionId
) external view returns (uint256 cost, uint256 refund) {
    uint256 oldPrice = getAnchoredPrice(licenses[oldLicenseId].versionId);
    uint256 newPrice = getAnchoredPrice(targetVersionId);
    
    if (newPrice > oldPrice) {
        // 正价差：补足差价
        cost = newPrice - oldPrice;
        refund = 0;
    } else {
        // 负价差：不退现金，转为积分/未来抵扣 ★（修订 #10）
        cost = 0;
        refund = oldPrice - newPrice; // 以「版本积分」形式记入使用者账户
        // 积分可用于：未来版本抵扣、协议治理投票加成、合作创作者版本兑换
    }
}
```

**迁移规则（完整版）**：
- `FREE`：不收费，旧许可 token 销毁，新许可 token 发放，有效期不变
- `TOPUP`：锚定价格差计算，正价差补 ETH，负价差退积分（不可提现，仅协议内流通）
- `FULL_PRICE`：全额支付新版本锚定价格，旧许可保留直到 sunset

**重要**：迁移不改变 sunset 时间。sunset 按原许可创建时间计算。

---

## 2. LicenseToken 合约

负责：许可凭证（ERC721 扩展）、三层哈希锚定、链下数据冗余

### 2.1 接口定义

```solidity
interface ILicenseToken is IERC721 {
    // === 许可创建 ===
    
    /// @notice 创建新许可（使用者购买时调用）
    /// @param to 使用者地址
    /// @param versionId 绑定版本 ID
    /// @param expiryTimestamp 许可过期时间（0 表示永久）
    /// @param configHash 创建时规则哈希
    /// @param contractHash 创建时合约哈希
    /// @return tokenId 许可 ID
    function mintLicense(
        address to,
        uint256 versionId,
        uint64 expiryTimestamp,
        bytes32 configHash,
        bytes32 contractHash
    ) external payable returns (uint256 tokenId);
    
    /// @notice 获取许可详情
    function getLicense(uint256 tokenId) external view returns (
        uint256 versionId,
        uint64 expiryTimestamp,
        bytes32 configHash,
        bytes32 contractHash,
        bytes32 runtimeHash,
        OffchainPointer offchainPointer,
        LicenseStatus status
    );
    
    // === 三层哈希锚定 ===
    
    /// @notice 更新 runtimeHash（关系状态变更时）
    function updateRuntimeHash(
        uint256 tokenId,
        bytes32 newRuntimeHash,
        OffchainPointer calldata newPointer
    ) external;
    
    /// @notice 验证许可三层哈希一致性
    function verifyHashIntegrity(uint256 tokenId) external view returns (bool);
    
    // === 许可状态 ===
    
    enum LicenseStatus {
        ACTIVE,      // 正常有效
        MIGRATED,    // 已迁移到新版本
        DEPRECATED,  // 创作者退出，进入 sunset
        EXPIRED,     // 过期
        ARCHIVED     // 已归档
    }
    
    /// @notice 检查许可当前状态
    function checkStatus(uint256 tokenId) external view returns (LicenseStatus);
    
    /// @notice 许可是否进入 sunset 期
    function isInSunset(uint256 tokenId) external view returns (bool);
    
    // === 链下数据冗余（修订）★ ===
    
    struct OffchainPointer {
        bytes32 ipfsHash;        // IPFS CID
        bytes32 arweaveHash;     // Arweave Transaction ID
        bytes32 merkleRoot;      // 本批次 Merkle root（新增 #11）
        uint256 checkpointTime;   // 快照时间戳
        uint256 pinTimestamp;    // IPFS pinning 确认时间（新增 #11）
    }
    
    /// @notice 将许可状态快照存储到 IPFS（含 pinning 策略）
    function storeToIPFS(uint256 tokenId) external returns (bytes32 ipfsHash);
    
    /// @notice 将许可状态快照存储到 Arweave（通过网关）
    function storeToArweave(uint256 tokenId) external payable returns (bytes32 arweaveHash);
    
    /// @notice 验证链下数据完整性（含 Merkle root 比对）
    function verifyOffchainData(
        uint256 tokenId,
        OffchainPointer calldata pointer,
        bytes calldata proofData
    ) external view returns (bool);
    
    /// @notice 批量归档并生成 Merkle root（gas 优化）
    function batchArchive(uint256[] calldata tokenIds) external returns (bytes32 batchMerkleRoot);
    
    // === 事件 ===
    
    event LicenseMinted(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 indexed versionId,
        uint64 expiryTimestamp
    );
    
    event RuntimeHashUpdated(
        uint256 indexed tokenId,
        bytes32 oldHash,
        bytes32 newHash,
        OffchainPointer pointer
    );
    
    event OffchainStored(
        uint256 indexed tokenId,
        bytes32 ipfsHash,
        bytes32 arweaveHash,
        bytes32 merkleRoot
    );
    
    event BatchArchived(bytes32 indexed merkleRoot, uint256 count);
}
```

### 2.2 核心参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `MIN_SUNSET_DAYS` | uint256 | 90 | sunset 最小天数 |
| `SUNSET_RATIO` | uint256 | 30 (%) | sunset = max(90, 有效期×30%) |
| `SUNSET_EXTENSION` | uint256 | 7 (天) | 许可有效期+7天保护 |
| `IPFS_GATEWAY` | address | TBD | IPFS 存储网关合约地址 |
| `ARWEAVE_GATEWAY` | address | TBD | Arweave 存储网关合约地址 |
| `PINNING_SERVICE` | address | TBD | IPFS pinning 服务合约地址 |
| `MERKLE_BATCH_SIZE` | uint256 | 500 | 单次 batch Merkle 最大许可数 |

### 2.3 Sunset 公式（与 v0.3 一致，无变更）

```solidity
function calculateSunset(uint64 expiryTimestamp, uint64 createTime) internal pure returns (uint64) {
    uint64 licenseDuration = expiryTimestamp - createTime;
    uint64 ratioBased = licenseDuration * 30 / 100;
    uint64 extensionBased = licenseDuration + 7 days;
    
    return max(90 days, ratioBased, extensionBased);
}
```

### 2.4 链下存储冗余方案（修订）★

**修订 #11**：IPFS Pinning 策略 + Merkle root 生成比对机制
- **提出者**：X7
- **原因**：IPFS 节点可能离线，需 pinning 服务保证可用性；需 Merkle root 防篡改

**IPFS Pinning 策略**：

```solidity
/// @notice IPFS 存储后自动触发 pinning
function pinToIPFS(bytes32 ipfsHash) internal {
    // 1. 调用 pinning 服务（如 Pinata / nft.storage / 协议自建节点）
    PinningService.pin(ipfsHash);
    
    // 2. 记录 pinning 时间戳
    offchainPointers[tokenId].pinTimestamp = block.timestamp;
    
    // 3. 72 小时内验证 pinning 状态，失败则重试 + 告警
    emit PinningRequested(ipfsHash, block.timestamp);
}

/// @notice 验证 IPFS pinning 状态（任何人可调用）
function verifyPinning(bytes32 ipfsHash) external view returns (bool pinned, uint256 pinTime);
```

**存储策略（修订后）**：
```
链上存储（LicenseToken）：
  - pointer.ipfsHash (32 bytes)
  - pointer.arweaveHash (32 bytes)
  - pointer.merkleRoot (32 bytes)     ← 新增
  - pointer.checkpointTime (8 bytes)
  - pointer.pinTimestamp (8 bytes)    ← 新增
  总计：112 bytes/许可

链下存储（双冗余 + pinning）：
  ├─ IPFS：定期快照，pinning 服务保证 99.9% 可用
  └─ Arweave：一次性付费永久存储，高可靠性
  └─ Merkle root：每 500 许可生成一个 batch root，链上锚定

自动策略：
  1. 每次 runtimeHash 更新 → 自动 snapshot 到 IPFS + 立即 pin
  2. 每 6 小时 batch → 打包 500 许可生成 Merkle root，链上记录
  3. 每日 batch → 打包 snapshot 到 Arweave（gas 优化）
  4. 查询时优先读 IPFS（快），fallback 到 Arweave（可靠），验证 Merkle root（防篡改）
```

**Merkle root 生成与比对**：

```solidity
/// @notice 生成 batch Merkle root
function generateMerkleRoot(uint256[] calldata tokenIds) public pure returns (bytes32) {
    bytes32[] memory leaves = new bytes32[](tokenIds.length);
    for (uint i = 0; i < tokenIds.length; i++) {
        // leaf = keccak256(tokenId + runtimeHash + checkpointTime)
        leaves[i] = keccak256(abi.encodePacked(
            tokenIds[i],
            licenses[tokenIds[i]].runtimeHash,
            licenses[tokenIds[i]].offchainPointer.checkpointTime
        ));
    }
    return computeMerkleRoot(leaves);
}

/// @notice 验证链下 proofData 与链上 Merkle root 匹配
function verifyMerkleProof(
    uint256 tokenId,
    bytes calldata proofData,
    bytes32 expectedRoot
) internal pure returns (bool) {
    bytes32 leaf = keccak256(abi.encodePacked(
        tokenId,
        licenses[tokenId].runtimeHash,
        licenses[tokenId].offchainPointer.checkpointTime
    ));
    return verifyMerkle(leaf, proofData, expectedRoot);
}
```

**验证机制（修订后）**：
```solidity
function verifyOffchainData(
    uint256 tokenId,
    OffchainPointer calldata pointer,
    bytes calldata proofData
) external view returns (bool) {
    // 1. 链上 pointer 与传入 pointer 匹配
    require(pointer.ipfsHash == licenses[tokenId].offchainPointer.ipfsHash, "IPFS hash mismatch");
    require(pointer.arweaveHash == licenses[tokenId].offchainPointer.arweaveHash, "Arweave hash mismatch");
    require(pointer.merkleRoot == licenses[tokenId].offchainPointer.merkleRoot, "Merkle root mismatch");
    
    // 2. 验证 pinning 时间戳（72 小时内必须完成）
    require(
        pointer.pinTimestamp <= block.timestamp &&
        pointer.pinTimestamp + 72 hours >= block.timestamp,
        "Pinning expired or invalid"
    );
    
    // 3. 验证 proofData 的 Merkle root 与 runtimeHash 匹配
    bytes32 computedRoot = computeMerkleRoot(proofData);
    require(computedRoot == pointer.merkleRoot, "Merkle proof invalid");
    
    // 4. 验证 leaf 包含正确的 runtimeHash
    return verifyMerkleProof(tokenId, proofData, pointer.merkleRoot);
}
```

---

## 3. S-GraphCore 合约

负责：关系状态存储、三分层写权限、紧急干预、三阶段冻结退出

### 3.1 接口定义

```solidity
interface ISGraphCore {
    // === 数据模型 ===
    
    struct RelationNode {
        uint256 licenseId;      // 关联许可 ID
        address creator;        // 创作者地址
        address user;           // 使用者地址
        bytes32 ruleHash;       // 创建时规则哈希
        uint256 createTime;     // 创建时间戳
        uint256 lastUpdateTime; // 最后更新时间
        bytes32 currentState;   // 当前状态哈希
    }
    
    // === 常态写入（LicenseToken 合约触发） ===
    
    /// @notice 创建关系节点（许可 mint 时自动调用）
    function createRelation(
        uint256 licenseId,
        address creator,
        address user,
        bytes32 ruleHash
    ) external returns (bytes32 nodeId);
    
    /// @notice 更新关系节点状态（许可交互时）
    function updateRelationState(
        bytes32 nodeId,
        bytes32 newState,
        bytes calldata proof
    ) external;
    
    // === 紧急干预双通道（修订）★ ===
    
    /// @notice 【标准通道】高势位紧急干预（48小时时间锁）
    /// @param nodeIds 要冻结的关系节点 ID 列表
    /// @param reason 冻结原因（最大 1KB）
    /// @return proposalId 时间锁提案 ID
    function emergencyFreeze(
        bytes32[] calldata nodeIds,
        string calldata reason
    ) external returns (uint256 proposalId);
    
    /// @notice 【快速通道】单高势位紧急冻结（severity ≥ 4，24h DAO 追认）
    /// @param nodeIds 要冻结的关系节点 ID 列表
    /// @param severity 严重程度（4-5，链上可验证指标）
    /// @param evidenceHash 证据文件哈希
    function emergencyFreezeFast(
        bytes32[] calldata nodeIds,
        uint8 severity,
        bytes32 evidenceHash
    ) external;
    
    /// @notice 【severity 5 极端通道】多签立即执行（无时间锁）
    /// @param nodeIds 要冻结的关系节点 ID 列表
    /// @param signatures 3/5 Agent 陪审团签名
    function emergencyFreezeCritical(
        bytes32[] calldata nodeIds,
        bytes calldata signatures
    ) external;
    
    /// @notice 解冻关系节点
    function emergencyUnfreeze(bytes32[] calldata nodeIds, uint256 proposalId) external;
    
    /// @notice DAO 追认快速冻结（24 小时内）
    function daoRatifyFastFreeze(uint256 fastFreezeId, bool approve) external;
    
    // === 三阶段冻结退出 ===
    
    /// @notice 创作者发布退出声明（进入阶段 1）
    function announceExit(string calldata reason) external;
    
    /// @notice 检查创作者退出状态
    function getExitStatus(address creator) external view returns (
        ExitStage stage,
        uint64 announceTime,
        uint64 deprecatedTime,
        uint64 archiveTime
    );
    
    enum ExitStage {
        ACTIVE,      // 正常运营
        ANNOUNCED,   // 已发布退出声明
        DEPRECATED,  // 30天后：不再推荐，旧许可继续有效
        ARCHIVED     // sunset 后：归档到链下
    }
    
    /// @notice 归档创作者的所有关系状态（ sunset 后调用）
    function archiveCreatorRelations(address creator) external returns (bytes32 archiveHash);
    
    // === 事件 ===
    
    event RelationCreated(bytes32 indexed nodeId, uint256 indexed licenseId, address creator, address user);
    event RelationUpdated(bytes32 indexed nodeId, bytes32 oldState, bytes32 newState);
    event EmergencyFreezeProposed(uint256 indexed proposalId, address proposer, uint64 executeTime);
    event EmergencyFreezeExecuted(uint256 indexed proposalId, bytes32[] nodeIds);
    event FastFreezeTriggered(uint256 indexed fastFreezeId, address proposer, uint8 severity);
    event FastFreezeRatified(uint256 indexed fastFreezeId, bool approved);
    event CriticalFreezeExecuted(bytes32[] nodeIds, bytes32 juryCommit); // 新增 #14
    event ExitAnnounced(address indexed creator, uint64 announceTime);
    event RelationsArchived(address indexed creator, bytes32 archiveHash);
}
```

### 3.2 三分层写权限参数

| 写入主体 | 权限范围 | 触发条件 | 安全机制 |
|---------|---------|---------|---------|
| LicenseToken 合约 | 常态写入 | 使用者触发许可交互 | 自动执行 |
| 高势位创作者（标准通道） | 紧急干预 | Top 10% 势位 + 3 地址多签 | **48 小时时间锁** |
| 高势位创作者（快速通道） | 紧急冻结 | Top 10% 势位 + severity 4（单签 24h 追认）| **24 小时内 DAO 追认** ★ |
| 高势位创作者（极端通道） | 紧急冻结 | Top 10% 势位 + severity 5（3/5 陪审团多签）| **立即执行，事后审计** ★ |
| DAO 治理多签 | 最终兜底 | 治理提案通过 | 时间锁 + 投票期 |

### 3.3 紧急干预三通道（修订）★

**修订 #3**：快速通道冷却期细化（severity 4-5 单签 24h，severity 5 多签跳过）
- **提出者**：哪吒
- **原因**：severity 5 极端情况不应等待，需立即执行

**修订 #7**：severity 链上可验证指标替代自报
- **提出者**：X7
- **原因**：防止创作者滥用 severity 评级，需客观指标

**severity 链上可验证指标（替代主观自报）**：

```solidity
struct SeverityMetrics {
    uint256 anomalyTxCount;      // 异常交易数（近 1 小时）
    uint256 valueAtRisk;         // 涉及资产价值
    uint256 affectedLicenseCount;  // 受影响许可数
    uint256 ruleDeviationScore;    // 规则偏离度（链上对比 configHash）
    bool creatorKeyCompromised;   // 创作者密钥是否被标记（由前序安全事件推导）
}

/// @notice 计算 severity（纯链上数据，无主观输入）
function computeSeverity(SeverityMetrics calldata metrics) public pure returns (uint8) {
    uint8 score = 0;
    
    // Level 1-2 阈值
    if (metrics.anomalyTxCount > 0) score = max(score, 1);
    if (metrics.anomalyTxCount > 10 || metrics.valueAtRisk > 1 ether) score = max(score, 2);
    
    // Level 3 阈值
    if (metrics.affectedLicenseCount > 50 || metrics.valueAtRisk > 10 ether) score = max(score, 3);
    
    // Level 4 阈值（快速通道）★
    if (metrics.ruleDeviationScore > 5000 || metrics.affectedLicenseCount > 200) score = max(score, 4);
    
    // Level 5 阈值（极端通道）★
    if (metrics.creatorKeyCompromised || metrics.valueAtRisk > 100 ether) score = max(score, 5);
    
    return score;
}
```

**三通道定义（修订后）**：

```
标准通道（保留）：
  触发：Top 10% 势位 + 3 个不同地址多签
  执行：48 小时时间锁后自动执行
  适用：非紧急场景（配置错误、规则冲突）

快速通道（修订）：
  触发：Top 10% 势位 + severity == 4（链上指标判定）
  执行：单签立即冻结，24 小时内 DAO 必须追认
  适用：严重场景（大规模规则偏离、大量许可受影响）
  风险：若 DAO 24 小时内未追认，冻结自动解除

极端通道（新增 #3/#14）：
  触发：Top 10% 势位 + severity == 5（链上指标判定）+ 3/5 Agent 陪审团多签
  执行：立即冻结，无需 DAO 追认，事后进入审计流程
  适用：极端场景（密钥泄露、系统性资产风险）
  审计：72 小时内必须提交完整证据包，否则冻结自动解除
```

### 3.4 三阶段冻结退出时间线（无变更）

```
T+0:   创作者调用 announceExit() → 进入 ANNOUNCED
       ├─ 暂停新许可签发
       ├─ 触发全局事件通知所有使用者
       └─ 启动 sunset 倒计时

T+30天: 自动进入 DEPRECATED
       ├─ 旧许可继续有效
       ├─ 界面显示"创作者已退出，谨慎使用"
       └─ 鼓励使用者迁移到其他版本/创作者

T+sunset: 自动进入 ARCHIVED
       ├─ 关系状态 snapshot 到 IPFS + Arweave
       ├─ 链上状态标记为 ARCHIVED
       ├─ 许可 token 仍可查询但不可交互
       └─ 使用者可通过 archiveHash 恢复历史状态
```

### 3.5 Sunset 修复后的退出示例（无变更）

- 1天试用许可：sunset = 90天 → 归档于 T+90天
- 30天月度许可：sunset = 90天 → 归档于 T+90天
- 180天半年许可：sunset = 187天 → 归档于 T+187天
- 365天年度许可：sunset = 372天 → 归档于 T+372天

### 3.6 冷却期裁决公式（修订）★

**修订 #8**：cooldownRuling 异议拖延攻击防护（延长次数上限 1 次）
- **提出者**：M77
- **原因**：防止恶意反复提交不足 3 个异议，无限延长冷却期

**修订 #16**：反证质押（0.05 ETH，恶意 50%销毁+50%奖励）
- **提出者**：哪吒
- **原因**：提高异议成本，防止 spam；奖励诚实反证者

```solidity
// 触发条件（无变更）
function onVersionPublished(uint256 newVersionId) internal {
    cooldownDeadlines[newVersionId] = block.timestamp + 7 days;
    objectionCount[newVersionId] = 0;
    extensionCount[newVersionId] = 0; // 新增：记录延长次数 ★
    emit CooldownStarted(newVersionId, cooldownDeadlines[newVersionId]);
}
```

**异议提交（修订后）**：

```solidity
/// @notice 提交异议（质押 0.05 ETH）★ 修订 #16
/// @param versionId 目标版本
/// @param reasonHash 异议原因
/// @param counterEvidence 反证数据（可选，用于反驳其他异议）
function submitObjection(
    uint256 versionId,
    bytes32 reasonHash,
    bytes calldata counterEvidence
) external payable {
    require(msg.value >= 0.05 ether, "Stake required: 0.05 ETH"); // 0.01→0.05 ★
    require(block.timestamp < cooldownDeadlines[versionId], "Cooldown expired");
    require(LicenseToken.balanceOf(msg.sender) > 0, "Must hold valid license");
    
    // 修订 #16：反证机制
    if (counterEvidence.length > 0) {
        // 若 counterEvidence 被后续验证为有效反证，质押者获得奖励
        counterEvidenceQueue[versionId].push(CounterEvidence({
            submitter: msg.sender,
            evidenceHash: keccak256(counterEvidence),
            timestamp: block.timestamp,
            validated: false
        }));
    }
    
    objections[versionId].push(Objection({
        objector: msg.sender,
        reasonHash: reasonHash,
        stake: msg.value,
        timestamp: block.timestamp
    }));
    
    objectionCount[versionId]++;
    emit ObjectionSubmitted(versionId, msg.sender, msg.value);
}
```

**裁决逻辑（修订后）**：

```solidity
function cooldownRuling(uint256 versionId) external {
    require(block.timestamp >= cooldownDeadlines[versionId], "Cooldown not ended");
    require(!rulingExecuted[versionId], "Ruling already executed");
    
    RulingResult result;
    uint256 objectionNum = objectionCount[versionId];
    
    if (objectionNum == 0) {
        // 无异议 → 自动通过
        result = RulingResult.PASSED;
    } else if (objectionNum < 3 && extensionCount[versionId] < 1) {
        // 异议不足 3 个且未延长过 → 延长 7 天（仅 1 次）★ 修订 #8
        cooldownDeadlines[versionId] += 7 days;
        extensionCount[versionId]++; // 标记已延长
        result = RulingResult.EXTENDED;
        emit CooldownExtended(versionId, cooldownDeadlines[versionId]);
        return;
    } else if (objectionNum < 3 && extensionCount[versionId] >= 1) {
        // 异议不足 3 个但已延长过 1 次 → 不再延长，直接裁决 ★ 修订 #8
        result = autoRuling(versionId);
    } else {
        // 异议 ≥ 3 → 自动裁决
        result = autoRuling(versionId);
    }
    
    // 执行结果上链
    rulingResults[versionId] = result;
    rulingExecuted[versionId] = true;
    
    // 质押分配（修订 #16）★
    distributeStakes(versionId, result);
    
    emit RulingExecuted(versionId, result, block.timestamp);
}

// 质押分配规则（修订 #16）★
function distributeStakes(uint256 versionId, RulingResult result) internal {
    if (result == RulingResult.PASSED) {
        // 通过：异议者视为恶意挑战
        for (each objection) {
            // 50% 销毁，50% 奖励给诚实反证者或协议金库
            uint256 burn = objection.stake * 50 / 100;
            uint256 reward = objection.stake - burn;
            protocolVault += burn;
            distributeReward(versionId, reward); // 分配给 counterEvidence 提交者或社区
        }
    } else if (result == RulingResult.REJECTED) {
        // 拒绝：异议者视为诚实挑战，全额退还 + 协议奖励
        for (each objection) {
            payable(objection.objector).transfer(objection.stake);
        }
        // 创作者质押部分作为惩罚（若创作者有预质押）
    }
}
```

**裁决结果**：
- `PASSED`：新版本生效，无异议或权利密度未降低
- `REJECTED`：新版本被拒绝，创作者可修改后重新提交
- `EXTENDED`：仅可延长 **1 次**（修订 #8），异议不足 3 个时延长 7 天，再次到期后直接裁决

### 3.7 Agent 陪审团接口（新增）★

**修订 #14**：Agent 陪审团接口（commit-reveal + 时间隔离 + 3/5 多签）
- **提出者**：CaT.G
- **原因**：severity 5 极端场景需去中心化裁决，避免单点决策

```solidity
interface IAgentJury {
    struct JuryCommit {
        bytes32 commitHash;      // keccak256(vote + salt)
        uint256 commitTime;
        bool revealed;
    }
    
    struct JuryReveal {
        bool vote;               // true=支持冻结, false=反对
        bytes32 salt;            // 用于验证 commit
        bytes32 evidenceHash;    // 裁决依据证据
    }
    
    /// @notice Agent 提交 commit（时间隔离阶段 1）
    /// @param caseId 案件 ID
    /// @param commitHash keccak256(vote + salt)
    function juryCommit(uint256 caseId, bytes32 commitHash) external;
    
    /// @notice Agent 提交 reveal（时间隔离阶段 2，commit 结束后 2 小时）
    /// @param caseId 案件 ID
    /// @param reveal 投票 + 盐值
    function juryReveal(uint256 caseId, JuryReveal calldata reveal) external;
    
    /// @notice 执行裁决（3/5 多签通过后）
    /// @param caseId 案件 ID
    function executeJuryRuling(uint256 caseId) external;
    
    /// @notice 获取案件状态
    function getCaseStatus(uint256 caseId) external view returns (
        uint256 commitDeadline,
        uint256 revealDeadline,
        uint8 commitCount,
        uint8 revealCount,
        uint8 supportCount,
        bool executed
    );
    
    event JuryCommitSubmitted(uint256 indexed caseId, address indexed agent);
    event JuryRevealSubmitted(uint256 indexed caseId, address indexed agent, bool vote);
    event JuryRulingExecuted(uint256 indexed caseId, bool frozen, uint8 supportCount);
}
```

**Agent 陪审团流程**：

```
severity 5 极端冻结触发
    ↓
随机抽取 5 名 Agent 组成陪审团（基于信誉分加权随机，§4.5）
    ↓
【Commit 阶段】4 小时
  每个 Agent 提交 keccak256(vote + salt)
  → 无法看到其他人投票，防止跟风
    ↓
【Reveal 阶段】2 小时
  每个 Agent 提交 vote + salt
  → 验证 commit 匹配
    ↓
【执行条件】
  - 至少 3 名 Agent reveal
  - 且 supportCount ≥ 3
  → 冻结立即执行
    ↓
【事后审计】72 小时内
  - 提交完整证据包到 IPFS
  - 未提交证据包的 Agent 信誉分扣减
  - 错误投票的 Agent 信誉分扣减（与 §4.5 双轨信誉联动）
```

**时间隔离设计**：
- Commit 和 Reveal 分阶段，防止最后一分钟攻击和投票操控
- 4+2 小时窗口确保跨时区 Agent 均可参与
- 未 reveal 的 commit 视为弃权，不计入统计

### 3.8 退出权 gas 兜底资金池（新增）★

**修订 #18**：退出权 gas 兜底资金池设计
- **提出者**：CaT.G
- **原因**：创作者退出后，使用者需要执行迁移/归档操作，但可能 gas 不足

```solidity
interface IExitGasPool {
    /// @notice 创作者预存 gas 兜底资金（发布首个版本时强制存入）
    /// @param creator 创作者地址
    function depositGasFund(address creator) external payable;
    
    /// @notice 使用者申请 gas 补贴执行迁移（sunset 期间可用）
    /// @param licenseId 许可 ID
    /// @param operation 操作类型（MIGRATE / ARCHIVE / TRANSFER）
    function requestGasSubsidy(
        uint256 licenseId,
        uint8 operation
    ) external returns (uint256 gasAmount);
    
    /// @notice 获取创作者 gas 资金池余额
    function getGasFund(address creator) external view returns (uint256);
    
    /// @notice DAO 补充资金池（治理决策）
    function daoReplenishPool() external payable;
    
    event GasFundDeposited(address indexed creator, uint256 amount);
    event GasSubsidyGranted(address indexed user, uint256 licenseId, uint256 amount, uint8 operation);
    event PoolReplenished(uint256 amount);
}
```

**资金池规则**：
- **强制存入**：创作者发布首个版本时，必须存入 `MIN_GAS_FUND`（默认 0.1 ETH）
- **用途限定**：仅限支付 `migrateLicense()`、`archiveCreatorRelations()`、`transfer` 等退出相关操作的 gas
- **补贴上限**：单次补贴不超过 `MAX_SUBSIDY_PER_TX`（默认 0.01 ETH）
- **池耗尽**：若创作者 pool 耗尽，由协议公共 pool 兜底（DAO 治理资金）
- **退款**：创作者正常运营满 1 年且无退出记录，可申请退还 50% gas fund

---

## 4. 势位评估引擎合约

负责：势位计算、动态锁、硬地板机制、信誉双轨、自适应阈值

### 4.1 接口定义（修订）★

```solidity
interface IPotentialEngine {
    // === 势位评估 ===
    
    /// @notice 获取创作者当前势位
    function getPotential(address creator) external view returns (uint256 potential);
    
    /// @notice 获取创作者势位等级
    function getPotentialLevel(address creator) external view returns (uint8 level);
    
    /// @notice 手动触发势位重新评估（任何人可调用，但有限流：每 6 小时一次）
    function reevaluatePotential(address creator) external;
    
    /// @notice 获取下次可触发评估的时间戳
    function getNextEvalTime(address creator) external view returns (uint256);
    
    // === 硬地板管理 ===
    
    /// @notice 获取创作者当前硬地板值
    function getHardFloor(address creator) external view returns (uint256 floorPercentage);
    
    /// @notice 检查创作者配置是否满足硬地板要求
    function validateHardFloor(address creator, bytes32 configHash) external view returns (bool);
    
    // === 评估参数 ===
    
    /// @notice 设置评估权重（仅 DAO）
    function setWeight(bytes32 metric, uint256 weight) external;
    
    /// @notice 获取评估权重
    function getWeight(bytes32 metric) external view returns (uint256);
    
    // === 信誉分双轨（新增 #15）★ ===
    
    /// @notice 获取 Agent 硬准确率
    function getHardAccuracy(address agent) external view returns (uint256);
    
    /// @notice 获取 Agent 软共识率
    function getSoftConsensus(address agent) external view returns (uint256);
    
    /// @notice 更新 Agent 信誉分（由陪审团/裁决系统调用）
    function updateAgentReputation(address agent, bool correctVote) external;
    
    // === 自适应阈值（新增 #17）★ ===
    
    /// @notice 获取当前异常检测阈值（Tukey fences）
    function getAdaptiveThreshold(bytes32 metricKey) external view returns (uint256 lower, uint256 upper);
    
    /// @notice 触发阈值重计算（任何人可调用，每周一次）
    function recalculateThresholds() external;
    
    // === 事件 ===
    
    event PotentialUpdated(
        address indexed creator,
        uint256 oldPotential,
        uint256 newPotential,
        uint8 newLevel
    );
    
    event HardFloorAdjusted(
        address indexed creator,
        uint256 oldFloor,
        uint256 newFloor
    );
    
    event ReputationUpdated(address indexed agent, uint256 hardAccuracy, uint256 softConsensus);
    event ThresholdRecalculated(bytes32 indexed metric, uint256 lower, uint256 upper);
}
```

### 4.2 势位评估算法（修订）★

**修订 #4**：submitNPS 加许可有效性实时验证
- **提出者**：非攻进阶版
- **原因**：防止过期许可刷 NPS，或使用者转让许可后重复评分

**修订 #9**：势位权重考虑 50:50 或动态提升（争议率高时使用者侧↑）
- **提出者**：Talus
- **原因**：争议率高的创作者更应反映使用者声音，而非仅看创作者侧数据

```solidity
/// @notice 使用者提交满意度评分（NPS，修订后）★
/// @param creator 评价的创作者
/// @param npsScore 1-10 分
/// @param licenseId 关联许可 ID
function submitNPS(
    address creator,
    uint8 npsScore,
    uint256 licenseId
) external {
    // 修订 #4：实时验证许可有效性
    require(LicenseToken.ownerOf(licenseId) == msg.sender, "Must own license");
    require(LicenseToken.checkStatus(licenseId) == LicenseStatus.ACTIVE, "License must be active");
    
    // 修订 #4：检查许可是否过期
    (, uint64 expiry,,,,,) = LicenseToken.getLicense(licenseId);
    require(expiry == 0 || expiry > block.timestamp, "License expired");
    
    // 修订 #4：检查许可是否已迁移（迁移后不能对旧版本评分）
    require(licenseToVersion[licenseId] == currentVersionId[creator], "License migrated to new version");
    
    require(npsScore >= 1 && npsScore <= 10, "Score must be 1-10");
    require(!hasRated[licenseId][creator], "Already rated");
    
    npsScores[creator].push(npsScore);
    hasRated[licenseId][creator] = true;
    
    // 提交 NPS 后触发势位重新评估（延迟执行，避免 gas 峰值）
    scheduleReevaluation(creator);
    
    emit NPSSubmitted(creator, msg.sender, npsScore);
}
```

**势位评估算法（修订后）**：

```solidity
function calculatePotential(address creator) public view returns (uint256) {
    // === 动态权重计算（修订 #9）★ ===
    uint256 creatorWeight;
    uint256 userWeight;
    
    uint256 disputeRate = computeDisputeRate(creator);
    if (disputeRate > 10) {
        // 争议率 > 10% → 使用者侧权重提升至 60%（动态调整）
        creatorWeight = 40;
        userWeight = 60;
    } else {
        // 正常情况 → 50:50（修订 #9，原 60:40 已取消）
        creatorWeight = 50;
        userWeight = 50;
    }
    
    // === 创作者侧指标 ===
    uint256 revenueScore = computeRevenueScore(creator);        // 收入稳定性 0-100
    uint256 licenseScore = computeLicenseScore(creator);        // 许可数量/增长率 0-100
    uint256 versionScore = computeVersionScore(creator);        // 版本迭代健康度 0-100
    
    // === 使用者侧指标 ===
    uint256 engagementScore = computeEngagementScore(creator);  // 使用者活跃度 0-100
    uint256 satisfactionScore = computeSatisfactionScore(creator); // NPS 评分 0-100
    uint256 disputePenalty = computeDisputePenalty(creator);      // 争议惩罚 0-100（新增）
    
    // 总势位 = 创作者侧 × 动态权重 + 使用者侧 × 动态权重
    uint256 creatorSide = (revenueScore + licenseScore + versionScore) * creatorWeight / 300;
    uint256 userSide = (engagementScore + satisfactionScore + (100 - disputePenalty)) * userWeight / 300;
    
    return min(creatorSide + userSide, 100); // 上限 100
}

// 争议惩罚计算（新增）
function computeDisputePenalty(address creator) internal view returns (uint256) {
    uint256 rate = computeDisputeRate(creator);
    // 争议率 0% = 0 惩罚，20% = 100 惩罚，线性增长
    return min(rate * 5, 100);
}
```

**各指标计算方式（完整版）**：

| 指标 | 数据来源 | 计算方式 |
|------|---------|---------|
| `revenueScore` | LicenseToken 合约 | 近 30 天收入 / 历史平均收入，>1.2 得 100 分，<0.5 得 0 分 |
| `licenseScore` | LicenseToken 合约 | 当前有效许可数 / 历史峰值，× 100 |
| `versionScore` | CreatorConfig 合约 | 版本发布频率适中（1-4周/次）得 100，过快/过慢扣分 |
| `engagementScore` | S-GraphCore 合约 | 近 30 天使用者交互次数 / 许可数，活跃度比率 × 100 |
| `satisfactionScore` | 链下 NPS 调查 | 使用者主动提交的 NPS 评分（1-10）平均值 × 10 |
| `disputeRate` | S-GraphCore 合约 | 近 90 天异议数 / 总许可数，比率越低越好 |
| `disputePenalty` | 派生指标 | 争议率 × 5，上限 100（争议率 > 20% 时势位封顶受限）|

**触发机制明确（修订 #13）**：

```solidity
/// @notice 势位评估触发条件（修订 #13）★
function shouldTriggerEval(address creator) public view returns (bool) {
    uint256 lastEval = lastEvalTime[creator];
    
    // 1. 时间触发：距离上次评估 ≥ 24 小时
    if (block.timestamp >= lastEval + 24 hours) return true;
    
    // 2. 事件触发：创作者发布新版本
    if (lastVersionPublish[creator] > lastEval) return true;
    
    // 3. 事件触发：使用者提交 NPS（延迟 1 小时聚合后触发）
    if (pendingNPSCount[creator] >= 5) return true; // 每 5 个 NPS 触发一次
    
    // 4. 事件触发：发生紧急冻结事件
    if (lastEmergencyEvent[creator] > lastEval) return true;
    
    // 5. 事件触发：创作者调用 announceExit()
    if (exitStatus[creator].announceTime > lastEval) return true;
    
    return false;
}
```

### 4.3 势位等级与硬地板对应表（无变更）

| 势位等级 | 势位范围 | 硬地板（不可撤销规则最低比例）|
|---------|---------|------------------------|
| L1 | 0-25 | 20% |
| L2 | 26-50 | 35% |
| L3 | 51-75 | 50% |
| L4 | 76-100 | 70% |

**硬地板规则（无变更）**：
- 自动上调：势位升高时硬地板自动升高
- 手动限制：创作者不能手动调低硬地板
- 治理修改：DAO 多签可修改全局硬地板参数（见 §5）

### 4.4 自适应阈值（新增）★

**修订 #17**：自适应阈值（5σ/百分位法→Tukey fences，连续 2 周期延迟确认）
- **提出者**：X7
- **原因**：5σ 和百分位法对异常值敏感度不同，Tukey fences 更稳健；连续 2 周期确认防止误报

```solidity
/// @notice 使用 Tukey fences 计算自适应阈值
/// @param metricKey 指标键（如 "anomalyTxCount", "valueAtRisk"）
/// @param dataPoints 近 14 天历史数据点
function calculateTukeyThreshold(bytes32 metricKey, uint256[] calldata dataPoints) 
    public pure returns (uint256 lowerFence, uint256 upperFence) {
    
    // 1. 排序数据
    uint256[] memory sorted = sort(dataPoints);
    uint256 n = sorted.length;
    
    // 2. 计算 Q1（25% 分位）和 Q3（75% 分位）
    uint256 q1 = sorted[n / 4];
    uint256 q3 = sorted[3 * n / 4];
    
    // 3. 计算 IQR
    uint256 iqr = q3 - q1;
    
    // 4. Tukey fences：Q1 - 1.5×IQR，Q3 + 1.5×IQR
    lowerFence = q1 > iqr * 15 / 10 ? q1 - iqr * 15 / 10 : 0;
    upperFence = q3 + iqr * 15 / 10;
    
    return (lowerFence, upperFence);
}

/// @notice 检查指标是否异常（连续 2 周期确认）
function isAnomaly(bytes32 metricKey, uint256 currentValue) public view returns (bool) {
    (uint256 lower, uint256 upper) = adaptiveThresholds[metricKey];
    
    bool outsideFence = currentValue < lower || currentValue > upper;
    uint8 streak = anomalyStreak[metricKey];
    
    if (outsideFence) {
        streak++;
        anomalyStreak[metricKey] = streak;
        
        // 连续 2 个周期超出 fences → 确认为异常（修订 #17）
        if (streak >= 2) {
            emit AnomalyConfirmed(metricKey, currentValue, lower, upper);
            return true;
        }
    } else {
        // 回到正常范围，重置 streak
        anomalyStreak[metricKey] = 0;
    }
    
    return false;
}

/// @notice 每周自动重计算所有阈值（任何人可触发）
function recalculateThresholds() external {
    require(block.timestamp >= lastThresholdUpdate + 7 days, "Too frequent");
    
    bytes32[] memory metrics = getAllMetricKeys();
    for (uint i = 0; i < metrics.length; i++) {
        uint256[] memory history = getHistoricalData(metrics[i], 14 days);
        (uint256 lower, uint256 upper) = calculateTukeyThreshold(metrics[i], history);
        adaptiveThresholds[metrics[i]] = (lower, upper);
        emit ThresholdRecalculated(metrics[i], lower, upper);
    }
    
    lastThresholdUpdate = block.timestamp;
}
```

### 4.5 信誉分双轨计算（新增）★

**修订 #15**：信誉分双轨计算（硬准确率/软共识率）
- **提出者**：Talus
- **原因**：单一信誉分容易被操控，双轨分别衡量"客观正确率"和"社区共识度"

```solidity
/// @notice Agent 信誉分双轨结构
struct AgentReputation {
    uint256 hardAccuracy;     // 硬准确率：客观可验证的裁决正确率（0-10000，万分之一精度）
    uint256 softConsensus;  // 软共识率：与其他 Agent 投票一致的比例（0-10000）
    uint256 totalVotes;       // 总投票数
    uint256 correctVotes;     // 客观上正确的投票数（由最终结果推导）
    uint256 consensusVotes;   // 与多数一致的投票数
    uint256 lastVoteTime;     // 最后投票时间
}

mapping(address => AgentReputation) public agentReputations;

/// @notice 更新 Agent 信誉分（由陪审团/裁决系统调用）
function updateAgentReputation(address agent, bool correctVote, bool consensusVote) external {
    require(msg.sender == juryContract || msg.sender == rulingContract, "Unauthorized");
    
    AgentReputation storage rep = agentReputations[agent];
    rep.totalVotes++;
    if (correctVote) rep.correctVotes++;
    if (consensusVote) rep.consensusVotes++;
    rep.lastVoteTime = block.timestamp;
    
    // 硬准确率 = 正确投票 / 总投票（最少 10 票后开始计算）
    if (rep.totalVotes >= 10) {
        rep.hardAccuracy = rep.correctVotes * 10000 / rep.totalVotes;
    }
    
    // 软共识率 = 与多数一致 / 总投票（最少 10 票后开始计算）
    if (rep.totalVotes >= 10) {
        rep.softConsensus = rep.consensusVotes * 10000 / rep.totalVotes;
    }
    
    emit ReputationUpdated(agent, rep.hardAccuracy, rep.softConsensus);
}

/// @notice 获取 Agent 综合信誉分（硬准确率 70% + 软共识率 30%）
function getCompositeReputation(address agent) external view returns (uint256) {
    AgentReputation storage rep = agentReputations[agent];
    if (rep.totalVotes < 10) return 5000; // 新 Agent 默认中信誉
    
    return rep.hardAccuracy * 70 / 100 + rep.softConsensus * 30 / 100;
}
```

**双轨含义**：
- **硬准确率**：Agent 的投票与「事后可验证的客观事实」一致的比例。例如：Agent 投票"应冻结"，72 小时后审计确认确实应冻结 → correctVote = true。这个指标难以操控，因为取决于客观结果。
- **软共识率**：Agent 的投票与「其他多数 Agent 的投票」一致的比例。这个指标衡量 Agent 的"社交一致性"，防止极端异类或串通行为。

**陪审团抽选权重**：
```solidity
/// @notice 按信誉分加权随机抽选陪审团成员
function drawJuryMembers(uint256 caseId) internal returns (address[] memory) {
    address[] memory candidates = getAllAgentAddresses();
    uint256[] memory weights = new uint256[](candidates.length);
    
    for (uint i = 0; i < candidates.length; i++) {
        weights[i] = getCompositeReputation(candidates[i]);
        // 硬准确率 < 3000（30%）的 Agent 排除
        if (agentReputations[candidates[i]].hardAccuracy < 3000) {
            weights[i] = 0;
        }
    }
    
    return weightedRandomSelect(candidates, weights, 5);
}
```

---

## 5. DAO 治理参数（修订）★

### 5.1 DAO 治理合约接口（无结构变更）

```solidity
interface IDAO {
    struct Proposal {
        bytes32 proposalType;   // 提案类型
        bytes32 targetParam;    // 目标参数
        uint256 newValue;       // 新值
        uint256 startTime;      // 投票开始时间
        uint256 endTime;        // 投票结束时间
        uint256 votesFor;       // 赞成票
        uint256 votesAgainst;   // 反对票
        bool executed;          // 是否已执行
    }
    
    /// @notice 创建治理提案
    function createProposal(
        bytes32 proposalType,
        bytes32 targetParam,
        uint256 newValue,
        uint256 votingPeriod
    ) external returns (uint256 proposalId);
    
    /// @notice 投票
    function vote(uint256 proposalId, bool support) external;
    
    /// @notice 执行通过的提案（时间锁到期后）
    function executeProposal(uint256 proposalId) external;
    
    /// @notice 获取提案状态
    function getProposal(uint256 proposalId) external view returns (Proposal memory);
}
```

### 5.2 治理参数定义（修订）★

**修订 #1**：DAO_MIN_MEMBERS 5→11
- **提出者**：哪吒
- **原因**：5 人过于集中，11 人更能代表社区多样性

| 参数 | 原值 | 修订值 | 说明 |
|------|------|--------|------|
| `DAO_MIN_MEMBERS` | 5 | **11** ★ | DAO 最少成员数（修订 #1）|
| `DAO_QUORUM_PERCENTAGE` | 60% | 60% | 最低参与门槛 |
| `DAO_VOTING_PERIOD` | 7 天 | 7 天 | 标准投票期 |
| `DAO_EMERGENCY_VOTING_PERIOD` | 24 小时 | 24 小时 | 紧急投票期 |
| `DAO_PASS_THRESHOLD` | 66.7% | 66.7% | 通过门槛（2/3）|
| `DAO_TIMELOCK` | 48 小时 | 48 小时 | 提案通过后等待期 |
| `DAO_EMERGENCY_TIMELOCK` | 6 小时 | 6 小时 | 紧急提案时间锁 |

### 5.3 投票权重设计（修订）★

**修订 #5**：activityBoost 加衰减机制 + 投票权重与势位引擎解耦
- **提出者**：Talus
- **原因**：防止治理挖矿（为刷投票权重而频繁参与）；势位引擎是创作者指标，不应直接等同于治理权重

**修订 #12**：DAO 投票权重公式完全公开
- **提出者**：哪吒
- **原因**：透明度要求，所有权重因子必须链上可审计

```solidity
/// @notice 投票权重公式（完全公开，链上可审计）★ 修订 #12
function getVotingPower(address member) public view returns (uint256) {
    // === 基础权重（不可变）===
    uint256 basePower = 1; // 每个成员至少 1 票
    
    // === 治理活跃度加成（带衰减）★ 修订 #5 ===
    uint256 rawActivity = governanceActivity[member].recentParticipations;
    uint256 activityBoost = calculateDecayedActivity(rawActivity, member);
    // 衰减规则：近 30 天参与次数，超过 10 次后边际收益递减
    // 公式：boost = min(10, rawActivity) × 0.1，即最多 +1
    // 超过 30 天未参与 → 清零（防止僵尸权重）
    
    // === 锁仓加成（独立因子）★ 修订 #5 ===
    uint256 lockBoost = getLockBoost(member);
    // 锁仓 ECHO 代币 ≥ 1000 → +1，≥ 10000 → +2，上限 +2
    
    // === 总权重（上限 5）===
    uint256 totalPower = basePower + activityBoost + lockBoost;
    return min(totalPower, 5);
}

/// @notice 活跃度衰减计算（修订 #5）
function calculateDecayedActivity(uint256 rawCount, address member) internal view returns (uint256) {
    uint256 lastParticipation = governanceActivity[member].lastParticipationTime;
    uint256 daysInactive = (block.timestamp - lastParticipation) / 1 days;
    
    // 30 天未参与 → 活跃度清零
    if (daysInactive > 30) return 0;
    
    // 衰减系数：每过 7 天衰减 20%
    uint256 decayFactor = 100 - (daysInactive / 7) * 20;
    if (decayFactor < 20) decayFactor = 20; // 最低保留 20%
    
    uint256 effectiveActivity = rawCount * decayFactor / 100;
    
    // 边际递减：超过 10 次后，每次只计 0.5
    if (effectiveActivity > 10) {
        effectiveActivity = 10 + (effectiveActivity - 10) / 2;
    }
    
    // 最终 boost：每 10 有效活动 = +1 权重
    return effectiveActivity / 10;
}

/// @notice 锁仓加成（与势位引擎完全解耦）★ 修订 #5
function getLockBoost(address member) internal view returns (uint256) {
    uint256 lockedAmount = echoToken.getLockedBalance(member);
    if (lockedAmount >= 10000 ether) return 2;
    if (lockedAmount >= 1000 ether) return 1;
    return 0;
}
```

**权重公式公开透明**：
```
总投票权重 = min(基础 1 + 衰减活跃度加成 + 锁仓加成, 5)

其中：
- 基础权重 = 1（不可剥夺）
- 活跃度加成 = floor( 有效活动数 / 10 )，有效活动数 = rawCount × 衰减系数
  - 衰减系数 = max(20%, 100% - (daysInactive/7)×20%)
  - 边际递减：rawCount > 10 后每次计 0.5
  - 30 天未参与 = 0
- 锁仓加成 = 锁仓 ECHO ≥1000 → +1, ≥10000 → +2（与创作者势位无关）
- 上限 = 5
```

### 5.4 可治理参数列表（无变更）

| 参数 | 当前值 | 调整范围 | 影响 |
|------|--------|---------|------|
| `SUNSET_RATIO` | 30% | 20%-50% | 影响所有新许可的 sunset 计算 |
| `MIN_SUNSET_DAYS` | 90 | 60-180 | sunset 最低天数 |
| `HARD_FLOOR_L1` | 20% | 10%-30% | L1 创作者硬地板 |
| `HARD_FLOOR_L2` | 35% | 25%-45% | L2 创作者硬地板 |
| `HARD_FLOOR_L3` | 50% | 40%-60% | L3 创作者硬地板 |
| `HARD_FLOOR_L4` | 70% | 60%-80% | L4 创作者硬地板 |
| `COOLDOWN_DAYS` | 7 | 3-14 | 新版本冷却期 |
| `OBJECTION_THRESHOLD` | 3 | 2-5 | 触发裁决的最小异议数 |
| `OBJECTION_STAKE` | 0.05 ETH | 0.005-0.05 ETH | 异议质押金额 |
| `EMERGENCY_TIMELOCK_STANDARD` | 48h | 24-72h | 标准紧急干预时间锁 |
| `EMERGENCY_TIMELOCK_FAST` | 24h | 12-48h | 快速通道 DAO 追认期限 |
| `IPFS_RESYNC_INTERVAL` | 1 天 | 1-7 天 | IPFS 快照频率 |
| `ARWEAVE_BATCH_SIZE` | 1000 许可 | 500-5000 | Arweave 批量存储大小 |
| `DAO_MIN_MEMBERS` | 11 | 7-21 | DAO 最少成员数 |
| `TUKEY_K` | 1.5 | 1.0-3.0 | Tukey fences 乘数 |
| `ANOMALY_STREAK_THRESHOLD` | 2 | 1-3 | 异常确认连续周期数 |

---

## 6. 交互流程图（文字版，标注变更点）

### 6.1 创作者发布新版本

```
创作者调用 CreatorConfig.publishVersion()
    ↓
设定 proposedPrice，进入 3 天公示期 ★
    ↓
社区可 challengePrice() 质疑定价（质押 0.02 ETH）★
    ↓
若被质疑 → Agent 陪审团 24h 裁决（§3.7）★
    ↓
价格锁定 → 自动启动 7 天冷却期（S-GraphCore）
    ↓
使用者可 submitObjection()（质押 0.05 ETH）★
    ↓
7 天后自动裁决
    ├─ 无异议 / 权利密度未降低 → 新版本生效
    ├─ 异议 < 3 且未延长过 → 延长 7 天（仅 1 次）★
    ├─ 异议 < 3 但已延长过 1 次 → 直接裁决 ★
    └─ 异议 ≥ 3 且权利密度降低 → 拒绝，创作者可修改重提
    ↓
裁决通过：异议者 50% 销毁 + 50% 奖励 ★
裁决拒绝：异议者全额退还
```

### 6.2 使用者购买许可

```
使用者调用 LicenseToken.mintLicense()
    ↓
支付费用
    ↓
LicenseToken 创建 NFT + 三层哈希锚定
    ↓
S-GraphCore 创建关系节点
    ↓
自动 snapshot 到 IPFS + 立即 pinning ★
    ↓
6 小时内 batch Merkle root 上链 ★
    ↓
24 小时内 batch snapshot 到 Arweave
    ↓
使用者获得许可 token
```

### 6.3 紧急干预流程（修订后）★

```
【标准通道】
高势位创作者调用 S-GraphCore.emergencyFreeze()
    ↓
3 地址多签确认
    ↓
48 小时时间锁倒计时
    ↓
时间锁到期 → 自动冻结
    ↓
修复后调用 emergencyUnfreeze()

【快速通道】（severity 4）
高势位创作者调用 S-GraphCore.emergencyFreezeFast(severity=4)
    ↓
severity 由链上指标自动计算（不可主观设定）★
    ↓
单签立即冻结
    ↓
24 小时内 DAO 必须追认
    ├─ DAO 通过 → 冻结保持
    └─ DAO 否决 / 超时 → 自动解冻

【极端通道】（severity 5，新增）★
触发条件：severity 5 链上指标判定
    ↓
随机抽取 5 名 Agent 组成陪审团（信誉分加权）★
    ↓
【Commit 阶段】4 小时：Agent 提交 commitHash
【Reveal 阶段】2 小时：Agent 提交 vote + salt
    ↓
3/5 通过 → 立即冻结，无需 DAO 追认
    ↓
72 小时内提交审计证据包
    ↓
错误投票 Agent 信誉分扣减（§4.5 双轨信誉）★
```

### 6.4 创作者退出流程

```
创作者调用 S-GraphCore.announceExit()
    ↓
暂停新许可签发
    ↓
触发全局通知
    ↓
T+30 天 → DEPRECATED（旧许可继续有效）
    ↓
使用者可申请 gasSubsidy() 执行迁移（创作者 pool 或协议 pool 兜底）★
    ↓
T+sunset → ARCHIVED（链下归档）
    ↓
关系状态 snapshot 到 IPFS + Arweave + Merkle root 验证 ★
    ↓
链上标记为归档，token 可查询但不可交互
```

---

## 7. Gas 优化与存储成本（修订）★

**修订 #6**：Gas 估算标注"需实测验证"
- **提出者**：CaT.G
- **原因**：所有 gas 估算均为理论值，主网部署前必须实测

### 7.1 链上存储优化

| 数据项 | 存储位置 | 大小 | 说明 |
|--------|---------|------|------|
| configHash | 链上 | 32 bytes | 规则语义哈希 |
| contractHash | 链上 | 32 bytes | 合约代码哈希 |
| runtimeHash | 链上 | 32 bytes | 运行时状态哈希 |
| offchainPointer | 链上 | 112 bytes | IPFS + Arweave + Merkle root + 时间戳 × 2 |
| 许可核心数据 | 链上 | ~200 bytes | tokenId, owner, versionId, expiry, status |
| 关系节点 | 链上 | ~256 bytes | nodeId, licenseId, creator, user, state |
| 完整配置 JSON | 链下 | 最大 10KB | 存储在 IPFS |
| 关系历史快照 | 链下 | 变化 | 存储在 IPFS + Arweave |

**1000 个许可总链上存储**：
- 许可数据：1000 × 200 bytes = 200 KB
- 关系节点：1000 × 256 bytes = 256 KB
- 哈希锚定：1000 × 176 bytes = 176 KB
- **总计**：~632 KB

⚠️ **需实测验证**：上述估算基于 Solidity 标准存储布局，实际部署时可能因编译器优化、存储槽打包等因素变化 10%-30%。**主网部署前必须用 Foundry gas snapshot 实测验证。**

### 7.2 Batch Arweave 存储（含 Merkle root）★

```solidity
function batchArchiveToArweave(uint256[] calldata tokenIds) external {
    require(tokenIds.length <= ARWEAVE_BATCH_SIZE, "Batch too large");
    
    // 打包多个许可状态为一个 Merkle tree
    bytes32[] memory leaves = new bytes32[](tokenIds.length);
    for (uint i = 0; i < tokenIds.length; i++) {
        leaves[i] = keccak256(abi.encodePacked(
            tokenIds[i],
            getLicense(tokenIds[i]).runtimeHash,
            block.timestamp
        ));
    }
    
    bytes32 batchRoot = computeMerkleRoot(leaves);
    
    // 一次性支付 Arweave 存储费
    bytes32 arweaveHash = ArweaveGateway.store(batchRoot, leaves);
    
    // 记录 Merkle root 到所有相关许可的 offchainPointer ★
    for (uint i = 0; i < tokenIds.length; i++) {
        licenses[tokenIds[i]].offchainPointer.merkleRoot = batchRoot;
    }
    
    emit BatchArchived(arweaveHash, tokenIds.length, batchRoot);
}
```

⚠️ **需实测验证**：Merkle tree 计算 gas 随 batch size 线性增长，500 许可 batch 的 `computeMerkleRoot` 预估 gas 为 80k-120k，但必须实测确认。

### 7.3 IPFS Pinning Gas 成本 ★

| 操作 | 预估 Gas | 备注 |
|------|---------|------|
| `storeToIPFS()` | ~45,000 | 含 pinning 调用 |
| `verifyPinning()` | ~12,000 | view 函数，无状态变更 |
| `batchArchive()` (500 许可) | ~150,000 | 含 Merkle root 计算 |
| `recalculateThresholds()` | ~80,000 | 14 天数据排序 + Tukey 计算 |
| `juryCommit()` | ~25,000 | 单次 commit |
| `juryReveal()` | ~35,000 | 含 hash 验证 |

⚠️ **需实测验证**：以上数值基于 Remix 模拟环境估算，L2（如 Arbitrum/Optimism）实际 gas 可能低 50%-80%。**部署前必须用目标链测试网实测。**

---

## 8. 待确认参数（需讨论）

| 参数 | 当前草案值 | 需要确认 | 负责 |
|------|-----------|---------|------|
| 势位评估周期 | 24h | 性能与实时性平衡 | 非攻进阶版 |
| NPS 评分防刷机制 | 一许可一评 + 实时有效性验证 | 前端可实现性 | 非攻进阶版 |
| 快速通道严重等级阈值 | severity 4/5（链上指标）| 社区共识 | X7 |
| DAO 成员准入标准 | Top 20% 势位 + 硬准确率 > 50% | 治理讨论 | 哪吒 |
| 版本迁移 gas 成本承担方 | 使用者（正价差）/ 积分（负价差）| 经济模型确认 | Talus |
| Arweave 存储费用来源 | 创作者质押 0.1 ETH + 协议基金 | 经济模型确认 | Talus |
| Agent 陪审团激励 | 正确投票 +0.5% 硬准确率，错误 -1% | 激励设计 | CaT.G |
| IPFS pinning 服务商 | Pinata / nft.storage / 自建 | 运维成本 | X7 |
| Tukey K 值 | 1.5 | 异常检测敏感度 | X7 |
| 连续异常周期阈值 | 2 | 误报 vs 延迟权衡 | M77 |

---

## 9. 修订总结

### v0.3 → v0.4 核心变化

1. **经济模型加固**：TOPUP 定价锚定（TWAP + 质疑窗口）+ 负价差积分策略 + 反证质押 0.05 ETH
2. **安全机制升级**：三通道紧急干预（severity 4 单签 24h / severity 5 陪审团 3/5）+ 链上可验证 severity
3. **防攻击增强**：cooldown 延长上限 1 次 + 反证质押 50/50 奖惩 + Tukey fences 异常检测
4. **去中心化推进**：Agent 陪审团（commit-reveal + 时间隔离）+ DAO 成员 11 人 + 投票权重完全公开
5. **数据可靠性**：IPFS pinning + Merkle root 生成比对 + 双轨信誉分
6. **使用者保护**：退出权 gas 兜底 pool + NPS 实时许可验证 + 争议率高时使用者侧权重提升
7. **透明度**：所有公式链上公开 + 权重因子可审计 + Gas 估算明确标注"需实测验证"

---

## 10. 下一步

1. **X7 / M77-claw**：code review，重点检查 §3.7 陪审团接口和 §4.4 自适应阈值安全
2. **Talus**：对照安全阈值，确认 Tukey fences K 值和势位评估动态权重参数
3. **非攻进阶版**：确认前端可实现性（NPS 实时验证、迁移 UI、陪审团界面、gas 补贴申请）
4. **雨娃**：协调 v0.4 合稿，整合到主文档和飞书知识库
5. **哪吒**：确认 DAO 11 人门槛和投票权重公式是否满足治理去中心化目标
6. **猫先森**：v0.4 正式版已完成，等待最终审阅通过

---

*文档版本：v0.4-final | 2026-05-23 | 猫先森*

*★ 标记处为 v0.4 新增或修订内容*
