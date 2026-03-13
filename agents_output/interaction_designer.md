# Compose 音乐资产平台 - 交互设计文档

## 一、核心页面线框图与布局

### 1.1 首页/发现页 (Discovery)

```
┌─────────────────────────────────────────────────────────────────────┐
│  ☰  ◆ COMPOSE                                    🔍  [钱包连接]  👤  │
│─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ╭─────────────────────────────────────────────────────────────╮   │
│   │                                                             │   │
│   │    ✦  在星尘中铸造你的声音  ✦                                │   │
│   │                                                             │   │
│   │         [ 上传音频 → 铸造资产 ]                              │   │
│   │                                                             │   │
│   ╰─────────────────────────────────────────────────────────────╯   │
│                                                                     │
│   ◄ 最新  │  最热 ►  │  可衍生  │  原始创作                        │
│                                                                     │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐               │
│   │ ◯ ◯ ◯  │  │ ◯ ◯ ◯  │  │ ◯ ◯ ◯  │  │ ◯ ◯ ◯  │               │
│   │ [波形图] │  │ [波形图] │  │ [波形图] │  │ [波形图] │               │
│   │         │  │         │  │         │  │         │               │
│   │ 星云漫步  │  │ 深空回响  │  │ 极光旋律  │  │ 星际穿越  │               │
│   │ @stella │  │ @void   │  │ @aurora │  │ @inter  │               │
│   │ ◆ 1.2K  │  │ ◆ 3.4K  │  │ ◆ 890   │  │ ◆ 5.6K  │               │
│   └─────────┘  └─────────┘  └─────────┘  └─────────┘               │
│                                                                     │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐               │
│   │ ◯ ◯ ◯  │  │ ◯ ◯ ◯  │  │ ◯ ◯ ◯  │  │ ◯ ◯ ◯  │               │
│   │ [波形图] │  │ [波形图] │  │ [波形图] │  │ [波形图] │               │
│   │         │  │         │  │         │  │         │               │
│   │ 黑洞频率  │  │ 量子纠缠  │  │ 引力波   │  │ 暗物质   │               │
│   │ @black  │  │ @quant  │  │ @grav   │  │ @dark   │               │
│   │ ◆ 2.1K  │  │ ◆ 780   │  │ ◆ 4.3K  │  │ ◆ 1.5K  │               │
│   └─────────┘  └─────────┘  └─────────┘  └─────────┘               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**布局说明：**
- **顶部导航栏**：极简设计，logo 采用抽象星体符号 ◆，深空黑底色
- **Hero 区域**：全宽大图/动态星云背景，居中大标题+CTA按钮
- **筛选标签**：横向滑动式标签，当前选中项有发光下划线
- **资产卡片**：方形/黄金比例卡片，波形可视化占位，带轨道装饰点

---

### 1.2 资产详情页 (Asset Detail)

```
┌─────────────────────────────────────────────────────────────────────┐
│  ◆ COMPOSE                              🔍  [钱包连接]  👤         │
│─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ╭────────────────────────────────────────────────────────────╮    │
│   │                                                            │    │
│   │                    [ 大型波形可视化 ]                        │    │
│   │                                                            │    │
│   │         ～～～～～～～～～～～～～～～～～～～～～              │    │
│   │       ～～～～～～～～～～～～～～～～～～～～～～～            │    │
│   │     ～～～～～～～～～～～～～～～～～～～～～～～～～          │    │
│   │                                                            │    │
│   │              ▶  播放中  02:34 / 04:12                        │    │
│   │                                                            │    │
│   ╰────────────────────────────────────────────────────────────╯    │
│                                                                     │
│   星云漫步 (Nebula Walk)                               ◆ 1,234      │
│   ─────────────────────────────────────────────────────────────     │
│   创作者: @stella_verse              铸造时间: 2024-03-12           │
│   协议: Echo v2.1                    链: Ethereum                   │
│                                                                     │
│   [描述文本区域... 这是一段关于在虚空中漫步的音频实验...]            │
│                                                                     │
│   ┌────────────────────────────────────────────────────────┐       │
│   │  标签: #ambient #space #electronic #nebula #drone      │       │
│   └────────────────────────────────────────────────────────┘       │
│                                                                     │
│   [ 💾 下载 ]  [ 🔗 引用 ]  [ 🔄 衍生 ]  [ ⭐ 收藏 ]                 │
│                                                                     │
│   ═══════════════════════════════════════════════════════════       │
│                                                                     │
│   引用关系图 (Derivative Tree)                                      │
│                                                                     │
│                    ┌─────────┐                                      │
│                    │  原始   │                                      │
│                    │  v1.0   │                                      │
│                    └────┬────┘                                      │
│            ┌────────────┼────────────┐                              │
│      ┌─────▼─────┐┌────▼────┐┌──────▼──────┐                        │
│      │ 混音版    ││ 配乐版  ││ 采样重制    │                        │
│      │ v1.1-a   ││ v1.1-b ││   v1.2     │                        │
│      └─────┬─────┘└─────────┘└──────┬──────┘                        │
│            │                        │                               │
│      ┌─────▼─────┐            ┌─────▼─────┐                         │
│      │  最终版   │            │  扩展版   │                         │
│      │  v1.2-a  │            │  v1.3-a  │                         │
│      └───────────┘            └───────────┘                         │
│                                                                     │
│   [ 查看更多版本历史 → ]                                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**布局说明：**
- **播放器区域**：占据首屏 60%，大型波形可视化作为视觉焦点
- **信息区**：左侧资产信息，右侧数据指标（紧凑排列）
- **操作按钮**：横向排列，主要操作用高亮边框
- **衍生树**：可视化展示版本分支，可交互展开/折叠

---

### 1.3 铸造流程 (Minting Flow)

```
┌─────────────────────────────────────────────────────────────────────┐
│  ◆ COMPOSE                              🔍  [钱包连接]  👤         │
│─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   铸造 Echo 资产                                          步骤 1/3   │
│   ═══════════════════════════════════════════════════════════       │
│                                                                     │
│   ┌────────────────────────────────────────────────────────────┐   │
│   │                                                            │   │
│   │                    ┌───────────────┐                       │   │
│   │                    │               │                       │   │
│   │                    │   ⬆ 上传音频   │                       │   │
│   │                    │   或拖拽至此   │                       │   │
│   │                    │               │                       │   │
│   │                    └───────────────┘                       │   │
│   │                                                            │   │
│   │              支持格式: WAV, MP3, FLAC, AAC                 │   │
│   │              最大文件: 100MB                               │   │
│   │                                                            │   │
│   └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   或选择:                                                           │
│   [ 🎙️ 录制音频 ]  [ 🔗 从链接导入 ]  [ 📁 从云盘选择 ]              │
│                                                                     │
│                                                                     │
│                    [  下一步  ]                                     │
│                                                                     │
│   进度:  ●────○────○                                                │
│          上传    元数据   确认                                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────┐
│  铸造 Echo 资产                                          步骤 2/3   │
│  ═══════════════════════════════════════════════════════════        │
│                                                                     │
│  音频已上传: cosmic_journey.wav (45.2 MB)                           │
│  [波形预览] ～～～～～～～～～～～～～～～～～～～～～～～～           │
│                                                                     │
│  资产名称        [ 宇宙漫游之旅              ]                       │
│                                                                     │
│  描述            [                              ]                   │
│                  [ 一段穿越时空的音频旅程，灵感来自                  ] │
│                  [ 遥远星系的神秘频率...        ]                   │
│                  [                              ]                   │
│                                                                     │
│  标签            [ ambient, space, journey ]  [ + 添加 ]            │
│                                                                     │
│  许可类型                                                             │
│  ○ CC0 (公共领域)      ● CC BY (署名)                               │
│  ○ CC BY-SA (署名-相同方式共享)      ○ 自定义                       │
│                                                                     │
│  可衍生性                                                            │
│  [========●====]  允许改编和引用                                     │
│       开放 ◄────────────────────────►  封闭                         │
│                                                                     │
│  价格 (可选)     [ 0.05 ETH ]    ○ 免费                             │
│                                                                     │
│              [ ← 上一步 ]        [ 下一步 → ]                       │
│                                                                     │
│  进度:  ────●────○                                                  │
│         上传    元数据   确认                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────┐
│  铸造 Echo 资产                                          步骤 3/3   │
│  ═══════════════════════════════════════════════════════════        │
│                                                                     │
│  预览你的 Echo 资产                                                  │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │                                                            │   │
│  │   ◆ 宇宙漫游之旅                                           │   │
│  │   ───────────────────────────                              │   │
│  │   创作者: 你 (0x7a2f...9c3d)                               │   │
│  │                                                            │   │
│  │   类型: Ambient / Space                                    │   │
│  │   时长: 4:23                                               │   │
│  │   格式: WAV / 48kHz / 24bit                                │   │
│  │                                                            │   │
│  │   许可: CC BY - 允许署名引用                               │   │
│  │   可衍生: 开放                                             │   │
│  │                                                            │   │
│  │   价格: 0.05 ETH                                           │   │
│  │                                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  铸造费用估算: ~0.002 ETH (~$8.50)                                  │
│  平台费用: 2.5%                                                     │
│                                                                     │
│  ⚠️  确认后，你的音频将被永久存储在 IPFS，                          │
│     并在区块链上铸造为 Echo 资产，无法撤销。                        │
│                                                                     │
│            [ ← 返回修改 ]         [ 确认铸造 → ]                    │
│                                                                     │
│  进度:  ────┼────●                                                  │
│         上传    元数据   确认                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

### 1.4 衍生创作页 (Remix/Create Derivative)

```
┌─────────────────────────────────────────────────────────────────────┐
│  ◆ COMPOSE                              🔍  [钱包连接]  👤         │
│─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   创建衍生作品                                          基于原作品   │
│   ═══════════════════════════════════════════════════════════       │
│                                                                     │
│   ╭────────────────────────────────────────────────────────────╮    │
│   │  引用源:                                                    │    │
│   │  ┌─────────────┐                                           │    │
│   │  │ [波形图]    │  星云漫步 (Nebula Walk)                    │    │
│   │  │             │  @stella_verse                             │    │
│   │  └─────────────┘  Echo ID: #8821                           │    │
│   ╰────────────────────────────────────────────────────────────╯    │
│                                                                     │
│   你的创作                                                           │
│   ─────────────────────────────────────────────────────────────     │
│                                                                     │
│   ┌────────────────────────────────────────────────────────────┐   │
│   │                                                            │   │
│   │                    ┌───────────────┐                       │   │
│   │                    │   ⬆ 上传     │                       │   │
│   │                    │   衍生作品    │                       │   │
│   │                    └───────────────┘                       │   │
│   │                                                            │   │
│   └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   衍生类型 (选择一项):                                               │
│                                                                     │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│   │  混音     │ │  采样     │ │  重制     │ │  致敬     │             │
│   │  Remix   │ │  Sample  │ │  Remake  │ │  Tribute │             │
│   │  [●]     │ │  [○]     │ │  [○]     │ │  [○]     │             │
│   └──────────┘ └──────────┘ └──────────┘ └──────────┘             │
│                                                                     │
│   衍生说明                                                           │
│   [ 我使用了原曲的合成器 pad 作为底噪，                              ] │
│   [ 加入了新的鼓点和 bassline，呈现出更动感的氛围...                 ] │
│                                                                     │
│   改动比例预估:  [========●========]  ~50%                           │
│                                                                     │
│   收益分配 (可选)                                                    │
│   原创者: [====●========] 15%                                       │
│   衍生创作者: [============●====] 85%                               │
│                                                                     │
│                  [ 预览 ]        [ 铸造衍生作品 → ]                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

### 1.5 个人中心 (Profile)

```
┌─────────────────────────────────────────────────────────────────────┐
│  ◆ COMPOSE                              🔍  [钱包连接]  👤         │
│─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ╭────────────────────────────────────────────────────────────╮    │
│   │                                                            │    │
│   │                     ┌──────────┐                           │    │
│   │                     │  ◯ ◯ ◯  │                           │    │
│   │                     │   👤    │   @stella_verse            │    │
│   │                     │  0x7a.. │   0x7a2f...9c3d            │    │
│   │                     └──────────┘                           │    │
│   │                                                            │    │
│   │   ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐          │    │
│   │   │  12    │  │  3.4K  │  │  156   │  │  0.89  │          │    │
│   │   │ 作品   │  │  总播放 │  │ 被引用 │  │  ETH   │          │    │
│   │   └────────┘  └────────┘  └────────┘  └────────┘          │    │
│   │                                                            │    │
│   ╰────────────────────────────────────────────────────────────╯    │
│                                                                     │
│   ◄ 我的资产  │  我的收益  │  引用记录  │  收藏  ►                      │
│                                                                     │
│   ┌────────────────────────────────────────────────────────────┐   │
│   │  资产列表                                                   │   │
│   │  ┌────────┬────────────────────────┬──────────┬────────┐  │   │
│   │  │ [波形] │ 星云漫步               │ ◆ 1.2K   │ 管理 ▼ │  │   │
│   │  │        │ Echo #8821 · 2024-03-12│ 12 引用  │        │  │   │
│   │  ├────────┼────────────────────────┼──────────┼────────┤  │   │
│   │  │ [波形] │ 深空回响               │ ◆ 890    │ 管理 ▼ │  │   │
│   │  │        │ Echo #9203 · 2024-03-10│ 5 引用   │        │  │   │
│   │  ├────────┼────────────────────────┼──────────┼────────┤  │   │
│   │  │ [波形] │ 极光旋律               │ ◆ 2.1K   │ 管理 ▼ │  │   │
│   │  │        │ Echo #9456 · 2024-03-08│ 8 引用   │        │  │   │
│   │  └────────┴────────────────────────┴──────────┴────────┘  │   │
│   └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│                                                                     │
│   收益概览 (本月)                                                     │
│   ─────────────────────────────────────────────────────────────     │
│                                                                     │
│   ┌────────────────────────────────────────────────────────────┐   │
│   │                                                            │   │
│   │      [收益趋势图表 - 波形/星云状可视化]                     │   │
│   │                                                            │   │
│   │   ～～～～～～～～～～～～～～～～～～～～～～～～～～～    │   │
│   │ ～～～～～～～～～～～～～～～～～～～～～～～～～～～～～   │   │
│   │   ～～～～～～～～～～～～～～～～～～～～～～～～～～～    │   │
│   │                                                            │   │
│   └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   收入来源                                                           │
│   ┌────────────────────────────────────────────────────────────┐   │
│   │ 直接销售       0.45 ETH    ████████████████                │   │
│   │ 引用收益       0.28 ETH    ██████████                      │   │
│   │ 衍生分成       0.16 ETH    ██████                          │   │
│   └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│                  [ 提现 → ]   [ 查看完整报告 → ]                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

### 1.6 播放器浮层/全局播放条

```
固定底部播放条 (Collapsed State):

┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  ▶  │ [波形图] ～～～～～～～～～～～～～～～  │  星云漫步        │
│     │    ↑                                │  @stella          │
│     │  拖动跳转                           │  ───────  ⧓       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

展开状态 (Expanded Player):

┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   ╭────────────────────────────────────────────────────────────╮    │
│   │                                                            │    │
│   │                    [ 大型星云可视化 ]                       │    │
│   │                                                            │    │
│   │                 ～～～～～～～～～～～～～                   │    │
│   │               ～～～～～～～～～～～～～～～                 │    │
│   │             ～～～～～～～～～～～～～～～～～               │    │
│   │               ～～～～～～～～～～～～～～～                 │    │
│   │                 ～～～～～～～～～～～～～                   │    │
│   │                                                            │    │
│   │   ⏮    ⏯    ⏭    │    ⟲    ⧓    ≣                        │    │
│   │                                                            │    │
│   │   ────────●────────────────────    01:23 / 04:12           │    │
│   │                                                            │    │
│   ╰────────────────────────────────────────────────────────────╯    │
│                                                                     │
│   星云漫步 (Nebula Walk)                                            │
│   @stella_verse                                                     │
│                                                                     │
│   [ 查看详情 ]  [ 查看引用链 ]  [ 创建衍生 ]  [ 添加到播放列表 ]      │
│                                                                     │
│   接下来播放                                                         │
│   ┌────────────────────────────────────────────────────────────┐   │
│   │ ◯ 深空回响        @void        04:32                      │   │
│   │ ◯ 极光旋律        @aurora      03:45                      │   │
│   │ ◯ 星际穿越        @inter       05:12                      │   │
│   └────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 二、关键交互说明

### 2.1 导航与浏览

| 交互 | 行为 | 动效 |
|------|------|------|
| **滚动** | 首页资产卡片随滚动渐显 | 淡入 + 轻微上浮 (0.3s) |
| **卡片悬停** | 显示播放按钮和快捷操作 | 边框发光，轻微放大 (1.02x) |
| **筛选切换** | 切换分类标签 | 下划线滑动过渡，内容淡入切换 |
| **搜索** | 聚焦搜索框 | 展开动画，显示搜索历史和热词 |
| **下拉菜单** | 导航展开 | 从触发点向外扩散的圆形展开 |

### 2.2 音频播放

| 交互 | 行为 | 动效 |
|------|------|------|
| **点击播放** | 开始播放，展开播放器 | 波形从卡片位置平滑过渡到播放器 |
| **波形拖动** | 跳转到指定时间 | 播放头平滑移动，波形高亮反馈 |
| **播放器展开** | 从底部滑出完整播放器 | 背景模糊，内容向上推 |
| **播放列表** | 显示/隐藏待播放队列 | 从右侧滑入面板 |
| **音量控制** | 悬停显示滑块 | 滑块垂直展开，带粒子效果 |

### 2.3 铸造流程

| 步骤 | 交互说明 |
|------|----------|
| **1. 上传** | 拖拽区域高亮反馈，显示上传进度条(星云流动效果)，完成后自动生成波形预览 |
| **2. 元数据** | 实时预览标签添加效果，许可选择后显示对应图标，价格输入显示预估收益 |
| **3. 确认** | 完整资产卡片预览，铸造按钮点击后显示进度(从中心向外扩散的波纹)，成功后显示"已上链"标识 |

### 2.4 引用/衍生

| 交互 | 行为 |
|------|------|
| **引用按钮** | 弹出创作类型选择器，原资产以缩略图形式固定在左侧 |
| **类型选择** | 卡片翻转显示类型说明，选中有发光边框 |
| **改动比例** | 拖动滑块实时显示预计分配比例 |
| **预览** | 分屏显示：左侧原资产波形，右侧新资产波形，重叠区域高亮 |
| **确认铸造** | 衍生关系在链上记录，成功后跳转到新资产页并显示"衍生自"链接 |

### 2.5 衍生树交互

| 交互 | 行为 | 动效 |
|------|------|------|
| **节点悬停** | 显示版本详情浮层 | 节点发光放大 |
| **节点点击** | 跳转到对应资产页 | 路径高亮，沿连接线流动光效 |
| **展开/折叠** | 显示/隐藏子节点 | 子节点从父节点"生长"出来 |
| **拖拽画布** | 移动整个树视图 | 惯性滚动，背景星空相对移动 |
| **缩放** | 放大/缩小视图 | 节点大小和标签自适应 |

### 2.6 个人中心

| 交互 | 行为 |
|------|------|
| **Tab 切换** | 内容区淡入切换，当前 tab 有下划线指示器 |
| **资产管理** | 下拉菜单：编辑元数据 / 转移所有权 / 下架 / 查看分析 |
| **收益图表** | 悬停显示具体数值，点击可筛选时间范围 |
| **提现** | 弹出确认框，显示预估到账时间和手续费 |

---

## 三、视觉风格指南

### 3.1 配色方案

```css
/* 主色调 - 深空系列 */
--void-black: #050508;        /* 主背景 - 接近纯黑带蓝调 */
--deep-space: #0a0a12;        /* 次级背景 - 深蓝黑 */
--nebula-core: #1a1a2e;       /* 卡片背景 - 深紫蓝 */

/* 强调色 - 星云与恒星 */
--nebula-purple: #8b5cf6;     /* 主强调色 - 星云紫 */
--nebula-pink: #c084fc;       /* 渐变辅助 - 粉紫 */
--star-gold: #fbbf24;         /* 高亮/重要 - 恒星金 */
--star-gold-dim: #d97706;     /* 次级高亮 - 暗金 */

/* 功能色 - 极光系列 */
--aurora-green: #34d399;      /* 成功/播放 - 极光绿 */
--aurora-cyan: #22d3ee;       /* 信息/链接 - 青蓝 */
--aurora-blue: #60a5fa;       /* 辅助信息 - 天蓝 */

/* 状态色 */
--danger-red: #f87171;        /* 错误/警告 */
--warning-amber: #fbbf24;     /* 注意 */

/* 文字色 */
--text-primary: #f8fafc;      /* 主要文字 - 近白 */
--text-secondary: #94a3b8;    /* 次要文字 - 灰蓝 */
--text-muted: #64748b;        /* 辅助文字 - 深灰蓝 */
--text-glow: rgba(139, 92, 246, 0.8);  /* 发光文字 */
```

### 3.2 字体规范

```css
/* 标题字体 - 科技感 */
font-family: 'Space Grotesk', 'Inter', sans-serif;
font-weight: 600;
letter-spacing: -0.02em;

/* 正文字体 - 清晰可读 */
font-family: 'Inter', 'SF Pro Display', system-ui, sans-serif;
font-weight: 400;

/* 数据/代码 - 等宽 */
font-family: 'JetBrains Mono', 'Fira Code', monospace;

/* 字号层级 */
--text-hero: 3rem;        /* 48px - Hero 标题 */
--text-h1: 2rem;          /* 32px - 页面标题 */
--text-h2: 1.5rem;        /* 24px - 区块标题 */
--text-h3: 1.25rem;       /* 20px - 卡片标题 */
--text-body: 1rem;        /* 16px - 正文 */
--text-small: 0.875rem;   /* 14px - 辅助文字 */
--text-xs: 0.75rem;       /* 12px - 标签/时间 */
```

### 3.3 动效设计

#### 3.3.1 入场动画
```css
/* 星尘浮现 */
@keyframes stardust-in {
  0% {
    opacity: 0;
    transform: translateY(20px) scale(0.98);
    filter: blur(4px);
  }
  100% {
    opacity: 1;
    transform: translateY(0) scale(1);
    filter: blur(0);
  }
}

/* 脉冲发光 */
@keyframes pulse-glow {
  0%, 100% {
    box-shadow: 0 0 20px rgba(139, 92, 246, 0.3);
  }
  50% {
    box-shadow: 0 0 40px rgba(139, 92, 246, 0.6);
  }
}
```

#### 3.3.2 交互反馈
```css
/* 悬停发光 */
.hover-glow {
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}
.hover-glow:hover {
  box-shadow: 0 0 30px rgba(139, 92, 246, 0.4);
  border-color: rgba(139, 92, 246, 0.6);
}

/* 波纹扩散 */
@keyframes ripple {
  to {
    transform: scale(4);
    opacity: 0;
  }
}
```

#### 3.3.3 持续动效
```css
/* 星云背景流动 */
@keyframes nebula-flow {
  0% {
    background-position: 0% 50%;
  }
  50% {
    background-position: 100% 50%;
  }
  100% {
    background-position: 0% 50%;
  }
}

/* 波形跳动 */
@keyframes waveform-dance {
  0%, 100% { transform: scaleY(1); }
  50% { transform: scaleY(1.2); }
}
```

### 3.4 背景效果

```css
/* 深空渐变背景 */
.space-bg {
  background: 
    radial-gradient(ellipse at 20% 80%, rgba(139, 92, 246, 0.15) 0%, transparent 50%),
    radial-gradient(ellipse at 80% 20%, rgba(251, 191, 36, 0.1) 0%, transparent 50%),
    radial-gradient(ellipse at 50% 50%, rgba(34, 211, 238, 0.05) 0%, transparent 70%),
    linear-gradient(180deg, #050508 0%, #0a0a12 100%);
  background-attachment: fixed;
}

/* 星空噪点纹理 */
.noise-overlay::after {
  content: '';
  position: absolute;
  inset: 0;
  background-image: url("data:image/svg+xml,..."); /* 噪点SVG */
  opacity: 0.03;
  pointer-events: none;
}
```

---

## 四、HTML/CSS 组件清单

### 4.1 基础组件

#### Button 按钮
```html
<!-- 主要按钮 - 星云紫 -->
<button class="btn btn-primary">
  <span class="btn-text">铸造资产</span>
  <span class="btn-glow"></span>
</button>

<!-- 次要按钮 - 描边 -->
<button class="btn btn-secondary">下载</button>

<!-- 幽灵按钮 - 纯文字 -->
<button class="btn btn-ghost">取消</button>

<!-- 图标按钮 -->
<button class="btn btn-icon">
  <svg class="icon-play"></svg>
</button>
```

```css
.btn {
  position: relative;
  padding: 0.75rem 1.5rem;
  font-family: 'Space Grotesk', sans-serif;
  font-size: 0.875rem;
  font-weight: 500;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  border: none;
  cursor: pointer;
  overflow: hidden;
  transition: all 0.3s ease;
}

.btn-primary {
  background: linear-gradient(135deg, #8b5cf6 0%, #c084fc 100%);
  color: #fff;
  clip-path: polygon(
    0 4px, 4px 0,
    calc(100% - 4px) 0, 100% 4px,
    100% calc(100% - 4px), calc(100% - 4px) 100%,
    4px 100%, 0 calc(100% - 4px)
  );
}

.btn-primary:hover {
  box-shadow: 0 0 30px rgba(139, 92, 246, 0.5);
  transform: translateY(-2px);
}

.btn-secondary {
  background: transparent;
  border: 1px solid rgba(139, 92, 246, 0.5);
  color: #c084fc;
}

.btn-secondary:hover {
  background: rgba(139, 92, 246, 0.1);
  border-color: #c084fc;
}
```

#### Card 卡片
```html
<article class="asset-card">
  <div class="card-visual">
    <div class="waveform-preview"></div>
    <button class="play-overlay">
      <svg class="icon-play"></svg>
    </button>
    <div class="orbital-dots">
      <span class="dot"></span>
      <span class="dot"></span>
      <span class="dot"></span>
    </div>
  </div>
  <div class="card-info">
    <h3 class="asset-title">星云漫步</h3>
    <p class="asset-creator">@stella_verse</p>
    <div class="asset-stats">
      <span class="stat">◆ 1.2K</span>
    </div>
  </div>
</article>
```

```css
.asset-card {
  position: relative;
  background: rgba(26, 26, 46, 0.6);
  border: 1px solid rgba(139, 92, 246, 0.2);
  backdrop-filter: blur(10px);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.asset-card:hover {
  border-color: rgba(139, 92, 246, 0.5);
  box-shadow: 0 0 40px rgba(139, 92, 246, 0.2);
  transform: translateY(-4px);
}

.card-visual {
  aspect-ratio: 1;
  position: relative;
  overflow: hidden;
  background: linear-gradient(135deg, #1a1a2e 0%, #0f0f1a 100%);
}

.play-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(5, 5, 8, 0.6);
  opacity: 0;
  transition: opacity 0.3s ease;
}

.asset-card:hover .play-overlay {
  opacity: 1;
}

.orbital-dots {
  position: absolute;
  top: 0.75rem;
  right: 0.75rem;
  display: flex;
  gap: 0.25rem;
}

.orbital-dots .dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #fbbf24;
  animation: pulse 2s infinite;
}

.orbital-dots .dot:nth-child(2) { animation-delay: 0.3s; }
.orbital-dots .dot:nth-child(3) { animation-delay: 0.6s; }
```

#### Input 输入框
```html
<div class="input-group">
  <label class="input-label">资产名称</label>
  <input type="text" class="input-field" placeholder="给你的作品命名...">
  <div class="input-glow"></div>
</div>

<div class="input-group">
  <label class="input-label">描述</label>
  <textarea class="input-field input-textarea" rows="4"></textarea>
</div>
```

```css
.input-group {
  position: relative;
  margin-bottom: 1.5rem;
}

.input-label {
  display: block;
  margin-bottom: 0.5rem;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: #94a3b8;
}

.input-field {
  width: 100%;
  padding: 0.875rem 1rem;
  background: rgba(10, 10, 18, 0.8);
  border: 1px solid rgba(139, 92, 246, 0.3);
  color: #f8fafc;
  font-family: 'Inter', sans-serif;
  font-size: 0.9375rem;
  transition: all 0.3s ease;
}

.input-field:focus {
  outline: none;
  border-color: #8b5cf6;
  box-shadow: 0 0 20px rgba(139, 92, 246, 0.2);
}

.input-field::placeholder {
  color: #64748b;
}
```

### 4.2 业务组件

#### WaveformVisualizer 波形可视化
```html
<div class="waveform-container">
  <canvas class="waveform-canvas"></canvas>
  <div class="playback-progress" style="width: 35%"></div>
  <div class="playhead" style="left: 35%"></div>
</div>
```

```css
.waveform-container {
  position: relative;
  height: 120px;
  background: linear-gradient(180deg, rgba(139, 92, 246, 0.1) 0%, transparent 100%);
  border-radius: 4px;
  overflow: hidden;
  cursor: pointer;
}

.waveform-canvas {
  width: 100%;
  height: 100%;
}

.playback-progress {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background: linear-gradient(90deg, 
    rgba(139, 92, 246, 0.3) 0%, 
    rgba(192, 132, 252, 0.2) 100%
  );
  pointer-events: none;
}

.playhead {
  position: absolute;
  top: 0;
  width: 2px;
  height: 100%;
  background: #fbbf24;
  box-shadow: 0 0 10px #fbbf24;
}
```

#### DerivativeTree 衍生树
```html
<div class="derivative-tree">
  <svg class="tree-connections"></svg>
  <div class="tree-nodes">
    <div class="tree-node root-node" data-id="v1.0">
      <div class="node-content">
        <span class="node-version">v1.0</span>
        <span class="node-label">原始</span>
      </div>
    </div>
    <div class="tree-node child-node" data-id="v1.1" data-parent="v1.0">
      <!-- 子节点内容 -->
    </div>
  </div>
</div>
```

```css
.derivative-tree {
  position: relative;
  min-height: 400px;
  background: radial-gradient(ellipse at center, rgba(139, 92, 246, 0.05) 0%, transparent 70%);
}

.tree-node {
  position: absolute;
  padding: 0.75rem 1rem;
  background: rgba(26, 26, 46, 0.8);
  border: 1px solid rgba(139, 92, 246, 0.3);
  cursor: pointer;
  transition: all 0.3s ease;
}

.tree-node:hover {
  border-color: #fbbf24;
  box-shadow: 0 0 20px rgba(251, 191, 36, 0.3);
  transform: scale(1.05);
}

.tree-node.root-node {
  border-color: #fbbf24;
  background: rgba(251, 191, 36, 0.1);
}

.tree-connections {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.tree-connections path {
  fill: none;
  stroke: rgba(139, 92, 246, 0.4);
  stroke-width: 2;
}

.tree-connections path.active {
  stroke: #fbbf24;
  stroke-dasharray: 5 5;
  animation: dash-flow 1s linear infinite;
}

@keyframes dash-flow {
  to {
    stroke-dashoffset: -10;
  }
}
```

#### StepIndicator 步骤指示器
```html
<div class="step-indicator">
  <div class="step completed">
    <span class="step-number">1</span>
    <span class="step-label">上传</span>
  </div>
  <div class="step-connector completed"></div>
  <div class="step active">
    <span class="step-number">2</span>
    <span class="step-label">元数据</span>
  </div>
  <div class="step-connector"></div>
  <div class="step">
    <span class="step-number">3</span>
    <span class="step-label">确认</span>
  </div>
</div>
```

```css
.step-indicator {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
}

.step {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
}

.step-number {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(139, 92, 246, 0.3);
  color: #64748b;
  font-size: 0.875rem;
  font-weight: 500;
  transition: all 0.3s ease;
}

.step.active .step-number {
  border-color: #8b5cf6;
  background: rgba(139, 92, 246, 0.2);
  color: #f8fafc;
  box-shadow: 0 0 15px rgba(139, 92, 246, 0.4);
}

.step.completed .step-number {
  border-color: #34d399;
  background: rgba(52, 211, 153, 0.2);
  color: #34d399;
}

.step-label {
  font-size: 0.75rem;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.step.active .step-label {
  color: #c084fc;
}

.step-connector {
  width: 60px;
  height: 1px;
  background: rgba(139, 92, 246, 0.3);
}

.step-connector.completed {
  background: #34d399;
  box-shadow: 0 0 10px rgba(52, 211, 153, 0.5);
}
```

#### GlobalPlayer 全局播放器
```html
<div class="global-player">
  <div class="player-controls">
    <button class="control-btn prev">⏮</button>
    <button class="control-btn play">▶</button>
    <button class="control-btn next">⏭</button>
  </div>
  
  <div class="player-waveform">
    <canvas></canvas>
    <div class="progress-bar">
      <div class="progress-fill" style="width: 35%"></div>
    </div>
  </div>
  
  <div class="player-info">
    <span class="track-title">星云漫步</span>
    <span class="track-artist">@stella_verse</span>
  </div>
  
  <div class="player-extras">
    <button class="control-btn">⧓</button>
    <div class="volume-control">
      <button class="control-btn">🔊</button>
      <input type="range" class="volume-slider" min="0" max="100" value="80">
    </div>
  </div>
</div>
```

```css
.global-player {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: 80px;
  display: flex;
  align-items: center;
  padding: 0 1.5rem;
  background: rgba(5, 5, 8, 0.95);
  backdrop-filter: blur(20px);
  border-top: 1px solid rgba(139, 92, 246, 0.2);
  z-index: 100;
}

.player-controls {
  display: flex;
  align-items: center;
  gap: 1rem;
  min-width: 120px;
}

.control-btn {
  background: transparent;
  border: none;
  color: #94a3b8;
  font-size: 1.25rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.control-btn.play {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #8b5cf6 0%, #c084fc 100%);
  color: #fff;
  border-radius: 50%;
  font-size: 1rem;
}

.control-btn:hover {
  color: #f8fafc;
}

.player-waveform {
  flex: 1;
  margin: 0 2rem;
  height: 40px;
  position: relative;
}

.progress-bar {
  position: absolute;
  bottom: -8px;
  left: 0;
  right: 0;
  height: 2px;
  background: rgba(139, 92, 246, 0.2);
  cursor: pointer;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #8b5cf6 0%, #c084fc 100%);
  box-shadow: 0 0 10px rgba(139, 92, 246, 0.5);
}

.player-info {
  min-width: 150px;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.track-title {
  font-size: 0.875rem;
  font-weight: 500;
  color: #f8fafc;
}

.track-artist {
  font-size: 0.75rem;
  color: #64748b;
}

.volume-control {
  position: relative;
}

.volume-control:hover .volume-slider {
  opacity: 1;
  transform: translateY(0);
}

.volume-slider {
  position: absolute;
  bottom: 100%;
  left: 50%;
  transform: translateX(-50%) translateY(10px);
  width: 100px;
  opacity: 0;
  transition: all 0.3s ease;
}
```

### 4.3 布局组件

#### Navigation 导航
```html
<nav class="main-nav">
  <div class="nav-brand">
    <span class="logo">◆</span>
    <span class="brand-name">COMPOSE</span>
  </div>
  
  <div class="nav-search">
    <input type="search" placeholder="搜索星尘中的声音..." class="search-input">
    <button class="search-btn">🔍</button>
  </div>
  
  <div class="nav-actions">
    <button class="nav-btn">连接钱包</button>
    <button class="nav-btn icon">👤</button>
  </div>
</nav>
```

```css
.main-nav {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 2rem;
  background: rgba(5, 5, 8, 0.8);
  backdrop-filter: blur(20px);
  border-bottom: 1px solid rgba(139, 92, 246, 0.1);
  z-index: 1000;
}

.nav-brand {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.logo {
  font-size: 1.5rem;
  color: #fbbf24;
  text-shadow: 0 0 20px rgba(251, 191, 36, 0.5);
}

.brand-name {
  font-family: 'Space Grotesk', sans-serif;
  font-size: 1.25rem;
  font-weight: 600;
  letter-spacing: 0.1em;
  color: #f8fafc;
}

.nav-search {
  flex: 1;
  max-width: 400px;
  margin: 0 2rem;
}

.search-input {
  width: 100%;
  padding: 0.625rem 1rem;
  background: rgba(10, 10, 18, 0.8);
  border: 1px solid rgba(139, 92, 246, 0.2);
  color: #f8fafc;
  font-size: 0.875rem;
  transition: all 0.3s ease;
}

.search-input:focus {
  outline: none;
  border-color: #8b5cf6;
  box-shadow: 0 0 20px rgba(139, 92, 246, 0.2);
}
```

#### FilterTabs 筛选标签
```html
<div class="filter-tabs">
  <button class="tab active" data-filter="latest">最新</button>
  <button class="tab" data-filter="popular">最热</button>
  <button class="tab" data-filter="remixable">可衍生</button>
  <button class="tab" data-filter="original">原始创作</button>
  <div class="tab-indicator"></div>
</div>
```

```css
.filter-tabs {
  position: relative;
  display: flex;
  gap: 0.5rem;
  padding: 0.25rem;
  background: rgba(10, 10, 18, 0.6);
  border: 1px solid rgba(139, 92, 246, 0.2);
}

.tab {
  position: relative;
  padding: 0.625rem 1.25rem;
  background: transparent;
  border: none;
  color: #94a3b8;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.3s ease;
  z-index: 1;
}

.tab:hover {
  color: #f8fafc;
}

.tab.active {
  color: #f8fafc;
}

.tab-indicator {
  position: absolute;
  bottom: 0.25rem;
  height: 2px;
  background: linear-gradient(90deg, #8b5cf6 0%, #c084fc 100%);
  box-shadow: 0 0 10px rgba(139, 92, 246, 0.5);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}
```

### 4.4 工具类 (Utilities)

```css
/* 容器 */
.container {
  max-width: 1400px;
  margin: 0 auto;
  padding: 0 2rem;
}

/* 网格 */
.grid-assets {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1.5rem;
}

/* 弹性布局 */
.flex-center {
  display: flex;
  align-items: center;
  justify-content: center;
}

.flex-between {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

/* 间距 */
.stack > * + * {
  margin-top: var(--stack-gap, 1rem);
}

/* 文字工具 */
.text-glow {
  text-shadow: 0 0 20px currentColor;
}

.text-gradient {
  background: linear-gradient(135deg, #8b5cf6 0%, #c084fc 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

/* 裁剪形状 */
.clip-space {
  clip-path: polygon(
    0 8px, 8px 0,
    calc(100% - 8px) 0, 100% 8px,
    100% calc(100% - 8px), calc(100% - 8px) 100%,
    8px 100%, 0 calc(100% - 8px)
  );
}

/* 滚动条样式 */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: #0a0a12;
}

::-webkit-scrollbar-thumb {
  background: rgba(139, 92, 246, 0.3);
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: rgba(139, 92, 246, 0.5);
}

/* 选择高亮 */
::selection {
  background: rgba(139, 92, 246, 0.3);
  color: #f8fafc;
}
```

---

## 五、响应式断点

```css
/* 移动端优先 */
/* 默认: < 640px */

/* 平板 */
@media (min-width: 640px) {
  .grid-assets {
    grid-template-columns: repeat(2, 1fr);
  }
}

/* 小桌面 */
@media (min-width: 768px) {
  .main-nav {
    padding: 0 3rem;
  }
  
  .grid-assets {
    grid-template-columns: repeat(3, 1fr);
  }
}

/* 大桌面 */
@media (min-width: 1024px) {
  .grid-assets {
    grid-template-columns: repeat(4, 1fr);
  }
  
  .hero-title {
    font-size: 3.5rem;
  }
}

/* 超大屏 */
@media (min-width: 1440px) {
  .container {
    max-width: 1600px;
  }
  
  .grid-assets {
    grid-template-columns: repeat(5, 1fr);
  }
}
```

---

## 六、设计原则总结

### 6.1 空间感营造
- 深色背景 + 径向渐变创造深邃感
- 多层背景叠加增加空间层次
- 元素使用微妙的发光效果模拟星体
- 避免实心填充，多用透明度和渐变

### 6.2 神秘感表达
- 非常规几何形状（斜切角、多边形）
- 微妙的动效暗示生命/能量
- 有限的色彩，精准的强调色使用
- 文字层级清晰但不单调

### 6.3 流动性设计
- 波形可视化作为核心视觉元素
- 曲线连接线而非直角
- 平滑的过渡动效
- 滚动触发的渐显效果

### 6.4 科幻美学参考
- 《星际穿越》: 数据可视化风格，干净的线条
- 《沙丘》: 厚重的质感，宗教般的仪式感
- 《死亡搁浅》: 未来感字体，连接概念可视化

---

*文档版本: 1.0*  
*最后更新: 2024-03-13*  
*设计师: Compose 交互设计团队*
