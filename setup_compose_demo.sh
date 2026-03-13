#!/bin/bash
# Compose Demo 文件自动创建脚本
# 使用方法：bash setup_compose_demo.sh

set -e

echo "🚀 创建 Compose Demo 文件..."

# 创建目录
mkdir -p compose-demo
cd compose-demo

# 1. integration_summary.md
cat > integration_summary.md << 'EOF'
# Compose Demo 整合摘要

> **文档版本**: v1.0  
> **整合日期**: 2026-03-13  
> **整合者**: 全栈整合 Agent

---

## 一、整合摘要 (Executive Summary)

| Agent | 核心贡献 | 关键交付物 |
|-------|----------|------------|
| **Protocol Architect** | 定义 Echo Protocol 技术架构，实现多层级分润的链上逻辑 | 5 个核心合约设计、Gas 优化策略、Sepolia 部署脚本 |
| **Interaction Designer** | 设计宇宙星系主题的 UI/UX 系统，确保技术概念的可视化呈现 | 6 个核心页面线框、完整 CSS 组件库、动效规范 |
| **Economy Analyst** | 建立数学严谨的多层级分润模型，平衡原创者与衍生创作者利益 | 分润公式、3 种场景数值表、收益计算器原型、风险分析 |
| **Video Director** | 制作 75 秒产品演示视频脚本，将技术概念转化为情感叙事 | 逐秒分镜脚本、录屏参数、后期制作指南 |

---

## 二、执行路线图 (Execution Roadmap)

### Phase 1: 准备阶段 (预估 2-3 天)

| 优先级 | 任务 | 依赖 | 预估时间 | 交付物 |
|--------|------|------|----------|--------|
| P0 | 准备钱包和测试代币 | 无 | 30 分钟 | Sepolia ETH、测试 USDC |
| P0 | 配置开发环境 (Node.js, Hardhat) | 无 | 2 小时 | 可编译的 Hardhat 项目 |
| P1 | 安装前端依赖 (React, Tailwind, ethers.js) | Hardhat 项目 | 1 小时 | 可运行的前端项目 |
| P1 | 准备音频素材 | 无 | 2 小时 | 3-5 个示例音频文件 |

### Phase 2: 合约开发 (预估 3-4 天)

| 优先级 | 任务 | 依赖 | 预估时间 | 交付物 |
|--------|------|------|----------|--------|
| P0 | 实现 EchoToken (ERC-721) | Hardhat 环境 | 4 小时 | 可部署的 Token 合约 |
| P0 | 实现 EchoRegistry | EchoToken | 4 小时 | 引用关系管理合约 |
| P0 | 实现 EchoDistributor | EchoRegistry | 6 小时 | 分润核心合约 |
| P1 | 实现 EchoMarket | Distributor | 4 小时 | 市场合约 |
| P1 | 编写部署脚本 | 所有合约 | 2 小时 | 自动化部署脚本 |
| P2 | 本地测试网验证 | 部署脚本 | 4 小时 | 测试报告 |

### Phase 3: 前端开发 (预估 4-5 天)

| 优先级 | 任务 | 依赖 | 预估时间 | 交付物 |
|--------|------|------|----------|--------|
| P0 | 搭建 UI 框架 (配色/字体/组件) | 前端项目 | 4 小时 | 可用的组件库 |
| P0 | 实现钱包连接 | UI 框架 | 2 小时 | Connect Wallet 功能 |
| P1 | 实现铸造流程页面 | 钱包连接、Token 合约 | 6 小时 | 可铸造资产的页面 |
| P1 | 实现发现页/资产卡片 | UI 框架 | 4 小时 | 资产展示页面 |
| P1 | 实现资产详情页 | 发现页、Registry 合约 | 6 小时 | 详情+播放功能 |
| P2 | 实现衍生创作页 | 资产详情页 | 4 小时 | 引用创作功能 |
| P2 | 实现收益计算器 | 经济模型参数 | 4 小时 | 可视化计算器 |
| P3 | 实现个人中心 | 所有核心页面 | 4 小时 | Profile 页面 |

### Phase 4: 视频制作 (预估 2-3 天)

| 优先级 | 任务 | 依赖 | 预估时间 | 交付物 |
|--------|------|------|----------|--------|
| P0 | 完成产品界面开发 | Phase 3 核心功能 | - | 可录制的产品 |
| P0 | 产品功能录屏 | 可录制的产品 | 4 小时 | 35-55s 演示素材 |
| P1 | 后期制作 (剪辑/调色/特效) | 录屏素材 | 8 小时 | 粗剪版本 |
| P2 | 配音与音效 | 粗剪版本 | 4 小时 | 完整音轨 |
| P2 | 最终输出 | 配音完成 | 2 小时 | 75秒完整版 + 15秒预告片 |

### Phase 5: 整合与部署 (预估 1-2 天)

| 优先级 | 任务 | 依赖 | 预估时间 | 交付物 |
|--------|------|------|----------|--------|
| P0 | Sepolia 测试网部署 | Phase 2 完成 | 2 小时 | 已部署的合约地址 |
| P0 | 前端连接测试网 | 合约部署 | 2 小时 | 可访问的 Demo 站点 |
| P1 | 端到端测试 | 完整系统 | 4 小时 | 测试报告 |
| P2 | Demo 打包与文档 | 全部完成 | 2 小时 | README + 演示指南 |

### 总时间估算

| 阶段 | 并行度 | 预估时间 |
|------|--------|----------|
| Phase 1: 准备 | 独立 | 1-2 天 |
| Phase 2: 合约 + Phase 3: 前端 | 可部分并行 | 5-7 天 |
| Phase 4: 视频 | 依赖前端 | 2-3 天 |
| Phase 5: 部署 | 依赖全部 | 1-2 天 |
| **总计** | - | **9-14 天** |

---

## 三、给用户的一句话建议

> **现在应该做什么**: 
> 
> **立即开始 Phase 1 准备** — 创建 Hardhat 项目并配置开发环境，同时准备 3-5 个示例音频文件；在合约开发完成前，先用 React + Tailwind 搭建 UI 组件库（可独立进行），这样合约部署后即可快速完成前端集成和视频录制。
EOF

echo "✅ integration_summary.md 创建完成"

# 2. video_director.md
cat > video_director.md << 'EOF'
# Compose 产品演示视频分镜脚本

> **视频名称**: Compose - 音乐创作的星尘之路  
> **时长**: 75秒  
> **目标受众**: 投资人、音乐人、创作者  
> **视觉风格**: 宇宙星系/星云主题 + 赛博光效  
> **输出日期**: 2026-03-13

---

## 一、逐秒分镜脚本 (时间轴)

### 第一幕：Hook - 痛点 (0-10秒)

| 时间 | 镜头 | 画面描述 | 旁白文案 | 音效/音乐 |
|------|------|----------|----------|-----------|
| 0-3s | 黑屏渐入 | **纯黑背景**，中央一个微弱光点闪烁，像遥远的恒星。光点逐渐放大，露出是一段音频波形。波形被一只手"切断"。 | (无旁白，只有环境音) | 深沉的底噪，类似太空中的低频嗡鸣 |
| 3-6s | 快切蒙太奇 | 快速闪过3个场景：**①** 音乐人在昏暗房间创作 **②** 作品上传到平台 **③** 平台logo变大吞噬一切，画面变暗 | "你的音乐在流传..." | 心跳声加速 |
| 6-10s | 文字冲击 | **大字标题炸开**：「但你一分没拿到」。文字周围有碎片飞散效果，像玻璃破碎。背景是模糊的流媒体平台界面。 | "...但你一分没拿到。" | 沉重的低音撞击 |

**转场效果**: 文字碎裂成粒子，粒子重组为星空背景

---

### 第二幕：Problem - 问题剖析 (10-20秒)

| 时间 | 镜头 | 画面描述 | 旁白文案 | 音效/音乐 |
|------|------|----------|----------|-----------|
| 10-13s | 黑洞隐喻 | **星系中心出现黑洞**，周围的音频文件（可视化的波形卡片）被吸入黑洞。每个卡片上有创作者的头像和名字，但名字逐渐模糊消失。 | "传统平台就像版权黑洞..." | 紧张的弦乐渐强 |
| 13-16s | 数据可视化 | **抽象的数据流动画**：90% 的标签飞向一个大公司Logo，10% 飞向创作者。比例条极度失衡。 | "90%的收益，流向了平台。" | 电子音效，数据流动的声音 |
| 16-20s | 痛点总结 | **三个图标依次浮现**：❌ 授权繁琐 ❌ 收益不明 ❌ 原创被忽视。每个图标都有红色"X"标记，背景是愤怒的创作者剪影。 | "授权繁琐，收益不明，原创被忽视。" | 低沉的鼓点，节奏渐快 |

---

### 第三幕：Solution - Echo协议 (20-35秒)

| 时间 | 镜头 | 画面描述 | 旁白文案 | 音效/音乐 |
|------|------|----------|----------|-----------|
| 20-23s | Logo登场 | **Compose Logo 从光中诞生**：一个旋转的星云核心，周围环绕着音轨形成的轨道。Logo下方文字"Compose"逐字打出。 | "Compose，基于 Echo 协议..." | 音乐突然明亮，大调和弦 |
| 23-27s | 架构演示 | **抽象的技术架构图**：从中心向外扩散的三层同心圆。内层-区块链（盾牌图标）、中层-引用图谱（网络节点）、外层-分润算法（金币流向）。每层都有粒子流动。 | "将创作关系上链，让每一次引用都可追溯。" | 科技感电子音效，脉冲节奏 |
| 27-32s | 上链动画 | **一个音频文件被"铸造"的过程**：文件被包裹在光球中，光球飞向太空，在星空中爆炸成无数粒子，粒子重组为区块链的区块样式，每个区块上有创作者签名。 | "你的作品，成为星尘中的永恒坐标。" | 金属质感的声音，像锁扣闭合 |
| 32-35s | 协议价值 | **全景展示**：无数光点组成的星系网络，每个光点都是一个音乐资产，连线代表引用关系，整个网络在缓缓旋转。 | "这就是 Echo Protocol。" | 音乐进入高潮铺垫 |

---

### 第四幕：Product Demo - 产品演示 (35-55秒)

| 时间 | 镜头 | 画面描述 | 旁白文案 | 音效/音乐 |
|------|------|----------|----------|-----------|
| 35-38s | 铸造流程 | **录屏画面**：Compose 产品界面，宇宙主题深色背景。用户点击"铸造资产"，拖拽音频文件上传。界面有发光边框和星云纹理。 | "铸造你的音乐资产，只需三步。" | 清脆的UI音效 |
| 38-41s | 元数据录入 | **快速剪辑**：填写资产名称、添加标签、设置许可类型。每个输入都有发光反馈。滑块拖动时有粒子拖尾效果。 | "上传、定义、确认。" | 轻快的电子节拍 |
| 41-45s | 引用他人 | **核心功能演示**：用户在"引用"界面搜索，找到另一个作品，点击"引用"按钮。两个音频波形并排显示，原作品波形高亮，新作品波形与之产生连线。 | "引用他人作品，自动建立创作血缘。" | 连接音效，像电路接通 |
| 45-50s | 分润演示 | **数据可视化重点**：100元的交易金额，被分解成多个流向。动画展示：10元→平台，36元→直接创作者，45元→上游分润池。上游池再细分：Alice 22.5元、Bob 9.26元、Charlie 13.24元。 | "当作品被使用，收益自动分润。原创者保底25%，确保你的贡献不被稀释。" | 硬币掉落的声音，分层级的清脆音效 |
| 50-55s | 衍生树展示 | **3D树状图旋转**：以原创者为根，衍生作品如树枝般生长。每个节点都是一个音乐资产卡片。 | "你的创作，可以激发无限的衍生可能。每一次使用，你都有收益。" | 音乐渐强，充满希望和可能性 |

---

### 第五幕：Vision - 愿景 (55-70秒)

| 时间 | 镜头 | 画面描述 | 旁白文案 | 音效/音乐 |
|------|------|----------|----------|-----------|
| 55-59s | 生态展示 | **宏观视角**：无数音乐人在各自的星球上创作（每个创作者是一个发光星球），作品是星球间的航线，形成璀璨的银河网络。 | "在 Compose，每一位创作者都是星辰。" | 宏大史诗感的音乐 |
| 59-63s | 价值主张 | **三个核心价值依次亮起**：① 创作自由 ② 收益透明 ③ 生态共建。每个价值主张都有对应的光效。 | "创作自由，收益透明，生态共建。" | 激昂的管弦乐+电子融合 |
| 63-67s | Slogan | **全屏文字动画**：「让每一次创作，都留下回响」文字从远处飞入，每个字都有星云拖尾效果。 | "让每一次创作，都留下回响。" | 音乐达到高潮，然后突然静止 |
| 67-70s | CTA | **Logo + 行动号召**：Compose Logo 居中，下方文字"Beta 申请开放中"，再下方是网址 compose.music 和二维码。背景是缓慢旋转的星云。 | "Compose，音乐创作的未来。" | 一个清澈的音符收尾 |

---

## 二、BGM/音效建议

### 音乐风格
- **整体风格**: Epic Electronic / Cinematic Ambient
- **参考艺人**: Hans Zimmer (Interstellar 风格)、M83、ODESZA
- **BPM**: 100-110 (前段) → 128 (中段产品演示) → 140 (高潮愿景)

### 分段音乐设计

| 段落 | 音乐特征 | 参考曲目 |
|------|----------|----------|
| Hook (0-10s) | 低频底噪 → 心跳节奏 → 沉重打击 | "Time" 前奏 |
| Problem (10-20s) | 紧张的弦乐，不和谐音程 | "Dunkirk" 配乐风格 |
| Echo协议 (20-35s) | 突然明亮，大调和弦，科技感 | "First Step" 风格 |
| 产品演示 (35-55s) | 轻快电子节拍，清脆的合成器音色 | ODESZA 风格 |
| 愿景 (55-70s) | 史诗管弦 + 电子融合，情感高潮 | "Arrival of the Birds" |

---

## 三、录屏参数设置

### 技术规格

| 参数 | 建议值 | 说明 |
|------|--------|------|
| **分辨率** | 1920x1080 (1080p) 或 2560x1440 (2K) | 推荐2K以便后期裁剪 |
| **帧率** | 60fps | 确保动画流畅，特别是粒子效果 |
| **编码格式** | H.264 或 ProRes 422 | H.264用于预览，ProRes用于后期 |

### 推荐录屏工具

| 工具 | 平台 | 特点 | 适用场景 |
|------|------|------|----------|
| **OBS Studio** | Win/Mac/Linux | 免费开源，高度可定制，支持多源 | 专业录制，复杂场景 |
| **Screen Studio** | Mac | 自动生成平滑运镜，专为产品演示设计 | 快速制作高质量演示 |
| **Camtasia** | Win/Mac | 录制+编辑一体化，易用 | 快速迭代，简单后期 |

---

## 四、后期制作建议

### 调色方向
- **风格**: 电影级科幻感，高对比度，强调紫/蓝色调
- **参考电影**: 《银翼杀手2049》《沙丘》《星际穿越》

### 特效建议
1. **粒子效果**: Trapcode Particular (AE) 或 Houdini
2. **光效**: 辉光 (Glow) 所有高亮元素添加 15-25 半径的辉光
3. **运动图形**: 缓动曲线 ease-out-expo，运动模糊 180° 快门角度

---

**文档版本**: v1.0  
**导演**: AI Video Director  
**状态**: 待制作
EOF

echo "✅ video_director.md 创建完成"

# 3. economy_analyst.md (精简版)
cat > economy_analyst.md << 'EOF'
# Echo Protocol 多层级分润经济模型设计

## 版本: v1.0
## 日期: 2026-03-13

---

## 一、核心参数定义

| 参数 | 符号 | 默认值 | 说明 |
|------|------|--------|------|
| 平台手续费率 | φ | 10% | 平台运营成本 |
| 直接创作者分成率 | α | 40% | 被购买作品的创作者获得比例 |
| 上游分润池比例 | β | 50% | 分配给所有上游创作者的总池 |
| 原创者保底比例 | γ | 25% | 引用链末端原创者的最低保障 |
| 衰减系数 | δ | 0.7 | 每上升一层，分配比例的衰减因子 |

---

## 二、三场景数值表

### 场景 A: 简单引用 (Alice → Bob → Carol)

Carol 支付 100 元购买 Bob 的作品：

| 角色 | 收益 | 占比 | 说明 |
|------|------|------|------|
| Alice (原创者) | 45.00 | 45% | 上游分润池 100% |
| Bob (直接创作者) | 36.00 | 36% | 直接创作者 40% |
| 平台 | 10.00 | 10% | 手续费 |
| 系统储备 | 9.00 | 9% | - |

### 场景 B: 链式引用 (Alice → Bob → Charlie → David → Eve)

Eve 支付 100 元购买 David 的作品：

| 角色 | 收益 | 占比 | 说明 |
|------|------|------|------|
| Alice (原创者) | 22.50 | 22.5% | 触发保底机制 |
| Bob | 9.26 | 9.3% | - |
| Charlie | 13.24 | 13.2% | - |
| David (直接创作者) | 36.00 | 36.0% | - |
| 平台 | 10.00 | 10.0% | - |
| 系统储备 | 9.00 | 9.0% | - |

### 场景 C: 分叉引用

Alice 原创作品被 Bob 和 Carol 分别引用：

| 角色 | 分支1收益 | 分支2收益 | 累计收益 |
|------|-----------|-----------|----------|
| Alice | 45.00 | 45.00 | 90.00 |
| Bob | 36.00 | 0 | 36.00 |
| Carol | 0 | 36.00 | 36.00 |

---

## 三、分润公式

```
总收益池 = 交易金额 × 90% (扣除10%平台费)

直接创作者收益 = 总收益池 × 40%
上游分润池 = 总收益池 × 50%

上游层级分配 (i=1,2,3...):
  层级收益 = 上游分润池 × (0.7^(i-1) / Σ(0.7^(k-1)))

原创者最低保障 = 总收益池 × 25% (若计算值低于此数)
```

---

## 四、经济模型风险分析

| 风险 | 等级 | 缓解方案 |
|------|------|----------|
| 收益稀释 | 高 | 原创者保底机制 |
| 原创者收益过高 | 中 | 动态调节保底比例 |
| 分叉"躺赚" | 中 | 正常设计，鼓励优质原创 |
| 参数调节困难 | 中 | 治理机制，社区投票 |
| 套利攻击 | 低 | 限制自引用，验证机制 |
EOF

echo "✅ economy_analyst.md 创建完成"

# 4. protocol_architect.md (精简版)
cat > protocol_architect.md << 'EOF'
# Echo Protocol 技术架构设计

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
EOF

echo "✅ protocol_architect.md 创建完成"

# 5. interaction_designer.md (精简版)
cat > interaction_designer.md << 'EOF'
# Compose 音乐资产平台 - 交互设计文档

## 版本: v1.0
## 日期: 2026-03-13

---

## 一、核心页面线框图

### 1.1 首页/发现页

```
┌─────────────────────────────────────────────────────────────┐
│  ☰  ◆ COMPOSE                          🔍  [钱包连接]  👤  │
│─────────────────────────────────────────────────────────────┤
│                                                             │
│   ╭─────────────────────────────────────────────────────╮   │
│   │                                                     │   │
│   │    ✦  在星尘中铸造你的声音  ✦                        │   │
│   │                                                     │   │
│   │         [ 上传音频 → 铸造资产 ]                      │   │
│   │                                                     │   │
│   ╰─────────────────────────────────────────────────────╯   │
│                                                             │
│   ◄ 最新  │  最热 ►  │  可衍生  │  原始创作                    │
│                                                             │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │
│   │ [波形图] │  │ [波形图] │  │ [波形图] │  │ [波形图] │       │
│   │ 星云漫步  │  │ 深空回响  │  │ 极光旋律  │  │ 星际穿越  │       │
│   │ @stella │  │ @void   │  │ @aurora │  │ @inter  │       │
│   │ ◆ 1.2K  │  │ ◆ 3.4K  │  │ ◆ 890   │  │ ◆ 5.6K  │       │
│   └─────────┘  └─────────┘  └─────────┘  └─────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 资产详情页

```
┌─────────────────────────────────────────────────────────────┐
│  ◆ COMPOSE                             🔍  [钱包连接]  👤  │
│─────────────────────────────────────────────────────────────┤
│                                                             │
│   ╭────────────────────────────────────────────────────╮    │
│   │                 [ 大型波形可视化 ]                  │    │
│   │     ～～～～～～～～～～～～～～～～～～～～～～     │    │
│   │              ▶  播放中  02:34 / 04:12               │    │
│   ╰────────────────────────────────────────────────────╯    │
│                                                             │
│   星云漫步 (Nebula Walk)                           ◆ 1,234  │
│   ─────────────────────────────────────────────────────     │
│   创作者: @stella_verse        铸造时间: 2024-03-12        │
│                                                             │
│   [ 💾 下载 ]  [ 🔗 引用 ]  [ 🔄 衍生 ]  [ ⭐ 收藏 ]         │
│                                                             │
│   ════════════════════════════════════════════════════      │
│                                                             │
│   引用关系图 (Derivative Tree)                               │
│                                                             │
│                ┌─────────┐                                  │
│                │  原始   │                                  │
│                │  v1.0   │                                  │
│                └────┬────┘                                  │
│        ┌────────────┼────────────┐                          │
│   ┌────▼─────┐┌────▼────┐┌──────▼──────┐                   │
│   │ 混音版   ││ 配乐版  ││ 采样重制    │                   │
│   │ v1.1-a  ││ v1.1-b ││   v1.2     │                   │
│   └──────────┘└─────────┘└─────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、配色系统

```css
:root {
  --void-black: #050508;        /* 深空黑 - 主背景 */
  --deep-space: #0a0a12;        /* 深空 */
  --nebula-core: #1a1a2e;       /* 星云核心 - 卡片背景 */
  --nebula-purple: #8b5cf6;     /* 星云紫 - 主强调色 */
  --nebula-pink: #c084fc;       /* 星云粉 - 渐变辅助 */
  --star-gold: #fbbf24;         /* 恒星金 - 高亮/CTA */
  --aurora-green: #34d399;      /* 极光绿 - 成功/播放 */
  --aurora-cyan: #22d3ee;       /* 极光青 - 信息/链接 */
}
```

---

## 三、字体规范

| 用途 | 字体 |
|------|------|
| 标题 | Space Grotesk |
| 正文 | Inter / SF Pro |
| 数据/代码 | JetBrains Mono |

---

## 四、核心组件代码

### Button 按钮

```css
.btn-primary {
  padding: 0.75rem 1.5rem;
  background: linear-gradient(135deg, #8b5cf6 0%, #c084fc 100%);
  border: none;
  color: white;
  font-family: 'Space Grotesk', sans-serif;
  cursor: pointer;
  position: relative;
  overflow: hidden;
  transition: all 0.3s ease;
}

.btn-primary::before {
  content: '';
  position: absolute;
  inset: -2px;
  background: linear-gradient(135deg, #8b5cf6, #fbbf24, #8b5cf6);
  z-index: -1;
  opacity: 0;
  transition: opacity 0.3s ease;
}

.btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 0 30px rgba(139, 92, 246, 0.5);
}

.btn-primary:hover::before {
  opacity: 1;
}
```

### Card 资产卡片

```css
.asset-card {
  background: rgba(26, 26, 46, 0.6);
  border: 1px solid rgba(139, 92, 246, 0.2);
  backdrop-filter: blur(10px);
  padding: 1rem;
  position: relative;
  transition: all 0.3s ease;
}

.asset-card:hover {
  border-color: rgba(139, 92, 246, 0.5);
  box-shadow: 0 0 30px rgba(139, 92, 246, 0.2);
  transform: scale(1.02);
}

.asset-card::before {
  content: '';
  position: absolute;
  top: 0.5rem;
  left: 0.5rem;
  right: 0.5rem;
  bottom: 0.5rem;
  border: 1px solid rgba(139, 92, 246, 0.1);
  pointer-events: none;
}
```

### 动画效果

```css
@keyframes stardust-in {
  0% { opacity: 0; transform: scale(0.9) translateY(20px); }
  100% { opacity: 1; transform: scale(1) translateY(0); }
}

@keyframes pulse-glow {
  0%, 100% { box-shadow: 0 0 20px rgba(139, 92, 246, 0.3); }
  50% { box-shadow: 0 0 40px rgba(139, 92, 246, 0.6); }
}

@keyframes nebula-flow {
  0% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}
```

---

## 五、页面清单

1. **首页/发现页** - 星云背景 Hero + 筛选标签 + 资产卡片网格
2. **资产详情页** - 大型波形播放器 + 信息区 + 交互式衍生树
3. **铸造流程** - 3步向导（上传 → 元数据 → 确认）带进度指示
4. **衍生创作页** - 引用源展示 + 创作类型选择 + 收益分配滑块
5. **个人中心** - 用户数据概览 + Tab切换（资产/收益/引用）+ 图表可视化
6. **播放器浮层** - 底部固定播放条 + 展开式完整播放器
EOF

echo "✅ interaction_designer.md 创建完成"

echo ""
echo "🎉 所有文件创建完成！"
echo ""
echo "下一步："
echo "1. 上传到你的 GitHub 仓库:"
echo "   cd compose-demo"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit'"
echo "   git remote add origin https://github.com/catgraceyao/compose-demo.git"
echo "   git push -u origin main"
echo ""
echo "2. 或者直接复制文件内容到你的仓库"
