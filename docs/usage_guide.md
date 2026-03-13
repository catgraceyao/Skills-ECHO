# 文档使用指南

本目录包含 Compose 项目的完整设计文档，按角色分类说明如何使用。

---

## 📂 文件结构

```
ECHO-compose/
├── README.md                    # 项目总览和快速开始
├── integration_summary.md       # 整合摘要（先看这个）
├── video_director.md           # 视频分镜脚本
├── interaction_designer.md     # UI/UX 设计文档
├── protocol_architect.md       # 技术架构和合约
├── economy_analyst.md          # 经济模型
└── docs/                       # 补充文档
    └── usage_guide.md          # 本文件
```

---

## 🎯 按角色使用

### 如果你是项目管理者
**阅读顺序**：
1. `README.md` - 了解项目全貌
2. `integration_summary.md` - 查看执行路线图和时间估算
3. `economy_analyst.md` - 理解商业模式和分润机制

**关键决策点**：
- Phase 1 准备（钱包、开发环境）
- Phase 2-3 并行开发（合约+前端）
- Phase 4 视频制作依赖前端完成

---

### 如果你是视频制作人员
**核心文档**：`video_director.md`

**关键信息**：
- **时长**: 75秒
- **风格**: 宇宙星系/赛博光效
- **BGM**: Epic Electronic（参考 Hans Zimmer）
- **重点镜头**: 45-50秒的分润演示

**执行清单**：
- [ ] 准备产品界面录屏素材（需前端完成）
- [ ] 制作动画片段（Logo登场、分润可视化）
- [ ] 录制配音
- [ ] 后期调色（银翼杀手2049风格）

---

### 如果你是前端开发者
**核心文档**：`interaction_designer.md`

**快速启动**：
```bash
# 1. 创建项目
npx create-react-app compose-frontend --template typescript
cd compose-frontend

# 2. 安装依赖
npm install tailwindcss ethers @rainbow-me/rainbowkit wagmi

# 3. 初始化 Tailwind
npx tailwindcss init
```

**必看内容**：
1. 配色系统（CSS变量）
2. Button/Card 组件代码
3. 6个页面线框图
4. 动画效果（stardust-in, pulse-glow）

**开发顺序**：
1. 搭建 UI 框架（配色、字体、基础组件）
2. 钱包连接（RainbowKit）
3. 发现页（资产卡片列表）
4. 铸造流程（3步向导）
5. 资产详情页（波形播放器+衍生树）

---

### 如果你是合约开发者
**核心文档**：`protocol_architect.md`

**快速启动**：
```bash
# 1. 创建 Hardhat 项目
mkdir compose-contracts && cd compose-contracts
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
npx hardhat init

# 2. 安装 OpenZeppelin
npm install @openzeppelin/contracts

# 3. 配置 Sepolia 测试网
# 在 hardhat.config.ts 中添加网络配置
```

**开发顺序**：
1. EchoToken (ERC-721)
2. EchoRegistry (引用关系管理)
3. EchoDistributor (分润核心)
4. EchoMarket (市场交易)

**关键优化**：
- Gas 优化：Merkle Tree 验证长链
- 存储：音频放 IPFS，链上存 hash
- 分润：累积领取模式

---

### 如果你是产品经理/设计师
**核心文档**：`economy_analyst.md` + `interaction_designer.md`

**重点理解**：
1. **三场景数值案例**：
   - 场景A：简单引用（Alice→Bob）
   - 场景B：链式引用（Alice→Bob→Charlie→David）
   - 场景C：分叉引用（Alice 被多人引用）

2. **核心参数**：
   - 原创者保底 25%（防止长链稀释）
   - 衰减系数 0.7（指数衰减）

3. **风险点**：
   - 收益稀释（已解决：保底机制）
   - 分叉"躺赚"（设计如此，鼓励原创）

---

## 🔧 常见问题

### Q1: 文档版本不一致怎么办？
**A**: 以 `integration_summary.md` 中的「关键参数一致性」表格为准，所有文档的参数已对齐。

### Q2: 应该先做什么？
**A**: 看 `integration_summary.md` 的「执行路线图」，按 Phase 1→2→3→4→5 推进。合约和前端可以部分并行。

### Q3: 视频制作需要什么前提？
**A**: 需要前端完成核心页面（铸造流程、资产详情、衍生树），才能开始录屏。

### Q4: 合约部署到哪个网络？
**A**: 先部署到 **Sepolia 测试网**（免费），成熟后再考虑主网。

### Q5: 配色可以改吗？
**A**: 建议保持宇宙主题（深空黑/星云紫/恒星金），但可以调整饱和度。如需大改，请更新所有文档保持一致。

---

## 📝 更新日志

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| 2026-03-13 | v1.0 | 初始版本，5个Agent输出整合 |

---

## 📮 反馈

如有问题或建议，请通过 GitHub Issues 反馈。
