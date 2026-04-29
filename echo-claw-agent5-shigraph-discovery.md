# ECHO Claw - ShiGraph 集成与 Skill 发现设计

**版本**: v1.0 | **日期**: 2026-04-21 | **状态**: 详细设计

---

## 一、ShiGraph 在 ECHO 网络中的角色

### 1.1 核心定位

```
传统推荐系统                    ShiGraph
    │                            │
    │ "我觉得你会喜欢这个"        │ "这个Skill正处在成长期，
    │ （平台主观判断）             │  被这些创作者引用，
    │                            │  这些用户在用" 
    │                            │  （物理法则涌现）
    │                            │
    │ 中心化排名算法              │ 分布式势场计算
    │                            │
    │ 平台控制创作者命运           │ 创作者自然生长
```

**ECHO 承诺**: ShiGraph 不"推荐"，它"描述"。不预测未来，只计算现在的势态。

### 1.2 与 ECHO Claw 的关系

```
ECHO Claw 网络
    │
    ├── 用户节点 ──────► 查询 ShiGraph ────► 发现 Skill
    │                       │
    ├── 沙箱节点 ──────► 生成事件 ────────► 更新 ShiGraph
    │                       │
    ├── 验证节点 ──────► 验证事件 ────────► 确认状态变更
    │                       │
    └── 发现节点 ──────► 维护 ShiGraph ──► 响应查询
```

---

## 二、ShiGraph 三层架构在 ECHO 中的实现

### 2.1 数据层：事件流 → 三维编织

```typescript
// 维度定义
const DIMENSIONS = {
  time: {
    name: "时间",
    levels: ["时辰", "日月", "季节", "纪元"],  // 4档
    mapping: {
      "时辰": (event) => new Date(event.timestamp).getHours(),
      "日月": (event) => new Date(event.timestamp).getDate(),
      "季节": (event) => Math.floor(new Date(event.timestamp).getMonth() / 3),
      "纪元": (event) => Math.floor(event.timestamp / (365 * 24 * 3600 * 1000))
    }
  },
  space: {
    name: "空间",
    levels: ["点", "域", "界", "境"],  // 4档
    mapping: {
      "点": (event) => event.sandbox_id,           // 单个沙箱
      "域": (event) => event.sandbox_region,        // 区域
      "界": (event) => event.skill_category,        // 分类
      "境": (event) => event.network_zone           // 网络分区
    }
  },
  relation: {
    name: "关系",
    levels: ["链", "网", "流", "场"],  // 4档
    mapping: {
      "链": (event) => event.parent_asset_id || null,  // 上下游
      "网": (event) => event.cited_by || [],           // 被引用
      "流": (event) => event.call_chain || [],         // 调用链
      "场": (event) => event.related_assets || []     // 相关资产
    }
  }
};

// 4×4×4 = 64 维度组合
type DimensionKey = `${TimeLevel}-${SpaceLevel}-${RelationLevel}`;
// 示例: "时辰-点-链", "季节-境-场" 等

// 事件到64维的映射
function mapEventToDimensions(event: EchoEvent): DimensionKey[] {
  const keys: DimensionKey[] = [];
  
  for (const timeLevel of DIMENSIONS.time.levels) {
    for (const spaceLevel of DIMENSIONS.space.levels) {
      for (const relationLevel of DIMENSIONS.relation.levels) {
        const key = `${timeLevel}-${spaceLevel}-${relationLevel}` as DimensionKey;
        keys.push(key);
      }
    }
  }
  
  return keys;
}
```

### 2.2 结构层：势场计算

```typescript
interface ShiField {
  // 势场标识
  id: string;
  hexagram: string;              // 所属卦象
  stage: "SEED" | "SPROUT" | "GROWTH" | "MATURE" | "TRANSFORM";
  
  // 三维坐标
  coordinate: {
    time: number;                // 时间维度值 (0-3)
    space: number;               // 空间维度值 (0-3)
    relation: number;            // 关系维度值 (0-3)
  };
  
  // 势能量
  potential: number;              // 当前势能 (0-1)
  momentum: number;              // 势动量（变化率）
  
  // 包含的资产
  assets: string[];              // 属于此势场的资产ID列表
  
  // 统计
  stats: {
    total_usage: number;
    total_revenue: number;
    active_creators: number;
    derivative_count: number;
    avg_quality: number;
  };
}

// t-SNE + DBSCAN 势场计算
class ShiFieldEngine {
  async computeFields(events: EchoEvent[]): Promise<ShiField[]> {
    // 1. 构建特征向量
    const features = events.map(e => [
      // 时间特征
      normalize(e.timestamp),
      e.context.duration_ms,
      
      // 空间特征
      hash(e.sandbox_region) / Number.MAX_SAFE_INTEGER,
      e.context.compute_units,
      
      // 关系特征
      e.call_chain?.length || 0,
      e.related_assets?.length || 0,
      
      // 价值特征
      e.cost.amount,
      e.context.quality_score
    ]);
    
    // 2. t-SNE降维到3D
    const embeddings = await tsne(features, {
      dimensions: 3,
      perplexity: 30,
      iterations: 1000
    });
    
    // 3. DBSCAN聚类（自动发现势场区域）
    const clusters = dbscan(embeddings, {
      epsilon: 0.5,
      minPoints: 5
    });
    
    // 4. 将聚类映射到64卦
    const fields = clusters.map(cluster => ({
      id: generateFieldId(),
      hexagram: mapToHexagram(cluster.centroid),
      stage: determineStage(cluster),
      coordinate: {
        time: Math.round(cluster.centroid[0] * 3),
        space: Math.round(cluster.centroid[1] * 3),
        relation: Math.round(cluster.centroid[2] * 3)
      },
      potential: calculatePotential(cluster),
      momentum: calculateMomentum(cluster, this.previousClusters),
      assets: cluster.points.map(i => events[i].asset_id),
      stats: calculateStats(cluster, events)
    }));
    
    return fields;
  }
}
```

### 2.3 状态层：势位协议

```typescript
interface ShiPosition {
  // 资产标识
  asset_id: string;
  
  // 六爻坐标
  yao: [number, number, number];  // 三维各4档 (0-3)
  
  // 当前卦象
  hexagram: string;                // 64卦之一
  stage: LifeStage;
  
  // 势能度量
  shi_score: {
    shi: number;                   // 使用势（0-1）
    yi: number;                    // 意义势（0-1）
    li: number;                    // 利益势（0-1）
  };
  
  // 变势趋势
  trend: {
    direction: "ascending" | "descending" | "stable";
    speed: number;                // 变化速度
    next_likely: string[];        // 可能变到的卦象
  };
}

// 变势规则（简化版）
const HEXAGRAM_RULES = {
  "坤": {                        // 潜藏期
    stage: "SEED",
    min_usage: 0,
    max_usage: 10,
    constraints: {
      yan: { min: 0, max: 2 },   // 衍权限制
      kuo: { min: 0, max: 2 }    // 扩权限制
    },
    next: ["屯", "复"]           // 可能变到的卦
  },
  "屯": {                        // 萌芽期
    stage: "SPROUT",
    min_usage: 10,
    max_usage: 100,
    constraints: {
      yan: { min: 1, max: 3 },
      kuo: { min: 1, max: 3 }
    },
    next: ["泰", "需"]
  },
  "泰": {                        // 成长期
    stage: "GROWTH",
    min_usage: 100,
    max_usage: 500,
    constraints: {
      yan: { min: 2, max: 4 },
      kuo: { min: 2, max: 4 },
      yi: { min: 0, max: 2, suggestion: "考虑解锁益权" }
    },
    next: ["咸", "大壮"]
  },
  "咸": {                        // 大成期
    stage: "MATURE",
    min_usage: 500,
    max_usage: Infinity,
    constraints: {
      yan: { min: 3, max: 5 },    // 强制开放衍生
      kuo: { min: 3, max: 5 },   // 强制开放扩展
      yi: { min: 2, max: 5, suggestion: "建议解锁益权" }
    },
    next: ["乾", "革"]
  },
  "乾": {                        // 转化期
    stage: "TRANSFORM",
    min_usage: 2000,
    constraints: {
      yan: { min: 4, max: 5 },
      kuo: { min: 4, max: 5 },
      yi: { min: 3, max: 5 }
    },
    next: ["坤", "艮"]
  }
};

// 变势计算
function calculateStateTransition(
  currentState: ShiPosition,
  newEvents: EchoEvent[]
): StateTransition {
  // 1. 计算新事件对三维坐标的影响
  const usageDelta = newEvents.filter(e => e.type === "UsageOccurred").length;
  const derivativeDelta = newEvents.filter(e => e.type === "DerivativeCreated").length;
  const deploymentDelta = newEvents.filter(e => e.type === "DeploymentEvent").length;
  
  // 2. 更新坐标
  const newYao: [number, number, number] = [
    Math.min(currentState.yao[0] + usageDelta / 100, 3),
    Math.min(currentState.yao[1] + deploymentDelta / 10, 3),
    Math.min(currentState.yao[2] + derivativeDelta / 10, 3)
  ];
  
  // 3. 映射到新卦象
  const newHexagram = yaoToHexagram(newYao);
  
  // 4. 检查约束
  const rules = HEXAGRAM_RULES[newHexagram];
  const conflicts = detectConflicts(currentState, rules);
  
  return {
    from: currentState,
    to: {
      asset_id: currentState.asset_id,
      yao: newYao,
      hexagram: newHexagram,
      stage: rules.stage,
      shi_score: calculateShiScore(newEvents),
      trend: calculateTrend(currentState, newYao)
    },
    trigger: "usage_threshold",
    conflicts,
    timestamp: Date.now()
  };
}
```

---

## 三、发现机制设计

### 3.1 查询接口

```typescript
// ShiGraph 查询 DSL
interface ShiQuery {
  // 基础过滤
  filters?: {
    // 生命周期阶段
    stages?: LifeStage[];
    
    // 卦象过滤
    hexagrams?: string[];
    
    // 势能范围
    potential?: {
      min?: number;
      max?: number;
    };
    
    // 创造者
    creators?: string[];
    
    // 标签
    tags?: string[];
    
    // 四权配置
    rights?: {
      yong?: { min?: number; max?: number };
      yan?: { min?: number; max?: number };
      kuo?: { min?: number; max?: number };
      yi?: { min?: number; max?: number };
    };
    
    // 价格范围
    price?: {
      min?: number;
      max?: number;
      currency?: string;
    };
    
    // 时间窗口
    timeWindow?: {
      start: number;
      end: number;
    };
    
    // 空间
    regions?: string[];
  };
  
  // 排序
  sort?: {
    field: "potential" | "momentum" | "usage" | "revenue" | "quality" | "created";
    direction: "asc" | "desc";
  };
  
  // 分页
  pagination?: {
    limit: number;
    offset: number;
  };
  
  // 关系查询
  relations?: {
    // 查询与特定Skill的关系
    relatedTo?: string;
    relationType?: "derivative" | "citation" | "similar" | "cousage";
    depth?: number;
  };
  
  // 相似度查询
  similarTo?: {
    asset_id?: string;
    vector?: number[];            // 语义向量
    threshold?: number;           // 相似度阈值
  };
}

// 查询示例
const exampleQueries = {
  // 查询成长期的、允许衍生的、高质量的Skill
  growingDerivative: {
    filters: {
      stages: ["GROWTH", "MATURE"],
      rights: { yan: { min: 2 } },
      potential: { min: 0.6 }
    },
    sort: { field: "momentum", direction: "desc" },
    pagination: { limit: 20, offset: 0 }
  },
  
  // 查询与我的Skill相关的衍生作品
  myDerivatives: {
    filters: {
      stages: ["SEED", "SPROUT", "GROWTH", "MATURE"]
    },
    relations: {
      relatedTo: "skill_myskill_alice",
      relationType: "derivative",
      depth: 2
    }
  },
  
  // 语义相似度搜索
  semanticSearch: {
    similarTo: {
      vector: [0.1, 0.2, 0.3, ...],  // 语义向量
      threshold: 0.8
    },
    filters: {
      rights: { yong: { min: 1 } }    // 至少允许使用
    }
  },
  
  // 趋势发现（势能上升最快的）
  trending: {
    sort: { field: "momentum", direction: "desc" },
    filters: {
      potential: { min: 0.3 },        // 排除太冷门的
      stages: ["SPROUT", "GROWTH"]    // 关注成长期
    },
    pagination: { limit: 10, offset: 0 }
  }
};
```

### 3.2 发现API

```typescript
class ShiGraphAPI {
  // 基础查询
  async query(query: ShiQuery): Promise<ShiResult> {
    // 1. 从缓存或网络获取ShiGraph状态
    const state = await this.getState();
    
    // 2. 应用过滤
    let results = state.assets.filter(asset => this.matchesFilters(asset, query.filters));
    
    // 3. 应用关系过滤
    if (query.relations) {
      results = await this.applyRelationFilter(results, query.relations);
    }
    
    // 4. 应用相似度过滤
    if (query.similarTo) {
      results = await this.applySimilarityFilter(results, query.similarTo);
    }
    
    // 5. 排序
    if (query.sort) {
      results = this.sortResults(results, query.sort);
    }
    
    // 6. 分页
    const total = results.length;
    const paginated = results.slice(
      query.pagination?.offset || 0,
      (query.pagination?.offset || 0) + (query.pagination?.limit || 20)
    );
    
    return {
      total,
      results: paginated,
      query,
      computed_at: Date.now()
    };
  }
  
  // 获取Skill的Shi状态
  async getShiState(assetId: string): Promise<ShiPosition> {
    // 1. 查缓存
    const cached = this.cache.get(`shi:${assetId}`);
    if (cached && cached.age < 3600000) {  // 1小时缓存
      return cached.data;
    }
    
    // 2. 计算最新状态
    const events = await this.getEventsForAsset(assetId, "7d");
    const state = await this.computeShiState(assetId, events);
    
    // 3. 缓存
    this.cache.set(`shi:${assetId}`, { data: state, age: 0 });
    
    return state;
  }
  
  // 获取趋势
  async getTrending(options?: {
    hexagram?: string;
    stage?: LifeStage;
    limit?: number;
  }): Promise<TrendingResult> {
    const query: ShiQuery = {
      filters: {
        stages: options?.stage ? [options.stage] : ["SPROUT", "GROWTH"],
        potential: { min: 0.3 }
      },
      sort: { field: "momentum", direction: "desc" },
      pagination: { limit: options?.limit || 10, offset: 0 }
    };
    
    if (options?.hexagram) {
      query.filters.hexagrams = [options.hexagram];
    }
    
    return this.query(query);
  }
  
  // 获取衍生树
  async getDerivationTree(assetId: string, depth: number = 3): Promise<TreeNode> {
    const root: TreeNode = {
      asset_id: assetId,
      children: []
    };
    
    const queue = [{ node: root, depth: 0 }];
    
    while (queue.length > 0) {
      const { node, depth: currentDepth } = queue.shift();
      
      if (currentDepth >= depth) continue;
      
      // 查询直接衍生作品
      const derivatives = await this.query({
        filters: {},
        relations: {
          relatedTo: node.asset_id,
          relationType: "derivative",
          depth: 1
        }
      });
      
      for (const child of derivatives.results) {
        const childNode: TreeNode = {
          asset_id: child.asset_id,
          children: []
        };
        node.children.push(childNode);
        queue.push({ node: childNode, depth: currentDepth + 1 });
      }
    }
    
    return root;
  }
}
```

### 3.3 CLI发现命令

```bash
# ========== 基础发现 ==========
echo-claw discover
  --query "写诗"                    # 关键词搜索
  --tag "文本生成"                   # 标签过滤
  --stage GROWTH                   # 生命周期阶段
  --hexagram 泰                     # 卦象过滤
  --price-max 0.05                 # 最高价格
  --sort momentum                  # 按势能排序
  --limit 20

# 输出示例:
# ╔═══════════════════════════════════════════════════════════════╗
# ║  发现结果 (按势能排序)                                        ║
# ╠═══════════════════════════════════════════════════════════════╣
# ║                                                               ║
# ║  1. 智能写诗助手 (skill_poet_alice)                            ║
# ║     卦象: 泰卦 (成长期)  ████████████████████                  ║
# ║     势位: [2,1,2]  势能: 0.78  动量: +0.12 ▲                 ║
# ║     价格: 0.01 ECHO/次  质量: 0.85                            ║
# ║     使用: 342次  衍生: 3个作品                                 ║
# ║     标签: #文本生成 #诗歌 #中文                                ║
# ║                                                               ║
# ║  2. 营销文案生成器 (skill_copy_bob)                            ║
# ║     卦象: 屯卦 (萌芽期)  ████████░░░░░░░░░░                    ║
# ║     势位: [1,1,1]  势能: 0.45  动量: +0.08 ▲                 ║
# ║     价格: 0.005 ECHO/次  质量: 0.72                           ║
# ║     使用: 89次  衍生: 1个作品                                  ║
# ║     标签: #营销 #文案 #商业                                    ║
# ║                                                               ║
# ║  ...                                                          ║
# ╚═══════════════════════════════════════════════════════════════╝

# ========== 趋势 ==========
echo-claw trending
  --stage SPROUT                   # 萌芽期趋势
  --region asia-east               # 亚洲东部区域

# ========== 相关Skill ==========
echo-claw related skill_poet_alice
  --depth 2                        # 衍生深度
  --include-ancestors              # 包含上游

# 输出示例:
# 衍生树:
# skill_poet_alice
# ├── skill_poet_enhanced (扩展: 多语言)
# │   ├── skill_poet_spanish
# │   └── skill_poet_french
# └── skill_marketing_copy (应用: 营销场景)
#     └── skill_ad_generator

# ========== 卦象查询 ==========
echo-claw hexagram 泰
  --assets                         # 显示所有泰卦的Skill
  --stats                          # 显示统计信息

# 输出示例:
# 泰卦 (成长期)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Skill数量: 127
# 平均使用: 234次
# 平均收益: 45 ECHO
# 衍生率: 23% (29个衍生作品)
# 质量分: 0.81
# 
# 约束条件:
#   衍权: ≥2 (建议)
#   扩权: ≥2 (建议)
#   益权: 建议解锁
```

---

## 四、发现机制保证

### 4.1 八大保证实现

```typescript
interface DiscoveryGuarantees {
  // 保证1: 无排名算法
  noRankingAlgorithm(): boolean {
    // ShiGraph 不排序，只分组
    // 用户看到: "这是屯卦区域的Skill"
    // 不是: "这是第1名、第2名..."
    return true;
  }
  
  // 保证2: 变势透明度
  transitionTransparency(assetId: string): TransitionLog {
    return {
      history: this.getTransitionHistory(assetId),
      current: this.getCurrentState(assetId),
      upcoming: this.getPredictedTransitions(assetId),
      // 所有数据公开可查
    };
  }
  
  // 保证3: 创作者沙箱主权
  creatorSandboxSovereignty(): boolean {
    // ECHO 网络只知道: Skill存在、执行发生、资源消耗
    // 不知道: 模型参数、Prompt内容、输入输出明文
    return true;
  }
  
  // 保证4: 无全局干预
  noGlobalIntervention(): boolean {
    // 没有全局管理员可以: 
    // - 修改Skill排名
    // - 删除Skill（除非违反法律）
    // - 调整收益分配
    return true;
  }
  
  // 保证5: 数据可迁移
  dataPortability(assetId: string): PortabilityInfo {
    return {
      canExport: true,
      exportFormat: ["echo-package", "json", "yaml"],
      // 导出包含: 元数据、蓝图、事件历史（不含明文内容）
    };
  }
  
  // 保证6: 验证开放性
  verificationOpenness(): boolean {
    // 任何人可以成为验证者
    // 条件: 质押 + 使用历史（不能纯质押）
    return true;
  }
  
  // 保证7: 无锁定效应
  noLockIn(): boolean {
    // 创作者可以随时:
    // - 导出Skill包
    // - 在另一节点重新登记
    // - 修改蓝图
    return true;
  }
  
  // 保证8: 开源可审计
  openSourceAuditable(): boolean {
    // ShiGraph 计算引擎开源
    // 事件流公开可查
    // 验证逻辑透明
    return true;
  }
}
```

### 4.2 零发现偏见机制

```typescript
class ZeroBiasDiscovery {
  // 防止"富者越富"效应
  
  async discoverWithBiasCorrection(query: ShiQuery): Promise<ShiResult> {
    // 1. 获取原始结果
    const raw = await this.shiGraph.query(query);
    
    // 2. 应用偏见修正
    const corrected = raw.results.map(skill => {
      // 对高势能Skill施加"重力衰减"
      // 防止它们永远占据前列
      const gravityDecay = 1 / (1 + Math.log(skill.shi_score.shi * 100 + 1));
      
      // 对新Skill施加"新保护"
      const ageBoost = skill.created_at > Date.now() - 7 * 24 * 3600 * 1000 ? 1.5 : 1;
      
      // 对多样化创作者施加"生态奖励"
      const diversityBoost = this.isFromUnderrepresentedCreator(skill) ? 1.3 : 1;
      
      return {
        ...skill,
        adjusted_score: skill.shi_score.shi * gravityDecay * ageBoost * diversityBoost
      };
    });
    
    // 3. 重新排序（使用调整后的分数）
    corrected.sort((a, b) => b.adjusted_score - a.adjusted_score);
    
    return {
      ...raw,
      results: corrected,
      bias_applied: {
        gravity_decay: true,
        new_protection: true,
        diversity_boost: true
      }
    };
  }
}
```

---

## 五、事件流集成

### 5.1 事件订阅

```typescript
class ShiGraphEventSubscriber {
  // 订阅ECHO网络事件，实时更新ShiGraph
  
  async startListening(): Promise<void> {
    // 1. 连接到Kafka
    await this.kafka.connect("echo.events.*");
    
    // 2. 注册处理器
    this.kafka.on("UsageOccurred", async (event) => {
      await this.handleUsageEvent(event);
    });
    
    this.kafka.on("DerivativeCreated", async (event) => {
      await this.handleDerivativeEvent(event);
    });
    
    this.kafka.on("DeploymentEvent", async (event) => {
      await this.handleDeploymentEvent(event);
    });
    
    this.kafka.on("PolicyAdjusted", async (event) => {
      await this.handlePolicyEvent(event);
    });
  }
  
  private async handleUsageEvent(event: UsageOccurred): Promise<void> {
    // 1. 更新Skill的使用统计
    await this.updateUsageStats(event.asset_id, event);
    
    // 2. 更新势场
    await this.updatePotential(event.asset_id);
    
    // 3. 检查是否需要变势
    const currentState = await this.getShiState(event.asset_id);
    const newEvents = await this.getRecentEvents(event.asset_id, "1h");
    const transition = calculateStateTransition(currentState, newEvents);
    
    if (transition.to.hexagram !== currentState.hexagram) {
      // 触发变势
      await this.applyStateTransition(transition);
      
      // 广播变势事件
      await this.broadcastTransition(transition);
    }
  }
  
  private async handleDerivativeEvent(event: DerivativeCreated): Promise<void> {
    // 1. 更新关系网络
    await this.addRelationship(event.from_asset_id, event.to_asset_id, "derivative");
    
    // 2. 更新上游Skill的关系维度
    await this.updateRelationDimension(event.from_asset_id);
    
    // 3. 更新下游Skill的关系维度
    await this.updateRelationDimension(event.to_asset_id);
  }
  
  private async handleDeploymentEvent(event: DeploymentEvent): Promise<void> {
    // 更新空间维度
    await this.updateSpaceDimension(event.asset_id, event.sandbox_region);
  }
}
```

### 5.2 实时流计算

```typescript
class StreamShiCalculator {
  // 使用流计算引擎实时更新ShiGraph
  
  async processEventStream(): Promise<void> {
    // 使用Apache Flink或类似引擎
    const pipeline = new FlinkPipeline();
    
    // 1. 读取事件流
    pipeline.source(this.kafkaStream("echo.events"));
    
    // 2. 按asset_id分组
    pipeline.keyBy(event => event.asset_id);
    
    // 3. 窗口计算（滑动窗口，5分钟）
    pipeline.window(SlidingEventTimeWindows.of(Time.minutes(5), Time.minutes(1)));
    
    // 4. 聚合计算
    pipeline.aggregate({
      usage_count: sum("type = 'UsageOccurred'"),
      revenue_sum: sum("cost.amount"),
      avg_quality: avg("context.quality_score"),
      derivative_count: sum("type = 'DerivativeCreated'"),
      unique_users: countDistinct("user_id")
    });
    
    // 5. 更新ShiGraph
    pipeline.sink(async (result) => {
      await this.updateShiState(result.asset_id, result);
    });
    
    pipeline.execute();
  }
}
```

---

## 六、索引与查询优化

### 6.1 多维索引

```typescript
// PostgreSQL + 扩展
interface ShiIndexSchema {
  // 主表
  skills: {
    asset_id: string;            // PRIMARY KEY
    name: string;
    creator_id: string;
    blueprint_hash: string;
    content_hash: string;
    created_at: timestamp;
    
    // Shi状态
    hexagram: string;
    stage: string;
    yao: number[];               // GIN索引
    potential: number;
    momentum: number;
    
    // 统计（物化视图）
    usage_count: number;
    revenue_total: number;
    derivative_count: number;
    avg_quality: number;
    
    // 搜索向量
    semantic_vector: number[];    // pgvector扩展
  };
  
  // 关系表
  relationships: {
    from_asset: string;
    to_asset: string;
    type: string;               // derivative | citation | cousage
    weight: number;
    created_at: timestamp;
  };
  
  // 事件表（分区）
  events: {
    event_id: string;
    asset_id: string;
    type: string;
    timestamp: timestamp;
    data: jsonb;
  };
}

// 索引策略
const INDEXES = {
  // B-tree: 精确查询
  "skills_asset_id": "CREATE UNIQUE INDEX ON skills(asset_id)",
  "skills_creator": "CREATE INDEX ON skills(creator_id)",
  "skills_hexagram": "CREATE INDEX ON skills(hexagram)",
  "skills_stage": "CREATE INDEX ON skills(stage)",
  
  // GIN: 多维查询
  "skills_yao": "CREATE INDEX ON skills USING GIN(yao)",
  "skills_tags": "CREATE INDEX ON skills USING GIN(tags)",
  
  // BRIN: 时间范围查询
  "events_timestamp": "CREATE INDEX ON events USING BRIN(timestamp)",
  
  // ivfflat: 向量相似度
  "skills_vector": "CREATE INDEX ON skills USING ivfflat(semantic_vector vector_cosine_ops)",
  
  // GiST: 空间查询
  "skills_coordinate": "CREATE INDEX ON skills USING GiST(coordinate)"
};
```

### 6.2 查询计划

```typescript
class QueryPlanner {
  async plan(query: ShiQuery): Promise<QueryPlan> {
    const plan: QueryPlan = {
      steps: [],
      estimatedCost: 0,
      indexesUsed: []
    };
    
    // 1. 确定索引策略
    if (query.filters?.hexagrams) {
      plan.steps.push({ type: "index_scan", index: "skills_hexagram" });
      plan.indexesUsed.push("skills_hexagram");
    }
    
    if (query.filters?.stages) {
      plan.steps.push({ type: "index_scan", index: "skills_stage" });
      plan.indexesUsed.push("skills_stage");
    }
    
    if (query.filters?.potential) {
      plan.steps.push({ type: "bitmap_scan", index: "skills_potential" });
      plan.indexesUsed.push("skills_potential");
    }
    
    if (query.similarTo?.vector) {
      plan.steps.push({ type: "vector_search", index: "skills_vector" });
      plan.indexesUsed.push("skills_vector");
    }
    
    if (query.relations) {
      plan.steps.push({ type: "join", table: "relationships" });
    }
    
    // 2. 排序策略
    if (query.sort?.field === "momentum") {
      plan.steps.push({ type: "sort", field: "momentum", index: "skills_momentum" });
    }
    
    // 3. 分页策略
    plan.steps.push({ type: "limit", limit: query.pagination?.limit || 20 });
    
    return plan;
  }
}
```

---

## 七、缓存策略

### 7.1 多级缓存

```typescript
class ShiCache {
  // L1: 内存缓存（单个节点）
  l1 = new LRUCache<string, any>({
    max: 1000,                    // 最多1000个Skill
    ttl: 300000                  // 5分钟TTL
  });
  
  // L2: Redis集群（共享）
  l2: RedisCluster;
  
  // L3: 本地文件（持久化）
  l3: FileStore;
  
  async getShiState(assetId: string): Promise<ShiPosition> {
    // 1. 查L1
    const l1Value = this.l1.get(`shi:${assetId}`);
    if (l1Value) return l1Value;
    
    // 2. 查L2
    const l2Value = await this.l2.get(`shi:${assetId}`);
    if (l2Value) {
      this.l1.set(`shi:${assetId}`, l2Value);
      return l2Value;
    }
    
    // 3. 计算
    const computed = await this.computeShiState(assetId);
    
    // 4. 写入缓存
    this.l1.set(`shi:${assetId}`, computed);
    this.l2.setex(`shi:${assetId}`, 3600, computed);  // 1小时
    
    return computed;
  }
  
  // 批量预热
  async warmCache(assetIds: string[]): Promise<void> {
    const missing = assetIds.filter(id => !this.l1.has(`shi:${id}`));
    
    // 并行查询
    const results = await Promise.all(
      missing.map(id => this.computeShiState(id))
    );
    
    // 写入缓存
    for (let i = 0; i < missing.length; i++) {
      this.l1.set(`shi:${missing[i]}`, results[i]);
    }
  }
}
```

### 7.2 缓存失效策略

```typescript
class CacheInvalidation {
  // 事件驱动的缓存失效
  
  async onEvent(event: EchoEvent): Promise<void> {
    switch (event.type) {
      case "UsageOccurred":
        // 轻度失效：更新统计
        await this.invalidateStats(event.asset_id);
        break;
        
      case "DerivativeCreated":
        // 中度失效：更新关系
        await this.invalidateRelationships(event.from_asset_id);
        await this.invalidateRelationships(event.to_asset_id);
        break;
        
      case "ShiStateChanged":
        // 重度失效：重新计算势状态
        await this.invalidateShiState(event.asset_id);
        break;
        
      case "PolicyAdjusted":
        // 全量失效：蓝图变更影响所有查询
        await this.invalidateBlueprint(event.asset_id);
        break;
    }
  }
  
  private async invalidateStats(assetId: string): Promise<void> {
    // 删除统计缓存
    this.cache.del(`stats:${assetId}`);
    // 标记Shi状态需要重新计算（但不立即删除，下次查询时计算）
    this.cache.set(`shi:${assetId}:stale`, true);
  }
  
  private async invalidateShiState(assetId: string): Promise<void> {
    // 立即删除Shi状态缓存
    this.cache.del(`shi:${assetId}`);
    this.cache.del(`shi:${assetId}:stale`);
  }
}
```

---

## 八、可视化

### 8.1 CLI可视化

```bash
# 势场地图
echo-claw map
  --dimension time                  # 按时间维度
  --hexagrams                       # 显示卦象
  
# 输出:
#       空间 →
#    点    域    界    境
# 时  ┌─────┬─────┬─────┬─────┐
# 辰  │ 坤  │ 坤  │ 屯  │ 屯  │
#  ↓  ├─────┼─────┼─────┼─────┤
# 日  │ 屯  │ 泰  │ 泰  │ 咸  │
#    ├─────┼─────┼─────┼─────┤
# 季  │ 泰  │ 咸  │ 乾  │ 乾  │
#    ├─────┼─────┼─────┼─────┤
# 纪  │ 咸  │ 乾  │ 乾  │ 乾  │
#    └─────┴─────┴─────┴─────┘

# 单个Skill的势态
echo-claw status skill_poet_alice
  --graph                           # 显示趋势图
  
# 输出:
# ╔════════════════════════════════════════════════════════════╗
# ║  skill_poet_alice                                          ║
# ║  智能写诗助手                                               ║
# ╠════════════════════════════════════════════════════════════╣
# ║                                                            ║
# ║  卦象: 泰卦 (成长期)                                        ║
# ║  势位: [2, 1, 2]                                           ║
# ║                                                            ║
# ║  使用势 ████████████████████░░░░ 0.72                       ║
# ║  意义势 ██████████████░░░░░░░░░░ 0.58                       ║
# ║  利益势 ████████████████░░░░░░░░ 0.64                       ║
# ║                                                            ║
# ║  变势趋势: ▲ 上升 (+0.12/天)                                ║
# ║  下一可能: 咸卦 (74%) 或 大壮卦 (26%)                       ║
# ║                                                            ║
# ║  使用: 342次  衍生: 3  部署: 2平台                           ║
# ║  收益: 34.2 ECHO  质量: 0.85                                 ║
# ║                                                            ║
# ║  约束预览:                                                  ║
# ║    当前: 衍权建议≥2 (当前=3 ✓)                              ║
# ║    下一: 衍权强制≥3 (当前=3 ✓)                              ║
# ║                                                            ║
# ╚════════════════════════════════════════════════════════════╝
```

### 8.2 Web可视化

```
┌─────────────────────────────────────────────────────────────┐
│  ShiGraph Explorer                                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────┐  ┌────────────────────────┐ │
│  │  势场3D地图               │  │  Skill详情              │ │
│  │                          │  │                        │ │
│  │    ★                     │  │  名称: 智能写诗助手      │ │
│  │   /|\                    │  │  卦象: 泰卦              │ │
│  │  / | \   泰卦区域        │  │  势位: [2,1,2]          │ │
│  │ /  |  \                  │  │                        │ │
│  │    |                     │  │  趋势图:                 │ │
│  │   屯卦区域                │  │  ▁▂▄▆█▇▆▄▂             │ │
│  │                          │  │  过去7天势能变化         │ │
│  │  [鼠标悬停查看详情]       │  │                        │ │
│  │                          │  │  相关Skill:              │ │
│  └──────────────────────────┘  │  • 英文诗生成器 (屯)     │ │
│                                │  • 歌词创作助手 (泰)     │ │
│  ┌──────────────────────────┐  │  • 古诗文分析器 (坤)     │ │
│  │  卦象流图                 │  │                        │ │
│  │                          │  └────────────────────────┘ │
│  │  坤 → 屯 → 泰 → 咸 → 乾  │                             │
│  │   ↓    ↓    ↓    ↓      │                             │
│  │  [我的位置]              │                             │
│  │                          │                             │
│  └──────────────────────────┘                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 九、性能指标

| 指标 | 目标 | 说明 |
|------|------|------|
| 查询延迟 | P99 < 200ms | 单节点查询 |
| 变势计算 | < 5秒 | 从事件到状态更新 |
| 索引更新 | < 1秒 | 事件到可查询 |
| 缓存命中 | > 90% | L1+L2缓存 |
| 并发查询 | 10,000 QPS | 单节点 |
| 事件处理 | 100,000/秒 | 单节点 |
| 势场重算 | < 10分钟 | 全网络 |

---

## 十、路线图

| 阶段 | 功能 | 时间 |
|------|------|------|
| MVP | 基础ShiGraph + 卦象映射 + 基础查询 | 8周 |
| V1.0 | 完整64卦 + 变势机制 + 势场可视化 | 16周 |
| V1.5 | 流计算 + 实时变势 + 高级查询DSL | 24周 |
| V2.0 | AI辅助发现 + 预测变势 + 个性化势图 | 36周 |

---

> **设计参考**: ShiGraph 参考 Google PageRank 的图计算理念 + Apache Kafka 的流处理 + 《周易》的卦变哲学。目标：不是"推荐"，是"涌现"。不是"控制"，是"描述"。
