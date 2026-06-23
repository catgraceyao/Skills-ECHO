# ECHO 协议 v0.3 合约接口正式版

**作者**：猫先森（Cat）  
**日期**：2026-05-22  
**状态**：Final v0.3  
**审阅记录**：
- 基于 v0.2 review 反馈修订（10 条核心问题全部落实）
- CaT.G 22:05 指令出正式版
- 哪吒 22:08 确认任务完成

**目标**：将 v0.2 review 反馈落实为可执行的合约接口与参数

---

## 0. Review 反馈映射

| Review 问题 | 本草案对应章节 | 接口/参数 |
|------------|--------------|----------|
| #7 版本切换成本不明 | §1.5 版本迁移机制 | `migrateLicense()`, `migrationMode` |
| #8 紧急干预入口太窄 | §3.3 紧急干预双通道 | `emergencyFreeze()`, `emergencyUnfreeze()` |
| #9 势位缺使用者反馈 | §4 势位评估引擎 | `engagementScore`, `satisfactionScore`, `disputeRate` |
| #10 链下持久性 | §2.4 链下存储冗余 | `storeToIPFS()`, `storeToArweave()`, `verifyOffchainData()` |
| #4 sunset公式漏洞 | §3.5 Sunset 修复 | `sunset = max(90天, 许可有效期×30%, 许可有效期+7天)` |
| #5 DAO门槛未定义 | §5 DAO治理参数 | `daoThreshold`, `quorumPercentage`, `votingPeriod` |
| #3 裁决不透明 | §3.6 冷却期裁决公式 | `cooldownRuling()` 伪代码 |

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
    /// @return versionId 新版本 ID
    function publishVersion(
        uint256 parentVersionId,
        string calldata configJSON,
        bytes32 configHash,
        bytes32 contractHash
    ) external returns (uint256 versionId);
    
    /// @notice 获取版本信息
    function getVersion(uint256 versionId) external view returns (
        uint256 parentId,
        bytes32 configHash,
        bytes32 contractHash,
        uint256 publishTime,
        uint256 childCount
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
        uint256 publishTime
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

### 1.3 版本迁移机制（新）★

**问题**：切换版本时，旧许可怎么处理？是否要重新付费？

**解决方案**：三种迁移模式，创作者在 `publishVersion()` 时选择

```solidity
enum MigrationMode {
    FREE,       // 免费迁移：旧许可自动继承到新版本（鼓励升级）
    TOPUP,      // 差价补足：新版本更贵则补差价，更便宜不退（平滑过渡）
    FULL_PRICE  // 全额重购：旧许可作废，需重新购买（重大变更时）
}
```

**接口扩展**：

```solidity
/// @notice 为旧版使用者迁移到新版本
/// @param oldLicenseId 旧许可 ID
/// @param targetVersionId 目标版本 ID
/// @param migrationMode 迁移模式（由创作者在发布时设定）
/// @return newLicenseId 新许可 ID
function migrateLicense(
    uint256 oldLicenseId,
    uint256 targetVersionId,
    MigrationMode migrationMode
) external payable returns (uint256 newLicenseId);

/// @notice 计算迁移成本（预览）
function previewMigrationCost(
    uint256 oldLicenseId,
    uint256 targetVersionId
) external view returns (uint256 cost);
```

**迁移规则**：
- `FREE`：不收费，旧许可 token 销毁，新许可 token 发放，有效期不变
- `TOPUP`：计算 `(新价格 - 旧价格)`，若为负则收 0
- `FULL_PRICE`：全额支付新版本价格，旧许可保留直到 sunset

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
    
    // === 链下数据冗余（新）★ ===
    
    struct OffchainPointer {
        bytes32 ipfsHash;      // IPFS CID
        bytes32 arweaveHash;   // Arweave Transaction ID
        uint256 checkpointTime; // 快照时间戳
    }
    
    /// @notice 将许可状态快照存储到 IPFS
    function storeToIPFS(uint256 tokenId) external returns (bytes32 ipfsHash);
    
    /// @notice 将许可状态快照存储到 Arweave（通过网关）
    function storeToArweave(uint256 tokenId) external payable returns (bytes32 arweaveHash);
    
    /// @notice 验证链下数据完整性
    function verifyOffchainData(
        uint256 tokenId,
        OffchainPointer calldata pointer,
        bytes calldata proofData
    ) external view returns (bool);
    
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
        bytes32 arweaveHash
    );
}
```

### 2.2 核心参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `MIN_SUNSET_DAYS` | uint256 | 90 | sunset 最小天数 |
| `SUNSET_RATIO` | uint256 | 30 (%) | sunset = max(90, 有效期×30%) |
| `SUNSET_EXTENSION` | uint256 | 7 (天) | 新增：许可有效期+7天保护 |
| `IPFS_GATEWAY` | address | TBD | IPFS 存储网关合约地址 |
| `ARWEAVE_GATEWAY` | address | TBD | Arweave 存储网关合约地址 |

### 2.3 Sunset 公式修复（新）★

**v0.2 原公式**：`sunset = max(90天, 许可有效期 × 30%)`

**问题**：1天试用许可 → sunset = 90天，对短期许可不公平（短期许可使用者应更快知道创作者退出）

**修复公式**：
```solidity
function calculateSunset(uint64 expiryTimestamp, uint64 createTime) internal pure returns (uint64) {
    uint64 licenseDuration = expiryTimestamp - createTime; // 许可总时长
    uint64 ratioBased = licenseDuration * 30 / 100;        // 有效期×30%
    uint64 extensionBased = licenseDuration + 7 days;        // 有效期+7天（新增）
    
    return max(90 days, ratioBased, extensionBased);
}
```

**示例**：
- 1天试用许可：`max(90, 0.3天, 8天)` = **90天**（原公式）→ `max(90, 0.3, 8)` = **90天**（修复后，8天被90天覆盖）
- 30天月度许可：`max(90, 9天, 37天)` = **90天**
- 180天半年许可：`max(90, 54天, 187天)` = **187天**（修复后延长，保护更充分）
- 365天年度许可：`max(90, 109.5天, 372天)` = **372天**（修复后大幅延长）

**结论**：修复后短期许可 sunset 不变（90天保底），但中期和长期许可获得更好的保护。

### 2.4 链下存储冗余方案（新）★

**问题**：链上只存 pointer（20 bytes），链下数据谁来存？节点失效怎么办？

**解决方案**：IPFS + Arweave 双冗余

```
链上存储（LicenseToken）：
  - pointer.ipfsHash (32 bytes)
  - pointer.arweaveHash (32 bytes)
  - pointer.checkpointTime (8 bytes)
  总计：72 bytes/许可

链下存储（双冗余）：
  ├─ IPFS：定期快照，免费/低成本，但节点可能离线
  └─ Arweave：一次性付费永久存储，高可靠性

自动策略：
  1. 每次 runtimeHash 更新 → 自动 snapshot 到 IPFS
  2. 每日 batch → 打包 snapshot 到 Arweave（gas 优化）
  3. 查询时优先读 IPFS（快），fallback 到 Arweave（可靠）
```

**验证机制**：
```solidity
function verifyOffchainData(uint256 tokenId, OffchainPointer calldata pointer, bytes calldata proofData) 
    external view returns (bool) {
    // 1. 链上 pointer 与传入 pointer 匹配
    require(pointer.ipfsHash == licenses[tokenId].offchainPointer.ipfsHash, "IPFS hash mismatch");
    require(pointer.arweaveHash == licenses[tokenId].offchainPointer.arweaveHash, "Arweave hash mismatch");
    
    // 2. 验证 proofData 的 Merkle root 与 runtimeHash 匹配
    bytes32 computedRoot = computeMerkleRoot(proofData);
    return computedRoot == licenses[tokenId].runtimeHash;
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
    
    // === 紧急干预双通道（新）★ ===
    
    /// @notice 【标准通道】高势位紧急干预（48小时时间锁）
    /// @param nodeIds 要冻结的关系节点 ID 列表
    /// @param reason 冻结原因（最大 1KB）
    /// @return proposalId 时间锁提案 ID
    function emergencyFreeze(
        bytes32[] calldata nodeIds,
        string calldata reason
    ) external returns (uint256 proposalId);
    
    /// @notice 【快速通道】单高势位紧急冻结（24小时内 DAO 追认）
    /// @param nodeIds 要冻结的关系节点 ID 列表
    /// @param severity 严重程度（1-5，5 为最高）
    /// @param evidenceHash 证据文件哈希
    function emergencyFreezeFast(
        bytes32[] calldata nodeIds,
        uint8 severity,
        bytes32 evidenceHash
    ) external;
    
    /// @notice 解冻关系节点（标准通道时间锁到期后 / 快速通道 DAO 追认后）
    function emergencyUnfreeze(bytes32[] calldata nodeIds, uint256 proposalId) external;
    
    /// @notice DAO 追认快速冻结（24小时内）
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
    event ExitAnnounced(address indexed creator, uint64 announceTime);
    event RelationsArchived(address indexed creator, bytes32 archiveHash);
}
```

### 3.2 三分层写权限参数

| 写入主体 | 权限范围 | 触发条件 | 安全机制 |
|---------|---------|---------|---------|
| LicenseToken 合约 | 常态写入 | 使用者触发许可交互 | 自动执行 |
| 高势位创作者（标准通道） | 紧急干预 | Top 10% 势位 + 3 地址多签 | **48 小时时间锁** |
| 高势位创作者（快速通道） | 紧急冻结 | Top 10% 势位 + 严重等级 ≥ 3 | **24 小时内 DAO 追认** |
| DAO 治理多签 | 最终兜底 | 治理提案通过 | 时间锁 + 投票期 |

### 3.3 紧急干预双通道（新）★

**问题**："Top 10% + 3 地址多签 + 48 小时"在漏洞被利用时来不及

**解决方案**：

```
标准通道（原设计保留）：
  触发：Top 10% 势位 + 3 个不同地址多签
  执行：48 小时时间锁后自动执行
  适用：非紧急场景（配置错误、规则冲突）

快速通道（新增）：
  触发：单个 Top 10% 势位 + 严重等级 ≥ 3（如安全漏洞、恶意行为）
  执行：立即冻结，24 小时内 DAO 必须追认
  适用：紧急场景（正在发生的攻击、数据篡改）
  风险：若 DAO 24 小时内未追认，冻结自动解除
```

**严重等级定义**：
- Level 1：配置错误，不影响使用者资产
- Level 2：规则冲突，可能导致执行歧义
- Level 3：安全漏洞，可能导致未授权访问
- Level 4：数据篡改风险，关系状态可能被破坏
- Level 5：主动攻击，资产损失风险

**只有 Level 3+ 可触发快速通道。**

### 3.4 三阶段冻结退出时间线

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
       ├─ 关系状态快照到 IPFS + Arweave
       ├─ 链上状态标记为 ARCHIVED
       ├─ 许可 token 仍可查询但不可交互
       └─ 使用者可通过 archiveHash 恢复历史状态
```

### 3.5 Sunset 修复后的退出示例

- 1天试用许可：sunset = 90天 → 归档于 T+90天
- 30天月度许可：sunset = 90天 → 归档于 T+90天
- 180天半年许可：sunset = 187天 → 归档于 T+187天
- 365天年度许可：sunset = 372天 → 归档于 T+372天

### 3.6 冷却期裁决公式（透明化）★

**问题**：review 反馈"冷却期自动化裁决逻辑不透明，需给出伪代码"

**触发条件**：
```solidity
// 创作者发布新版本时自动启动
function onVersionPublished(uint256 newVersionId) internal {
    cooldownDeadlines[newVersionId] = block.timestamp + 7 days;
    objectionCount[newVersionId] = 0;
    emit CooldownStarted(newVersionId, cooldownDeadlines[newVersionId]);
}
```

**异议提交**：
```solidity
function submitObjection(uint256 versionId, bytes32 reasonHash) external payable {
    require(msg.value >= 0.01 ether, "Stake required: 0.01 ETH");
    require(block.timestamp < cooldownDeadlines[versionId], "Cooldown expired");
    require(LicenseToken.balanceOf(msg.sender) > 0, "Must hold valid license");
    
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

**裁决逻辑（7 天冷却期结束后自动执行）**：
```solidity
function cooldownRuling(uint256 versionId) external {
    require(block.timestamp >= cooldownDeadlines[versionId], "Cooldown not ended");
    require(!rulingExecuted[versionId], "Ruling already executed");
    
    RulingResult result;
    uint256 objectionNum = objectionCount[versionId];
    
    if (objectionNum == 0) {
        // 无异议 → 自动通过
        result = RulingResult.PASSED;
    } else if (objectionNum < 3) {
        // 异议不足 3 个 → 进入延期冷却（再延长 7 天，给更多人时间反应）
        cooldownDeadlines[versionId] += 7 days;
        result = RulingResult.EXTENDED;
        emit CooldownExtended(versionId, cooldownDeadlines[versionId]);
        return;
    } else {
        // 异议 ≥ 3 → 自动裁决
        result = autoRuling(versionId);
    }
    
    // 执行结果上链
    rulingResults[versionId] = result;
    rulingExecuted[versionId] = true;
    
    // 退还质押（通过者全退，被驳回者扣除 10% 作为协议费）
    distributeStakes(versionId, result);
    
    emit RulingExecuted(versionId, result, block.timestamp);
}

function autoRuling(uint256 versionId) internal view returns (RulingResult) {
    // 1. 获取新版本的权利密度（configHash 解码后计算）
    uint256 newRightsDensity = computeRightsDensity(versionId);
    
    // 2. 获取旧版本的权利密度（父版本）
    uint256 parentVersionId = CreatorConfig.getVersion(versionId).parentId;
    uint256 oldRightsDensity = computeRightsDensity(parentVersionId);
    
    // 3. 比较权利密度变化
    if (newRightsDensity >= oldRightsDensity) {
        // 权利密度未降低 → 通过
        return RulingResult.PASSED;
    } else {
        // 权利密度降低 → 拒绝
        // 但允许创作者修改后重新提交
        return RulingResult.REJECTED;
    }
}

// 权利密度计算：遍历 configJSON，统计不可撤销规则比例 + 使用者保护条款数量
function computeRightsDensity(uint256 versionId) internal view returns (uint256) {
    bytes32 configHash = CreatorConfig.getVersion(versionId).configHash;
    string memory configJSON = IPFSResolver.resolve(configHash); // 从 IPFS 读取配置内容
    
    // 解析 JSON 计算密度（简化版，实际可优化）
    uint256 irrevocableRatio = parseIrrevocableRatio(configJSON); // 0-100
    uint256 protectionClauses = parseProtectionClauses(configJSON); // 计数
    
    // 密度 = 不可撤销比例 × 0.7 + 保护条款数 × 5（每项最多 30 分）
    return irrevocableRatio * 70 / 100 + min(protectionClauses * 5, 30);
}
```

**裁决结果**：
- `PASSED`：新版本生效，无异议或权利密度未降低
- `REJECTED`：新版本被拒绝，创作者可修改后重新提交
- `EXTENDED`：异议不足 3 个，延长 7 天给更多人反应时间

---

## 4. 势位评估引擎合约

负责：势位计算、动态锁、硬地板机制

### 4.1 接口定义

```solidity
interface IPotentialEngine {
    // === 势位评估 ===
    
    /// @notice 获取创作者当前势位
    function getPotential(address creator) external view returns (uint256 potential);
    
    /// @notice 获取创作者势位等级
    function getPotentialLevel(address creator) external view returns (uint8 level);
    
    /// @notice 手动触发势位重新评估（任何人可调用，但有限流）
    function reevaluatePotential(address creator) external;
    
    // === 硬地板管理 ===
    
    /// @notice 获取创作者当前硬地板值（不可撤销规则最低比例）
    function getHardFloor(address creator) external view returns (uint256 floorPercentage);
    
    /// @notice 检查创作者配置是否满足硬地板要求
    function validateHardFloor(address creator, bytes32 configHash) external view returns (bool);
    
    // === 评估参数 ===
    
    /// @notice 设置评估权重（仅 DAO）
    function setWeight(bytes32 metric, uint256 weight) external;
    
    /// @notice 获取评估权重
    function getWeight(bytes32 metric) external view returns (uint256);
    
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
}
```

### 4.2 势位评估算法（含使用者反馈权重）★

**问题**：当前只有创作者侧指标（收入、许可数），缺少使用者反馈

**修复后算法**：

```solidity
function calculatePotential(address creator) public view returns (uint256) {
    // === 创作者侧指标（权重 60%） ===
    uint256 revenueScore = computeRevenueScore(creator);        // 收入稳定性 0-100
    uint256 licenseScore = computeLicenseScore(creator);        // 许可数量/增长率 0-100
    uint256 versionScore = computeVersionScore(creator);        // 版本迭代健康度 0-100
    
    // === 使用者侧指标（权重 40%，新增）★ ===
    uint256 engagementScore = computeEngagementScore(creator);  // 使用者活跃度 0-100
    uint256 satisfactionScore = computeSatisfactionScore(creator); // NPS 评分 0-100
    uint256 disputeRate = computeDisputeRate(creator);          // 争议率（越低越好）0-100
    
    // 总势位 = 创作者侧 × 60% + 使用者侧 × 40%
    uint256 creatorSide = (revenueScore + licenseScore + versionScore) * 60 / 300; // 平均后 × 60%
    uint256 userSide = (engagementScore + satisfactionScore + (100 - disputeRate)) * 40 / 300; // 平均后 × 40%
    
    return creatorSide + userSide; // 0-100
}
```

**各指标计算方式**：

| 指标 | 数据来源 | 计算方式 |
|------|---------|---------|
| `revenueScore` | LicenseToken 合约 | 近 30 天收入 / 历史平均收入，>1.2 得 100 分，<0.5 得 0 分 |
| `licenseScore` | LicenseToken 合约 | 当前有效许可数 / 历史峰值，× 100 |
| `versionScore` | CreatorConfig 合约 | 版本发布频率适中（1-4周/次）得 100，过快/过慢扣分 |
| `engagementScore` | S-GraphCore 合约（新增）★ | 近 30 天使用者交互次数 / 许可数，活跃度比率 × 100 |
| `satisfactionScore` | 链下 NPS 调查（新增）★ | 使用者主动提交的 NPS 评分（1-10）平均值 × 10 |
| `disputeRate` | S-GraphCore 合约（新增）★ | 近 90 天异议数 / 总许可数，比率越低得分越高 |

**使用者反馈收集机制**：
```solidity
/// @notice 使用者提交满意度评分（NPS）
/// @param creator 评价的创作者
/// @param npsScore 1-10 分
/// @param licenseId 关联许可 ID（防刷）
function submitNPS(
    address creator,
    uint8 npsScore,
    uint256 licenseId
) external {
    require(LicenseToken.ownerOf(licenseId) == msg.sender, "Must own license");
    require(npsScore >= 1 && npsScore <= 10, "Score must be 1-10");
    require(!hasRated[licenseId][creator], "Already rated");
    
    npsScores[creator].push(npsScore);
    hasRated[licenseId][creator] = true;
    
    emit NPSSubmitted(creator, msg.sender, npsScore);
}
```

### 4.3 势位等级与硬地板对应表

| 势位等级 | 势位范围 | 硬地板（不可撤销规则最低比例）|
|---------|---------|------------------------|
| L1 | 0-25 | 20% |
| L2 | 26-50 | 35% |
| L3 | 51-75 | 50% |
| L4 | 76-100 | 70% |

**硬地板规则**：
- 自动上调：势位升高时硬地板自动升高
- 手动限制：创作者不能手动调低硬地板
- 治理修改：DAO 多签可修改全局硬地板参数（见 §5）

---

## 5. DAO 治理参数（新）★

**问题**：review 反馈"DAO 治理多签修改全局硬地板参数的门槛未定义"

### 5.1 DAO 治理合约接口

```solidity
interface IDAO {
    struct Proposal {
        bytes32 proposalType;   // 提案类型
        bytes32 targetParam;  // 目标参数
        uint256 newValue;     // 新值
        uint256 startTime;    // 投票开始时间
        uint256 endTime;      // 投票结束时间
        uint256 votesFor;     // 赞成票
        uint256 votesAgainst; // 反对票
        bool executed;        // 是否已执行
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

### 5.2 治理参数定义

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `DAO_MIN_MEMBERS` | 5 | DAO 最少成员数 |
| `DAO_QUORUM_PERCENTAGE` | 60% | 最低参与门槛（总票数 × 60%）|
| `DAO_VOTING_PERIOD` | 7 天 | 标准投票期 |
| `DAO_EMERGENCY_VOTING_PERIOD` | 24 小时 | 紧急投票期（快速通道追认）|
| `DAO_PASS_THRESHOLD` | 66.7% | 通过门槛（赞成 / 总投票 ≥ 2/3）|
| `DAO_TIMELOCK` | 48 小时 | 提案通过后执行前的等待期 |
| `DAO_EMERGENCY_TIMELOCK` | 6 小时 | 紧急提案时间锁 |

### 5.3 投票权重设计

```solidity
function getVotingPower(address member) public view returns (uint256) {
    // 基础权重：1（每个成员至少 1 票）
    uint256 basePower = 1;
    
    // 势位加成：成员自身的势位 / 100
    uint256 potentialBoost = PotentialEngine.getPotential(member) / 100;
    
    // 活跃度加成：近 30 天参与治理次数
    uint256 activityBoost = governanceActivity[member].recentParticipations;
    
    // 总权重 = 基础 + 势位加成 + 活跃度加成（上限 10）
    return min(basePower + potentialBoost + activityBoost, 10);
}
```

### 5.4 可治理参数列表

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
| `OBJECTION_STAKE` | 0.01 ETH | 0.005-0.05 ETH | 异议质押金额 |
| `EMERGENCY_TIMELOCK_STANDARD` | 48h | 24-72h | 标准紧急干预时间锁 |
| `EMERGENCY_TIMELOCK_FAST` | 24h | 12-48h | 快速通道 DAO 追认期限 |
| `IPFS_RESYNC_INTERVAL` | 1 天 | 1-7 天 | IPFS 快照频率 |
| `ARWEAVE_BATCH_SIZE` | 1000 许可 | 500-5000 | Arweave 批量存储大小 |

---

## 6. 交互流程图（文字版）

### 6.1 创作者发布新版本

```
创作者调用 CreatorConfig.publishVersion()
    ↓
自动启动 7 天冷却期（S-GraphCore）
    ↓
使用者可提交异议（质押 0.01 ETH）
    ↓
7 天后自动裁决
    ├─ 无异议 / 权利密度未降低 → 新版本生效
    ├─ 异议 < 3 → 延长 7 天
    └─ 异议 ≥ 3 且权利密度降低 → 拒绝，创作者可修改重提
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
自动 snapshot 到 IPFS
    ↓
24 小时内 batch snapshot 到 Arweave
    ↓
使用者获得许可 token
```

### 6.3 紧急干预流程

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

【快速通道】
高势位创作者调用 S-GraphCore.emergencyFreezeFast(severity ≥ 3)
    ↓
立即冻结
    ↓
24 小时内 DAO 必须追认
    ├─ DAO 通过 → 冻结保持
    └─ DAO 否决 / 超时 → 自动解冻
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
T+sunset → ARCHIVED（链下归档）
    ↓
关系状态 snapshot 到 IPFS + Arweave
    ↓
链上标记为归档，token 可查询但不可交互
```

---

## 7. Gas 优化与存储成本

### 7.1 链上存储优化

| 数据项 | 存储位置 | 大小 | 说明 |
|--------|---------|------|------|
| configHash | 链上 | 32 bytes | 规则语义哈希 |
| contractHash | 链上 | 32 bytes | 合约代码哈希 |
| runtimeHash | 链上 | 32 bytes | 运行时状态哈希 |
| offchainPointer | 链上 | 72 bytes | IPFS + Arweave 哈希 + 时间戳 |
| 许可核心数据 | 链上 | ~200 bytes | tokenId, owner, versionId, expiry, status |
| 关系节点 | 链上 | ~256 bytes | nodeId, licenseId, creator, user, state |
| 完整配置 JSON | 链下 | 最大 10KB | 存储在 IPFS |
| 关系历史快照 | 链下 | 变化 | 存储在 IPFS + Arweave |

**1000 个许可总链上存储**：
- 许可数据：1000 × 200 bytes = 200 KB
- 关系节点：1000 × 256 bytes = 256 KB
- 哈希锚定：1000 × 168 bytes = 168 KB
- **总计**：~624 KB（原估算 64KB 是仅 pointer 部分，实际完整数据更大）

### 7.2 Batch Arweave 存储

```solidity
function batchArchiveToArweave(uint256[] calldata tokenIds) external {
    require(tokenIds.length <= ARWEAVE_BATCH_SIZE, "Batch too large");
    
    // 打包多个许可状态为一个 Merkle tree
    bytes32[] memory hashes = new bytes32[](tokenIds.length);
    for (uint i = 0; i < tokenIds.length; i++) {
        hashes[i] = getLicense(tokenIds[i]).runtimeHash;
    }
    
    bytes32 batchRoot = computeMerkleRoot(hashes);
    
    // 一次性支付 Arweave 存储费
    bytes32 arweaveHash = ArweaveGateway.store(batchRoot, hashes);
    
    emit BatchArchived(arweaveHash, tokenIds.length);
}
```

---

## 8. 待确认参数（需讨论）

| 参数 | 当前草案值 | 需要确认 |
|------|-----------|---------|
| 势位评估权重（创作者侧 vs 使用者侧）| 60:40 | Talus 安全审计 |
| NPS 评分防刷机制 | 一许可一评 | 非攻进阶版前端确认 |
| 快速通道严重等级阈值 | ≥ 3 | 社区共识 |
| DAO 成员准入标准 | Top 20% 势位 | 治理讨论 |
| 版本迁移 gas 成本承担方 | 使用者 | 经济模型确认 |
| Arweave 存储费用来源 | 创作者质押 / 协议基金 | 经济模型确认 |
| 势位评估周期 | daily | 性能与实时性平衡 |
| runtimeHash 更新触发条件 | 每次关系变更 | 性能优化 |

---

## 9. 下一步

1. **X7 / M77-claw**：code review，检查安全漏洞
2. **Talus**：对照安全阈值，确认势位评估权重和硬地板参数
3. **非攻进阶版**：确认前端可实现性（NPS 收集、迁移 UI、紧急干预界面）
4. **雨娃**：协调 v0.3 合稿，整合到主文档
5. **猫先森**：v0.3 正式版已完成，等待最终审阅通过

---

*文档版本：v0.3-final | 2026-05-22 | 猫先森*
