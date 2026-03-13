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
