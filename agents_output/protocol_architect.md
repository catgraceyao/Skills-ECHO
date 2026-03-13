# Echo Protocol 技术架构设计

## 版本: v2.0
## 日期: 2026-03-14
## 架构师: Echo Protocol 技术团队
## 更新说明: 从 ERC721 扩展重构为原生 ECHO 协议实现

---

# 重要声明: ECHO ≠ ERC721

**ECHO 是一个全新的产权分离协议，不是 ERC721 的扩展。**

| 特性 | ERC721 | ECHO Protocol |
|------|--------|---------------|
| 资产模型 | 单一所有权 (ownerOf) | 产权分离 (所有权/使用权/衍生权/扩展权) |
| 权利粒度 | 整枚 Token | 可拆分交易 |
| 引用关系 | 无原生支持 | 链上原生衍生树 |
| 分润机制 | 无 | 多层级自动分润 |
| 兼容性 | 标准 NFT | 可选 ERC721 包装器 |

**设计原则**: ECHO 协议是底层实现，ERC721 只是可选的兼容性接口。原生 ECHO 资产不依赖 ERC721。

---

# 一、资产 Schema 设计

## 1.1 核心数据结构 (Solidity)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EchoAsset
 * @notice Echo Protocol 核心资产结构
 * @dev 注意: 这不是 ERC721 扩展，是独立协议
 */
struct EchoAsset {
    // 基础信息
    uint256 assetId;           // 唯一标识 (非 tokenId)
    address creator;           // 创作者地址 (永久不变)
    uint256 createdAt;         // 铸造时间戳
    string metadataURI;        // IPFS/Arweave 上的元数据链接
    
    // 资产内容
    string audioHash;          // 音频文件内容哈希 (IPFS CID)
    uint256 duration;          // 音频时长 (秒)
    string title;              // 作品标题
    string description;        // 作品描述
    
    // 引用关系
    uint256[] parents;         // 引用的父资产 ID 数组 (支持多父引用)
    uint256 version;           // 版本号 (原创=1，每次衍生+1)
    DerivationType derivationType; // 衍生类型
    
    // 权属定价 (单位: wei 或自定义代币)
    RightsPricing pricing;
    
    // 状态
    AssetStatus status;        // ACTIVE, FROZEN, BURNED
}

/**
 * @notice 权属分离结构 - ECHO 核心创新
 * @dev 所有权/使用权/衍生权/扩展权 独立记录
 */
struct RightsHolders {
    address owner;             // 所有权持有者 (可转让)
    mapping(address => uint256) usageExpires;  // 使用者 -> 到期时间戳
    mapping(address => bool) hasDerivativeRight; // 拥有衍生权的钱包
    mapping(address => bool) hasExtensionRight;  // 拥有扩展权的钱包
}

/**
 * @notice 权属定价结构
 */
struct RightsPricing {
    uint256 ownershipPrice;    // 所有权价格 (买断)
    uint256 usagePrice;        // 单次使用权价格
    uint256 derivativePrice;   // 衍生权价格 (获得创建衍生作品的许可)
    uint256 extensionPrice;    // 扩展权价格
}

/**
 * @notice 衍生类型枚举
 */
enum DerivationType {
    ORIGINAL,   // 原创作品
    REMIX,      // 混音
    SAMPLE,     // 采样
    COVER,      // 翻唱
    EXTEND      // 扩展/续作
}

/**
 * @notice 资产状态枚举
 */
enum AssetStatus {
    ACTIVE,    // 正常可用
    FROZEN,    // 冻结 (争议或创作者主动冻结)
    BURNED     // 已销毁
}
```

## 1.2 与 ERC721 的核心差异

### ERC721 所有权模型
```solidity
// ERC721: 单一 owner
function ownerOf(uint256 tokenId) external view returns (address);
// 一个人拥有整枚 NFT，其他人只能看
```

### ECHO 产权分离模型
```solidity
// ECHO: 多维权利
function getOwner(uint256 assetId) external view returns (address);
function hasUsageRight(uint256 assetId, address user) external view returns (bool);
function hasDerivativeRight(uint256 assetId, address user) external view returns (bool);
function hasExtensionRight(uint256 assetId, address user) external view returns (bool);
// 同一份资产，不同人拥有不同权利
```

## 1.3 引用关系图存储设计

```solidity
/**
 * @notice 引用关系存储优化方案
 * @dev 为了节省 Gas，采用双向指针 + 事件日志的设计
 */
contract EchoRegistry {
    // ========== ECHO 原生资产存储 ==========
    mapping(uint256 => EchoAsset) public assets;
    mapping(uint256 => RightsHolders) public rights;
    uint256 public nextAssetId;
    
    // 正向：资产 -> 它的直接子资产 (用于展示"被谁引用了")
    mapping(uint256 => uint256[]) public children;
    
    // 缓存：资产 -> 到根的路径哈希 (用于快速验证和分润计算)
    mapping(uint256 => bytes32) public lineageHash;
    
    // 全局衍生树根节点列表 (原创资产)
    uint256[] public originalAssets;
    
    // ========== 事件日志 ==========
    event AssetCreated(uint256 indexed assetId, address indexed creator, DerivationType dType);
    event AssetDerived(uint256 indexed childId, uint256 indexed parentId, DerivationType dType);
    event RightsTransferred(uint256 indexed assetId, RightsType rType, address from, address to);
    event UsageGranted(uint256 indexed assetId, address indexed user, uint256 expiresAt);
    
    enum RightsType { OWNERSHIP, USAGE, DERIVATIVE, EXTENSION }
}
```

### 引用关系查询优化

由于链上存储昂贵，完整的多层级树遍历不适合在合约中执行。采用**链下计算 + 链上验证**模式：

1. **链下索引器**：监听事件，在链下维护完整的衍生树结构
2. **链上验证**：只需验证直接父资产存在且有效
3. **分润计算**：由链下提交计算结果，链上合约验证路径有效性

```solidity
/**
 * @notice 分润路径证明结构
 * @dev 链下计算好路径后，提交此结构供合约验证
 */
struct LineageProof {
    uint256[] path;            // 从被购买资产到原创者的路径 [child, parent, grandparent, ..., original]
    bytes32[] merkleProofs;    // 各节点的 Merkle Proof (可选，用于高价值交易)
    uint256 totalDepth;        // 路径深度
}
```

---

# 二、多层级分润算法实现

## 2.1 合约核心逻辑

```solidity
/**
 * @title EchoDistributor
 * @notice 多层级分润核心合约
 */
contract EchoDistributor {
    // 参数 (可治理升级)
    uint256 public platformFeeRate = 1000;      // 10% = 1000/10000
    uint256 public directCreatorRate = 4000;    // 40%
    uint256 public upstreamPoolRate = 5000;     // 50%
    uint256 public originalGuarantee = 2500;    // 25% 原创者保底
    uint256 public decayFactor = 7000;          // 0.7 = 7000/10000
    
    address public platformTreasury;
    
    /**
     * @notice 执行分润
     * @param assetId 被购买的资产 ID
     * @param amount 支付金额
     * @param proof 链下计算好的分润路径证明
     */
    function distribute(
        uint256 assetId, 
        uint256 amount, 
        LineageProof calldata proof
    ) external payable {
        require(msg.value >= amount, "Insufficient payment");
        
        // 1. 平台手续费
        uint256 platformFee = amount * platformFeeRate / 10000;
        payable(platformTreasury).transfer(platformFee);
        
        uint256 netAmount = amount - platformFee;
        
        // 2. 直接创作者分成
        address directCreator = getCreator(assetId);
        uint256 directShare = netAmount * directCreatorRate / 10000;
        payable(directCreator).transfer(directShare);
        
        // 3. 上游分润池
        uint256 upstreamPool = netAmount * upstreamPoolRate / 10000;
        _distributeUpstream(upstreamPool, proof);
        
        emit DistributionCompleted(assetId, amount, proof.path);
    }
    
    /**
     * @notice 上游分润计算 (指数衰减模型)
     */
    function _distributeUpstream(uint256 pool, LineageProof calldata proof) internal {
        uint256 n = proof.path.length - 1; // 上游层级数
        if (n == 0) return; // 原创资产，无上游
        
        // 计算权重总和
        uint256 totalWeight = 0;
        uint256[] memory weights = new uint256[](n);
        
        for (uint256 i = 0; i < n; i++) {
            // weight[i] = decayFactor^i
            weights[i] = _pow(decayFactor, i);
            totalWeight += weights[i];
        }
        
        // 按权重分配
        uint256 originalShare = 0;
        for (uint256 i = 0; i < n; i++) {
            uint256 ancestorId = proof.path[i + 1]; // path[0]是被购买的资产
            address creator = getCreator(ancestorId);
            
            uint256 share = pool * weights[i] / totalWeight;
            
            // 原创者保底检查
            if (i == n - 1) { // 最后一个是最原创的
                uint256 minGuarantee = pool * originalGuarantee / 10000;
                if (share < minGuarantee) {
                    // 从其他上游重新分配，确保原创者拿够保底
                    share = minGuarantee;
                }
            }
            
            payable(creator).transfer(share);
        }
    }
    
    function _pow(uint256 base, uint256 exp) internal pure returns (uint256) {
        uint256 result = 10000; // 基数为 1.0
        for (uint256 i = 0; i < exp; i++) {
            result = result * base / 10000;
        }
        return result;
    }
}
```

## 2.2 分润流程图

```
用户支付 100 USDC 购买 Asset D 使用权
│
├─► 平台手续费 10 USDC (10%) ────────────────────────────► 平台国库
│
├─► 净收益池 90 USDC
    │
    ├─► 直接创作者 (Asset D) 36 USDC (40%) ─────────────► David
    │
    └─► 上游分润池 45 USDC (50%)
        │
        ├─► 父级 (Asset C) ──► 指数衰减权重 1.0 ────────► Charlie
        ├─► 祖父级 (Asset B) ──► 权重 0.7 ─────────────► Bob
        └─► 原创者 (Asset A) ──► 权重 0.49 + 保底补足 ─► Alice
```

---

# 三、智能合约架构

## 3.1 合约清单

| 合约 | 职责 | 说明 |
|------|------|------|
| **EchoCore** | ECHO 协议核心资产与权属管理 | ⭐ 主合约，不继承 ERC721 |
| **EchoRegistry** | 引用关系管理、资产元数据索引 | 关联 EchoCore |
| **EchoDistributor** | 分润逻辑、收益分配 | 关联 EchoCore |
| **EchoMarket** | 市场交易、定价、撮合 | 处理四维权利交易 |
| **EchoERC721Wrapper** | ERC721 兼容性包装器 | 可选，将 ECHO 资产包装为 ERC721 |
| **EchoGovernance** | 参数治理、升级控制 | OpenZeppelin Governor |

## 3.2 核心接口定义 (ECHO 原生)

```solidity
// IEchoCore.sol - ECHO 协议核心接口
interface IEchoCore {
    // ========== 资产生命周期 ==========
    function mintOriginal(EchoAsset calldata asset) external returns (uint256 assetId);
    function derive(uint256[] calldata parentIds, EchoAsset calldata asset) external returns (uint256 assetId);
    function burn(uint256 assetId) external;
    
    // ========== 权利查询 ==========
    function getAsset(uint256 assetId) external view returns (EchoAsset memory);
    function getOwner(uint256 assetId) external view returns (address);
    function hasUsageRight(uint256 assetId, address user) external view returns (bool);
    function hasDerivativeRight(uint256 assetId, address user) external view returns (bool);
    function hasExtensionRight(uint256 assetId, address user) external view returns (bool);
    function getLineage(uint256 assetId) external view returns (uint256[] memory);
    
    // ========== 权利转让 ==========
    function transferOwnership(uint256 assetId, address to) external;
    function grantUsage(uint256 assetId, address user, uint256 duration) external;
    function grantDerivativeRight(uint256 assetId, address user) external;
    function grantExtensionRight(uint256 assetId, address user) external;
    
    // ========== 事件 ==========
    event AssetMinted(uint256 indexed assetId, address indexed creator, DerivationType dType);
    event OwnershipTransferred(uint256 indexed assetId, address indexed from, address indexed to);
    event UsageGranted(uint256 indexed assetId, address indexed user, uint256 expiresAt);
}

// IEchoMarket.sol - ECHO 市场接口
interface IEchoMarket {
    function purchaseOwnership(uint256 assetId) external payable;
    function purchaseUsage(uint256 assetId, uint256 duration) external payable;
    function purchaseDerivativeRight(uint256 assetId) external payable;
    function purchaseExtensionRight(uint256 assetId) external payable;
    
    function listAsset(uint256 assetId, RightsPricing calldata pricing) external;
    function delistAsset(uint256 assetId) external;
    function updatePricing(uint256 assetId, RightsPricing calldata pricing) external;
}

// IEchoDistributor.sol - 分润接口
interface IEchoDistributor {
    function distribute(uint256 assetId, uint256 amount, LineageProof calldata proof) external payable;
    function claimPendingRewards() external;
    function getPendingRewards(address creator) external view returns (uint256);
}
```

## 3.3 ERC721 兼容性包装器 (可选)

```solidity
/**
 * @title EchoERC721Wrapper
 * @notice 将 ECHO 资产包装为 ERC721，兼容现有 NFT 基础设施
 * @dev 这是可选层，不是 ECHO 协议的核心
 */
contract EchoERC721Wrapper is ERC721Enumerable {
    IEchoCore public echoCore;
    
    // ECHO assetId => 包装后的 tokenId (1:1 映射)
    mapping(uint256 => uint256) public wrappedTokenIds;
    mapping(uint256 => uint256) public echoAssetIds;
    
    /**
     * @notice 包装 ECHO 资产为 ERC721
     * @dev 只有所有权持有者可以包装
     */
    function wrap(uint256 assetId) external returns (uint256 tokenId) {
        require(echoCore.getOwner(assetId) == msg.sender, "Not owner");
        
        tokenId = totalSupply() + 1;
        wrappedTokenIds[assetId] = tokenId;
        echoAssetIds[tokenId] = assetId;
        
        _mint(msg.sender, tokenId);
    }
    
    /**
     * @notice 解包恢复为原生 ECHO 资产
     */
    function unwrap(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        
        uint256 assetId = echoAssetIds[tokenId];
        delete wrappedTokenIds[assetId];
        delete echoAssetIds[tokenId];
        
        _burn(tokenId);
    }
    
    /**
     * @notice 重写 ownerOf，指向 ECHO 所有权
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        uint256 assetId = echoAssetIds[tokenId];
        return echoCore.getOwner(assetId);
    }
}
```

---

# 四、存储与部署方案

## 4.1 链上 vs 链下存储

| 数据类型 | 存储位置 | 理由 |
|----------|----------|------|
| 资产所有权 | 链上 (ECHO Core) | 核心确权，不可篡改 |
| 使用权/衍生权/扩展权 | 链上 (ECHO Core) | 权利分离的核心 |
| 引用关系 | 链上 (轻量) + 链下 (完整) | 链上存直接父，链下存完整树 |
| 音频文件 | IPFS/Arweave | 链上存 hash 验证完整性 |
| 元数据 (标题/描述) | IPFS | 节省 Gas，支持富文本 |
| 分润计算结果 | 链上 (验证) + 链下 (计算) | 复杂计算链下做，链上验证 |
| 波形数据 | 链下 | 纯展示用途，无链上必要 |

## 4.2 部署策略 (QNG TestNet)

```javascript
// hardhat deployment script - ECHO 原生部署
async function main() {
    // 1. 部署 ECHO Core 合约 (⭐ 主合约，不依赖 ERC721)
    const EchoCore = await ethers.getContractFactory("EchoCore");
    const echoCore = await EchoCore.deploy();
    await echoCore.deployed();
    console.log("EchoCore deployed:", echoCore.address);
    
    // 2. 部署 Registry
    const EchoRegistry = await ethers.getContractFactory("EchoRegistry");
    const registry = await EchoRegistry.deploy(echoCore.address);
    await registry.deployed();
    
    // 3. 部署 Distributor
    const EchoDistributor = await ethers.getContractFactory("EchoDistributor");
    const distributor = await EchoDistributor.deploy(echoCore.address);
    await distributor.deployed();
    
    // 4. 部署 Market
    const EchoMarket = await ethers.getContractFactory("EchoMarket");
    const market = await EchoMarket.deploy(
        echoCore.address,
        registry.address,
        distributor.address
    );
    await market.deployed();
    
    // 5. 设置权限
    await echoCore.setRegistry(registry.address);
    await echoCore.setDistributor(distributor.address);
    await echoCore.setMarket(market.address);
    
    // 6. (可选) 部署 ERC721 包装器 - 用于兼容 OpenSea 等平台
    const EchoERC721Wrapper = await ethers.getContractFactory("EchoERC721Wrapper");
    const wrapper = await EchoERC721Wrapper.deploy(echoCore.address);
    await wrapper.deployed();
    console.log("EchoERC721Wrapper deployed (optional):", wrapper.address);
    
    console.log("\n=== ECHO Protocol Deployment Complete ===");
    console.log("Core:", echoCore.address);
    console.log("Registry:", registry.address);
    console.log("Distributor:", distributor.address);
    console.log("Market:", market.address);
    console.log("ERC721 Wrapper (optional):", wrapper.address);
}
```

---

# 五、Gas 优化策略

## 5.1 高 Gas 场景及优化

| 场景 | 原方案 Gas 估算 | 优化方案 | 优化后 Gas |
|------|----------------|----------|-----------|
| 铸造原创资产 | ~120k | clone 模式 | ~80k |
| 铸造衍生作品 | ~150k + N*30k | 链下计算路径 | ~100k |
| 权利转让 (所有权) | ~30k | 直接状态更新 | ~25k |
| 权利转让 (使用权) | ~40k | 批量授权 | ~35k |
| 分润分发 (链长 N) | ~80k + N*15k | Merkle 验证 | ~60k + log(N)*10k |
| 查询引用树 | N 次 storage read | 链下索引器 | 0 次 |

## 5.2 关键优化技巧

1. **权利批量授权**
   ```solidity
   function batchGrantUsage(
       uint256 assetId, 
       address[] calldata users, 
       uint256 duration
   ) external {
       for (uint i = 0; i < users.length; i++) {
           _grantUsage(assetId, users[i], duration);
       }
   }
   ```

2. **使用 Merkle Tree 验证长链引用**
   - 链下构建完整的引用树 Merkle Root
   - 链上只需验证 Merkle Proof，O(logN) 复杂度

3. **累积收益模式**
   - 不每次交易都分发，而是记录应得份额
   - 创作者主动调用 `claim()` 领取，节省大部分交易的 Gas

---

# 六、技术白皮书 (面向开发者)

## 6.1 协议定位

Echo Protocol 是一个面向数字创作领域的**产权分离协议**。通过将资产的所有权、使用权、衍生权、扩展权解耦，配合多层级自动分润机制，实现创作生态的可持续激励。

**与 ERC721 的关系**: ECHO 是独立协议，ERC721 只是可选的兼容性包装。原生 ECHO 资产不依赖 ERC721 标准。

## 6.2 核心创新点

1. **引用图谱上链**：首创将创作引用关系原生记录在区块链上，形成不可篡改的衍生树
2. **多层级自动分润**：链上自动执行指数衰减分润，确保原创者在长尾引用中持续获益
3. **权属颗粒化**：支持所有权、使用权、衍生权、扩展权独立定价和交易
4. **产权分离架构**：同一份资产，不同参与者可拥有不同维度的权利

## 6.3 技术选型理由

- **EVM 兼容链**：开发者生态成熟，用户钱包普及度高
- **原生 ECHO 实现**：不依赖 ERC721，产权分离是协议原生能力
- **可选 ERC721 包装**：兼容现有 NFT 基础设施 (OpenSea, 钱包, 索引器)
- **IPFS/Arweave**：去中心化存储，与区块链的不可篡改特性一致
- **链下计算+链上验证**：在可验证性和 Gas 成本之间取得平衡

## 6.4 接入指南

```javascript
// 示例：第三方开发者接入 Echo Protocol
const echo = new EchoSDK({
    provider: window.ethereum,
    network: 'qng_testnet'
});

// 铸造原创资产
const asset = await echo.mintOriginal({
    audioFile: file,
    title: "My Song",
    pricing: {
        ownership: ethers.utils.parseEther("1.0"),   // 买断价格
        usage: ethers.utils.parseEther("0.01"),      // 使用一次的价格
        derivative: ethers.utils.parseEther("0.1"),  // 获得衍生权的价格
        extension: ethers.utils.parseEther("0.05")   // 获得扩展权的价格
    }
});

// 引用他人作品创作 (需要拥有父资产的衍生权)
const remix = await echo.derive({
    parentIds: [123],
    audioFile: remixFile,
    title: "Remix of My Song",
    derivationType: DerivationType.REMIX
});

// 购买使用权 (可以播放/下载，但不能转让)
await echo.market.purchaseUsage(assetId, 30 * 24 * 60 * 60); // 30天使用权

// 购买衍生权 (可以创建 remix/sample/cover)
await echo.market.purchaseDerivativeRight(assetId);

// 购买所有权 (完全买断)
await echo.market.purchaseOwnership(assetId);

// 查询资产的引用链
const lineage = await echo.getLineage(remix.assetId);
// 返回: [123, 456, 789] (从近到远的引用链)
```

## 6.5 ERC721 兼容性 (可选)

```javascript
// 如果需要兼容 OpenSea 等平台，使用包装器
const wrapper = await echo.getERC721Wrapper();

// 将 ECHO 资产包装为 ERC721
await wrapper.wrap(assetId);

// 现在在 OpenSea 上可以看到这个资产
// 但注意: ERC721 只能表示所有权，无法表示使用权/衍生权

// 解包恢复为原生 ECHO 资产
await wrapper.unwrap(tokenId);
```

---

**文档版本**: v2.0  
**最后更新**: 2026-03-14  
**更新内容**: 重构为原生 ECHO 协议实现，明确与 ERC721 的差异  
**维护者**: Echo Protocol 核心团队
