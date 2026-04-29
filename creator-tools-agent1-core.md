# ECHO 创作者工具矩阵 - 核心创作工具设计文档

> 设计版本: v1.0  
> 设计目标: 构建专业级、云端优先、AI 增强的数字内容创作工具集
> 参考: Ableton Live, DaVinci Resolve, Blender, Figma, VS Code

---

## 1. 音频创作工作室 (ECHO Audio Studio)

### 1.1 功能模块详细设计

#### 1.1.1 多轨音频编辑器 (DAW Core)

**轨道系统**
```typescript
interface Track {
  id: string;
  type: 'audio' | 'midi' | 'aux' | 'master';
  name: string;
  color: string;
  height: number; // 像素高度
  
  // 音频特性
  clips: AudioClip[];
  automation: AutomationLane[];
  
  // 信号链
  input: InputRouting;
  effects: EffectSlot[];
  sends: SendRouting[];
  output: OutputRouting;
  
  // 控制
  volume: dB;
  pan: number; // -100 ~ 100
  mute: boolean;
  solo: boolean;
  arm: boolean; // 录音启用
}
```

**核心功能清单**
| 功能 | 优先级 | 技术细节 |
|------|--------|----------|
| 无限音轨创建 | P0 | 支持音频/MIDI/Aux/Master 四种轨道类型 |
| 非破坏性编辑 | P0 | 基于 Region 的编辑，保留原始音频文件 |
| 音频片段剪辑 | P0 | 切割/合并/淡入淡出/时间拉伸/音高偏移 |
| 多格式导入 | P0 | WAV/AIFF/MP3/FLAC/OGG/M4A，支持 16/24/32bit |
| 交叉淡化 | P1 | 自动和手动 crossfade，支持多种曲线类型 |
| 编组轨道 | P1 | Folder Track 概念，支持嵌套编组 |
| 轨道链接 | P1 | 多轨道同步编辑，常用于立体声对 |
| 区域标记 | P1 | Marker / Region / Loop 标记系统 |
| 吸附系统 | P1 | 网格/瞬态/节拍/相对吸附 |
| 时间拉伸算法 | P1 | élastique Pro/Solo/efficient, Formant 保持 |
| 音频量化 | P2 | 自动对齐网格， swing 调节 |

**波形编辑器视图**
- 多分辨率缩放 (从单个采样到整首歌概览)
- 频谱视图叠加 (FFT 分析，可选 STFT 显示)
- 瞬态检测与编辑
- 零交叉点检测 (ZCS)

#### 1.1.2 MIDI 编辑与虚拟乐器

**MIDI 编辑器组件**
```typescript
interface MidiEditor {
  viewModes: ('piano_roll' | 'score' | 'drum' | 'event_list')[];
  
  // Piano Roll 功能
  pianoRoll: {
    keyHeight: number;
    showVelocity: boolean;
    showModulation: boolean;
    snapGrid: GridDivision;
    ghostTracks: Track[]; // 显示其他轨道的音符作为参考
  };
  
  // 编辑工具
  tools: {
    select: SelectionTool;
    draw: DrawTool;
    erase: EraseTool;
    split: SplitTool;
    glue: GlueTool;
    quantize: QuantizeTool;
    velocity: VelocityTool;
  };
}
```

**MIDI 功能清单**
| 功能 | 优先级 | 技术细节 |
|------|--------|----------|
| 钢琴卷帘编辑 | P0 | 多选、拖拽、长度调整、音高调整 |
| 鼓组编辑器 | P0 | 步进音序器风格，支持 MPC 垫映射 |
| 乐谱视图 | P1 | 五线谱显示，支持多声部、表情记号 |
| 事件列表 | P2 | 原始 MIDI 事件查看与精确编辑 |
| MIDI 量化 | P0 | 强度可调 (0-100%)，支持 swing |
| 人性化 | P1 | 随机化力度、时序、音长 |
| 和弦检测 | P1 | 自动识别和弦并显示和弦名称 |
| 琶音器 | P1 | 内置实时 MIDI 效果 |
| MIDI 效果链 | P1 | 琶音/和弦/力度映射/音符范围限制 |
| 外部 MIDI 控制 | P2 | MPE 支持，复音触后 |

**虚拟乐器系统 (VSTi / AU / CLAP / WebAudio)**
```typescript
interface InstrumentRack {
  instruments: InstrumentSlot[];
  macroControls: MacroKnob[]; // 8 个宏控制旋钮
  chainMode: 'serial' | 'parallel' | 'key_split' | 'velocity_split';
  
  // 内置乐器
  builtIn: {
    sampler: EchoSampler;
    synth: {
      wavetable: WavetableSynth;
      fm: FMSynth;
      subtractive: SubtractiveSynth;
      granular: GranularSynth;
    };
    drum_machine: DrumMachine;
  };
}
```

**内置乐器清单**
| 乐器 | 类型 | 功能特点 |
|------|------|----------|
| Echo Sampler | 采样器 | 多采样映射，根音检测，循环点编辑 |
| Wave Synth | 波表合成 | 100+ 波表，波表位置调制，波形变形 |
| FM Pro | FM 合成 | 6 运算符，算法矩阵，反馈路径 |
| Analog Emu | 减法合成 | 双振荡器，滤波器，包络，LFO |
| Grain Cloud | 粒子合成 | 实时粒子化，密度/位置/大小控制 |
| Drum Box | 鼓机 | 16 步进，采样层叠，概率触发 |

#### 1.1.3 音频效果器 (Audio Effects)

**效果器架构**
```typescript
interface EffectChain {
  preFader: EffectSlot[]; // 插入效果
  postFader: EffectSlot[]; // 发送效果返回
  parallel: ParallelEffect[]; // 并联效果
}

interface EffectSlot {
  id: string;
  plugin: PluginInstance;
  enabled: boolean;
  wetDry: number; // 0-100%
  automation: AutomationTarget[];
  
  // 侧链
  sidechain: {
    source: Track | Bus;
    filter: EQFilter;
    threshold: dB;
  };
}
```

**内置效果器清单**

*动态处理*
| 效果器 | 参数 | 特性 |
|--------|------|------|
| ECHO Compressor | Threshold, Ratio, Attack, Release, Knee, Makeup | 模拟硬件压缩器模型 |
| Limiter | Ceiling, Release, True Peak | ISP 检测，母带级限制 |
| Gate/Expander | Threshold, Ratio, Attack, Hold, Release, Range | 噪声门，扩展器双模式 |
| De-esser | Frequency, Bandwidth, Threshold, Reduction | 频段特定压缩 |
| Transient Shaper | Attack, Sustain, Sensitivity | 瞬态增强/抑制 |

*均衡器*
| 效果器 | 参数 | 特性 |
|--------|------|------|
| Channel EQ | 4 段 (LF/LMF/HMF/HF) | 参数 EQ，可选 Bell/Sheif/Cut |
| Graphic EQ | 31 段 | 1/3 倍频程 |
| Dynamic EQ | 5 段 + 动态控制 | 每段独立压缩/扩展 |
| Linear Phase EQ | 8 段 | 零相位失真，母带级 |
| Match EQ | 频谱匹配 | 学习参考音轨频谱 |

*空间效果*
| 效果器 | 参数 | 特性 |
|--------|------|------|
| Reverb | Room/Hall/Plate/Cloud/ shimmer | 算法混响，预延迟，衰减，扩散 |
| Convolution Reverb | 脉冲响应库 | 真实空间模拟 |
| Delay | Tap/Mod/PingPong/Duck | BPM 同步，反馈滤波 |
| Chorus | Rate, Depth, Voices, Spread | 多声部合唱 |
| Phaser/Flanger | Rate, Depth, Feedback, Stages | 经典调制效果 |

*特殊效果*
| 效果器 | 功能 |
|--------|------|
| Pitch Shift | 音高偏移，保持时长，Formant 控制 |
| Time Stretch | 时长调整，保持音高，多种算法 |
| Bitcrusher | 降采样，位深压缩，饱和度 |
| Saturation | 磁带/电子管/晶体管饱和模型 |
| Vocal Tuner | 音高校正，自动调音，图形调音 |

#### 1.1.4 采样器与 Loop 库

**ECHO Sampler 架构**
```typescript
interface Sampler {
  // 采样管理
  zones: SampleZone[]; // 键位映射区域
  layers: SampleLayer[]; // 力度层
  roundRobin: number; // 轮询层数
  
  // 播放控制
  playback: {
    mode: 'oneshot' | 'loop' | 'pingpong' | 'slice';
    loopPoints: { start: number; end: number };
    crossfade: number;
    sliceMode: 'transient' | 'beat' | 'manual';
  };
  
  // 调制
  modMatrix: ModulationEntry[];
  envelopes: ADSREnvelope[];
  lfos: LFO[];
  
  // 切片模式 (如 Ableton Simpler/Sampler)
  slicePlayback: 'mono' | 'poly' | 'thru';
}
```

**Loop 库系统**
| 功能 | 描述 |
|------|------|
| 智能标签 | AI 自动分析 BPM、调性、情绪、乐器 |
| 预览 | 波形预览，悬停播放 |
| 收藏/分类 | 用户自定义标签，智能文件夹 |
| 拖放导入 | 直接拖到轨道上，自动时间拉伸 |
| Loop 切片 | 自动检测节拍切片，支持导出切片 |

**ECHO Sound Library**
- 5000+ 原厂采样和 Loop
- 50+ 虚拟乐器预设
- 200+ 效果器链预设
- 按风格分类：Electronic, Hip-Hop, Rock, Jazz, Orchestral...

#### 1.1.5 AI 音频增强工具

**AI 功能模块**
```typescript
interface AIAudioTools {
  // 音源分离
  stemSeparation: {
    models: (' vocals' | 'drums' | 'bass' | 'other' | 'piano')[];
    quality: 'fast' | 'balanced' | 'high';
    outputMode: 'separate_tracks' | 'mute_stem' | 'solo_stem';
  };
  
  // 降噪
  noiseReduction: {
    profile: 'auto' | 'learned';
    reductionAmount: number;
    preserveTransients: boolean;
  };
  
  // 智能增益
  smartGain: {
    targetLUFS: number;
    autoNormalize: boolean;
  };
}
```

| AI 功能 | 描述 | 模型 |
|---------|------|------|
| Stem Splitter | 分离人声/鼓/贝斯/其他 | Demucs/Spleeter 架构 |
| AI Mastering | 自动母带处理 | 参考分析 + 智能 EQ/压缩/限制 |
| Voice Isolation | 人声提取 | 深度学习降噪 |
| De-noise | 背景噪音消除 | 谱减法 + 神经网络 |
| De-reverb | 去除房间混响 | 混响抑制算法 |
| Clarity Enhancer | 智能瞬态增强 | 机器学习瞬态检测 |
| Auto-Tune Pro | 专业级音高校正 | 图形化编辑 |

#### 1.1.6 导出与格式设置

**导出配置**
```typescript
interface ExportConfig {
  // 范围
  range: 'loop' | 'selection' | 'all' | 'custom';
  customRange: { start: Time; end: Time };
  
  // 格式
  format: {
    type: 'wav' | 'aiff' | 'mp3' | 'flac' | 'ogg' | 'm4a';
    bitDepth: 16 | 24 | 32;
    sampleRate: 44100 | 48000 | 88200 | 96000;
    mp3Quality: 128 | 192 | 256 | 320;
    oggQuality: 0.1 | ... | 1.0;
  };
  
  // 声道
  channels: 'mono' | 'stereo' | '5.1' | '7.1' | 'stems';
  stemConfig?: StemExportConfig;
  
  // 处理
  normalize: boolean;
  targetLUFS?: number;
  truePeakLimit: number;
  dither: 'none' | 'TPDF' | 'noise_shaping';
  
  // ECHO 集成
  echoMetadata: ECHOAssetMetadata;
}
```

---

### 1.2 界面布局草图描述

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [菜单栏] 文件 | 编辑 | 视图 | 插入 | 效果 | AI 工具 | 导出 | 帮助          │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌────────────┐ ┌──────────────────────────────────────────────────────┐   │
│  │            │ │  时间标尺    1  2  3  4  | ►  [定位器] [循环区]       │   │
│  │ 浏览器面板  │ ├──────────────────────────────────────────────────────┤   │
│  │  ─────────  │ │  主工具栏    [选择] [裁剪] [画笔] [橡皮] [分割] [胶合]  │   │
│  │  采样库     │ │         [吸附] [网格: 1/4] [量化] [录音] [播放]      │   │
│  │  虚拟乐器   │ ├──────────────────────────────────────────────────────┤   │
│  │  效果器     │ │                                                      │   │
│  │  MIDI效果   │ │  音  轨  列  表                                       │   │
│  │  工程文件   │ │  ┌────┬──────────────────────────────────────────────┐│   │
│  │            │ │  │  1 │ 🎹 Piano Track          [M] [S] 🔴  [音量]  ││   │
│  │            │ │  │    │ ▓▓▓▓░░▓▓▓▓░░▓▓▓▓░░▓▓▓▓░░▓▓▓▓░░▓▓▓▓░░      ││   │
│  │            │ │  ├────┼──────────────────────────────────────────────┤│   │
│  │            │ │  │  2 │ 🥁 Drum Track           [M] [S]    [音量]  ││   │
│  │            │ │  │    │ ░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░▓▓░░    ││   │
│  │            │ │  ├────┼──────────────────────────────────────────────┤│   │
│  │            │ │  │  3 │ 🎸 Bass Track           [M] [S]    [音量]  ││   │
│  │            │ │  │    │ ▓▓▓▓▓▓▓▓░░░░▓▓▓▓▓▓▓▓░░░░▓▓▓▓▓▓▓▓░░░░      ││   │
│  │            │ │  ├────┴──────────────────────────────────────────────┤│   │
│  │            │ │  │  📐 时间线编辑区 (可缩放、可多选)                    ││   │
│  │            │ │  └──────────────────────────────────────────────────────┘│   │
│  │            │ │                                                      │   │
│  ├────────────┤ │  ═══════════════════════════════════════════════════  │   │
│  │  属性面板   │ │  底部面板 (可切换: MIDI编辑器 / 混音器 / 效果器 / 浏览器)│   │
│  │  ─────────  │ │  ┌────────────────────────────────────────────────────┐│   │
│  │  轨道参数   │ │  │  🎹 MIDI 钢琴卷帘编辑器                               ││   │
│  │  插件参数   │ │  │     C5 │░░░░░░░░░░░░▓▓▓▓░░░░░░░░▓▓▓▓░░░░░░░░░░░░││   │
│  │  采样编辑   │ │  │     B4 │░░░░░░▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░││   │
│  │            │ │  │     A4 │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░││   │
│  │            │ │  │     G4 │▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓░░░░░░││   │
│  └────────────┘ │  └────────────────────────────────────────────────────┘│   │
│                 └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────────┤
│  状态栏: [采样率: 48kHz] [位深: 24bit] [工程时长: 3:45] [CPU: 12%] [ECHO 🔗] │
└─────────────────────────────────────────────────────────────────────────────┘
```

**视图切换**
- `Arrangement View`: 整体编排视图
- `Session View`: 场景触发视图 (类似 Ableton Live，可选)
- `Mixer View`: 全屏混音器
- `Browser View`: 全屏浏览器

---

### 1.3 与 ECHO 协议集成

**导出为 ECHO 资产**
```typescript
interface AudioAssetExport {
  // 基本元数据
  title: string;
  description: string;
  genre: string[];
  bpm: number;
  key: string;
  duration: number;
  
  // 技术规格
  technical: {
    sampleRate: number;
    bitDepth: number;
    channels: number;
    format: string;
    fileSize: number;
  };
  
  // ECHO 特定
  echo: {
    assetType: 'music' | 'sound_effect' | 'loop' | 'stem' | 'sample';
    license: LicenseType;
    royalties: RoyaltyConfig;
    stems?: StemAsset[]; // 分层资产
    projectFile?: string; // 可编辑工程文件
    previewRegions?: TimeRange[]; // 预览片段
  };
}
```

| 导出类型 | 包含内容 | ECHO 资产类别 |
|----------|----------|---------------|
| 完整工程 | 音频文件 + 工程文件 + 插件配置 | `.echoaudio` - 可编辑 |
| 音频成品 | 立体声混音 | `music` / `sound_effect` |
| 分层导出 | 分轨音频 + 总线混音 | `stem_pack` - 含子资产 |
| Loop 包 | 切片 Loop + MIDI 片段 | `loop_kit` |
| 采样包 | 单音采样 + 采样器映射 | `sample_pack` |

---

## 2. 图像设计工作室 (ECHO Visual Studio)

### 2.1 功能模块详细设计

#### 2.1.1 图层式图像编辑器

**文档与图层架构**
```typescript
interface Document {
  id: string;
  name: string;
  
  // 画布
  canvas: {
    width: number;
    height: number;
    resolution: number; // DPI
    colorProfile: ColorProfile;
    colorSpace: 'sRGB' | 'P3' | 'Adobe RGB' | 'ProPhoto';
  };
  
  // 图层系统
  layers: Layer[];
  layerComps: LayerComp[]; // 图层复合状态
  
  // 历史记录
  history: HistoryState[];
  historyPanel: {
    maxStates: number;
    linear: boolean; // 是否线性历史
  };
  
  // 参考线/网格
  guides: Guide[];
  grids: GridConfig;
}

interface Layer {
  id: string;
  name: string;
  type: 'pixel' | 'text' | 'shape' | 'smart_object' | 'adjustment' | 'group';
  
  // 可见性与锁定
  visible: boolean;
  opacity: number;
  blendMode: BlendMode;
  locked: LockState;
  
  // 变换
  transform: TransformMatrix;
  
  // 遮罩
  mask?: LayerMask;
  vectorMask?: VectorMask;
  clippingMask?: boolean; // 剪贴蒙版
  
  // 效果
  effects: LayerEffect[];
  
  // 内容 (根据类型)
  content: PixelData | TextContent | ShapePath | AdjustmentData;
}
```

**图层功能清单**
| 功能 | 优先级 | 描述 |
|------|--------|------|
| 像素图层 | P0 | 基于栅格的图像数据 |
| 文字图层 | P0 | 可编辑文本，支持 OTF/variable fonts |
| 形状图层 | P0 | 矢量路径，可无限缩放 |
| 智能对象 | P0 | 嵌入/链接的外部文件，保留可编辑性 |
| 调整图层 | P0 | 非破坏性色彩调整，影响下方所有图层 |
| 图层组 | P0 | 图层文件夹，支持嵌套 |
| 蒙版图层 | P1 | 基于另一个图层的透明度蒙版 |
| 3D 图层 | P2 | 基础 3D 对象渲染 (与 3D 工作室联动) |
| 视频图层 | P2 | 帧动画，GIF 支持 |
| 链接图层 | P2 | 跨文档链接，统一更新 |

**选择工具集**
```typescript
interface SelectionTools {
  // 基础选择
  rectangle: RectMarqueeTool;
  ellipse: EllipseMarqueeTool;
  lasso: LassoTool;
  polygonLasso: PolygonLassoTool;
  magneticLasso: MagneticLassoTool;
  
  // 智能选择
  quickSelection: QuickSelectionTool; // 画笔式智能选择
  magicWand: MagicWandTool; // 颜色相似选择
  objectSelection: ObjectSelectionTool; // AI 对象检测
  
  // 选择操作
  operations: {
    add: SelectionMode;
    subtract: SelectionMode;
    intersect: SelectionMode;
    feather: number;
    expandContract: number;
    smooth: number;
    refineEdge: RefineEdgeDialog;
  };
}
```

#### 2.1.2 矢量绘图工具

**矢量系统架构**
```typescript
interface VectorSystem {
  // 路径
  paths: VectorPath[];
  activePath: VectorPath;
  
  // 路径组件
  pathComponents: {
    anchorPoint: AnchorPoint;
    directionLine: BezierHandle;
    segment: PathSegment;
  };
  
  // 形状工具
  tools: {
    pen: PenTool;
    curvaturePen: CurvaturePenTool;
    freeformPen: FreeformPenTool;
    addAnchor: AddAnchorPointTool;
    deleteAnchor: DeleteAnchorPointTool;
    convertPoint: ConvertPointTool;
    
    // 基本形状
    rectangle: RectangleTool;
    roundedRectangle: RoundedRectangleTool;
    ellipse: EllipseTool;
    polygon: PolygonTool;
    line: LineTool;
    customShape: CustomShapeTool;
  };
  
  // 路径操作
  operations: {
    combineShapes: PathCombineMode;
    subtractFront: PathCombineMode;
    intersectShapes: PathCombineMode;
    excludeOverlap: PathCombineMode;
    mergeComponents: boolean;
  };
}
```

**矢量功能清单**
| 功能 | 优先级 | 描述 |
|------|--------|------|
| 钢笔工具 | P0 | 贝塞尔曲线绘制 |
| 曲率钢笔 | P0 | 自动平滑曲线 |
| 形状工具 | P0 | 预设几何形状 |
| 路径面板 | P0 | 路径管理，工作路径/保存路径 |
| 描边与填充 | P0 | 纯色/渐变/图案 |
| 布尔运算 | P0 | 路径加减交差 |
| 路径对齐 | P1 | 锚点对齐，路径分布 |
| 文字沿路径 | P1 | 路径文字排版 |
| 矢量蒙版 | P1 | 基于路径的蒙版 |
| 从选区生成路径 | P1 | 选区转矢量 |
| 从路径生成选区 | P1 | 矢量转选区 |
| SVG 导入/导出 | P1 | 原生 SVG 支持 |

#### 2.1.3 滤镜与调色面板

**调整图层清单**
| 调整类型 | 功能参数 |
|----------|----------|
| 亮度/对比度 | 亮度 (-100~100), 对比度, 使用旧版 (线性/感知) |
| 色阶 | 输入/输出色阶，黑白场吸管，自动 |
| 曲线 | RGB/单色曲线，控制点，铅笔工具 |
| 曝光度 | 曝光度，位移，灰度系数校正 |
| 自然饱和度 | 自然饱和度 (保护肤色), 饱和度 |
| 色相/饱和度 | 全图/单色色相偏移，明度，饱和度 |
| 色彩平衡 | 阴影/中间调/高光三色平衡 |
| 黑白 | 单色转换，色调调整，预设 |
| 照片滤镜 | 加温/冷却滤镜，颜色选择，浓度 |
| 通道混合器 | 输出通道 = 输入通道混合 |
| 反相 | 颜色反转 |
| 色调分离 | 指定色阶数 |
| 阈值 | 黑白二值化 |
| 渐变映射 | 映射到渐变颜色 |
| 可选颜色 | CMYK 通道单独调整 |
| HDR 色调 | 单张 HDR 效果 |
| 阴影/高光 | 分别恢复阴影/高光细节 |
| 颜色查找 | 3D LUT 应用 |

**滤镜库 (Filter Gallery)**
```typescript
interface FilterGallery {
  // 艺术效果
  artistic: [
    'colored_pencil', 'cutout', 'dry_brush', 'film_grain',
    'fresco', 'neon_glow', 'paint_daubs', 'palette_knife',
    'plastic_wrap', 'poster_edges', 'rough_pastels', 'smudge_stick',
    'sponge', 'underpainting', 'watercolor'
  ];
  
  // 模糊
  blur: [
    'average', 'blur', 'blur_more', 'box_blur', 'gaussian_blur',
    'lens_blur', 'motion_blur', 'radial_blur', 'shape_blur',
    'smart_blur', 'surface_blur', 'tilt_shift'
  ];
  
  // 扭曲
  distort: [
    'displace', 'pinch', 'polar_coordinates', 'ripple',
    'shear', 'spherize', 'twirl', 'wave', 'zigzag',
    'liquify' // 液化面板
  ];
  
  // 杂色
  noise: [
    'add_noise', 'despeckle', 'dust_and_scratches', 'median'
  ];
  
  // 像素化
  pixelate: [
    'color_halftone', 'crystallize', 'facet', 'fragment',
    'mezzotint', 'mosaic', 'pointillize'
  ];
  
  // 渲染
  render: [
    'flame', 'tree', 'picture_frame', 'clouds', 'difference_clouds',
    'fibers', 'lens_flare'
  ];
  
  // 锐化
  sharpen: [
    'sharpen', 'sharpen_edges', 'sharpen_more', 'smart_sharpen',
    'unsharp_mask', 'high_pass', 'shake_reduction'
  ];
  
  // 风格化
  stylize: [
    'diffuse', 'emboss', 'extrude', 'find_edges', 'oil_paint',
    'neon_edges', 'solarize', 'tiles', 'trace_contour', 'wind'
  ];
  
  // 视频
  video: ['ntsc_colors', 'de_interlace'];
  
  // 其他
  other: [
    'custom', 'high_pass', 'maximum', 'minimum', 'offset'
  ];
}
```

**智能滤镜 (非破坏性滤镜)**
- 所有滤镜可作为智能滤镜应用
- 可编辑参数
- 可添加蒙版
- 混合模式和不透明度控制
- 堆叠多个滤镜

#### 2.1.4 AI 图像生成/编辑集成

**AI 工具面板**
```typescript
interface AITools {
  // 生成
  generation: {
    textToImage: TextToImageConfig;
    imageToImage: ImageToImageConfig;
    inpainting: InpaintingConfig;
    outpainting: OutpaintingConfig;
  };
  
  // 编辑
  editing: {
    generativeFill: GenerativeFillTool;
    generativeExpand: GenerativeExpandTool;
    removeObject: RemoveObjectTool;
    replaceBackground: ReplaceBackgroundTool;
    superResolution: SuperResolutionTool;
  };
  
  // 辅助
  assistance: {
    subjectSelect: AISubjectSelection;
    skyReplacement: SkyReplacementTool;
    neuralFilters: NeuralFilter[];
  };
}
```

**AI 功能清单**
| 功能 | 描述 | 模型/技术 |
|------|------|-----------|
| 文生图 | 从文本描述生成图像 | SDXL / DALL-E / Midjourney API |
| 图生图 | 基于参考图生成变体 | img2img pipeline |
| 智能填充 | 根据周围内容填充选区 | Generative Fill |
| 智能扩展 | 智能扩展画布边界 | Outpainting |
| 对象移除 | 智能擦除并修复背景 | Inpainting |
| 背景替换 | 智能分割主体并替换背景 | Segmentation + Generation |
| 超分辨率 | 2x/4x 智能放大 | Real-ESRGAN / SwinIR |
| 神经滤镜 | 智能人像编辑 | 皮肤平滑，表情调整，年龄变化 |
| AI 选择主体 | 一键选择主要对象 | Object Detection |
| AI 天空替换 | 自动识别天空并替换 | Sky Segmentation |

#### 2.1.5 模板库与设计系统

**设计系统架构**
```typescript
interface DesignSystem {
  // 颜色
  colors: {
    primitives: ColorToken[];
    semantic: ColorToken[];
    themes: ColorTheme[];
  };
  
  // 排版
  typography: {
    fontFamilies: FontFamily[];
    typeScale: TypeStyle[];
    textStyles: TextStyle[];
  };
  
  // 组件
  components: DesignComponent[];
  
  // 效果
  effects: {
    shadows: ShadowStyle[];
    blurs: BlurStyle[];
    gradients: GradientStyle[];
  };
  
  // 布局
  layout: {
    grids: GridStyle[];
    spacings: SpacingToken[];
    breakpoints: Breakpoint[];
  };
}
```

**模板类型**
| 类别 | 模板示例 |
|------|----------|
| 社交媒体 | Instagram 帖子/故事, TikTok, YouTube 缩略图 |
| 印刷品 | 名片, 海报, 传单, 简历 |
| 网页设计 | 着陆页, 仪表板, 电商页面 |
| 品牌 | Logo, 品牌指南, 社交媒体套件 |
| 摄影 | 照片编辑预设, 调色 LUT |
| 艺术 | 数字绘画模板, 漫画分镜 |

#### 2.1.6 导出预设与切片

**导出系统**
```typescript
interface ExportSystem {
  // 快速导出
  quickExport: {
    format: 'png' | 'jpg' | 'webp' | 'svg' | 'pdf';
    quality: number;
    scale: number;
  };
  
  // 导出为 Web
  exportForWeb: {
    formats: WebFormat[];
    optimization: ImageOptimizationConfig;
    responsive: boolean;
    artboardExport: boolean;
  };
  
  // 切片
  slices: Slice[];
  
  // 批量导出
  batchExport: {
    layers: Layer[];
    artboards: Artboard[];
    presets: ExportPreset[];
  };
  
  // ECHO 导出
  echoExport: ECHOImageAssetConfig;
}

interface Slice {
  id: string;
  name: string;
  bounds: Rectangle;
  exportSettings: ExportSettings;
  userSlice: boolean; // 用户创建 vs 自动切片
}
```

**导出格式支持**
| 格式 | 特性 |
|------|------|
| PNG | 8/24/32 bit, 透明, 交错 |
| JPEG | 质量 0-100, 渐进式, 元数据保留 |
| WebP | 有损/无损, 质量, 动画支持 |
| GIF | 调色板, 抖动, 动画帧 |
| SVG | 矢量导出, 文字转曲线选项 |
| PDF | 多页面, 嵌入字体, 印刷标准 |
| TIFF | 无损, 图层保留 (PSD 兼容) |
| PSD | 完整 Photoshop 兼容 |
| ECHO | 原生格式，完整编辑历史 |

---

### 2.2 界面布局草图描述

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ [菜单] 文件 | 编辑 | 图像 | 图层 | 选择 | 滤镜 | 视图 | 窗口 | AI 工具 | ECHO        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌────────┐ ┌──────────────────────────────────────────────────────────────────┐    │
│  │ 工具箱  │ │                        选项栏                                  │    │
│  │        │ │  [选区样式] [羽化: 0px] [消除锯齿 ✓] [样式: 正常] [宽度: 100]   │    │
│  ├────────┤ ├──────────────────────────────────────────────────────────────────┤    │
│  │ ⬚ 选框 │ │                                                  ↑ ↑ ↑ ↑        │    │
│  │ ✒ 钢笔 │ │  ┌─────────────────────────────────────────────┐ │ │ │ │        │    │
│  │ ✏ 画笔 │ │  │                                             │ │ │ │ │        │    │
│  │ 🖊 橡皮 │ │  │                                             │ │ │ │ │        │    │
│  │ 🪣 填充│ │  │          画布 / 文档编辑区                    │ │ │ │ │        │    │
│  │ 📝 文字│ │  │                                             │ │ │ │ │        │    │
│  │ 🔍 缩放│ │  │    [图层内容显示区域]                         │ │ │ │ │        │    │
│  │ 👋 手抓│ │  │                                             │ │ │ │ │        │    │
│  ├────────┤ │  │                                             │ │ │ │ │        │    │
│  │ 前景/背景│ │  └─────────────────────────────────────────────┘ │ │ │ │        │    │
│  │  [■] [□] │ │  ← 标尺                                      状态信息          │    │
│  ├────────┤ ├──────────────────────────────────────────────────────────────────┤    │
│  │        │ │                    面板停靠区                                  │    │
│  │ 颜色   │ │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │    │
│  │ 色板   │ │  │  图 层 面 板 │ │  通 道 面 板 │ │  路 径 面 板 │ │  历 史 面 板 │ │    │
│  │ 样式   │ │  │  ─────────  │ │  ─────────  │ │  ─────────  │ │  ─────────  │ │    │
│  │        │ │  │  📁 Group   │ │  RGB        │ │  Work Path  │ │  ○ 打开     │ │    │
│  │        │ │  │  📄 Layer 3 │ │  Red        │ │  Path 1     │ │  ● 复制图层 │ │    │
│  │        │ │  │  📄 Layer 2 │ │  Green      │ │  Path 2     │ │  ○ 曲线调整 │ │    │
│  │        │ │  │  📄 Layer 1 │ │  Blue       │ │             │ │  ● 高斯模糊 │ │    │
│  │        │ │  │  🔲 Background│ │  CMYK       │ │             │ │             │ │    │
│  │        │ │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │    │
│  │        │ │                                                                    │    │
│  │        │ │  ┌──────────────────────────────────────────────────────────┐    │    │
│  │        │ │  │                属性 / 调整面板                            │    │    │
│  │        │ │  │  不透明度: 100%  [██████████████████]                      │    │    │
│  │        │ │  │  混合模式: 正常 [▼]                                      │    │    │
│  │        │ │  │  ─────────────────────────────────────────────────────  │    │    │
│  │        │ │  │  效果: [+] 投影  内阴影  外发光  内发光  斜面浮雕  颜色叠加   │    │    │
│  └────────┘ │  └──────────────────────────────────────────────────────────┘    │    │
│             └──────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**工作区布局**
| 布局模式 | 用途 |
|----------|------|
| 绘画 | 左侧工具箱，右侧颜色和图层面板 |
| 摄影 | 专注图像，隐藏大部分面板 |
| 图形设计 | 中央画布，周围面板环绕 |
| 3D | 3D 工具架，材质面板 |
| 动效 | 时间轴底部显示 |
| AI 工作流 | AI 工具面板常驻右侧 |

---

## 3. 视频剪辑工作室 (ECHO Video Studio)

### 3.1 功能模块详细设计

#### 3.1.1 多轨时间线编辑器

**时间线架构**
```typescript
interface Timeline {
  // 序列设置
  sequence: {
    name: string;
    frameSize: { width: number; height: number };
    pixelAspectRatio: number;
    frameRate: number;
    audioSampleRate: number;
    videoPreviewFormat: string;
    workingColorSpace: ColorSpace;
  };
  
  // 轨道
  videoTracks: VideoTrack[];
  audioTracks: AudioTrack[];
  
  // 时间显示
  timeDisplay: 'timecode' | 'frames' | 'feet+frames';
  timecodeBase: number; // 24/25/30/60fps
  
  // 播放控制
  playhead: Time;
  inPoint: Time;
  outPoint: Time;
  duration: Time;
}

interface VideoTrack {
  id: string;
  index: number;
  name: string;
  enabled: boolean;
  locked: boolean;
  
  // 合成模式
  compositeMode: 'normal' | 'add' | 'multiply' | 'screen' | 'overlay' | ...;
  opacity: number;
  
  // 内容
  clips: VideoClip[];
  
  // 效果
  effects: VideoEffect[];
  motion: MotionProperties; // 位置/缩放/旋转/锚点
  opacity: OppertyProperty;
}

interface AudioTrack {
  id: string;
  index: number;
  name: string;
  
  // 路由
  pan: number;
  volume: dB;
  
  // 声道配置
  channelFormat: 'mono' | 'stereo' | '5.1' | 'adaptive';
  
  clips: AudioClip[];
  effects: AudioEffect[];
}
```

**时间线功能清单**
| 功能 | 优先级 | 描述 |
|------|--------|------|
| 多轨编辑 | P0 | 无限视频/音频轨道 |
| 三点/四点编辑 | P0 | 专业编辑流程 |
| 波纹编辑 | P0 | 自动关闭间隙 |
| 滚动编辑 | P0 | 调整剪辑点同时保持时长 |
| 滑动/滑移 | P0 | 调整片段位置或内容 |
| 嵌套序列 | P0 | 序列内嵌序列 |
| 多机位编辑 | P1 | 同步多机位素材，实时切换 |
| 时间重映射 | P1 | 速度曲线，时间扭曲 |
| 关键帧动画 | P0 | 所有参数可动画 |
| 标记系统 | P0 | 片段/序列标记，章节标记 |
| 代理工作流 | P1 | 低分辨率代理，高分辨率回批 |
| 素材箱管理 | P0 | 项目媒体组织 |

**编辑工具集**
```typescript
interface EditingTools {
  // 选择
  selection: {
    select: SelectionTool;
    trackSelect: TrackSelectTool;
    rippleSelect: RippleSelectTool;
  };
  
  // 编辑
  edit: {
    razor: RazorTool; // 切割
    slip: SlipTool; // 滑动内容
    slide: SlideTool; // 滑动片段
    rateStretch: RateStretchTool; // 速度调整
  };
  
  // 其他
  other: {
    pen: PenTool; // 关键帧和曲线编辑
    hand: HandTool;
    zoom: ZoomTool;
    type: TypeTool;
  };
}
```

#### 3.1.2 转场与特效库

**视频过渡 (Transitions)**
| 类别 | 转场效果 |
|------|----------|
| 溶解 | Cross Dissolve, Dip to Black/White, Film Dissolve |
| 划像 | Wipe, Barn Doors, Venetian Blinds, Iris |
| 滑动 | Push, Slide, Split, Swap |
| 缩放 | Cross Zoom, Zoom In/Out |
| 页面 | Page Peel, Page Turn |
| 3D | Cube Spin, Flip, Doors |
| 运动 | Morph Cut (AI 自动平滑跳切) |
| 音频 | Constant Power, Constant Gain, Exponential Fade |

**视频效果 (Effects)**
```typescript
interface VideoEffects {
  // 变换
  transform: [
    'position', 'scale', 'rotation', 'anchor_point',
    'crop', 'transform_2d', 'transform_3d'
  ];
  
  // 扭曲
  distort: [
    'corner_pin', 'lens_distortion', 'magnify', 'mesh_warp',
    'mirror', 'offset', 'optics_compensation', 'ripple',
    'spherize', 'transform', 'turbulent_displace', 'wave_warp'
  ];
  
  // 生成
  generate: [
    '4_color_gradient', 'circle', 'ellipse', 'grid',
    'lens_flare', 'paint_bucket', 'ramp', 'write_on'
  ];
  
  // 键控
  keying: [
    'alpha_adjust', 'color_key', 'color_range', 'difference_matte',
    'extract', 'keylight', 'luma_key', 'track_matte'
  ];
  
  // 遮罩
  matte: [
    'matte_choker', 'refine_hard_matte', 'refine_soft_matte',
    'simple_choker'
  ];
  
  // 噪波与颗粒
  noise: [
    'dust_and_scratches', 'fractal_noise', 'median',
    'noise', 'noise_alpha', 'noise_hls', 'turbulent_noise'
  ];
  
  // 风格化
  stylize: [
    'brush_strokes', 'cartoon', 'find_edges', 'glow',
    'mosaic', 'posterize', 'rough_edges', 'solarize', 'strobe'
  ];
  
  // 时间
  time: [
    'echo', 'posterize_time', 'time_difference', 'time_displacement',
    'timewarp'
  ];
  
  // 色彩校正
  color: [
    'arithmetic', 'black_and_white', 'brightness_and_contrast',
    'broadcast_colors', 'change_color', 'change_to_color',
    'channel_mixer', 'color_balance', 'color_balance_hls',
    'color_link', 'color_stabilizer', 'curves',
    'equalize', 'exposure', 'gamma_correction', 'hue_saturation',
    'leave_color', 'levels', 'lumetri_color', 'photo_filter',
    'proc_amp', 'shadow_highlight', 'tint', 'tint_lights', 'three_way_color_corrector'
  ];
  
  // 模糊与锐化
  blur: [
    'antialias', 'camera_blur', 'channel_blur', 'compound_blur',
    'directional_blur', 'fast_blur', 'gaussian_blur',
    'lens_blur', 'radial_blur', 'reduce_interlace_flicker',
    'sharpen', 'smart_blur', 'unsharp_mask'
  ];
}
```

**关键帧与动画**
- 空间插值: 线性/贝塞尔/自动贝塞尔/连续贝塞尔
- 时间插值: 保持/线性/贝塞尔/自动贝塞尔
- 速度曲线编辑
- 图表编辑器 (Graph Editor)

#### 3.1.3 字幕与标题工具

**字幕系统**
```typescript
interface SubtitleSystem {
  // 文本图层
  textLayers: TextLayer[];
  
  // 字幕导入/导出
  import: {
    srt: SRTImport;
    ass: ASSImport;
    vtt: VTTImport;
    stl: STLImport;
  };
  export: {
    srt: SRTExport;
    ass: ASSExport;
    vtt: VTTExport;
    burnedIn: BurnedInExport;
  };
  
  // 样式
  styles: SubtitleStyle[];
  
  // 语音转文字
  autoTranscribe: {
    language: string;
    speakerDetection: boolean;
    autoSync: boolean;
  };
}

interface TextLayer {
  type: 'point' | 'paragraph' | 'path';
  content: string;
  formatting: TextFormatting;
  animation: TextAnimationPreset;
  
  // 排版
  font: Font;
  size: number;
  leading: number;
  tracking: number;
  kerning: number;
  
  // 外观
  fill: FillStyle;
  stroke: StrokeStyle;
  background: BackgroundStyle;
  
  // 动画
  animation: TextAnimation;
}
```

**标题模板**
| 类别 | 示例 |
|------|------|
| 下三分之一 | 新闻字幕条，人名条 |
| 片头片尾 | 电影标题，演职员表 |
| 动态图形 | 订阅按钮，社交媒体图标 |
| 数据可视化 | 图表，进度条，计数器 |
| 呼出标注 | 箭头指示，放大镜效果 |
| 复古风格 | 老电影效果，胶片框 |

#### 3.1.4 调色与 LUT 管理

**Lumetri 风格调色面板**
```typescript
interface ColorPanel {
  // 基本校正
  basic: {
    inputLUT: LUT;
    whiteBalance: { temperature: number; tint: number };
    tone: {
      exposure: number;
      contrast: number;
      highlights: number;
      shadows: number;
      whites: number;
      blacks: number;
    };
    saturation: number;
  };
  
  // 创意
  creative: {
    look: LUT;
    intensity: number;
    fadedFilm: number;
    clarity: number;
    sharpen: number;
    vibrance: number;
    shadowTint: Color;
    highlightTint: Color;
  };
  
  // 曲线
  curves: {
    rgb: Curve;
    red: Curve;
    green: Curve;
    blue: Curve;
    hueVsHue: Curve;
    hueVsSat: Curve;
    hueVsLum: Curve;
    lumVsSat: Curve;
    satVsSat: Curve;
  };
  
  // 色轮
  colorWheels: {
    shadows: ColorBalance;
    midtones: ColorBalance;
    highlights: ColorBalance;
  };
  
  // HSL 辅助
  hslSecondary: {
    key: HSLKey;
    refine: RefineSettings;
    correction: ColorCorrection;
  };
  
  // 晕影
  vignette: {
    amount: number;
    midpoint: number;
    feather: number;
    roundness: number;
  };
}
```

**LUT 管理**
| 功能 | 描述 |
|------|------|
| LUT 浏览器 | 预览所有 LUT 效果 |
| 分类 | 电影模拟, 风格化, 技术转换 |
| 强度调节 | 0-100% LUT 混合 |
| LUT 导出 | 从调色导出 LUT |
| 场景剪切检测 | 自动应用不同 LUT |

**专业调色工具**
| 工具 | 功能 |
|------|------|
| 示波器 | 波形监视器, 矢量示波器, 直方图, RGB  Parade |
| 颜色匹配 | 自动匹配参考镜头 |
| HDR 调色 | PQ/HLG 工作流 |
| 遮罩跟踪 | 自动跟踪蒙版调色 |
| AI 肤色保护 | 智能识别人脸保持肤色自然 |

#### 3.1.5 音频混合面板

**音频编辑功能**
```typescript
interface AudioMixing {
  // 轨道控制
  trackMixer: {
    volume: dB;
    pan: number;
    mute: boolean;
    solo: boolean;
    arm: boolean;
  };
  
  // 效果
  effects: AudioEffect[];
  
  // 子混合
  submixes: SubmixTrack[];
  
  // 母带
  master: {
    effects: MasterEffect[];
    loudness: {
      targetLUFS: number;
      truePeak: number;
    };
  };
  
  // 测量
  meters: {
    peak: dB;
    rms: dB;
    loudness: LUFS;
  };
}
```

**音频功能清单**
| 功能 | 描述 |
|------|------|
| 自动音频对齐 | 同步视频和外录音频 |
| 音频增强 | 自动降噪，去混响 |
| 语音突显 | AI 增强人声清晰度 |
| 音乐智能重组 | 自动延长或缩短音乐 |
| 响度标准化 | 自动调整到标准 LUFS |
| 音频修复 | 爆音/咔嗒声去除 |

#### 3.1.6 渲染队列管理

**渲染队列**
```typescript
interface RenderQueue {
  jobs: RenderJob[];
  
  // 预设
  presets: RenderPreset[];
  
  // 输出模块
  outputModule: {
    format: 'h264' | 'prores' | 'dnxhd' | 'cineform' | 'webp' | 'gif';
    codec: string;
    quality: number;
    resolution: 'full' | 'half' | 'third' | 'quarter' | 'custom';
    frameRate: 'source' | number;
    fieldOrder: 'progressive' | 'upper' | 'lower';
    aspect: 'square' | 'source' | number;
    depth: '8bit' | '16bit' | '32bit';
    colorSpace: ColorSpace;
    audioFormat: 'aac' | 'pcm' | 'dolby';
    audioSampleRate: number;
  };
}

interface RenderPreset {
  name: string;
  category: 'web' | 'broadcast' | 'mobile' | 'archive' | 'echo';
  settings: OutputModuleSettings;
}
```

**预设类别**
| 类别 | 预设 |
|------|------|
| Web | YouTube 4K, YouTube 1080p, Instagram, TikTok, Twitter |
| 广播 | ProRes 422 HQ, DNxHD 220x, XDCAM HD |
| 移动 | H.264 高质量, H.265/HEVC 高效 |
| 存档 | ProRes 4444, 无损, 图像序列 |
| ECHO | 原生 ECHO 格式，元数据完整保留 |

---

### 3.2 界面布局草图描述

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ [菜单栏] 文件 | 编辑 | 剪辑 | 序列 | 标记 | 图形 | 视图 | 窗口 | AI 工具 | ECHO    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌─────────────────────────────────────────────────────────────┐   │
│  │            │  │  源监视器                    │  节目监视器                    │   │
│  │  项目面板   │  │  [素材预览/入点出点标记]      │  [时间线输出预览]              │   │
│  │  ─────────  │  │                              │                              │   │
│  │  📁 素材箱  │  │  ┌────────────────────────┐ │  ┌────────────────────────┐  │   │
│  │     📹 视频 │  │  │                        │ │  │                        │  │   │
│  │     🎵 音频 │  │  │     预览画面             │ │  │     预览画面             │  │   │
│  │     🖼 图片 │  │  │                        │ │  │                        │  │   │
│  │  ─────────  │  │  └────────────────────────┘ │  └────────────────────────┘  │   │
│  │  效果面板   │  │  [播放控制] [标记]          │  [播放控制] [全屏] [对比]      │   │
│  │  ─────────  │  └─────────────────────────────┴──────────────────────────────┘   │
│  │  🔍 搜索   │  ┌─────────────────────────────────────────────────────────────┐   │
│  │  📂 分类   │  │                      时间线面板                            │   │
│  ├────────────┤  │  ┌─────────────────────────────────────────────────────────┐ │   │
│  │            │  │  │ 时间标尺 [00:00:00:00] ◄────────── ►                   │ │   │
│  │ 效果控件   │  │  ├─────────────────────────────────────────────────────────┤ │   │
│  │  ─────────  │  │  │ V5 │ ░░░░░░░░░▓▓▓▓▓▓▓▓░░░░░░░░▓▓▓▓▓▓▓▓░░░░░░░░│       │ │   │
│  │  运动     │  │  │ V4 │ ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│       │ │   │
│  │  不透明度  │  │  │ V3 │ ░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░│       │ │   │
│  │  时间重映射│  │  │ V2 │ ▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓░░│       │ │   │
│  │  效果列表  │  │  │ V1 │ ░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░│       │ │   │
│  │            │  │  ├────┴─────────────────────────────────────────────────────┤ │   │
│  └────────────┘  │  │ A1 │ ∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿│ │   │
│                 │  │ A2 │ ∿∿∿∿∿∿∿∿∿∿∿∿░░░░░░░░░░░░░░░░░░∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿│ │   │
│                 │  │ A3 │ ░░░░∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿░░░░░░░░│ │   │
│                 │  └────┴─────────────────────────────────────────────────────┘ │   │
│                 │  [工具栏: 选择 | 剃刀 | 滑动 | 滑动 | 钢笔 | 手型 | 缩放]       │   │
│                 └─────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  音频仪表 [██░░░░░░░░] [████░░░░░░]    时间码: 00:02:15:04 | ECHO 导出就绪        │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. 3D 创作工作室 (ECHO 3D Studio)

### 4.1 功能模块详细设计

#### 4.1.1 基础建模工具

**建模系统架构**
```typescript
interface ModelingSystem {
  // 对象类型
  objects: {
    mesh: MeshObject[];
    curve: CurveObject[];
    surface: SurfaceObject[];
    text: TextObject[];
    metaball: MetaballObject[];
    empty: EmptyObject[];
  };
  
  // 选择模式
  selectionMode: 'object' | 'vertex' | 'edge' | 'face' | 'curve';
  
  // 修改器
  modifiers: Modifier[];
  
  // 工具
  tools: ModelingTool[];
}

interface MeshObject {
  vertices: Vertex[];
  edges: Edge[];
  faces: Face[];
  uvs: UVMap[];
  vertexColors: Color[];
  
  // 法线
  normals: {
    vertex: Vector3[];
    face: Vector3[];
    autoSmooth: boolean;
    angle: number;
  };
}
```

**基础建模工具清单**
| 工具 | 优先级 | 功能 |
|------|--------|------|
| 基本体 | P0 | 立方体, 球体, 圆柱, 圆锥, 圆环, 平面, 网格 |
| 编辑模式 | P0 | 顶点/边/面选择，软选择 |
| 挤出 | P0 | 面挤出，边挤出，顶点挤出 |
| 内插 | P0 | 面内插，环切 |
| 倒角 | P0 | 边倒角，顶点倒角，权重倒角 |
| 循环切割 | P0 | 循环边切割 |
| 细分 | P0 | Catmull-Clark, Simple |
| 布尔运算 | P0 | 并集, 差集, 交集 |
| 雕刻 | P1 | 动态拓扑雕刻 |
| 曲线转网格 | P1 | 贝塞尔/曲线生成表面 |
| 阵列 | P1 | 线性/圆形/物体阵列 |
| 镜像 | P1 | 对称建模 |
| 实体化 | P1 | 面厚度生成 |
| 晶格变形 | P2 | 非线性变形 |
| 缩裹 | P2 | 投影到其他表面 |

**雕刻模式**
```typescript
interface Sculpting {
  brushes: SculptBrush[];
  
  brushTypes: {
    draw: DrawBrush;
    clay: ClayBrush;
    inflate: InflateBrush;
    blob: BlobBrush;
    crease: CreaseBrush;
    smooth: SmoothBrush;
    flatten: FlattenBrush;
    scrape: ScrapeBrush;
    fill: FillBrush;
    grab: GrabBrush;
    snake_hook: SnakeHookBrush;
    pinch: PinchBrush;
    inflate: InflateBrush;
    layer: LayerBrush;
  };
  
  symmetry: {
    x: boolean;
    y: boolean;
    z: boolean;
    radial: number; // 径向对称轴数
  };
  
  dynamicTopology: {
    enabled: boolean;
    detailSize: number;
    detailType: 'relative' | 'constant' | 'brush';
  };
}
```

#### 4.1.2 材质与纹理编辑器

**材质系统**
```typescript
interface MaterialSystem {
  materials: Material[];
  
  // 着色器节点
  nodeEditor: {
    nodes: ShaderNode[];
    links: NodeLink[];
    groups: NodeGroup[];
  };
  
  // 材质类型
  types: {
    principledBSDF: PrincipledBSDF;
    emission: EmissionShader;
    glass: GlassBSDF;
    metal: MetallicBSDF;
    subsurface: SubsurfaceScattering;
    toon: ToonShader;
    hair: HairBSDF;
    volume: VolumeShader;
  };
}

interface Material {
  name: string;
  
  // 基础参数
  baseColor: Color | Texture;
  metallic: number | Texture;
  roughness: number | Texture;
  ior: number; // 折射率
  
  // 次表面
  subsurface: number;
  subsurfaceRadius: Vector3;
  subsurfaceColor: Color;
  
  // 其他
  specular: number;
  specularTint: Color;
  anisotropic: number;
  anisotropicRotation: number;
  sheen: number;
  sheenTint: Color;
  clearcoat: number;
  clearcoatRoughness: number;
  
  // 透射
  transmission: number;
  transmissionRoughness: number;
  
  // 发射
  emission: Color;
  emissionStrength: number;
  
  // Alpha
  alpha: number | Texture;
  alphaClip: number;
  
  // 法线
  normal: Texture | BumpMap;
  displacement: Texture;
  
  // 其他贴图
  ao: Texture; // 环境光遮蔽
  height: Texture;
  
  // 节点
  useNodes: boolean;
  nodeTree: NodeTree;
}
```

**纹理编辑器**
| 功能 | 描述 |
|------|------|
| 节点编辑器 | 可视化着色器编程 |
| 纹理绘制 | 直接在 3D 模型上绘画 |
| UV 展开 | 自动和手动 UV 展开 |
| 烘焙 | 光照/法线/AO 烘焙 |
| 程序化纹理 | 噪声, 沃罗诺伊, 波浪等 |
| 图像纹理 | 导入/编辑图像贴图 |
| PBR 工作流 | 金属/粗糙度标准工作流 |

#### 4.1.3 灯光与渲染设置

**灯光系统**
```typescript
interface LightingSystem {
  lights: Light[];
  
  lightTypes: {
    point: PointLight;
    sun: SunLight;
    spot: SpotLight;
    area: AreaLight;
    hdri: HDRILight;
    emission: MeshEmission;
  };
}

interface Light {
  type: LightType;
  color: Color;
  intensity: number; // 瓦特或流明
  
  // 点光源/聚光灯
  falloff: 'inverse_square' | 'constant' | 'linear' | 'custom_curve';
  radius: number; // 软阴影半径
  
  // 聚光灯特有
  spotSize: number;
  spotBlend: number;
  
  // 阴影
  useShadow: boolean;
  shadowResolution: number;
  shadowSoftness: number;
  contactShadows: boolean;
}
```

**渲染引擎**
```typescript
interface RenderEngine {
  // 实时预览
  viewport: {
    engine: 'workbench' | 'eevee' | 'echo_viewport';
    samples: number;
    denoising: boolean;
  };
  
  // 最终渲染
  production: {
    engine: 'cycles' | 'echo_render' | 'oidn';
    device: 'cpu' | 'gpu' | 'hybrid';
    samples: number;
    denoising: DenoisingConfig;
  };
  
  // 输出
  output: {
    resolution: { width: number; height: number };
    format: 'png' | 'exr' | 'hdr' | 'webp';
    colorDepth: 8 | 16 | 32;
    colorSpace: 'sRGB' | 'ACES' | 'Filmic';
    alpha: boolean;
    passes: RenderPass[];
  };
}
```

**渲染功能清单**
| 功能 | 优先级 | 描述 |
|------|--------|------|
| 实时光栅化 | P0 | Eevee 风格实时预览 |
| 路径追踪 | P0 | Cycles 风格高质量渲染 |
| GPU 加速 | P0 | CUDA/OptiX/Metal/HIP 支持 |
| 降噪 | P0 | OIDN/OptiX 降噪 |
| HDRI 照明 | P0 | 环境光照明 |
| 体积渲染 | P1 | 雾, 云, 烟 |
| 运动模糊 | P1 | 物体和相机运动模糊 |
| 景深 | P1 | 相机散景效果 |
| 次表面散射 | P1 | 皮肤, 蜡等材质 |
| 焦散 | P2 | 玻璃/水面光焦散 |
| 多通道渲染 | P1 | 分离通道输出 |

#### 4.1.4 动画时间线

**动画系统**
```typescript
interface AnimationSystem {
  // 时间线
  timeline: {
    startFrame: number;
    endFrame: number;
    currentFrame: number;
    fps: number;
  };
  
  // 关键帧
  keyframes: Keyframe[];
  
  // 插值
  interpolation: 'constant' | 'linear' | 'bezier' | 'automatic';
  
  // 编辑器
  editors: {
    dopeSheet: DopeSheetEditor;
    graphEditor: GraphEditor;
    nla: NLAEditor; // 非线性动画
    actionEditor: ActionEditor;
  };
  
  // 骨骼
  armatures: Armature[];
  
  // 物理
  physics: {
    rigidBody: RigidBodySimulation;
    softBody: SoftBodySimulation;
    cloth: ClothSimulation;
    fluid: FluidSimulation;
    particles: ParticleSystem;
  };
}

interface Keyframe {
  object: Object;
  property: string;
  frame: number;
  value: any;
  
  // 插值控制
  handleLeft: Vector2;
  handleRight: Vector2;
  handleType: 'free' | 'aligned' | 'vector' | 'auto' | 'auto_clamped';
  
  // 修饰
  easing: EasingType;
}
```

**动画工具清单**
| 工具 | 优先级 | 描述 |
|------|--------|------|
| 关键帧编辑 | P0 | 插入/删除/移动关键帧 |
| 曲线编辑器 | P0 | 贝塞尔曲线调整动画 |
| 摄影表 | P0 | 时间线关键帧概览 |
| 骨骼系统 | P1 | 正向/反向动力学 |
| 形状键 | P1 | 顶点级动画 |
| 约束 | P1 | 复制位置/旋转/缩放, 跟随路径 |
| 驱动器 | P1 | 基于表达式的动画 |
| 动作混合 | P2 | NLA 编辑器非线性混合 |
| 物理模拟 | P2 | 刚体/软体/布料/流体 |
| 粒子系统 | P2 | 发射器, 毛发, 群体 |
| 动作捕捉 | P2 | 导入/重定向 mocap 数据 |

#### 4.1.5 导出格式支持

**导出配置**
```typescript
interface ExportConfig3D {
  // 几何
  format: 'fbx' | 'obj' | 'gltf' | 'gltf_binary' | 'stl' | 'ply' | 'abc';
  
  // FBX 特定
  fbx: {
    version: '7.4' | '7.5' | 'ASCII';
    axis: 'Y-up' | 'Z-up';
    scale: number;
    applyModifiers: boolean;
    includeAnimations: boolean;
    includeCameras: boolean;
    includeLights: boolean;
  };
  
  // glTF 特定
  gltf: {
    format: 'embedded' | 'separate' | 'binary';
    exportMaterials: boolean;
    exportTextures: boolean;
    imageFormat: 'png' | 'jpeg' | 'auto';
    compression: 'none' | 'draco' | 'ktx2';
  };
  
  // 动画
  animation: {
    exportAnimations: boolean;
    bakeAnimations: boolean;
    frameRange: 'scene' | 'preview' | 'custom';
    samplingRate: number;
  };
}
```

**格式支持矩阵**
| 格式 | 几何 | 材质 | 纹理 | 动画 | 骨骼 | 场景 | 适用场景 |
|------|------|------|------|------|------|------|----------|
| glTF/glb | ✓ | PBR | ✓ | ✓ | ✓ | ✓ | Web/AR/VR 首选 |
| FBX | ✓ | Lambert/Phong | ✓ | ✓ | ✓ | ✓ | 行业通用 |
| OBJ | ✓ | MTL基础 | 部分 | ✗ | ✗ | ✗ | 通用交换 |
| STL | ✓ (三角面) | ✗ | ✗ | ✗ | ✗ | ✗ | 3D 打印 |
| PLY | ✓ | 顶点色 | ✗ | ✗ | ✗ | ✗ | 扫描数据 |
| Alembic | ✓ | ✓ | ✓ | ✓ (顶点) | ✗ | ✗ | VFX 缓存 |
| USD/USDZ | ✓ | PBR | ✓ | ✓ | ✓ | ✓ | 高端 VFX |
| ECHO 3D | ✓ | 完整节点 | ✓ | ✓ | ✓ | ✓ | 原生可编辑 |

---

### 4.2 界面布局草图描述

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ [菜单] 文件 | 编辑 | 物体 | 网格 |  sculpt | 材质 | 渲染 | 动画 | 脚本 | ECHO    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌────────┐ ┌──────────────────────────────────────────────────────────────────┐   │
│  │ 工具架  │ │                        3D 视口                                │   │
│  │        │ │  ┌──────────────────────────────────────────────────────────────┐ │   │
│  │ [选择] │ │  │                                                              │ │   │
│  │ [移动] │ │  │                        /\                                    │ │   │
│  │ [旋转] │ │  │                       /  \                                   │ │   │
│  │ [缩放] │ │  │                      /    \    [3D 场景内容]                  │ │   │
│  │ [变换] │ │  │                     /______\                                  │ │   │
│  │        │ │  │                                                              │ │   │
│  │ [挤出] │ │  │     [网格物体]    [灯光]    [相机]                            │ │   │
│  │ [内插] │ │  │                                                              │ │   │
│  │ [倒角] │ │  │  [Gizmo 控件: 移动/旋转/缩放轴]                               │ │   │
│  │ [切割] │ │  └──────────────────────────────────────────────────────────────┘ │   │
│  │        │ │  [视图导航: 平移 | 旋转 | 缩放 | 透视/正交 | 视图锁定]            │   │
│  │ 雕刻   │ ├──────────────────────────────────────────────────────────────────┤   │
│  │ 工具   │ │                    时间线 / 动画编辑器                           │   │
│  │ [画笔] │ │  ┌──────────────────────────────────────────────────────────────┐ │   │
│  │ [平滑] │ │  │ [开始] [◀◀] [▶] [▶▶] [结束]  帧: 1   /   250            │ │   │
│  │ [抓取] │ │  │ ──────────────────────────────────────────────────────────── │ │   │
│  │ [Inflate]│ │ │ ●────●────────●────●────────●────●────────●────●────────●────│ │   │
│  │        │ │  │ 1   25      50   75      100  125     150  175     200  225  │ │   │
│  ├────────┤ │  └──────────────────────────────────────────────────────────────┘ │   │
│  │        │ ├──────────────────────────────────────────────────────────────────┤   │
│  │ 属性面板│ │                     面板区域 (可切换)                            │   │
│  │        │ │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐ │   │
│  │ 场景   │ │  │   场景集合    │ │   材质预览    │ │   修改器列表  │ │   渲染设置  │ │   │
│  │ 世界   │ │  │   ────────   │ │   ────────   │ │   ────────   │ │  ────────  │ │   │
│  │ 物体   │ │  │  📦 Collection│ │  [材质球预览] │ │  □ Subdivision│ │  分辨率    │ │   │
│  │ 修改器  │ │  │     📦 Cube  │ │  BaseColor   │ │  □ Mirror     │ │  采样数    │ │   │
│  │ 材质   │ │  │     💡 Light │ │  Metallic    │ │  □ Array      │ │  降噪      │ │   │
│  │ 纹理   │ │  │     🎥 Camera│ │  Roughness   │ │  □ Boolean    │ │  输出格式  │ │   │
│  │ 约束   │ │  │              │ │  Normal      │ │              │ │            │ │   │
│  │ 动画   │ │  └──────────────┘ └──────────────┘ └──────────────┘ └────────────┘ │   │
│  │ 物理   │ │                                                                    │   │
│  └────────┘ └────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘

工作区切换:
[建模] [雕刻] [UV编辑] [纹理绘制] [着色] [动画] [渲染] [合成] [脚本]
```

---

## 5. 代码/文档创作 (ECHO Code Studio)

### 5.1 功能模块详细设计

#### 5.1.1 Markdown 编辑器

**编辑器架构**
```typescript
interface MarkdownEditor {
  // 编辑模式
  mode: 'source' | 'split' | 'preview' | 'wysiwyg';
  
  // 文档结构
  document: {
    content: string;
    frontmatter: Record<string, any>;
    toc: TableOfContents;
  };
  
  // 扩展语法支持
  extensions: {
    gfm: boolean; // GitHub Flavored Markdown
    math: boolean; // LaTeX 数学公式
    mermaid: boolean; // 流程图
    codeFolding: boolean;
    emoji: boolean;
    taskLists: boolean;
    tables: boolean;
    footnotes: boolean;
    definitionLists: boolean;
    strikethrough: boolean;
    subscript: boolean;
    superscript: boolean;
    highlight: boolean;
    alerts: boolean; // GitHub Alerts
  };
}
```

**编辑器功能清单**
| 功能 | 优先级 | 描述 |
|------|--------|------|
| 双栏实时预览 | P0 | 编辑与预览同步滚动 |
| 所见即所得 | P0 | 类 Notion 的块编辑器 |
| 源码模式 | P0 | 纯 Markdown 编辑 |
| 语法高亮 | P0 | Markdown 语法着色 |
| 快捷键 | P0 | 粗体/斜体/标题/列表等 |
| 表格编辑 | P1 | 可视化表格编辑 |
| 数学公式 | P1 | LaTeX 渲染 (KaTeX/MathJax) |
| 图表支持 | P1 | Mermaid, PlantUML |
| 代码块高亮 | P0 | 200+ 语言语法高亮 |
| 图片拖拽 | P1 | 拖放插入图片 |
| 自动保存 | P0 | 定时自动保存 |
| 大纲导航 | P1 | 文档结构树 |
| 字数统计 | P1 | 实时字数/阅读时间 |
| 拼写检查 | P2 | 多语言拼写检查 |
| 专注模式 | P2 | 无干扰写作 |
| 打字机模式 | P2 | 当前行居中 |

#### 5.1.2 代码片段管理

**片段系统**
```typescript
interface SnippetManager {
  // 个人片段
  personal: Snippet[];
  
  // 团队/公共片段
  team: Snippet[];
  
  // ECHO 片段市场
  marketplace: Snippet[];
  
  // 收藏
  favorites: string[];
}

interface Snippet {
  id: string;
  title: string;
  description: string;
  
  // 分类
  language: string;
  tags: string[];
  category: string;
  
  // 内容
  code: string;
  
  // 变量
  variables: SnippetVariable[];
  
  // 元数据
  author: string;
  version: string;
  createdAt: Date;
  updatedAt: Date;
  
  // ECHO
  echoAssetId?: string;
}
```

**片段功能清单**
| 功能 | 描述 |
|------|------|
| 片段库 | 按语言/分类浏览 |
| 搜索 | 全文搜索片段 |
| 导入/导出 | JSON 格式交换 |
| 同步 | 云端同步个人片段 |
| 快捷键触发 | Tab 补全触发 |
| 变量插值 | 日期, 文件名, 光标位置等 |
| 多光标 | 多处同时编辑 |
| 嵌套片段 | 片段内调用其他片段 |
| 共享 | 发布到 ECHO 市场 |
| 版本历史 | 片段修改记录 |

#### 5.1.3 实时预览

**预览系统**
```typescript
interface PreviewSystem {
  // 预览引擎
  engine: 'echo_renderer' | 'pandoc' | 'marked';
  
  // 预览类型
  types: {
    markdown: MarkdownPreview;
    html: HTMLPreview;
    code: CodePreview;
    data: DataPreview; // JSON/YAML/CSV
  };
  
  // 同步
  sync: {
    scrollSync: boolean; // 滚动同步
    selectionSync: boolean; // 选区同步
    liveUpdate: boolean; // 实时更新
    debounce: number; // 防抖延迟
  };
  
  // 样式
  styling: {
    theme: string;
    css: string; // 自定义 CSS
    codeTheme: string;
    font: string;
  };
}
```

| 预览类型 | 技术 | 用途 |
|----------|------|------|
| Markdown | Marked/KaTeX | 文档预览 |
| HTML/CSS | iframe 沙箱 | 前端开发 |
| React/Vue | Vite HMR | 组件开发 |
| Python | Jupyter 风格 | 数据科学 |
| SQL | 表格渲染 | 数据库查询 |
| GraphQL | 交互式 | API 探索 |
| 图表 | Mermaid/Plotly | 数据可视化 |

#### 5.1.4 版本对比

**差异对比系统**
```typescript
interface DiffSystem {
  // 对比模式
  mode: 'inline' | 'split' | 'unified';
  
  // 对比类型
  types: {
    file: FileDiff;
    folder: FolderDiff;
    git: GitDiff;
    history: HistoryDiff;
  };
  
  // 显示选项
  options: {
    ignoreWhitespace: boolean;
    ignoreCase: boolean;
    contextLines: number;
    wordWrap: boolean;
  };
}
```

**版本功能清单**
| 功能 | 描述 |
|------|------|
| 历史版本 | 文档修改历史 |
| Git 集成 | 查看 Git diff |
| 三路合并 | 冲突解决 |
| 时间旅行 | 回溯任意版本 |
| 标注模式 | 显示修改者 |
| 差异导出 | 导出为 patch |
| 智能对比 | 语义级差异 |
| 批注对比 | 对比批注变化 |

---

### 5.2 界面布局草图描述

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ [菜单] 文件 | 编辑 | 视图 | 插入 | 工具 | 预览 | Git | AI 助手 | 导出 | ECHO       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌────────────┐ ┌───────────────────────────────────────────────────────────────┐  │
│  │  文件浏览器 │ │  [标签栏] 文档1.md | 文档2.md × | 代码片段.js × | 未命名 ×    │  │
│  │  ─────────  │ ├───────────────────────────────────────────────────────────────┤  │
│  │  📁 项目    │ │  [工具栏] 源码 | 分栏 | 预览    [格式: 段落 ▼] [B] [I] [🔗]   │  │
│  │    📄 doc1 │ │  [大纲] 显示                                                   │  │
│  │    📄 doc2 │ ├───────────────────┬───────────────────────────────────────────┤  │
│  │    📁 img  │ │                   │                                          │  │
│  │  ─────────  │ │   编 辑 区 域      │              预 览 区 域                  │  │
│  │  大纲导航   │ │                   │                                          │  │
│  │  ─────────  │ │  # 文档标题        │         文档标题                         │  │
│  │  # 介绍     │ │                   │                                          │  │
│  │  ## 功能    │ │  这是一段正文，    │  这是一段正文，支持**粗体**和*斜体*。     │  │
│  │  ### 细节   │ │  支持**粗体**和    │                                          │  │
│  │  ## 总结    │ │  *斜体*。          │  ## 功能                                 │  │
│  │             │ │                   │                                          │  │
│  │             │ │  ## 功能           │  ### 细节                                │  │
│  │             │ │                   │  - 列表项 1                              │  │
│  │             │ │  ### 细节          │  - 列表项 2                              │  │
│  │             │ │  - 列表项 1        │  - [ ] 任务项                            │  │
│  │             │ │  - 列表项 2        │                                          │  │
│  │             │ │  - [ ] 任务项       │  ```javascript                           │  │
│  │             │ │                   │  const hello = () => "ECHO";              │  │
│  │             │ │  ```javascript     │  ```                                      │  │
│  │             │ │  const hello = ()  │                                          │  │
│  │             │ │  => "ECHO";         │  > 引用块                                │  │
│  │             │ │  ```                │                                          │  │
│  │             │ │                   │  | 表格 | 表格 |                          │  │
│  │             │ │  > 引用块            │  |-------|-------|                        │  │
│  │             │ │                   │  | 内容 | 内容 |                          │  │
│  │             │ │  | 表格 | 表格 |    │                                          │  │
│  │             │ │  |-------|-------|  │                                          │  │
│  └────────────┘ │  | 内容 | 内容 |    │                                          │  │
│                 │                   │                                          │  │
│                 └───────────────────┴───────────────────────────────────────────┘  │
│  ┌────────────┐ ┌─────────────────────────────────────────────────────────────────┐  │
│  │  代码片段   │ │                     状态栏                                      │  │
│  │  ─────────  │ │  行 15, 列 42 | 纯文本 | UTF-8 | 1,234 字 | 自动保存 ✓ | ECHO 🔗 │  │
│  │  [HTML]     │ └─────────────────────────────────────────────────────────────────┘  │
│  │  [CSS]      │                                                                    │
│  │  [JS]       │  [底部面板 - 可切换: 终端 | Git | 问题 | 输出 | 调试控制台]         │
│  │  [React]    │  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  [Python]   │  │ $ echo "Hello ECHO"                                            │ │
│  │  [SQL]      │  │ Hello ECHO                                                      │ │
│  └────────────┘  └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**工作区模式**
| 模式 | 布局 |
|------|------|
| 写作模式 | 全屏编辑器，隐藏侧边栏 |
| 开发模式 | 三栏：文件/编辑器/预览/终端 |
| 阅读模式 | 专注预览，可注释 |
| 演示模式 | 全屏幻灯片式预览 |

---

## 6. 工具间数据流转关系

### 6.1 资产流转图

```
                    ┌─────────────────────────────────────────────────────┐
                    │                  ECHO 资产中心                        │
                    │         (统一元数据、版本、授权管理)                    │
                    └─────────────────────────────────────────────────────┘
                                        ▲
        ┌───────────────┬───────────────┼───────────────┬───────────────┐
        │               │               │               │               │
        ▼               ▼               ▼               ▼               ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│  音频工作室    │ │  图像工作室    │ │  视频工作室    │ │   3D 工作室    │ │  代码工作室    │
│  ───────────  │ │  ───────────  │ │  ───────────  │ │  ───────────  │ │  ───────────  │
│  • 音频工程    │ │  • PSD 文档    │ │  • 时间线项目  │ │  • Blend 文件  │ │  • Markdown   │
│  • 音频片段    │ │  • 矢量图形    │ │  • 合成项目    │ │  • 材质球      │ │  • 代码仓库    │
│  • 采样库     │ │  • 图层样式    │ │  • 运动图形    │ │  • 动画数据    │ │  • 代码片段    │
│  • MIDI 文件  │ │  • 智能对象    │ │  • 调色预设    │ │  • 导出模型    │ │  • 技术文档    │
└───────┬───────┘ └───────┬───────┘ └───────┬───────┘ └───────┬───────┘ └───────┬───────┘
        │                 │                 │                 │                 │
        │  ═══════════════╪═════════════════╪═════════════════╪═════════════════╡
        │                 │                 │                 │                 │
        ▼                 ▼                 ▼                 ▼                 ▼
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                              跨工具资产引用与嵌入                                       │
├──────────────────────────────────────────────────────────────────────────────────────┤
│  音频 → 视频: 音频轨道直接拖放                                                        │
│  图像 → 视频: 图片作为图层/转场素材                                                   │
│  图像 → 3D: 纹理贴图, HDRI 环境                                                        │
│  3D → 视频: 渲染序列导入为视频素材                                                    │
│  3D → 图像: 渲染帧作为图像素材                                                        │
│  代码 → 全部: 程序化生成/自动化脚本                                                   │
│  视频 → 音频: 提取音频轨道独立编辑                                                    │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 具体流转场景

| 源工具 | 目标工具 | 流转内容 | 方式 |
|--------|----------|----------|------|
| 音频工作室 | 视频工作室 | 混音音频 | 项目链接/导出导入 |
| 音频工作室 | 图像工作室 | 音频可视化波形 | 生成图像 |
| 图像工作室 | 视频工作室 | 图片素材, PSD 图层 | 智能对象/分层导入 |
| 图像工作室 | 3D 工作室 | 纹理, HDRI, 法线贴图 | 贴图引用 |
| 3D 工作室 | 视频工作室 | 渲染序列, 动画 | 帧序列导入 |
| 3D 工作室 | 图像工作室 | 渲染帧 | 静态图像导出 |
| 视频工作室 | 音频工作室 | 音频轨道 | 音频提取 |
| 视频工作室 | 图像工作室 | 静帧, 图层 | 帧导出/分层导出 |
| 代码工作室 | 全部 | 自动化脚本, 插件 | API 调用 |

### 6.3 统一资产格式

**ECHO 通用资产封装**
```typescript
interface ECHOAsset {
  // 元数据
  metadata: {
    id: string;
    version: string;
    title: string;
    description: string;
    author: string;
    createdAt: Date;
    modifiedAt: Date;
    tags: string[];
    license: LicenseInfo;
  };
  
  // 类型特定数据
  content: AudioContent | ImageContent | VideoContent | Model3DContent | CodeContent;
  
  // 预览
  preview: {
    thumbnail: string;
    poster: string;
    previewVideo?: string;
    previewAudio?: string;
  };
  
  // 依赖
  dependencies: ECHOAssetRef[];
  
  // 历史
  history: VersionSnapshot[];
  
  // 编辑数据 (可选)
  editable: {
    projectFile: string;
    pluginData: Record<string, any>;
  };
}
```

---

## 7. 技术实现建议

### 7.1 整体架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              ECHO Creator Studio                                    │
│                              (Electron/Web 外壳)                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────┬───────────────┬───────────────┬───────────────┬───────────────┐ │
│  │  音频工作室    │ │  图像工作室    │ │  视频工作室    │ │   3D 工作室    │ │  代码工作室    │ │
│  │  ───────────  │ │  ───────────  │ │  ───────────  │ │  ───────────  │ │  ───────────  │ │
│  │  Web Audio API│ │  HTML5 Canvas │ │  WebCodecs    │ │  WebGL/WebGPU │ │  Monaco       │ │
│  │  AudioWorklet │ │  WebGL 渲染   │ │  WebGPU 加速  │ │  Three.js/    │ │  Editor       │ │
│  │  WASM DSP     │ │  WASM 图像处理 │ │  FFmpeg WASM  │ │  Babylon.js   │ │  WebAssembly  │ │
│  │  Tone.js      │ │  Canvas API   │ │  MSE 流式     │ │  glTF 管线    │ │  Markdown-it  │ │
│  └───────┬───────┘ └───────┬───────┘ └───────┬───────┘ └───────┬───────┘ └───────┬───────┘ │
│          │                 │                 │                 │                 │       │
│          └─────────────────┴─────────────────┴─────────────────┴─────────────────┘       │
│                                    │                                                    │
│                          ┌─────────┴─────────┐                                           │
│                          │   共享服务层       │                                           │
│                          │  ───────────────  │                                           │
│                          │  • 项目管理系统    │                                           │
│                          │  • 资产浏览器      │                                           │
│                          │  • 云同步服务      │                                           │
│                          │  • AI 服务接口     │                                           │
│                          │  • 插件系统        │                                           │
│                          │  • 导出/渲染队列   │                                           │
│                          └─────────┬─────────┘                                           │
│                                    │                                                    │
│                          ┌─────────┴─────────┐                                           │
│                          │   ECHO 协议层      │                                           │
│                          │  ───────────────  │                                           │
│                          │  • 资产确权        │                                           │
│                          │  • 版权元数据      │                                           │
│                          │  • 发行合约        │                                           │
│                          │  • 收益追踪        │                                           │
│                          └───────────────────┘                                           │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 各工作室技术栈

| 工作室 | 核心技术 | 渲染引擎 | 音频引擎 | 推荐方案 |
|--------|----------|----------|----------|----------|
| 音频 | Web Audio API, AudioWorklet, WASM (C++ DSP) | - | 自研/集成 JUCE | Tone.js + 自研 WASM 效果器 |
| 图像 | HTML5 Canvas, WebGL, WASM (OpenCV) | 2D Canvas/WebGL | - | Fabric.js / PixiJS + 自研滤镜 |
| 视频 | WebCodecs, WebGPU, FFmpeg WASM | WebGPU 计算 | Web Audio API | 自研时间线 + FFmpeg 编解码 |
| 3D | WebGL 2.0, WebGPU, Three.js/Babylon.js | PBR 实时渲染 | - | Three.js + 自研材质系统 |
| 代码 | Monaco Editor, WebAssembly | - | - | Monaco + 自研扩展 |

### 7.3 性能优化策略

| 层面 | 策略 |
|------|------|
| 渲染 | WebWorker 离屏渲染, GPU 加速, 虚拟滚动 |
| 存储 | IndexedDB 本地缓存, OPFS 文件系统, 增量同步 |
| 内存 | 对象池, 纹理压缩, 流式加载 |
| 计算 | WASM SIMD, WebGPU Compute Shader, 云渲染后备 |
| 网络 | 断点续传, 差分同步, CDN 加速 |

### 7.4 AI 集成架构

```typescript
interface AIPipeline {
  // 本地模型 (ONNX/WebNN)
  local: {
    enabled: boolean;
    models: LocalModel[];
    fallback: 'cloud' | 'disable';
  };
  
  // 云服务
  cloud: {
    providers: AIProvider[];
    queue: TaskQueue;
    priority: 'speed' | 'quality' | 'cost';
  };
  
  // 混合推理
  hybrid: {
    autoRouting: boolean;
    localFirst: boolean;
  };
}
```

---

## 8. ECHO 协议集成点

### 8.1 资产导出流程

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   创作完成    │────▶│  导出设置    │────▶│  元数据填写   │────▶│  ECHO 签名   │
│  (各工作室)   │     │  (格式/质量) │     │  (标题/标签)  │     │  (版权确权)   │
└──────────────┘     └──────────────┘     └──────────────┘     └───────┬──────┘
                                                                       │
                                                                       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   发行完成    │◀────│  上链确认    │◀────│  预览生成    │◀────│  资产打包    │
│  (市场可见)   │     │  (交易哈希)  │     │  (多分辨率)   │     │  (ECHO 格式)  │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

### 8.2 ECHO 导出配置

```typescript
interface ECHOExport {
  // 资产身份
  identity: {
    title: string;
    description: string;
    creator: string;
    coCreators: string[];
    createdAt: Date;
  };
  
  // 分类
  categorization: {
    primaryType: AssetType;
    secondaryTypes: AssetType[];
    genres: string[];
    tags: string[];
    collections: string[];
  };
  
  // 技术规格 (自动填充)
  technical: {
    format: string;
    dimensions?: { width: number; height: number };
    duration?: number;
    fileSize: number;
    codecs: string[];
  };
  
  // 版权与授权
  licensing: {
    licenseType: 'copyright' | 'cc' | 'public_domain' | 'custom';
    ccVersion?: 'by' | 'by-sa' | 'by-nc' | 'by-nc-sa' | 'by-nd' | 'by-nc-nd';
    commercialUse: boolean;
    attributionRequired: boolean;
    derivativeWorks: 'allowed' | 'same_license' | 'not_allowed';
  };
  
  // ECHO 特有
  echo: {
    assetId: string; // 链上 ID
    fractionalization: boolean;
    royaltyStructure: RoyaltyConfig;
    stakingRewards: boolean;
    exclusiveRights?: ExclusiveRights;
  };
  
  // 可编辑性
  editability: {
    projectFileIncluded: boolean;
    editableFormat: string;
    pluginRequirements: string[];
  };
}
```

### 8.3 各工作室 ECHO 集成

| 工作室 | ECHO 导出类型 | 链上元数据 | 可编辑资产 |
|--------|---------------|------------|------------|
| 音频 | 音乐/音效/Loop/采样 | BPM, 调性, 时长, 乐器标签 | .echoaudio 工程文件 |
| 图像 | 插画/设计/纹理/图标 | 分辨率, 色彩空间, 图层数 | .echovisual PSD 兼容 |
| 视频 | 影片/MV/广告/教程 | 分辨率, 帧率, 时长, 编码 | .echovideo 项目文件 |
| 3D | 模型/材质/动画/场景 | 多边形数, 绑定状态, 贴图 | .echo3d 完整场景 |
| 代码 | 脚本/组件/模板/文档 | 语言, 依赖, 许可证 | .echocode 源码包 |

### 8.4 智能合约交互

```typescript
interface ECHOContract {
  // 铸造
  mint: {
    assetURI: string;
    metadataURI: string;
    royaltyBps: number; // 基点 (0-10000 = 0-100%)
    maxSupply?: number; // 限量版
  };
  
  // 分割 (可选)
  fractionalize: {
    shares: number;
    shareClass: 'fungible' | 'non_fungible';
  };
  
  // 授权
  license: {
    licenseType: LicenseType;
    price: bigint;
    duration?: number; // 限时许可
    usageRights: UsageRights;
  };
  
  // 收益
  revenue: {
    primarySaleSplits: RevenueSplit[];
    secondaryRoyalty: number;
    stakingYield?: number;
  };
}
```

---

## 附录 A: 参考设计系统

### 界面设计语言

| 元素 | 规范 |
|------|------|
| 色彩 | 深色主题为主 (类似 DaVinci Resolve, Ableton Live) |
| 排版 | Inter / SF Pro 为主，等宽 JetBrains Mono |
| 图标 | 线性图标，2px 描边 |
| 间距 | 8px 网格系统 |
| 动画 | 120fps 流畅过渡，0.2s 缓动 |
| 主题 | 暗色 (专业创作), 浅色 (文档/代码可选) |

### 快捷键体系

跨工作室统一快捷键:
| 快捷键 | 功能 |
|--------|------|
| Ctrl/Cmd + S | 保存 |
| Ctrl/Cmd + Z | 撤销 |
| Ctrl/Cmd + Shift + Z | 重做 |
| Ctrl/Cmd + C/V/X | 复制/粘贴/剪切 |
| Space | 播放/暂停 |
| J/K/L | 后退/暂停/前进 (视频/音频) |
| +/- | 缩放 |
| F | 全屏预览 |
| Tab | 隐藏/显示面板 |
| E | 导出到 ECHO |

---

*文档结束*

> 设计参考: Ableton Live 11, DaVinci Resolve 18, Blender 4.0, Figma, VS Code, Photoshop 2024  
> 技术参考: Web Audio API, WebCodecs, WebGPU, WebGL 2.0, FFmpeg WASM, Three.js  
> 产权参考: EIP-721, EIP-1155, Creative Commons, IPFS
