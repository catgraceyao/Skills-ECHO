# Echo Protocol 技术架构

## 版本: v1.0
## 日期: 2026-03-13

---

## 一、资产 Schema 设计 (Solidity)

```solidity
struct EchoAsset {
    uint256 tokenId;           // 唯一标识
    address creator;           // 创作者地址
    uint256 createdAt;         // 铸造时间戳
    string metadataURI;        // IPFS/Arweave 元数据链接
    string audioHash;          // 音频文件内容哈希
    uint256 duration;          // 音频时长
    string title;              // 作品标题
    uint256[] parents;         // 引用的父资产 ID 数组
    uint256 version;           // 版本号
    bytes32 derivationType;    // 衍生类型: REMIX / SAMPLE / COVER
    RightsPricing pricing;     // 权属定价
    AssetStatus status;        // ACTIVE, FROZEN, BURNED
}

struct RightsPricing {
    uint256 ownershipPrice;    // 所有权价格
    uint256 usagePrice;        // 使用权价格
    uint256 derivativePrice;   // 衍生权价格
    uint256 extensionPrice;    // 扩展权价格
}
```

---

## 二、合约架构

| 合约 | 职责 | 依赖 |
|------|------|------|
| **EchoToken** | ERC-721 资产代币 | OpenZeppelin |
| **EchoRegistry** | 引用关系管理 | EchoToken |
| **EchoDistributor** | 分润逻辑 | EchoRegistry |
| **EchoMarket** | 市场交易 | Distributor, Rights |
| **EchoGovernance** | 参数治理 | Governor |

---

## 三、核心接口

```solidity
interface IEchoToken {
    function mint(EchoAsset calldata asset) external returns (uint256);
    function derive(uint256 parentId, EchoAsset calldata asset) external returns (uint256);
    function getAsset(uint256 tokenId) external view returns (EchoAsset memory);
    function getLineage(uint256 tokenId) external view returns (uint256[] memory);
}

interface IEchoMarket {
    function purchaseUsage(uint256 assetId) external payable;
    function purchaseDerivativeRight(uint256 assetId) external payable;
}
```

---

## 四、存储策略

| 数据类型 | 存储位置 | 理由 |
|----------|----------|------|
| 资产所有权 | 链上 (ERC-721) | 核心确权 |
| 引用关系 | 链上(轻量) + 链下(完整) | Gas 优化 |
| 音频文件 | IPFS/Arweave | 链上存 hash |
| 元数据 | IPFS | 节省 Gas |
| 分润计算 | 链下计算 + 链上验证 | 效率平衡 |

---

## 五、Gas 优化策略

| 场景 | 优化前 Gas | 优化方案 | 优化后 Gas |
|------|-----------|----------|-----------|
| 铸造原创资产 | ~150k | clone 模式 | ~80k |
| 衍生作品 | ~200k + N*50k | 链下计算路径 | ~120k |
| 分润分发 | ~100k + N*30k | 累积领取模式 | ~80k + N*15k |

**关键技巧**:
1. Merkle Tree 验证长链引用
2. 累积收益模式 (claim)
3. 批量交易打包

---

## 六、部署脚本 (Hardhat)

```javascript
async function main() {
    const EchoToken = await ethers.getContractFactory("EchoToken");
    const token = await EchoToken.deploy("Echo Music Asset", "ECHO");
    
    const EchoRegistry = await ethers.getContractFactory("EchoRegistry");
    const registry = await EchoRegistry.deploy(token.address);
    
    const EchoDistributor = await ethers.getContractFactory("EchoDistributor");
    const distributor = await EchoDistributor.deploy(registry.address);
    
    const EchoMarket = await ethers.getContractFactory("EchoMarket");
    const market = await EchoMarket.deploy(token.address, registry.address, distributor.address);
    
    await token.setRegistry(registry.address);
    await registry.setDistributor(distributor.address);
    
    console.log("Token:", token.address);
    console.log("Registry:", registry.address);
    console.log("Distributor:", distributor.address);
    console.log("Market:", market.address);
}
```
