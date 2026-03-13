# QITMEER QNG Network Hardhat 配置指南

> 项目: ECHO Compose - 音乐资产平台
> 适用于: QITMEER QNG TestNet (EVM 兼容层)

---

## 📋 目录

1. [QNG TestNet 配置参数](#1-qng-testnet-配置参数)
2. [Hardhat 配置](#2-hardhat-配置)
3. [测试币领取步骤](#3-测试币领取步骤)
4. [部署命令示例](#4-部署命令示例)
5. [常用资源链接](#5-常用资源链接)

---

## 1. QNG TestNet 配置参数

### 1.1 网络参数 (JSON 格式)

```json
{
  "networkName": "QNG - Testnet",
  "chainId": 223,
  "rpcUrls": {
    "http": [
      "https://explorer.qitmeer.io/rpc",
      "https://testnet.meerlabs.com/rpc"
    ],
    "ws": [
      "wss://explorer.qitmeer.io/ws"
    ]
  },
  "nativeCurrency": {
    "name": "Qitmeer Testnet",
    "symbol": "MEER",
    "decimals": 18
  },
  "blockExplorer": {
    "name": "QNG Testnet Explorer",
    "url": "https://qng-testnet.meerscan.io/",
    "apiUrl": "https://qng-testnet.meerscan.io/api"
  },
  "faucet": {
    "url": "https://faucet.qitmeer.io/",
    "amount": "5 MEER",
    "limit": "每地址最多20次，每次5 MEER，同一IP或地址72小时内只能领取一次"
  },
  "testnet": true,
  "evmCompatible": true,
  "consensus": "BlockDAG PoW"
}
```

### 1.2 节点配置参数

| 参数 | 值 | 说明 |
|------|-----|------|
| HTTP Port | 18535 | QNG EVM HTTP RPC 默认端口 |
| WebSocket Port | 18536 | QNG EVM WebSocket RPC 默认端口 |
| UTXO RPC Port | 18131 | Qitmeer UTXO 层 RPC 端口 |
| Chain ID | 223 | QNG TestNet 链 ID |
| Currency | MEER | 原生代币符号 |

---

## 2. Hardhat 配置

### 2.1 完整 hardhat.config.js

```javascript
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// 从环境变量读取私钥（推荐做法）
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x" + "0".repeat(64);
const QNG_RPC_URL = process.env.QNG_RPC_URL || "https://explorer.qitmeer.io/rpc";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  // Solidity 编译器配置
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },

  // 网络配置
  networks: {
    // 本地 Hardhat 网络
    hardhat: {
      chainId: 31337
    },

    // QNG TestNet
    qngTestnet: {
      url: QNG_RPC_URL,
      chainId: 223,
      accounts: [PRIVATE_KEY],
      gasPrice: "auto",
      gas: "auto",
      timeout: 60000, // 60秒超时
      httpHeaders: {
        "Content-Type": "application/json"
      }
    },

    // QNG Mainnet (生产环境)
    qngMainnet: {
      url: process.env.QNG_MAINNET_RPC || "https://mainnet.qng.meerscan.io/rpc",
      chainId: 813, // QNG Mainnet Chain ID
      accounts: [PRIVATE_KEY],
      gasPrice: "auto",
      gas: "auto"
    }
  },

  // Etherscan 验证配置 (用于合约验证)
  etherscan: {
    apiKey: {
      qngTestnet: process.env.QNG_API_KEY || "your-api-key"
    },
    customChains: [
      {
        network: "qngTestnet",
        chainId: 223,
        urls: {
          apiURL: "https://qng-testnet.meerscan.io/api",
          browserURL: "https://qng-testnet.meerscan.io/"
        }
      }
    ]
  },

  // 路径配置
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },

  // Mocha 测试配置
  mocha: {
    timeout: 40000
  },

  // Gas 报告配置
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY
  }
};
```

### 2.2 环境变量配置 (.env)

创建 `.env` 文件：

```bash
# QNG TestNet 配置
PRIVATE_KEY=0x你的私钥（不带0x前缀也可以）
QNG_RPC_URL=https://explorer.qitmeer.io/rpc

# 可选: API Keys
QNG_API_KEY=your_qng_api_key
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key

# 可选: 主网配置 (生产环境)
QNG_MAINNET_RPC=https://mainnet.qng.meerscan.io/rpc
```

### 2.3 package.json 依赖

```json
{
  "name": "echo-compose-qng",
  "version": "1.0.0",
  "description": "ECHO Compose 音乐资产平台 - QNG 部署",
  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "deploy:testnet": "hardhat run scripts/deploy.js --network qngTestnet",
    "deploy:mainnet": "hardhat run scripts/deploy.js --network qngMainnet",
    "verify:testnet": "hardhat verify --network qngTestnet",
    "node": "hardhat node"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^4.0.0",
    "dotenv": "^16.3.1",
    "hardhat": "^2.19.0"
  }
}
```

### 2.4 部署脚本示例 (scripts/deploy.js)

```javascript
const hre = require("hardhat");

async function main() {
  // 获取部署账户
  const [deployer] = await hre.ethers.getSigners();
  console.log("部署账户:", deployer.address);
  
  // 检查余额
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("账户余额:", hre.ethers.formatEther(balance), "MEER");

  // 部署合约示例: MusicNFT
  console.log("\n开始部署 MusicNFT 合约...");
  const MusicNFT = await hre.ethers.getContractFactory("MusicNFT");
  const musicNFT = await MusicNFT.deploy("ECHO Music", "ECHO");
  
  await musicNFT.waitForDeployment();
  
  const contractAddress = await musicNFT.getAddress();
  console.log("✅ MusicNFT 合约已部署到:", contractAddress);

  // 验证合约地址
  console.log("\n区块浏览器链接:");
  console.log(`https://qng-testnet.meerscan.io/address/${contractAddress}`);

  // 保存部署信息
  const deploymentInfo = {
    network: hre.network.name,
    chainId: 223,
    contract: "MusicNFT",
    address: contractAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString()
  };
  
  console.log("\n部署信息:", JSON.stringify(deploymentInfo, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ 部署失败:", error);
    process.exit(1);
  });
```

---

## 3. 测试币领取步骤

### 3.1 官方 Faucet 领取

**地址**: https://faucet.qitmeer.io/

#### 步骤说明:

1. **准备钱包地址**
   - 安装 MetaMask 浏览器插件
   - 创建或导入钱包
   - 复制你的钱包地址 (0x... 格式)

2. **访问 Faucet 网站**
   - 打开 https://faucet.qitmeer.io/
   - 在输入框中粘贴你的钱包地址

3. **领取测试币**
   - 点击 "Claim" 或 "领取" 按钮
   - 等待交易确认
   - 每次可领取 5 MEER

#### 领取限制:
- 每个地址最多可领取 **20 次**
- 每次领取 **5 MEER**
- 同一 IP 或地址 **72 小时内只能领取一次**

### 3.2 通过第三方平台领取

**Thirdweb Faucet**: https://thirdweb.com/qitmeer-network-testnet

- 每日可领取 0.01 MEER-T
- 需要连接钱包

### 3.3 通过 KAHF Wallet 跨链转移

如果你已有 Qitmeer UTXO 网络的 MEER，可以通过 KAHF 钱包转移到 QNG:

1. 下载 KAHF Wallet 应用
2. 进入首页，点击 "Transfer" 图标
3. 选择目标地址并输入金额
4. 确认交易，输入密码或指纹
5. 点击 "Transfer" 完成跨链

### 3.4 验证余额

在 MetaMask 中:
1. 确保已添加 QNG TestNet 网络
2. 切换到 QNG TestNet
3. 查看余额显示

通过区块浏览器验证:
```
https://qng-testnet.meerscan.io/address/你的地址
```

---

## 4. 部署命令示例

### 4.1 初始化项目

```bash
# 创建项目目录
mkdir echo-compose-qng
cd echo-compose-qng

# 初始化 npm 项目
npm init -y

# 安装 Hardhat
npm install --save-dev hardhat

# 初始化 Hardhat 项目
npx hardhat init

# 安装依赖
npm install --save-dev @nomicfoundation/hardhat-toolbox dotenv
```

### 4.2 编译合约

```bash
# 编译所有合约
npx hardhat compile

# 强制重新编译
npx hardhat compile --force
```

### 4.3 部署合约到 QNG TestNet

```bash
# 部署到 QNG TestNet
npx hardhat run scripts/deploy.js --network qngTestnet

# 使用 Hardhat Ignition 部署 (推荐)
npx hardhat ignition deploy ignition/modules/MusicNFT.js --network qngTestnet
```

### 4.4 验证合约

```bash
# 验证已部署的合约
npx hardhat verify --network qngTestnet <合约地址> "构造函数参数1" "构造函数参数2"

# 示例
npx hardhat verify --network qngTestnet 0x1234... "ECHO Music" "ECHO"
```

### 4.5 运行测试

```bash
# 运行所有测试
npx hardhat test

# 运行特定测试文件
npx hardhat test test/MusicNFT.test.js

# 在 QNG TestNet 上运行测试
npx hardhat test --network qngTestnet
```

### 4.6 执行脚本

```bash
# 运行脚本
npx hardhat run scripts/interact.js --network qngTestnet
```

### 4.7 交互脚本示例

```javascript
// scripts/interact.js
const hre = require("hardhat");

async function main() {
  const contractAddress = "0x你的合约地址";
  
  // 连接合约
  const MusicNFT = await hre.ethers.getContractFactory("MusicNFT");
  const musicNFT = await MusicNFT.attach(contractAddress);
  
  // 调用合约函数
  const name = await musicNFT.name();
  console.log("合约名称:", name);
  
  // 发送交易
  const tx = await musicNFT.mint("ipfs://音乐元数据URI");
  await tx.wait();
  console.log("铸造成功! 交易哈希:", tx.hash);
}

main().catch(console.error);
```

---

## 5. 常用资源链接

### 官方资源

| 资源 | 链接 |
|------|------|
| 官方网站 | https://www.qitmeer.io/qng |
| 官方文档 | https://docs.meerlabs.com/ |
| GitHub | https://github.com/Qitmeer/qng |
| Faucet | https://faucet.qitmeer.io/ |

### 区块浏览器

| 网络 | 链接 |
|------|------|
| QNG TestNet | https://qng-testnet.meerscan.io/ |
| QNG Mainnet | https://qng.meerscan.io/ |

### RPC 节点

| 类型 | URL |
|------|-----|
| TestNet HTTP | https://explorer.qitmeer.io/rpc |
| TestNet WS | wss://explorer.qitmeer.io/ws |

### 社区与支持

| 平台 | 链接 |
|------|------|
| Telegram (UK Developer) | Meer Labs |
| Discord | 参考官方文档 |
| Twitter/X | @QitmeerNetwork |

---

## 6. 常见问题 (FAQ)

### Q1: QNG 和 Qitmeer 有什么区别?
**A**: Qitmeer 是基于 BlockDAG 的 PoW 公链，使用 UTXO 模型。QNG (Qitmeer Next Generation) 是 Qitmeer 上的 EVM 兼容层，允许部署 Solidity 智能合约。

### Q2: 为什么交易一直 pending?
**A**: QNG TestNet 使用 PoW 共识，区块确认可能需要时间。如果 gas 价格设置过低，交易可能被延迟。建议使用 `gasPrice: "auto"` 让 Hardhat 自动估算。

### Q3: 如何查看交易状态?
**A**: 复制交易哈希 (tx hash) 到区块浏览器查询:
```
https://qng-testnet.meerscan.io/tx/交易哈希
```

### Q4: Chain ID 223 和 813 有什么区别?
**A**: 
- 223 = QNG TestNet
- 813 = QNG Mainnet

---

## 7. 项目特定配置 (ECHO Compose)

对于 ECHO Compose 音乐资产平台的特定配置:

```javascript
// 音乐 NFT 合约部署参数
const MUSIC_NFT_CONFIG = {
  name: "ECHO Music Assets",
  symbol: "ECHO",
  maxSupply: 10000,
  mintPrice: ethers.parseEther("0.1"), // 0.1 MEER
  platformFee: 250, // 2.5% (basis points)
  royaltyPercentage: 500 // 5% (basis points)
};

// IPFS 配置
const IPFS_CONFIG = {
  gateway: "https://ipfs.io/ipfs/",
  pinataApi: process.env.PINATA_API_KEY,
  pinataSecret: process.env.PINATA_SECRET_KEY
};
```

---

**文档版本**: 1.0  
**最后更新**: 2026-03-13  
**适用网络**: QITMEER QNG TestNet (Chain ID: 223)
