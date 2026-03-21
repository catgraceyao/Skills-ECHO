# ECHO-compose

> Compose 是基于 **Echo Protocol** 的音乐资产平台 Demo 项目。
> 
> 让每一次创作，都留下回响。

---

## 🎵 「音」项目

**音** 是 ECHO Compose 生态中的独立音乐展示与播放平台。

### 在线预览
直接打开 `sound.html` 即可体验完整功能。

### 功能特性
| 功能 | 描述 |
|------|------|
| 🔍 搜索筛选 | 关键词、资产类型（原创/衍生）、流派、排序 |
| 🎶 音乐播放 | 底部迷你播放器、频谱可视化、播放控制 |
| 🎨 宇宙主题 | 星云/星系视觉风格、星空动画、青蓝+粉紫配色 |
| 📝 创作面板 | 上传音乐、编辑信息、ECHO权利配置、价格设置 |

### 快速开始
```bash
# 克隆仓库
git clone https://github.com/catgraceyao/ECHO-compose.git
cd ECHO-compose

# 直接打开 sound.html（或使用本地服务器）
open sound.html
```

---

## 📚 文档导航

| 文档 | 内容 | 适合读者 |
|------|------|----------|
| [sound.html](./sound.html) | **「音」项目 - 完整音乐平台 Demo** | 所有人 |
| [ECHO-MultiAgent-Fusion.html](./ECHO-MultiAgent-Fusion.html) | **ECHO与多Agent融合 - 三大场景PPT** | 所有人 |
| [ECHO-Agent-Presentation.html](./ECHO-Agent-Presentation.html) | ECHO与Agent关系演示 | 所有人 |
| [integration_summary.md](./integration_summary.md) | 项目总览、执行路线图、关键参数 | 所有人 |
| [video_director.md](./video_director.md) | 75秒演示视频分镜脚本 | 视频制作人员 |
| [interaction_designer.md](./interaction_designer.md) | UI设计、配色、CSS组件 | 前端开发 |
| [protocol_architect.md](./protocol_architect.md) | 智能合约架构、部署脚本 | 合约开发 |
| [economy_analyst.md](./economy_analyst.md) | 分润模型、数值案例 | 产品经理、经济设计 |

---

## 🤖 ECHO与多Agent融合

ECHO与AI Agent不是简单的"确权工具"关系，而是**势场与导航员**的共生关系。

### 核心场景

| 场景 | 描述 | Agent角色 |
|------|------|----------|
| **创作者生态闭环** | 从想法到收益，Agent全程护航创作生命周期 | 导航Agent、铸造Agent、监测Agent、跃迁Agent、收益Agent |
| **多Agent势场网络** | 五维Agent分工协作，形成技能血缘链 | 创作Agent、分析Agent(时间维)、传播Agent(空间维)、连接Agent(关系维)、导航Agent(综合) |
| **AI训练数据ECHO化** | Agent服务数据确权交易，使用即收益 | 数据打包Agent、查询Agent、协调Agent |

### 核心洞察

- **Agent不是工具** —— 是用户在势场中的导航员
- **三场景并存** —— 共享同一个ECHO协议层，相互嵌套赋能
- **技能血缘链** —— Agent能力可被引用、衍生，形成技能谱系

### 查看PPT
直接打开 [ECHO-MultiAgent-Fusion.html](./ECHO-MultiAgent-Fusion.html) 查看完整演示（13页东方美学风格）。

---

## 🚀 快速开始

### 1. 项目概述

**Compose** 是一个基于 Echo Protocol 的音乐资产平台：
- **创作者**可以将音频作品铸造成链上资产
- **引用机制**支持 remix、采样、改编等二次创作
- **自动分润**确保原创者在每次引用中获得收益

**核心创新**：多层级分润机制（原创者保底 25%）

### 2. 技术栈

| 层级 | 技术 |
|------|------|
| 区块链 | Ethereum (Sepolia 测试网) |
| 合约 | Solidity + Hardhat |
| 前端 | React + Tailwind CSS |
| 存储 | IPFS / Arweave |

### 3. 开发路线图（9-14天）

```
Phase 1: 准备（1-2天）
├── 安装 MetaMask，领取 Sepolia 测试 ETH
├── 配置 Hardhat 开发环境
└── 准备示例音频素材

Phase 2: 合约开发（3-4天）
├── EchoToken (ERC-721)
├── EchoRegistry (引用关系)
├── EchoDistributor (分润核心)
└── EchoMarket (市场交易)

Phase 3: 前端开发（4-5天）
├── UI 组件库（宇宙主题）
├── 铸造流程页面
├── 发现页/资产详情
└── 收益计算器

Phase 4: 视频制作（2-3天）
├── 产品功能录屏
├── 后期制作（剪辑/调色/特效）
└── 配音与音效

Phase 5: 部署（1-2天）
├── Sepolia 测试网部署
├── 前端连接测试网
└── 端到端测试
```

---

## 📖 使用说明

### 视频制作人员

查看 **[video_director.md](./video_director.md)**：
- 75秒分镜脚本（逐秒拆解）
- BGM建议（Epic Electronic风格）
- 录屏参数（2K/60fps）
- 调色参考（银翼杀手2049风格）

**关键时间点**：
- 0-10s: 痛点开场
- 45-50s: 分润演示（核心卖点）
- 63-67s: Slogan「让每一次创作，都留下回响」

### 前端开发人员

查看 **[interaction_designer.md](./interaction_designer.md)**：
- 6个核心页面线框图
- 配色系统（深空黑/星云紫/恒星金）
- CSS组件代码（Button/Card/动画）
- 字体规范（Space Grotesk/Inter）

**快速启动**：
```bash
npx create-react-app compose-frontend
cd compose-frontend
npm install tailwindcss ethers
# 复制 interaction_designer.md 中的CSS变量和组件
```

### 合约开发人员

查看 **[protocol_architect.md](./protocol_architect.md)**：
- Solidity 合约架构
- Gas 优化策略
- Hardhat 部署脚本
- 存储策略（链上+链下）

**快速启动**：
```bash
mkdir compose-contracts && cd compose-contracts
npm init -y
npm install hardhat @openzeppelin/contracts
npx hardhat init
# 复制 protocol_architect.md 中的合约代码
```

### 产品经理/经济设计

查看 **[economy_analyst.md](./economy_analyst.md)**：
- 分润公式数学推导
- 三场景数值案例（简单/链式/分叉引用）
- 风险分析（收益稀释/套利攻击）

**核心参数**：
| 参数 | 值 | 说明 |
|------|-----|------|
| 平台手续费 | 10% | 运营成本 |
| 直接创作者 | 40% | 被购买作品的创作者 |
| 上游分润池 | 50% | 所有上游创作者分配 |
| 原创者保底 | 25% | 长链引用时的最低保障 |

---

## 🎨 设计系统

### 配色

```css
--void-black: #050508;      /* 深空黑 - 主背景 */
--nebula-purple: #8b5cf6;   /* 星云紫 - 主强调色 */
--star-gold: #fbbf24;       /* 恒星金 - 高亮/CTA */
--aurora-green: #34d399;    /* 极光绿 - 成功/播放 */
```

### 字体

- **标题**: Space Grotesk
- **正文**: Inter / SF Pro
- **数据**: JetBrains Mono

### 视觉风格

- **主题**: 星系、星云、宇宙
- **感觉**: 空间感、神秘感、深邃、流动
- **参考**: 《星际穿越》《沙丘》《死亡搁浅》UI

---

## 📝 文档更新规范

### 文件命名
- 全部小写，单词间用下划线连接
- 例如：`integration_summary.md`

### 版本控制
- 文档版本格式：`v1.0`, `v1.1`
- 更新日期：YYYY-MM-DD 格式

### 提交信息规范
```
<type>: <subject>

<body>
```

**type 类型**:
- `docs`: 文档更新
- `feat`: 新功能
- `fix`: 修复
- `refactor`: 重构

**示例**:
```
docs: 更新视频分镜脚本

- 调整第45-50秒的分润演示动画
- 添加BGM具体曲目建议
```

---

## 🤝 贡献指南

1. **Fork** 本仓库
2. 创建分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m 'docs: 添加...'`
4. 推送分支：`git push origin feature/your-feature`
5. 创建 **Pull Request**

---

## 📄 许可证

MIT License

---

## 🔗 相关链接

- **GitHub**: https://github.com/catgraceyao/ECHO-compose
- **文档目录**: 见上方 [文档导航](#-文档导航)

---

> **让每一次创作，都留下回响。**
> 
> *Compose Team, 2026*
