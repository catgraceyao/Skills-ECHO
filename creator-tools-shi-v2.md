# ECHO 势体系配套应用设计 v2.0

> **完整技术架构文档**  
> **设计理念**: 势是描述框架，不是控制系统。配套应用帮助创作者理解、观测、参与资产的生长过程。

---

## 第一部分：配套应用总览

### 1.1 应用矩阵

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ECHO 势体系配套应用                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  创作者工具   │  │  开发者工具   │  │  发现与匹配   │  │  治理与观测   │ │
│  │  (Creator)   │  │  (Developer) │  │  (Discovery) │  │  (Governance)│ │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤  ├──────────────┤ │
│  │• 四权蓝图    │  │• ShiGraph SDK│  │• 势场浏览器  │  │• 势场测绘台  │ │
│  │  编辑器      │  │• 沙箱接入   │  │• 关系网络图  │  │• 约束规则表  │ │
│  │• 势位仪表板  │  │  SDK        │  │• 智能编排    │  │• 验证者节点  │ │
│  │• 生长预警    │  │• 事件流API  │  │• 冷启动引导  │  │• 争议仲裁    │ │
│  │  系统       │  │• PoU生成器  │  │             │  │             │ │
│  │• 事件流     │  │• 模拟器     │  │             │  │             │ │
│  │  查看器    │  │             │  │             │  │             │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 用户角色与使用场景

| 角色 | 核心需求 | 主要使用应用 | 关键功能 |
|------|---------|-------------|----------|
| **创作者** | 管理资产生命周期 | 四权蓝图编辑器、势位仪表板、生长预警 | 配置四权、观测势位、接收预警 |
| **开发者** | 集成 ECHO 协议 | ShiGraph SDK、沙箱接入SDK、事件流API | 查询势位、生成PoU、处理事件 |
| **发现者** | 发现和使用 Skill | 势场浏览器、关系网络图 | 浏览势场、发现关联资产 |
| **验证者** | 维护网络共识 | 验证者节点、势场测绘台 | 验证PoU、参与测绘 |
| **治理者** | 参与协议治理 | 治理与观测层全部应用 | 投票、仲裁、规则制定 |

---

## 第二部分：核心概念映射

### 2.1 势体系概念到应用功能

```
势枢 (ShiShu) —— 三维编织元结构
    ├── 四权蓝图编辑器 —— 配置意图层
    ├── 势位仪表板 —— 可视化三维坐标
    └── 势场浏览器 —— 观测64场域分布

势场 (ShiField) —— 64种涌现模式
    ├── 势场测绘台 —— 每周测绘64势场
    ├── 约束规则表 —— 查看64卦约束
    └── 生长预警系统 —— 预测变势

势位 (ShiWei) —— 六爻坐标 + 势能
    ├── 势位仪表板 —— 实时显示六爻坐标
    ├── 事件流查看器 —— 记录跃迁历史
    └── ShiGraph SDK —— 查询当前势位
```

### 2.2 双层架构映射

```
声明式策略层 (Policy Engine)
    ├── 四权蓝图编辑器 —— 创作者意图输入
    ├── 约束规则表 —— 物理法则边界
    └── 有效配置计算 —— 意图 ∩ 物理法则

事件流层 (Event Store)
    ├── 事件流查看器 —— 浏览不可变事件
    ├── PoU 生成器 —— 生成使用证明
    └── 验证者节点 —— 验证事件有效性
```

---

## 第三部分：创作者工具层详细设计

### 3.1 四权蓝图编辑器 (Blueprint Editor)

#### 3.1.1 功能架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    四权蓝图编辑器架构                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  配置输入层  │ →  │  约束计算层  │ →  │  预览输出层  │         │
│  │             │    │             │    │             │         │
│  │ • 用权配置  │    │ • 加载当前   │    │ • 有效配置   │         │
│  │ • 衍权配置  │    │   势位      │    │   预览      │         │
│  │ • 扩权配置  │    │ • 查询64卦   │    │ • 约束解释   │         │
│  │ • 益权配置  │    │   约束      │    │ • 版本对比   │         │
│  │             │    │ • 计算交集   │    │             │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                  │                  │                │
│         ▼                  ▼                  ▼                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  数据层: BlueprintRepository + ShiGraphClient + PolicyEngine│   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.1.2 数据模型

```typescript
// 四权蓝图数据模型
interface Blueprint {
  id: string;                    // 蓝图唯一标识
  assetId: string;               // 关联资产ID
  version: string;               // 语义化版本 (e.g., "1.2.0")
  createdAt: Timestamp;
  createdBy: string;             // 创作者地址
  
  // 创作者意图 (声明式策略)
  intent: {
    yong: UsageIntent;           // 用权意图
    yan: DerivativeIntent;       // 衍权意图
    kuo: ExpansionIntent;        // 扩权意图
    yi: BenefitIntent;           // 益权意图
  };
  
  // 版本管理
  versionChain: {
    previousVersion?: string;    // 上一版本ID
    isActive: boolean;           // 是否接受新授权
    activationTime?: Timestamp;  // 生效时间
  };
  
  // 元数据
  metadata: {
    name?: string;               // 蓝图名称
    description?: string;        // 描述
    tags?: string[];             // 标签
  };
}

// 用权意图
interface UsageIntent {
  pricingModel: 'free' | 'per_use' | 'subscription' | 'hybrid';
  pricePerUse?: Decimal;         // 单次使用价格 (ECHO)
  subscriptionPrice?: Decimal;   // 订阅价格
  subscriptionPeriod?: 'day' | 'week' | 'month';
  monthlyQuota?: number;         // 月限额
  customRules?: UsageRule[];     // 自定义规则
}

// 衍权意图
interface DerivativeIntent {
  allowed: boolean;              // 是否允许衍生
  royaltyRate: number;           // 分润比例 (0-100)
  maxDepth: number;              // 最大衍生深度
  requireApproval: boolean;      // 是否需要审批
  allowedTypes?: string[];       // 允许的衍生类型
}

// 扩权意图
interface ExpansionIntent {
  visibility: 'hidden' | 'restricted' | 'public';
  platformLimit?: number;        // 平台限制数量
  tags?: string[];               // 扩展标签
}

// 益权意图
interface BenefitIntent {
  model: 'locked' | 'usage_based' | 'fixed' | 'hybrid';
  unlockConditions?: UnlockCondition[];  // 解锁条件
  distributionRules?: DistributionRule[]; // 分配规则
}

// 有效配置 (意图与物理法则的交集)
interface EffectivePolicy {
  blueprintId: string;
  assetId: string;
  
  // 当前势位上下文
  context: {
    hexagram: Hexagram;          // 当前卦象
    coordinate: ShiCoordinate;   // 三维坐标
    yao: SixYao;                 // 六爻坐标
  };
  
  // 实际生效的四权配置
  effective: {
    yong: EffectiveUsagePolicy;
    yan: EffectiveDerivativePolicy;
    kuo: EffectiveExpansionPolicy;
    yi: EffectiveBenefitPolicy;
  };
  
  // 约束说明
  constraints: Constraint[];     // 应用的约束列表
  warnings?: Warning[];          // 警告信息
  
  computedAt: Timestamp;
}
```

#### 3.1.3 约束计算逻辑

```typescript
// 约束计算引擎
class PolicyEngine {
  constructor(
    private shigraph: ShiGraphClient,
    private constraintRegistry: ConstraintRegistry
  ) {}

  /**
   * 计算有效配置
   * 有效配置 = 创作者意图 ∩ 物理法则约束
   */
  async calculateEffectivePolicy(
    blueprint: Blueprint
  ): Promise<EffectivePolicy> {
    // 1. 获取资产当前势位
    const position = await this.shigraph.getPosition(blueprint.assetId);
    
    // 2. 获取当前卦象的约束
    const hexagramConstraints = await this.constraintRegistry
      .getConstraints(position.hexagram);
    
    // 3. 逐权计算交集
    const effectiveYong = this.intersectUsage(
      blueprint.intent.yong,
      hexagramConstraints.yong
    );
    
    const effectiveYan = this.intersectDerivative(
      blueprint.intent.yan,
      hexagramConstraints.yan
    );
    
    const effectiveKuo = this.intersectExpansion(
      blueprint.intent.kuo,
      hexagramConstraints.kuo
    );
    
    const effectiveYi = this.intersectBenefit(
      blueprint.intent.yi,
      hexagramConstraints.yi
    );
    
    // 4. 收集约束说明
    const constraints = this.collectConstraints(
      blueprint.intent,
      {
        yong: effectiveYong,
        yan: effectiveYan,
        kuo: effectiveKuo,
        yi: effectiveYi
      }
    );
    
    // 5. 检查警告
    const warnings = this.checkWarnings(blueprint.intent, constraints);
    
    return {
      blueprintId: blueprint.id,
      assetId: blueprint.assetId,
      context: {
        hexagram: position.hexagram,
        coordinate: position.coordinate,
        yao: position.yao
      },
      effective: {
        yong: effectiveYong,
        yan: effectiveYan,
        kuo: effectiveKuo,
        yi: effectiveYi
      },
      constraints,
      warnings,
      computedAt: new Date().toISOString()
    };
  }

  /**
   * 用权意图与约束的交集
   */
  private intersectUsage(
    intent: UsageIntent,
    constraint: UsageConstraint
  ): EffectiveUsagePolicy {
    return {
      // 定价模型取意图，但价格受约束限制
      pricingModel: intent.pricingModel,
      pricePerUse: this.clamp(
        intent.pricePerUse,
        constraint.minPrice,
        constraint.maxPrice
      ),
      // 月限额不能超过约束最大值
      monthlyQuota: Math.min(
        intent.monthlyQuota ?? Infinity,
        constraint.maxMonthlyQuota
      ),
      // 标记哪些配置被约束修改
      modifiedByConstraint: this.getModifications(intent, constraint)
    };
  }

  /**
   * 衍权意图与约束的交集
   * 示例: 坤卦衍权只允许 0-1，意图为 2 会被限制为 1
   */
  private intersectDerivative(
    intent: DerivativeIntent,
    constraint: DerivativeConstraint
  ): EffectiveDerivativePolicy {
    const effectiveAllowed = intent.allowed && constraint.allowDerivative;
    
    return {
      allowed: effectiveAllowed,
      // 分润比例取较小值
      royaltyRate: Math.min(intent.royaltyRate, constraint.maxRoyaltyRate),
      // 深度受约束限制
      maxDepth: Math.min(intent.maxDepth, constraint.maxDepth),
      // 是否被约束强制修改
      constraintForced: !effectiveAllowed || intent.maxDepth > constraint.maxDepth
    };
  }

  /**
   * 收集约束说明
   */
  private collectConstraints(
    intent: BlueprintIntent,
    effective: EffectivePolicies
  ): Constraint[] {
    const constraints: Constraint[] = [];
    
    // 检查衍权是否被约束
    if (intent.yan.maxDepth > effective.yan.maxDepth) {
      constraints.push({
        type: 'DERIVATIVE_DEPTH_LIMITED',
        description: `当前卦象限制最大衍生深度为 ${effective.yan.maxDepth}，您的配置 ${intent.yan.maxDepth} 已调整`,
        severity: 'info'
      });
    }
    
    // 检查益权是否被锁定
    if (intent.yi.model !== 'locked' && effective.yi.model === 'locked') {
      constraints.push({
        type: 'BENEFIT_LOCKED_BY_HEXAGRAM',
        description: '当前卦象要求锁定收益，需达到解锁条件后自动开放',
        severity: 'warning'
      });
    }
    
    return constraints;
  }
}
```

#### 3.1.4 用户界面设计

**主编辑界面**:
```
┌─────────────────────────────────────────────────────────────────────┐
│  四权蓝图编辑器                                          [保存] [预览]│
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  资产信息                                                    │   │
│  │  智能写诗助手 (skill_poet_alice)                             │   │
│  │  当前势位: 泰卦 · 成长期  │  坐标 [2,1,2]  │  六爻: 九三·九二·九三│   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  四权配置                                                    │   │
│  │  ┌──────────┬──────────┬──────────┬──────────┐              │   │
│  │  │   用权   │   衍权   │   扩权   │   益权   │              │   │
│  │  ├──────────┼──────────┼──────────┼──────────┤              │   │
│  │  │ 💰 定价  │ 🌱 许可  │ 🌐 可见 │ 💰 收益  │              │   │
│  │  │          │          │          │          │              │   │
│  │  │ ○ 免费   │ ○ 禁止   │ ○ 隐藏  │ ● 锁定   │              │   │
│  │  │ ● 按次   │ ● 允许   │ ● 受限  │ ○ 按使用 │              │   │
│  │  │ ○ 订阅   │          │ ○ 公开  │ ○ 固定   │              │   │
│  │  │          │          │          │          │              │   │
│  │  │ 价格:    │ 分润:    │ 平台:    │ 解锁:    │              │   │
│  │  │ 0.01 ECHO│ 15%      │ 无限制   │ 800次使用│              │   │
│  │  │          │          │          │          │              │   │
│  │  │ 限额:    │ 深度:    │ 标签:    │          │              │   │
│  │  │ 500/月   │ 2层      │ AI,写作  │          │              │   │
│  │  └──────────┴──────────┴──────────┴──────────┘              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  ⚠️ 约束预览                                                 │   │
│  │                                                             │   │
│  │  当前卦象: 泰卦(成长期) 约束相对宽松                          │   │
│  │                                                             │   │
│  │  ✓ 用权: 您的配置在允许范围内                                │   │
│  │  ✓ 衍权: 您的配置在允许范围内                                │   │
│  │  ⚠ 益权: 当前益权锁定，将在进入咸卦后自动解锁                 │   │
│  │                                                             │   │
│  │  [查看完整约束说明]                                          │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  版本管理                                                    │   │
│  │  当前: v1.2  [创建新版本]  [查看历史]  [对比版本]             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**约束详情弹窗**:
```
┌─────────────────────────────────────────────────────────────────┐
│  泰卦(成长期) 约束说明                              [X]           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  泰卦特点:                                                      │
│  天地交泰，万物生长。此时资产已度过萌芽期，进入快速成长阶段。     │
│  生态开始形成，适度开放有助于价值增长。                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  各权约束范围                                            │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  用权: 无特殊限制                                        │   │
│  │  衍权: 允许值 0-3 (完全禁止 ～ 完全开放)                  │   │
│  │  扩权: 允许值 0-3 (隐藏 ～ 完全公开)                      │   │
│  │  益权: 建议锁定，达到以下条件自动解锁:                    │   │
│  │        • 使用次数 ≥ 800                                  │   │
│  │        • 被引用次数 ≥ 10                                 │   │
│  │        • 进入咸卦(大成期)                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  📊 数据支持: 泰卦资产的平均使用增长率比坤卦高 340%              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.1.5 版本管理与软分叉

```typescript
// 版本管理服务
class BlueprintVersionManager {
  constructor(
    private blueprintRepo: BlueprintRepository,
    private policyEngine: PolicyEngine,
    private eventStore: EventStore
  ) {}

  /**
   * 创建新版本
   * 软分叉: 新版本不影响已有授权
   */
  async createNewVersion(
    assetId: string,
    newIntent: BlueprintIntent,
    reason: string
  ): Promise<Blueprint> {
    // 1. 获取当前激活版本
    const currentVersion = await this.blueprintRepo.getActiveVersion(assetId);
    
    // 2. 计算语义化版本号
    const newVersionNumber = this.calculateVersion(
      currentVersion.version,
      newIntent,
      currentVersion.intent
    );
    
    // 3. 创建新版本
    const newBlueprint: Blueprint = {
      id: generateUUID(),
      assetId,
      version: newVersionNumber,
      createdAt: new Date().toISOString(),
      intent: newIntent,
      versionChain: {
        previousVersion: currentVersion.id,
        isActive: true,
        activationTime: new Date().toISOString()
      },
      metadata: {
        ...currentVersion.metadata,
        versionReason: reason
      }
    };
    
    // 4. 保存新版本
    await this.blueprintRepo.save(newBlueprint);
    
    // 5. 旧版本保持激活状态但不接受新授权
    await this.blueprintRepo.deactivateForNewAuthorizations(currentVersion.id);
    
    // 6. 发布事件
    await this.eventStore.append({
      type: 'BlueprintVersionCreated',
      assetId,
      newVersionId: newBlueprint.id,
      previousVersionId: currentVersion.id,
      timestamp: new Date().toISOString()
    });
    
    return newBlueprint;
  }

  /**
   * 计算语义化版本
   * 重大变更: 约束强制变化 → 主版本+1
   * 次要变更: 配置调整 → 次版本+1
   * 补丁变更: 描述修改 → 补丁版本+1
   */
  private calculateVersion(
    currentVersion: string,
    newIntent: BlueprintIntent,
    oldIntent: BlueprintIntent
  ): string {
    const [major, minor, patch] = currentVersion.split('.').map(Number);
    
    // 检查是否有重大变更
    if (this.isBreakingChange(newIntent, oldIntent)) {
      return `${major + 1}.0.0`;
    }
    
    // 检查是否有配置变更
    if (this.hasConfigChange(newIntent, oldIntent)) {
      return `${major}.${minor + 1}.0`;
    }
    
    // 仅元数据变更
    return `${major}.${minor}.${patch + 1}`;
  }

  /**
   * 获取版本链
   */
  async getVersionChain(assetId: string): Promise<VersionNode[]> {
    const allVersions = await this.blueprintRepo.getAllVersions(assetId);
    
    // 构建版本树
    const versionMap = new Map(allVersions.map(v => [v.id, v]));
    const root = allVersions.find(v => !v.versionChain.previousVersion);
    
    return this.buildVersionTree(root, versionMap);
  }
}
```

---

### 3.2 势位仪表板 (ShiPosition Dashboard)

#### 3.2.1 功能架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    势位仪表板架构                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  数据获取层  │ →  │  计算投影层  │ →  │  可视化层   │         │
│  │             │    │             │    │             │         │
│  │ • ShiGraph  │    │ • 三维编织   │    │ • 3D可视化  │         │
│  │   API      │    │   计算      │    │ • 六爻图    │         │
│  │ • 事件流    │    │ • 六爻定位   │    │ • 时间线    │         │
│  │   重播     │    │ • 势能计算   │    │ • 统计卡片  │         │
│  │             │    │             │    │             │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                  │
│  实时更新: WebSocket 订阅 ShiPositionChanged 事件                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.2.2 三维编织可视化

```typescript
// 三维编织可视化组件
interface ShiVisualizationConfig {
  // 视角配置
  camera: {
    position: [number, number, number];
    target: [number, number, number];
    fov: number;
  };
  
  // 渲染配置
  render: {
    showGrid: boolean;
    showLabels: boolean;
    particleSize: number;
    colorScheme: 'default' | 'energy' | 'hexagram';
  };
  
  // 交互配置
  interaction: {
    allowRotation: boolean;
    allowZoom: boolean;
    highlightOnHover: boolean;
  };
}

// 三维编织数据
interface ShiWeavingData {
  // 中心资产
  centerAsset: {
    id: string;
    name: string;
    position: ShiCoordinate;
    hexagram: Hexagram;
    energy: number;
  };
  
  // 邻近资产
  neighbors: NeighborAsset[];
  
  // 场域边界
  fieldBoundaries: FieldBoundary[];
  
  // 跃迁轨迹
  trajectory: TrajectoryPoint[];
}

// Three.js 渲染实现
class ShiWeavingRenderer {
  private scene: THREE.Scene;
  private camera: THREE.PerspectiveCamera;
  private renderer: THREE.WebGLRenderer;
  
  constructor(canvas: HTMLCanvasElement) {
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(75, 1, 0.1, 1000);
    this.renderer = new THREE.WebGLRenderer({ canvas });
    
    // 设置相机位置
    this.camera.position.set(10, 10, 10);
    this.camera.lookAt(0, 0, 0);
  }

  /**
   * 渲染三维编织
   */
  render(data: ShiWeavingData): void {
    this.clearScene();
    
    // 1. 渲染网格
    this.renderGrid();
    
    // 2. 渲染场域边界
    this.renderFieldBoundaries(data.fieldBoundaries);
    
    // 3. 渲染资产节点
    this.renderAssetNode(data.centerAsset, true);
    data.neighbors.forEach(n => this.renderAssetNode(n, false));
    
    // 4. 渲染跃迁轨迹
    this.renderTrajectory(data.trajectory);
    
    // 5. 渲染连线
    this.renderConnections(data.centerAsset, data.neighbors);
    
    this.renderer.render(this.scene, this.camera);
  }

  /**
   * 渲染资产节点
   */
  private renderAssetNode(asset: AssetNode, isCenter: boolean): void {
    const geometry = new THREE.SphereGeometry(
      isCenter ? 0.5 : 0.3,
      32,
      32
    );
    
    // 根据势能设置颜色
    const color = this.getEnergyColor(asset.energy);
    const material = new THREE.MeshBasicMaterial({ color });
    
    const sphere = new THREE.Mesh(geometry, material);
    sphere.position.set(
      asset.position.temporal,
      asset.position.spatial,
      asset.position.relational
    );
    
    // 添加标签
    if (isCenter || this.config.render.showLabels) {
      this.addLabel(sphere, asset.name);
    }
    
    this.scene.add(sphere);
  }

  /**
   * 获取势能对应的颜色
   */
  private getEnergyColor(energy: number): THREE.Color {
    // 低势能: 蓝色
    // 高势能: 红色
    const normalized = Math.min(energy / 5000, 1);
    return new THREE.Color().setHSL(0.6 - normalized * 0.6, 1, 0.5);
  }
}
```

#### 3.2.3 用户界面设计

**主仪表板**:
```
┌─────────────────────────────────────────────────────────────────────┐
│  势位仪表板 - 智能写诗助手                            [刷新] [导出]  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                     三维编织空间                             │   │
│  │                                                              │   │
│  │                     时间(↑)                                  │   │
│  │                        │                                     │   │
│  │                        │    ★ 你在这里                       │   │
│  │                        │    泰卦 · 成长期                    │   │
│  │                        │    [2, 1, 2]                        │   │
│  │                        │                                     │   │
│  │         关系(→) ───────┼────── 空间(↗)                      │   │
│  │                        │                                     │   │
│  │    ○ 诗歌教学          │          ○ 营销文案                 │   │
│  │    蒙卦 · 萌芽期       │          同人卦 · 成长期            │   │
│  │                        │                                     │   │
│  │              ○ 古文翻译                                     │   │
│  │              坤卦 · 潜藏期                                  │   │
│  │                                                              │   │
│  │  [旋转] [缩放] [重置视角] [切换颜色方案]                      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │    时间维     │  │    空间维     │  │    关系维     │              │
│  │   ─────────  │  │   ─────────  │  │   ─────────  │              │
│  │              │  │              │  │              │              │
│  │   ████████   │  │   ████░░░░   │  │   █████░░░   │              │
│  │   280次/周   │  │   2个沙箱    │  │   12次引用   │              │
│  │              │  │              │  │              │              │
│  │   档位: 2    │  │   档位: 1    │  │   档位: 2    │              │
│  │   (活跃)     │  │   (少平台)   │  │   (网络)     │              │
│  │              │  │              │  │              │              │
│  │   趋势 ↑23%  │  │   新增 +1    │  │   新增 +3    │              │
│  │              │  │              │  │              │              │
│  │  [查看详情]  │  │  [查看详情]  │  │  [查看详情]  │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  六爻坐标                                                    │   │
│  │                                                             │   │
│  │  上九 ○────────────────────────── 转化期 (>95%)             │   │
│  │       │                                                     │   │
│  │  九五 ○────────────────────────── 大成期 (85-95%)           │   │
│  │       │                                                     │   │
│  │  九四 ○────────────────────────── 试探期 (70-85%)           │   │
│  │       │         ★ 时间维 (80百分位)                        │   │
│  │  九三 ●────────────────────────── 勤勉期 (50-70%) ← 当前    │   │
│  │       │         ★ 关系维 (65百分位)                        │   │
│  │  九二 ●────────────────────────── 显现期 (25-50%)           │   │
│  │       │         ★ 空间维 (40百分位)                        │   │
│  │  初九 ●────────────────────────── 潜藏期 (<25%)             │   │
│  │                                                             │   │
│  │  当前六爻: (九三, 九二, 九三) → 泰卦                        │   │
│  │  势能: 1,247 气数                                           │   │
│  │                                                             │   │
│  │  [查看跃迁历史]  [预测下一步]                                │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

（继续到下一部分...）
