# ECHO UI 设计系统

## 完整组件规范文档

> 版本: v1.0  
> 基于东方美学数字资产平台设计

---

## 一、设计原则

### 1.1 东方美学五要素

| 要素 | 设计表达 | 应用场景 |
|------|----------|----------|
| **留白** | 虚实相生，计白当黑 | 页面布局、间距控制 |
| **墨色** | 浓淡层次，丰富质感 | 文字、边框、阴影 |
| **朱砂** | 点睛强调，突出重点 | 按钮、印章、高亮 |
| **印章** | 身份象征，权威认证 | 数字签名、成就徽章 |
| **卷轴** | 流动渐进，时空延展 | 页面切换、内容展开 |

### 1.2 设计理念

```
传统东方美学 × 现代Web3交互 = ECHO设计系统

不是复古，而是东方精神的当代表达。
不是堆砌，而是恰到好处的留白与节奏。
```

---

## 二、色彩系统

### 2.1 核心色彩

```css
:root {
  /* 主色调 */
  --echo-ink: #1a1a1a;           /* 墨色 - 庄重深沉 */
  --echo-cinnabar: #c93756;      /* 朱砂 - 热情重要 */
  --echo-paper: #f5f0e8;         /* 宣纸 - 温暖雅致 */
  
  /* 辅助色 */
  --echo-indigo: #4a5568;        /* 青黛 - 次级文字 */
  --echo-gamboge: #d69e2e;       /* 藤黄 - 温暖点缀 */
  --echo-jade: #38a169;          /* 石绿 - 成功状态 */
  --echo-ink-light: #718096;     /* 墨灰 - 禁用状态 */
  
  /* 背景色 */
  --echo-bg-primary: #f5f0e8;
  --echo-bg-secondary: #ffffff;
  --echo-bg-tertiary: #faf8f5;
}
```

### 2.2 五行模块色

| 模块 | 五行 | 色彩 | 色值 | 应用 |
|------|------|------|------|------|
| 宫 | 土 | 土黄 | #D4A574 | 史诗、宏大音乐 |
| 商 | 金 | 银白 | #C0C0C0 | 金属、冷峻音乐 |
| 角 | 木 | 青绿 | #7CB342 | 自然、灵动音乐 |
| 徵 | 火 | 火红 | #E53935 | 热烈、激情音乐 |
| 羽 | 水 | 深蓝 | #1E88E5 | 柔润、空灵音乐 |

### 2.3 色彩使用规范

#### 主色比例
```
墨色 60%    - 文字、框架、图标
宣纸 30%    - 背景、卡片
朱砂 10%    - 强调、交互、印章
```

#### 状态色
| 状态 | 颜色 | 使用场景 |
|------|------|----------|
| 成功 | #38a169 | 完成、确认、通过 |
| 警告 | #d69e2e | 注意、提醒、预警 |
| 错误 | #c93756 | 错误、删除、危险 |
| 信息 | #1e88e5 | 提示、链接、引导 |

---

## 三、字体系统

### 3.1 字体栈

```css
/* 标题字体 */
--font-serif: 'Noto Serif SC', 'Source Han Serif SC', 'SimSun', serif;

/* 正文字体 */
--font-sans: 'Noto Sans SC', 'Source Han Sans SC', 'PingFang SC', 'Microsoft YaHei', sans-serif;

/* 等宽字体 */
--font-mono: 'JetBrains Mono', 'Fira Code', 'Consolas', monospace;

/* 书法字体（装饰） */
--font-calligraphy: '钟齐流江毛笔草字', 'Zhi Mang Xing', cursive;
```

### 3.2 字号规范

| 层级 | 大小 | 字重 | 行高 | 用途 |
|------|------|------|------|------|
| Hero | 48px | 700 | 1.2 | 首页大标题 |
| H1 | 36px | 700 | 1.3 | 页面标题 |
| H2 | 28px | 600 | 1.4 | 章节标题 |
| H3 | 22px | 600 | 1.4 | 小节标题 |
| H4 | 18px | 600 | 1.5 | 卡片标题 |
| Body Large | 18px | 400 | 1.7 | 引导文字 |
| Body | 16px | 400 | 1.7 | 正文 |
| Body Small | 14px | 400 | 1.6 | 辅助文字 |
| Caption | 12px | 400 | 1.5 | 注释说明 |

### 3.3 排版原则

- **中文禁则**：标点符号不出现在行首
- **行宽控制**：正文每行25-35个中文字符
- **段间距**：1.5倍行高，段间空一行
- **对齐方式**：正文两端对齐，标题左对齐

---

## 四、间距系统

### 4.1 间距令牌

```css
:root {
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 20px;
  --space-6: 24px;
  --space-8: 32px;
  --space-10: 40px;
  --space-12: 48px;
  --space-16: 64px;
  --space-20: 80px;
  --space-24: 96px;
}
```

### 4.2 组件间距

| 组件 | 内边距 | 间距 |
|------|--------|------|
| 按钮 | 12px 24px | - |
| 卡片 | 24px | - |
| 输入框 | 12px 16px | - |
| 列表项 | 16px | 8px |
| 章节间距 | - | 48px |

---

## 五、动效规范

### 5.1 缓动函数

```css
:root {
  /* 标准缓动 */
  --ease-standard: cubic-bezier(0.4, 0, 0.2, 1);
  
  /* 减速缓动（进入） */
  --ease-decelerate: cubic-bezier(0, 0, 0.2, 1);
  
  /* 加速缓动（退出） */
  --ease-accelerate: cubic-bezier(0.4, 0, 1, 1);
  
  /* 弹性缓动 */
  --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
  
  /* 水墨缓动（特殊） */
  --ease-ink: cubic-bezier(0.25, 0.46, 0.45, 0.94);
}
```

### 5.2 时长规范

| 时长 | 使用场景 |
|------|----------|
| 100ms | 微交互（hover状态） |
| 200ms | 小过渡（颜色变化） |
| 300ms | 标准过渡（展开/收起） |
| 500ms | 大过渡（页面切换） |
| 800ms | 特殊效果（卷轴展开） |

### 5.3 动效预设

#### 水墨淡入
```css
@keyframes ink-fade-in {
  0% {
    opacity: 0;
    filter: blur(8px);
    transform: scale(0.98);
  }
  50% {
    opacity: 0.5;
    filter: blur(4px);
  }
  100% {
    opacity: 1;
    filter: blur(0);
    transform: scale(1);
  }
}
```

#### 卷轴展开
```css
@keyframes scroll-unfold {
  0% {
    clip-path: inset(0 100% 0 0);
  }
  100% {
    clip-path: inset(0 0 0 0);
  }
}
```

#### 印章盖印
```css
@keyframes seal-stamp {
  0% {
    transform: scale(1.5);
    opacity: 0;
  }
  50% {
    transform: scale(0.95);
    opacity: 1;
  }
  70% {
    transform: scale(1.02);
  }
  100% {
    transform: scale(1);
  }
}
```

---

## 六、组件规范

### 6.1 基础组件

#### Button 按钮

**类型：**
- Primary (主按钮) - 朱砂背景
- Secondary (次按钮) - 墨色边框
- Ghost (幽灵按钮) - 透明背景
- Danger (危险按钮) - 红色背景

**规格：**
```jsx
<Button
  variant="primary"      // primary | secondary | ghost | danger
  size="medium"          // small | medium | large
  disabled={false}
  loading={false}
  onClick={handleClick}
>
  按钮文字
</Button>
```

**样式代码：**
```css
.echo-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 12px 24px;
  border-radius: 8px;
  font-weight: 500;
  transition: all 200ms var(--ease-standard);
}

.echo-btn-primary {
  background: var(--echo-cinnabar);
  color: white;
}

.echo-btn-primary:hover {
  background: rgba(201, 55, 86, 0.9);
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(201, 55, 86, 0.3);
}
```

#### Input 输入框

**规格：**
```jsx
<Input
  type="text"
  placeholder="请输入"
  value={value}
  onChange={handleChange}
  error={errorMessage}
  disabled={false}
/>
```

**样式代码：**
```css
.echo-input {
  width: 100%;
  padding: 12px 16px;
  border: 1px solid rgba(26, 26, 26, 0.2);
  border-radius: 8px;
  background: white;
  transition: border-color 200ms var(--ease-standard);
}

.echo-input:focus {
  border-color: var(--echo-cinnabar);
  outline: none;
  box-shadow: 0 0 0 3px rgba(201, 55, 86, 0.1);
}
```

#### Card 卡片

**规格：**
```jsx
<Card
  variant="default"      // default | hover | interactive
  padding="large"        // small | medium | large
>
  {children}
</Card>
```

**样式代码：**
```css
.echo-card {
  background: white;
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  border: 1px solid rgba(26, 26, 26, 0.05);
  transition: all 300ms var(--ease-standard);
}

.echo-card-hover:hover {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
  transform: translateY(-2px);
}
```

### 6.2 ECHO专用组件

#### PowerSlider 四权力滑块

**用途：** 配置四权力（用/扩/衍/益）档位

**规格：**
```jsx
<PowerSlider
  power="use"            // use | spread | derive | profit
  value={5}              // 1-8
  onChange={handleChange}
  showAgentTip={true}
/>
```

**交互：**
- 拖动滑块选择1-8档
- 实时显示当前档位名称
- Agent建议提示
- 档位改变时触发卦象更新

**样式代码：**
```css
.power-slider {
  position: relative;
  height: 8px;
  background: rgba(26, 26, 26, 0.1);
  border-radius: 4px;
}

.power-slider-track {
  height: 100%;
  background: linear-gradient(to right, 
    var(--echo-ink) 0%,
    var(--echo-cinnabar) 100%
  );
  border-radius: 4px;
}

.power-slider-thumb {
  width: 24px;
  height: 24px;
  background: white;
  border: 3px solid var(--echo-cinnabar);
  border-radius: 50%;
  cursor: grab;
  transition: transform 200ms var(--ease-spring);
}

.power-slider-thumb:hover {
  transform: scale(1.2);
}

.power-slider-thumb:active {
  cursor: grabbing;
  transform: scale(1.1);
}
```

#### GuaPreview 卦象预览

**用途：** 实时显示当前四权力对应的卦象

**规格：**
```jsx
<GuaPreview
  upperGua="qian"        // 上卦
  lowerGua="kun"         // 下卦
  qiShu={0.78}           // 气数
  dongYao={[2, 5]}       // 变爻位置
/>
```

**样式代码：**
```css
.gua-preview {
  background: linear-gradient(135deg, #faf8f5 0%, #f5f0e8 100%);
  border-radius: 16px;
  padding: 32px;
  text-align: center;
  border: 1px solid rgba(26, 26, 26, 0.1);
}

.gua-symbol {
  font-size: 64px;
  margin-bottom: 16px;
  animation: seal-stamp 500ms var(--ease-spring);
}

.gua-name {
  font-family: var(--font-serif);
  font-size: 24px;
  font-weight: 600;
  margin-bottom: 8px;
}

.gua-meaning {
  color: var(--echo-indigo);
  font-size: 14px;
}
```

#### RadarChart 六爻雷达图

**用途：** 可视化六爻坐标（时/空/关/势/变/根）

**规格：**
```jsx
<RadarChart
  data={{
    shangLiu: 82,    // 上六 - 时位
    jiuWu: 65,       // 九五 - 空位
    liuSi: 78,       // 六四 - 人位
    jiuSan: 88,      // 九三 - 势位
    liuEr: 45,       // 六二 - 变位
    chuJiu: 92       // 初九 - 根位
  }}
  size={240}
/>
```

**SVG实现：**
```jsx
function RadarChart({ data, size = 240 }) {
  const center = size / 2;
  const radius = size * 0.4;
  const angles = [0, 60, 120, 180, 240, 300];
  const labels = ['天', '地', '时', '空', '关', '衍'];
  
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {/* 背景网格 */}
      {[0.3, 0.6, 1].map(scale => (
        <polygon
          key={scale}
          points={angles.map(angle => {
            const rad = (angle - 90) * Math.PI / 180;
            const r = radius * scale;
            return `${center + r * Math.cos(rad)},${center + r * Math.sin(rad)}`;
          }).join(' ')}
          fill="none"
          stroke="rgba(26,26,26,0.1)"
          strokeWidth="1"
        />
      ))}
      
      {/* 数据区域 */}
      <polygon
        points={angles.map((angle, i) => {
          const rad = (angle - 90) * Math.PI / 180;
          const value = Object.values(data)[i] / 100;
          const r = radius * value;
          return `${center + r * Math.cos(rad)},${center + r * Math.sin(rad)}`;
        }).join(' ')}
        fill="rgba(201,55,86,0.2)"
        stroke="#c93756"
        strokeWidth="2"
      />
      
      {/* 顶点标记 */}
      {angles.map((angle, i) => {
        const rad = (angle - 90) * Math.PI / 180;
        const value = Object.values(data)[i] / 100;
        const r = radius * value;
        return (
          <circle
            key={i}
            cx={center + r * Math.cos(rad)}
            cy={center + r * Math.sin(rad)}
            r="4"
            fill="#c93756"
          />
        );
      })}
      
      {/* 标签 */}
      {angles.map((angle, i) => {
        const rad = (angle - 90) * Math.PI / 180;
        const labelRadius = radius + 20;
        return (
          <text
            key={i}
            x={center + labelRadius * Math.cos(rad)}
            y={center + labelRadius * Math.sin(rad)}
            textAnchor="middle"
            dominantBaseline="middle"
            fontSize="12"
            fill="#4a5568"
          >
            {labels[i]}
          </text>
        );
      })}
    </svg>
  );
}
```

#### QiGauge 气数仪表盘

**用途：** 显示气数值（0-1）和等级

**规格：**
```jsx
<QiGauge
  value={0.72}           // 0-1
  size={180}
  showLabel={true}
/>
```

**等级颜色：**
```
0.85-1.00: 凛冽 - 火红 #E53935
0.65-0.85: 蓬勃 - 橙黄 #D69E2E
0.40-0.65: 温润 - 碧绿 #38A169
0.20-0.40: 沉寂 - 青灰 #4A5568
0.00-0.20: 虚无 - 墨黑 #1A1A1A
```

**样式代码：**
```css
.qi-gauge {
  position: relative;
  width: 180px;
  height: 180px;
}

.qi-gauge-ring {
  width: 100%;
  height: 100%;
  border-radius: 50%;
  background: conic-gradient(
    from 0deg,
    #E53935 0deg 72deg,
    #D69E2E 72deg 144deg,
    #38A169 144deg 216deg,
    #4A5568 216deg 288deg,
    #1A1A1A 288deg 360deg
  );
}

.qi-gauge-inner {
  position: absolute;
  inset: 16px;
  background: white;
  border-radius: 50%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.qi-gauge-value {
  font-size: 36px;
  font-weight: 700;
  color: var(--echo-ink);
}

.qi-gauge-label {
  font-size: 14px;
  color: var(--echo-indigo);
}

.qi-gauge-indicator {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 4px;
  height: 50%;
  background: var(--echo-cinnabar);
  transform-origin: bottom center;
  transform: translate(-50%, -100%) rotate(calc(var(--qi-value) * 360deg));
  transition: transform 800ms var(--ease-spring);
}
```

#### LineageGraph 血缘图谱

**用途：** 可视化展示资产的引用和衍生关系（DAG图）

**规格：**
```jsx
<LineageGraph
  rootAsset="asset-id"
  depth={3}
  direction="vertical"   // vertical | horizontal | radial
  onNodeClick={handleClick}
/>
```

**节点样式：**
```css
.lineage-node {
  padding: 12px 16px;
  background: white;
  border-radius: 12px;
  border: 2px solid transparent;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transition: all 300ms var(--ease-standard);
  cursor: pointer;
}

.lineage-node:hover {
  border-color: var(--echo-cinnabar);
  transform: scale(1.05);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
}

.lineage-node-root {
  border-color: var(--echo-cinnabar);
  background: linear-gradient(135deg, #faf8f5 0%, #fff5f5 100%);
}

.lineage-node-upstream {
  border-left: 4px solid var(--echo-gamboge);
}

.lineage-node-downstream {
  border-left: 4px solid var(--echo-jade);
}

.lineage-edge {
  stroke: rgba(26, 26, 26, 0.2);
  stroke-width: 2;
  fill: none;
}

.lineage-edge-animated {
  stroke-dasharray: 8, 4;
  animation: dash-flow 1s linear infinite;
}

@keyframes dash-flow {
  to {
    stroke-dashoffset: -12;
  }
}
```

#### SealStamp 印章

**用途：** 数字签名、成就徽章、认证标记

**规格：**
```jsx
<SealStamp
  text="认证"
  size="medium"          // small | medium | large
  variant="red"          // red | black | gold
  shape="square"         // square | circle | oval
/>
```

**样式代码：**
```css
.seal-stamp {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-family: var(--font-serif);
  font-weight: 700;
  border: 3px solid;
  animation: seal-stamp 500ms var(--ease-spring);
}

.seal-stamp-red {
  color: var(--echo-cinnabar);
  border-color: var(--echo-cinnabar);
}

.seal-stamp-black {
  color: var(--echo-ink);
  border-color: var(--echo-ink);
}

.seal-stamp-gold {
  color: var(--echo-gamboge);
  border-color: var(--echo-gamboge);
}

.seal-stamp-small {
  width: 40px;
  height: 40px;
  font-size: 14px;
  border-radius: 6px;
}

.seal-stamp-medium {
  width: 60px;
  height: 60px;
  font-size: 20px;
  border-radius: 8px;
}

.seal-stamp-large {
  width: 80px;
  height: 80px;
  font-size: 28px;
  border-radius: 10px;
}

.seal-stamp-circle {
  border-radius: 50%;
}
```

#### ScrollContainer 卷轴容器

**用途：** 内容展示采用横向卷轴滑动效果

**规格：**
```jsx
<ScrollContainer
  direction="horizontal" // horizontal | vertical
  showIndicators={true}
  autoPlay={false}
>
  {children}
</ScrollContainer>
```

**样式代码：**
```css
.scroll-container {
  position: relative;
  overflow: hidden;
}

.scroll-track {
  display: flex;
  gap: 24px;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  scrollbar-width: none;
  -ms-overflow-style: none;
  padding: 16px 0;
}

.scroll-track::-webkit-scrollbar {
  display: none;
}

.scroll-item {
  flex-shrink: 0;
  scroll-snap-align: start;
  animation: scroll-unfold 800ms var(--ease-ink) forwards;
}

.scroll-indicator {
  position: absolute;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 8px;
}

.scroll-indicator-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: rgba(26, 26, 26, 0.2);
  transition: all 300ms var(--ease-standard);
}

.scroll-indicator-dot.active {
  width: 24px;
  border-radius: 4px;
  background: var(--echo-cinnabar);
}
```

### 6.3 模块专用组件

#### 五声调式选择器

**用途：** 「音」模块 - 选择宫商角徵羽调式

```jsx
<WuYinSelector
  selected="gong"        // gong | shang | jue | zhi | yu
  onChange={handleChange}
  showCharacteristics={true}
/>
```

**样式：**
```css
.wuyin-selector {
  display: flex;
  gap: 12px;
  padding: 16px;
  background: white;
  border-radius: 12px;
}

.wuyin-item {
  flex: 1;
  padding: 16px;
  text-align: center;
  border-radius: 8px;
  cursor: pointer;
  transition: all 300ms var(--ease-standard);
}

.wuyin-item-gong { --color: #D4A574; }
.wuyin-item-shang { --color: #C0C0C0; }
.wuyin-item-jue { --color: #7CB342; }
.wuyin-item-zhi { --color: #E53935; }
.wuyin-item-yu { --color: #1E88E5; }

.wuyin-item:hover {
  background: rgba(var(--color), 0.1);
}

.wuyin-item.active {
  background: rgba(var(--color), 0.2);
  border: 2px solid var(--color);
}
```

#### 波形可视化

**用途：** 「音」模块 - 音频波形频谱着色

**规格：**
```jsx
<WaveformVisualizer
  audioData={frequencyData}
  colorScheme="wuxing"   // wuxing | single | gradient
  barCount={64}
/>
```

**五行频谱着色：**
```
20-250 Hz    → 土黄 #D4A574 (宫)
250-500 Hz   → 银白 #C0C0C0 (商)
500-2000 Hz  → 青绿 #7CB342 (角)
2000-6000 Hz → 火红 #E53935 (徵)
6000-20000Hz → 深蓝 #1E88E5 (羽)
```

#### 图层管理器

**用途：** 「画」模块 - 图层编辑管理

```jsx
<LayerManager
  layers={layers}
  activeLayer={activeId}
  onLayerSelect={handleSelect}
  onLayerReorder={handleReorder}
/>
```

**图层结构：**
```
题款/印章层
细节层
主体层
渲染层
墨骨层
线描层
底色层
```

#### 章节树

**用途：** 「文」模块 - 树形章节管理

```jsx
<ChapterTree
  chapters={chapters}
  selectedId={selectedId}
  onSelect={handleSelect}
  onReorder={handleReorder}
  maxDepth={5}
/>
```

---

## 七、响应式规则

### 7.1 断点定义

| 断点 | 宽度 | 设备类型 |
|------|------|----------|
| xs | < 640px | 手机竖屏 |
| sm | 640px - 768px | 手机横屏/小平板 |
| md | 768px - 1024px | 平板 |
| lg | 1024px - 1280px | 小桌面 |
| xl | > 1280px | 大桌面 |

### 7.2 栅格系统

```css
/* 12列栅格 */
.echo-container {
  max-width: 1280px;
  margin: 0 auto;
  padding: 0 24px;
}

.echo-row {
  display: grid;
  gap: 24px;
}

/* 响应式列数 */
.echo-col-1 { grid-template-columns: repeat(1, 1fr); }
.echo-col-2 { grid-template-columns: repeat(2, 1fr); }
.echo-col-3 { grid-template-columns: repeat(3, 1fr); }
.echo-col-4 { grid-template-columns: repeat(4, 1fr); }

@media (max-width: 1024px) {
  .echo-col-lg-2 { grid-template-columns: repeat(2, 1fr); }
  .echo-col-lg-1 { grid-template-columns: repeat(1, 1fr); }
}

@media (max-width: 768px) {
  .echo-col-md-1 { grid-template-columns: repeat(1, 1fr); }
}
```

### 7.3 触摸适配

- **最小点击区域**：44×44px
- **滑动手势**：左滑删除、右滑展开
- **双指缩放**：图片/画布查看
- **长按菜单**：更多选项

---

## 八、无障碍设计

### 8.1 键盘导航

- **Tab键**：顺序导航
- **Enter/Space**：激活按钮
- **Esc**：关闭弹窗
- **方向键**：滑块调整、列表选择

### 8.2 屏幕阅读器

```jsx
// ARIA标签示例
<button 
  aria-label="铸造新资产"
  aria-describedby="mint-tooltip"
>
  铸造
</button>

<div role="alert" aria-live="polite">
  铸造成功
</div>
```

### 8.3 色彩对比度

- 正文文字：对比度 ≥ 4.5:1
- 大号文字：对比度 ≥ 3:1
- 交互元素：对比度 ≥ 3:1

---

## 附录

### 图标库

使用 **Lucide React** 图标库，风格简洁优雅：

```jsx
import { Music, Image, FileText, Settings, User } from 'lucide-react';
```

### 代码规范

- 使用语义化HTML标签
- CSS采用BEM命名规范
- 组件props需有完整TypeScript类型定义
- 动画优先考虑CSS，复杂交互使用GSAP

---

*东方美学，现代表达。*  
*势在流动，位在变化。* 🎋
