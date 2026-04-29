# ECHO 创作者工具矩阵 - 协作与组织工具设计文档

## 设计愿景

ECHO 的协作工具旨在打破创作者之间的隔阂，让不同地域、不同专长的创作者能够无缝协作。我们不仅要提供功能，更要构建一个**协作生态系统**，让每个参与者都能明确自己的贡献、保护自己的权益、高效地完成创作。

---

## 1. 协作功能技术架构

### 1.1 核心架构选择：CRDT + OT 混合模型

#### 为什么选择混合？

| 场景 | 技术选择 | 理由 |
|------|---------|------|
| 文本编辑 | CRDT | 最终一致性，离线友好，无冲突 |
| 设计画布 | OT (Operational Transformation) | 强一致性，操作顺序重要 |
| 代码编辑 | CRDT | 长期离线支持，版本分支 |
| 音频波形 | OT + 锁定机制 | 片段操作，需要严格顺序 |

#### CRDT 层（Yjs 作为基础库）

```typescript
// ECHO CRDT 核心架构
interface CRDTConfig {
  docType: 'text' | 'rich-text' | 'canvas' | 'spreadsheet' | 'code';
  awareness: {
    cursors: boolean;
    selections: boolean;
    presence: boolean;
  };
  persistence: {
    level: 'memory' | 'indexeddb' | 'cloud';
    autoSaveInterval: number; // ms
  };
}

// 统一文档模型
class ECHODocument {
  private ydoc: Y.Doc;
  private provider: WebsocketProvider;
  private awareness: Awareness;
  
  // 文档权限绑定
  bindRights(rightId: string): void {
    this.ydoc.setMeta('rightId', rightId);
    this.ydoc.setMeta('contributors', new Map());
  }
  
  // 记录贡献时间戳
  recordContribution(userId: string, operation: Operation): void {
    const contributors = this.ydoc.getMeta('contributors');
    const current = contributors.get(userId) || { time: 0, ops: 0 };
    contributors.set(userId, {
      time: current.time + operation.duration,
      ops: current.ops + 1,
      lastEdit: Date.now()
    });
  }
}
```

#### OT 层（用于设计工具）

```typescript
// OT 服务器端架构
interface OTOperation {
  type: 'insert' | 'delete' | 'move' | 'transform' | 'style';
  path: string[]; // JSON Path
  value?: any;
  timestamp: number;
  clientId: string;
  operationId: string; // 全局唯一
}

// 操作转换引擎
class OTEngine {
  // 转换操作以支持并发编辑
  transform(op1: OTOperation, op2: OTOperation): [OTOperation, OTOperation] {
    if (this.isIndependent(op1, op2)) {
      return [op1, op2];
    }
    return this.doTransform(op1, op2);
  }
  
  // 基于路径冲突检测
  private isIndependent(op1: OTOperation, op2: OTOperation): boolean {
    return !this.pathsOverlap(op1.path, op2.path);
  }
}
```

### 1.2 实时同步协议

#### WebSocket 层设计

```
┌─────────────────────────────────────────────────────────────┐
│                    ECHO 实时协作架构                         │
├─────────────────────────────────────────────────────────────┤
│  Client Layer    │  Sync Layer      │  Persistence Layer   │
├──────────────────┼──────────────────┼───────────────────────┤
│  ┌──────────┐    │  ┌──────────┐    │  ┌───────────────┐   │
│  │ Editor   │───▶│  │ WebSocket│───▶│  │ Redis Pub/Sub │   │
│  │ CRDT     │    │  │ Gateway  │    │  │ (Realtime)    │   │
│  └──────────┘    │  └──────────┘    │  └───────────────┘   │
│       │          │       │          │           │         │
│  ┌──────────┐    │  ┌──────────┐    │  ┌───────────────┐   │
│  │ Local    │    │  │ Message  │    │  │ PostgreSQL    │   │
│  │ IndexedDB│◀───│  │ Router   │◀───│  │ (Persistent)  │   │
│  └──────────┘    │  └──────────┘    │  └───────────────┘   │
└──────────────────┴──────────────────┴───────────────────────┘
```

#### 协议消息格式

```typescript
// 统一消息协议
interface ECHOMessage {
  header: {
    version: '1.0';
    messageId: string;
    timestamp: number;
    roomId: string; // document/project id
    userId: string;
    sessionId: string;
  };
  payload: 
    | UpdatePayload      // CRDT 更新
    | AwarenessPayload   // 光标/选区/在线状态
    | RightPayload       // 权限变更
    | CommentPayload     // 评论相关
    | LockPayload;       // 锁定机制
}

// 消息类型枚举
enum MessageType {
  // 文档操作
  DOC_UPDATE = 'doc:update',
  DOC_SYNC = 'doc:sync',
  DOC_AWARENESS = 'doc:awareness',
  
  // 权限与锁定
  RIGHT_CHECK = 'right:check',
  RIGHT_GRANT = 'right:grant',
  LOCK_ACQUIRE = 'lock:acquire',
  LOCK_RELEASE = 'lock:release',
  
  // 评论与沟通
  COMMENT_CREATE = 'comment:create',
  COMMENT_UPDATE = 'comment:update',
  COMMENT_DELETE = 'comment:delete',
  
  // 项目状态
  PROJECT_UPDATE = 'project:update',
  TASK_UPDATE = 'task:update',
}
```

### 1.3 离线优先架构

```typescript
// 离线支持核心
interface OfflineSupport {
  // 离线队列
  pendingQueue: Operation[];
  
  // 本地缓存策略
  cacheStrategy: {
    documents: 'all' | 'recent' | 'pinned';
    maxCacheSize: number; // MB
    evictionPolicy: 'lru' | 'lfu';
  };
  
  // 同步冲突解决
  resolveConflict(local: Operation, remote: Operation): Operation {
    // 1. 基于时间戳
    // 2. 基于用户权限
    // 3. 基于内容哈希
    return this.mergeOperations(local, remote);
  }
  
  // 增量同步
  async syncAfterOffline(): Promise<SyncResult> {
    const localOps = await this.getPendingOperations();
    const serverState = await this.fetchServerState();
    return this.reconcile(localOps, serverState);
  }
}
```

---

## 2. 权限模型详细设计

### 2.1 分层权限体系

```
┌─────────────────────────────────────────────────────────────────┐
│                    ECHO 权限模型架构                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐      │
│   │  平台级     │────▶│  团队级     │────▶│  项目级     │      │
│   │  Platform   │     │  Team       │     │  Project    │      │
│   └─────────────┘     └─────────────┘     └─────────────┘      │
│          │                   │                   │              │
│          ▼                   ▼                   ▼              │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐      │
│   │ 计费/套餐   │     │ 资源配额    │     │ 文档权限    │      │
│   │ 功能访问    │     │ 成员管理    │     │ 任务权限    │      │
│   └─────────────┘     └─────────────┘     └─────────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 角色定义矩阵

#### 团队角色

| 角色 | 权限范围 | 可管理 | 特殊说明 |
|------|---------|--------|---------|
| **所有者 (Owner)** | 全部 | 团队设置、成员、计费、删除 | 唯一，可转让 |
| **管理员 (Admin)** | 除计费外全部 | 成员、项目、设置 | 可执行所有者委托的操作 |
| **编辑者 (Editor)** | 创建/编辑内容 | 自己创建的项目 | 可邀请协作，需审批 |
| **协作者 (Contributor)** | 指定项目 | 分配给自己的任务 | 临时或项目级成员 |
| **查看者 (Viewer)** | 只读 | 无 | 可评论、可查看 |

#### 项目内角色

| 角色 | 文档编辑 | 任务管理 | 成员邀请 | 发布 | 删除 |
|------|---------|---------|---------|------|------|
| 项目负责人 | ✓ | ✓ | ✓ | ✓ | ✓ |
| 核心贡献者 | ✓ | ✓ | △ | △ | ✗ |
| 普通贡献者 | ✓ | △ | ✗ | ✗ | ✗ |
| 审阅者 | △ | ✗ | ✗ | ✗ | ✗ |
| 访客 | ✗ | ✗ | ✗ | ✗ | ✗ |

*△ = 有限权限，需审批*

### 2.3 资源级权限（ACL）

```typescript
// 统一权限系统
interface PermissionSystem {
  // 权限粒度
  granularity: 'workspace' | 'project' | 'folder' | 'document' | 'field';
  
  // 权限定义
  permissions: {
    // 文档权限
    document: [
      'read',           // 查看
      'write',          // 编辑
      'comment',        // 评论
      'share',          // 分享
      'download',       // 下载
      'copy',           // 复制
      'delete',         // 删除
      'admin',          // 管理权限
    ],
    // 项目权限
    project: [
      'view',           // 查看项目
      'edit_content',   // 编辑内容
      'manage_tasks',   // 管理任务
      'invite_member',  // 邀请成员
      'manage_settings', // 项目设置
      'publish',        // 发布作品
      'delete_project', // 删除项目
    ],
    // 协作权限
    collaboration: [
      'suggest_edit',   // 建议编辑（PR模式）
      'direct_edit',    // 直接编辑
      'approve',        // 审批权限
      'review',         // 审阅权限
    ]
  };
}

// 细粒度权限规则
interface ACLRule {
  resource: string; // resource://type/id
  principal: string;  // user://id or team://id
  action: string;
  effect: 'allow' | 'deny';
  condition?: {
    timeRange?: { start: Date; end: Date };
    ipRange?: string[];
    deviceType?: string[];
    watermark?: boolean; // 强制水印
  };
}
```

### 2.4 协作作品的权益分配

```typescript
// ECHO 权利与协作的集成
interface CollaborationRights {
  // 贡献追踪
  contributionTracking: {
    // 自动记录
    autoRecord: {
      editTime: number;      // 编辑时长
      editCount: number;     // 编辑次数
      linesChanged: number;  // 行数变化
      bytesContributed: number; // 字节贡献
    };
    // 手动申报
    manualClaim: {
      role: 'creator' | 'designer' | 'editor' | 'reviewer';
      contribution: string;
      percentage: number;
    }[];
  };
  
  // 权益分配模型
  revenueSharing: {
    model: 'equal' | 'weighted' | 'fixed' | 'hybrid';
    weights: Map<string, number>; // userId -> weight
    // 智能建议
    suggestions: {
      basedOn: 'activity' | 'agreement' | 'expertise';
      confidence: number;
    };
  };
  
  // 作品归属链
  attributionChain: {
    workId: string;
    version: string;
    contributors: {
      userId: string;
      contribution: ContributionRecord;
      rightId: string; // 绑定的权利ID
    }[];
    parentWorks: string[]; // 衍生作品链
  };
}
```

---

## 3. 实时同步机制

### 3.1 状态同步架构

```
                    ┌─────────────────────┐
                    │   状态同步服务      │
                    │   Sync Service      │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   全量同步      │  │   增量同步      │  │   差异同步      │
│   Full Sync     │  │   Delta Sync    │  │   Diff Sync     │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ 首次连接        │  │ 在线更新        │  │ 离线恢复        │
│ 长时间离线后    │  │ 实时协作        │  │ 冲突解决        │
│ 强制刷新        │  │ 心跳同步        │  │ 选择性合并      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### 3.2 增量同步协议

```typescript
// 增量同步消息
interface DeltaSync {
  baseVersion: string;  // 基准版本
  targetVersion: string; // 目标版本
  
  // 变化集
  changes: {
    // 文档内容变化
    document?: Uint8Array; // CRDT update
    // 元数据变化
    metadata?: {
      modifiedBy: string;
      modifiedAt: number;
      changeType: 'content' | 'structure' | 'permission';
    };
    // 引用变化
    references?: {
      added: string[];
      removed: string[];
      modified: string[];
    };
  };
  
  // 压缩策略
  compression: 'none' | 'gzip' | 'brotli' | 'custom';
}

// 差异计算
class DiffEngine {
  // 基于快照的差异
  computeSnapshotDiff(old: Snapshot, current: Snapshot): Diff {
    return {
      documentDiff: this.computeDocumentDiff(old.doc, current.doc),
      treeDiff: this.computeTreeDiff(old.tree, current.tree),
      metadataDiff: this.computeMetadataDiff(old.meta, current.meta)
    };
  }
  
  // 基于操作的差异（更高效）
  computeOperationDiff(ops: Operation[]): Diff {
    return this.optimizeOperations(ops);
  }
}
```

### 3.3 冲突解决策略

```typescript
// 冲突解决策略矩阵
enum ConflictStrategy {
  // 自动策略
  LAST_WRITE_WINS = 'lww',           // 最后写入
  FIRST_WRITE_WINS = 'fww',          // 首次写入
  TIMESTAMP_PRIORITY = 'timestamp',  // 时间戳优先
  
  // 交互策略
  MANUAL_MERGE = 'manual',           // 手动合并
  THREE_WAY_MERGE = '3way',          // 三路合并
  
  // 智能策略
  SEMANTIC_MERGE = 'semantic',       // 语义合并（基于内容理解）
  AI_ASSISTED = 'ai',                // AI辅助合并
}

// 冲突解决引擎
interface ConflictResolver {
  // 冲突检测
  detectConflict(op1: Operation, op2: Operation): ConflictType;
  
  // 策略选择
  selectStrategy(
    conflict: Conflict,
    context: ResolutionContext
  ): ConflictStrategy;
  
  // 自动解决
  resolveAutomatically(
    conflict: Conflict,
    strategy: ConflictStrategy
  ): Resolution;
  
  // 生成合并建议
  generateMergeSuggestions(
    conflict: Conflict
  ): MergeSuggestion[];
}

// 三路合并实现
class ThreeWayMerge {
  merge(base: Document, left: Document, right: Document): MergedResult {
    const leftDiff = this.diff(base, left);
    const rightDiff = this.diff(base, right);
    
    // 独立变更直接应用
    const independent = this.findIndependentChanges(leftDiff, rightDiff);
    
    // 冲突变更需要解决
    const conflicts = this.findConflictingChanges(leftDiff, rightDiff);
    
    return {
      result: this.applyChanges(base, independent),
      conflicts: conflicts.map(c => this.generateConflictUI(c))
    };
  }
}
```

### 3.4 网络恢复机制

```typescript
// 断线重连策略
interface ReconnectionStrategy {
  // 指数退避
  backoff: {
    initialDelay: 1000;      // ms
    maxDelay: 30000;         // ms
    multiplier: 2;
    jitter: 0.1;
  };
  
  // 重连步骤
  async reconnect(): Promise<void> {
    // 1. 检测网络恢复
    await this.waitForNetwork();
    
    // 2. 建立 WebSocket 连接
    const ws = await this.establishConnection();
    
    // 3. 获取服务器当前状态
    const serverState = await this.requestStateSnapshot();
    
    // 4. 对比本地状态
    const localState = this.getLocalState();
    const diff = this.computeDiff(localState, serverState);
    
    // 5. 应用本地变更或接受服务器状态
    if (diff.localChanges.length > 0) {
      await this.pushLocalChanges(diff.localChanges);
    }
    if (diff.serverChanges.length > 0) {
      await this.applyServerChanges(diff.serverChanges);
    }
    
    // 6. 恢复协作状态
    this.restoreCollaborationState();
  }
  
  // 乐观锁重试
  async optimisticUpdate(operation: Operation): Promise<void> {
    let retries = 0;
    const maxRetries = 3;
    
    while (retries < maxRetries) {
      try {
        await this.applyOperation(operation);
        return;
      } catch (conflict) {
        // 合并冲突并重试
        operation = this.mergeWithRemote(operation, conflict);
        retries++;
      }
    }
    
    // 最终失败，通知用户
    throw new OptimisticLockError(operation);
  }
}
```

---

## 4. 项目管理系统

### 4.1 项目数据结构

```typescript
// 项目核心模型
interface Project {
  id: string;
  name: string;
  description: string;
  
  // 项目类型与模板
  type: 'video' | 'podcast' | 'article' | 'design' | 'music' | 'code' | 'mixed';
  template?: ProjectTemplate;
  
  // 时间线
  timeline: {
    startDate: Date;
    targetDate: Date;
    actualEndDate?: Date;
    timezone: string;
  };
  
  // 层级结构
  structure: {
    folders: Folder[];
    documents: DocumentRef[];
    tasks: Task[];
    milestones: Milestone[];
  };
  
  // 权限
  permissions: {
    owner: string;
    members: ProjectMember[];
    visibility: 'private' | 'team' | 'public';
  };
  
  // 统计
  stats: {
    totalTasks: number;
    completedTasks: number;
    totalHours: number;
    lastActivity: Date;
  };
}

// 任务模型
interface Task {
  id: string;
  title: string;
  description: string;
  
  // 状态
  status: 'backlog' | 'todo' | 'in_progress' | 'review' | 'done';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  
  // 分配
  assignee?: string;
  collaborators: string[];
  
  // 时间
  timeline: {
    created: Date;
    startDate?: Date;
    dueDate?: Date;
    completedAt?: Date;
  };
  
  // 关联
  relations: {
    parent?: string;
    subtasks: string[];
    dependencies: string[]; // 前置任务
    dependents: string[]; // 后续任务
    linkedDocuments: string[];
  };
  
  // 与 ECHO 权利关联
  rights?: {
    rightId: string;
    contributionPercentage: number;
  };
}
```

### 4.2 甘特图引擎

```typescript
// 甘特图数据模型
interface GanttData {
  // 时间轴配置
  timeAxis: {
    start: Date;
    end: Date;
    scale: 'hour' | 'day' | 'week' | 'month' | 'quarter';
    workdays: number[]; // 0-6, 0=周日
    holidays: Date[];
  };
  
  // 任务条
  bars: GanttBar[];
  
  // 依赖线
  dependencies: {
    from: string;
    to: string;
    type: 'finish-to-start' | 'start-to-start' | 'finish-to-finish' | 'start-to-finish';
  }[];
  
  // 里程碑
  milestones: {
    id: string;
    name: string;
    date: Date;
    color: string;
  }[];
}

interface GanttBar {
  taskId: string;
  name: string;
  
  // 时间
  start: Date;
  end: Date;
  duration: number; // hours
  
  // 进度
  progress: number; // 0-100
  
  // 显示
  row: number;
  color: string;
  
  // 折叠
  collapsed: boolean;
  children: string[];
}

// 关键路径计算
class CriticalPathCalculator {
  calculate(tasks: Task[]): CriticalPath {
    // 1. 构建任务网络图
    const graph = this.buildGraph(tasks);
    
    // 2. 正向遍历计算最早开始时间
    this.forwardPass(graph);
    
    // 3. 反向遍历计算最晚开始时间
    this.backwardPass(graph);
    
    // 4. 计算浮动时间，找出关键路径
    return this.identifyCriticalPath(graph);
  }
}
```

### 4.3 看板引擎

```typescript
// 看板配置
interface KanbanConfig {
  columns: KanbanColumn[];
  swimlanes?: KanbanSwimlane[]; // 泳道
  
  // 自动化规则
  automations: AutomationRule[];
  
  // 视图设置
  view: {
    cardFields: string[];      // 卡片显示字段
    groupBy: 'assignee' | 'priority' | 'tag' | 'none';
    sortBy: string;
    filter: FilterCondition;
  };
}

interface KanbanColumn {
  id: string;
  name: string;
  status: string | string[]; // 对应的任务状态
  
  // WIP 限制
  wipLimit?: {
    max: number;
    warningAt: number;
  };
  
  // 进入/退出规则
  entryRules: AutomationRule[];
  exitRules: AutomationRule[];
}

// 自动化规则
interface AutomationRule {
  trigger: 
    | { type: 'status_change'; from: string; to: string }
    | { type: 'due_date'; when: 'approaching' | 'overdue'; hours: number }
    | { type: 'custom'; condition: string };
    
  action:
    | { type: 'notify'; to: 'assignee' | 'owner' | 'custom'; message: string }
    | { type: 'move'; column: string }
    | { type: 'set_field'; field: string; value: any }
    | { type: 'webhook'; url: string; payload: object };
}
```

### 4.4 项目模板系统

```typescript
// 项目模板
interface ProjectTemplate {
  id: string;
  name: string;
  category: string;
  
  // 模板内容
  structure: {
    folders: TemplateFolder[];
    documents: TemplateDocument[];
    tasks: TemplateTask[];
    milestones: TemplateMilestone[];
  };
  
  // 配置
  settings: {
    defaultVisibility: Project['visibility'];
    defaultPermissions: Partial<Project['permissions']>;
    automationEnabled: boolean;
  };
  
  // 变量
  variables: TemplateVariable[];
  
  // 元数据
  meta: {
    author: string;
    downloads: number;
    rating: number;
    tags: string[];
  };
}

// 模板实例化
class TemplateEngine {
  instantiate(
    template: ProjectTemplate,
    variables: Record<string, string>
  ): Project {
    return {
      ...this.replaceVariables(template.structure, variables),
      id: generateId(),
      createdAt: new Date(),
      template: { id: template.id, name: template.name }
    };
  }
}
```

---

## 5. 实时协作编辑系统

### 5.1 编辑器架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    协作编辑器架构                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   UI Layer   │    │   CRDT Core  │    │  Sync Layer  │       │
│  ├──────────────┤    ├──────────────┤    ├──────────────┤       │
│  │              │    │              │    │              │       │
│  │ ┌──────────┐ │    │ ┌──────────┐ │    │ ┌──────────┐ │       │
│  │ │ 光标渲染  │ │◀───│ │ Awareness│ │◀───│ │ WebSocket│ │       │
│  │ └──────────┘ │    │ └──────────┘ │    │ └──────────┘ │       │
│  │              │    │              │    │              │       │
│  │ ┌──────────┐ │    │ ┌──────────┐ │    │ ┌──────────┐ │       │
│  │ │ 选区同步  │ │◀───│ │  Selection│ │◀───│ │  Delta   │ │       │
│  │ └──────────┘ │    │ └──────────┘ │    │ └──────────┘ │       │
│  │              │    │              │    │              │       │
│  │ ┌──────────┐ │    │ ┌──────────┐ │    │ ┌──────────┐ │       │
│  │ │ 评论系统  │ │◀───│ │  Comments │ │◀───│ │  Message │ │       │
│  │ └──────────┘ │    │ └──────────┘ │    │ └──────────┘ │       │
│  │              │    │              │    │              │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Persistence Layer                       │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │   │
│  │  │IndexedDB│  │  Redis  │  │   S3    │  │PostgreSQL│      │   │
│  │  │ (Local) │  │(Session)│  │(History)│  │(Metadata)│      │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 光标与选区同步

```typescript
// 光标系统
interface CursorSystem {
  // 本地光标
  local: {
    position: EditorPosition;
    selection: EditorRange | null;
  };
  
  // 远程光标
  remote: Map<string, RemoteCursor>;
  
  // 渲染配置
  render: {
    colors: string[]; // 为每个用户分配的颜色
    showName: boolean;
    showSelection: boolean;
    fadeDelay: number; // 长时间不活动后淡出
  };
}

interface RemoteCursor {
  userId: string;
  userName: string;
  userAvatar: string;
  color: string;
  
  // 位置
  position: EditorPosition;
  selection: EditorRange | null;
  
  // 状态
  lastActivity: number;
  isTyping: boolean;
  
  // 跟随模式
  followMode: {
    enabled: boolean;
    lockedTo: string | null; // 跟随的用户
  };
}

// 位置锚定（处理内容变化时的光标稳定性）
class PositionAnchor {
  // 使用 Yjs 的 RelativePosition
  anchor(relativePos: Y.RelativePosition): Anchor {
    return {
      // 当文档变化时，相对位置自动调整
      resolve: (doc: Y.Doc): EditorPosition => {
        return Y.resolveRelativePosition(relativePos, doc);
      }
    };
  }
}
```

### 5.3 评论与标注系统

```typescript
// 评论系统
interface CommentSystem {
  // 评论类型
  comments: {
    inline: InlineComment[];    // 行内评论
    range: RangeComment[];      // 选区评论
    document: DocumentComment[]; // 文档级评论
    thread: ThreadComment[];    // 讨论串
  };
  
  // 评论状态
  states: {
    draft: '草稿';
    pending: '待回复';
    resolved: '已解决';
    archived: '已归档';
  };
}

interface InlineComment {
  id: string;
  
  // 锚定位置
  anchor: {
    relativePos: Y.RelativePosition;
    line: number;
    preview: string; // 锚定文本预览
  };
  
  // 内容
  author: string;
  content: RichText;
  createdAt: Date;
  editedAt?: Date;
  
  // 回复
  replies: CommentReply[];
  
  // 状态
  status: 'open' | 'resolved';
  resolvedBy?: string;
  resolvedAt?: Date;
  
  // 关联
  mentions: string[];
  reactions: Reaction[];
}

// 标注工具
interface AnnotationTools {
  // 高亮
  highlight: {
    colors: string[];
    ranges: EditorRange[];
    persistent: boolean; // 是否保存到文档
  };
  
  // 批注
  annotation: {
    types: ['note', 'warning', 'question', 'suggestion'];
    visual: 'margin' | 'inline' | 'overlay';
  };
  
  // 建议模式（类似 PR 的 Suggestion）
  suggestion: {
    original: string;
    proposed: string;
    author: string;
    status: 'pending' | 'accepted' | 'rejected';
  };
}
```

### 5.4 变更历史与回滚

```typescript
// 历史系统
interface HistorySystem {
  // 版本快照
  snapshots: {
    automatic: Snapshot[];    // 自动保存
    manual: Snapshot[];       // 手动保存（命名版本）
    branches: Branch[];     // 分支版本
  };
  
  // 操作日志
  operations: {
    granular: Operation[];   // 细粒度操作（用于撤销）
    compressed: CompressedOperation[]; // 压缩（用于长期存储）
  };
}

interface Snapshot {
  id: string;
  name?: string;
  timestamp: Date;
  author: string;
  
  // 内容
  state: Uint8Array; // Yjs 文档状态
  
  // 元数据
  stats: {
    operations: number;
    contributors: string[];
  };
  
  // 标签
  tags: ('milestone' | 'release' | 'checkpoint' | 'backup')[];
}

// 时间旅行 UI
interface TimeTravel {
  // 版本时间线
  timeline: {
    mode: 'linear' | 'branch';
    current: string;
    highlighted: string[];
  };
  
  // 对比视图
  diff: {
    mode: 'split' | 'unified' | 'visual';
    from: string;
    to: string;
  };
  
  // 恢复操作
  restore: {
    toVersion: (snapshotId: string) => Promise<void>;
    cherryPick: (operations: Operation[]) => Promise<void>;
    revert: (operations: Operation[]) => Promise<void>;
  };
}
```

---

## 6. 团队管理系统

### 6.1 团队数据结构

```typescript
// 团队模型
interface Team {
  id: string;
  name: string;
  slug: string;
  description: string;
  avatar: string;
  
  // 成员
  members: TeamMember[];
  invites: PendingInvite[];
  
  // 资源
  resources: {
    projects: string[];
    templates: string[];
    assets: string[];
    storage: {
      used: number;
      total: number;
    };
  };
  
  // 设置
  settings: {
    defaultProjectVisibility: Project['visibility'];
    autoJoin: boolean;
    joinCode?: string;
    domains: string[]; // 允许自动加入的邮箱域名
  };
  
  // 计费
  billing: {
    plan: 'free' | 'pro' | 'enterprise';
    seats: number;
    renewalDate: Date;
  };
}

interface TeamMember {
  userId: string;
  role: 'owner' | 'admin' | 'editor' | 'viewer';
  joinedAt: Date;
  invitedBy: string;
  
  // 工作状态
  status: {
    lastActive: Date;
    currentProject?: string;
    availability: 'available' | 'busy' | 'away' | 'offline';
  };
  
  // 权限覆盖
  permissions?: Partial<PermissionSystem['permissions']>;
}
```

### 6.2 邀请与成员管理

```typescript
// 邀请系统
interface InviteSystem {
  // 邀请方式
  methods: {
    email: {
      to: string;
      role: TeamMember['role'];
      message?: string;
      expiresIn: number; // days
    };
    link: {
      role: TeamMember['role'];
      maxUses?: number;
      expiresIn: number;
      url: string;
    };
    code: {
      code: string;
      role: TeamMember['role'];
      expiresIn: number;
    };
  };
  
  // 审批流程
  approval: {
    required: boolean;
    approvers: string[]; // userIds
    autoApprove: {
      domainMatch: boolean;
      existingMembers: number;
    };
  };
}

// 成员生命周期
interface MemberLifecycle {
  // 入职流程
  onboarding: {
    welcomeMessage: string;
    suggestedProjects: string[];
    requiredActions: ('complete_profile' | 'install_app' | 'join_channel')[];
  };
  
  // 离职流程
  offboarding: {
    transferOwnership: boolean;
    revokeAccess: boolean;
    exportData: boolean;
    gracePeriod: number; // days
  };
}
```

### 6.3 团队资源库

```typescript
// 团队资源库
interface TeamResourceLibrary {
  // 分类存储
  categories: {
    documents: DocumentLibrary;
    templates: TemplateLibrary;
    assets: AssetLibrary;
    snippets: SnippetLibrary;
  };
  
  // 元数据
  metadata: {
    tags: Tag[];
    collections: Collection[];
    favorites: Map<string, string[]>; // userId -> resourceIds
  };
}

interface AssetLibrary {
  // 支持的资源类型
  types: [
    'image',
    'video',
    'audio',
    'font',
    '3d',
    'vector',
    'document',
    'code_snippet'
  ];
  
  // 智能组织
  organization: {
    autoTag: boolean; // AI 自动标签
    autoCategorize: boolean;
    duplicateDetection: boolean;
    similarImageGrouping: boolean;
  };
  
  // 搜索
  search: {
    byContent: boolean; // 图片内容搜索
    byColor: boolean;   // 颜色搜索
    byStyle: boolean;   // 风格搜索
    byUsage: boolean;   // 使用频率
  };
}
```

### 6.4 团队活动与统计

```typescript
// 活动日志
interface ActivityLog {
  events: {
    timestamp: Date;
    actor: string;
    action: string;
    resource: string;
    details: object;
    ip?: string;
    userAgent?: string;
  }[];
  
  // 过滤与搜索
  filter: {
    dateRange: DateRange;
    actors: string[];
    actions: string[];
    resources: string[];
  };
}

// 团队统计
interface TeamAnalytics {
  // 活跃度
  activity: {
    dailyActiveUsers: TimeSeries;
    weeklyActiveUsers: TimeSeries;
    monthlyActiveUsers: TimeSeries;
    
    projectActivity: Map<string, ActivityMetrics>;
    memberActivity: Map<string, ActivityMetrics>;
  };
  
  // 产出统计
  productivity: {
    documentsCreated: TimeSeries;
    tasksCompleted: TimeSeries;
    commentsAdded: TimeSeries;
    
    velocity: { // 敏捷速度
      period: 'sprint' | 'week' | 'month';
      completed: number;
      planned: number;
    };
  };
  
  // 协作分析
  collaboration: {
    mostCollaborated: string[]; // 项目
    collaborationGraph: GraphData; // 成员协作关系图
    responseTime: { // 回复时间
      comment: number; // minutes
      task: number;
      mention: number;
    };
  };
}
```

---

## 7. 模板与素材库

### 7.1 模板市场架构

```typescript
// 模板市场
interface TemplateMarketplace {
  // 官方模板
  official: {
    categories: TemplateCategory[];
    curated: Template[];
    featured: Template[];
  };
  
  // 用户模板
  community: {
    templates: Template[];
    creators: Creator[];
    reviews: Review[];
  };
  
  // 团队模板
  team: {
    templates: Template[];
    sharedWith: string[]; // teamIds
  };
}

interface Template {
  id: string;
  name: string;
  description: string;
  
  // 分类
  category: string;
  subcategory: string;
  tags: string[];
  
  // 内容
  content: TemplateContent;
  preview: {
    thumbnail: string;
    gallery: string[];
    demoUrl?: string;
  };
  
  // 统计
  stats: {
    downloads: number;
    rating: number;
    reviewCount: number;
  };
  
  // 版权
  license: {
    type: 'free' | 'premium' | 'custom';
    price?: number;
    terms: string;
    attribution: boolean;
    commercial: boolean;
    modification: boolean;
  };
  
  // 与 ECHO 集成
  echo: {
    rightTemplate?: string; // 权利模板ID
    suggestedAttribution: string;
  };
}
```

### 7.2 智能推荐系统

```typescript
// 模板推荐引擎
interface RecommendationEngine {
  // 推荐来源
  sources: {
    // 基于内容
    contentBased: {
      projectType: string;
      currentContent: string;
      similarTemplates: string[];
    };
    
    // 协同过滤
    collaborative: {
      usersLikeYou: string[];
      frequentlyUsedTogether: string[];
    };
    
    // 趋势
    trending: {
      popularNow: string[];
      risingStars: string[];
    };
    
    // AI 推荐
    ai: {
      basedOnGoals: string[];
      completeTheProject: string[]; // 补全项目
      nextStep: string[];
    };
  };
  
  // 推荐算法
  algorithm: {
    score: (template: Template, context: Context) => number;
    rank: (candidates: ScoredTemplate[]) => Template[];
    diversify: boolean; // 避免重复推荐
  };
}

// 推荐上下文
interface RecommendationContext {
  // 当前状态
  current: {
    project?: Project;
    document?: Document;
    team?: Team;
    user: User;
  };
  
  // 历史
  history: {
    usedTemplates: string[];
    viewedTemplates: string[];
    searchQueries: string[];
  };
  
  // 意图
  intent: {
    goal: string;
    stage: 'start' | 'progress' | 'finish' | 'publish';
    neededType: string;
  };
}
```

---

## 8. 沟通与反馈系统

### 8.1 内置沟通工具

```typescript
// 沟通系统
interface CommunicationSystem {
  // 异步沟通
  async: {
    comments: CommentSystem;
    mentions: MentionSystem;
    threads: ThreadSystem;
  };
  
  // 同步沟通
  sync: {
    chat: ChatSystem;
    audio: AudioChannel;
    video: VideoChannel;
    screen: ScreenShare;
  };
  
  // 通知
  notifications: NotificationSystem;
}

// 聊天系统
interface ChatSystem {
  // 聊天类型
  channels: {
    project: ProjectChat[];    // 项目级聊天
    document: DocumentChat[];    // 文档级聊天
    direct: DirectMessage[];   // 私信
    group: GroupChat[];        // 群聊
  };
  
  // 功能
  features: {
    richText: boolean;
    codeBlocks: boolean;
    fileSharing: boolean;
    voiceMessages: boolean;
    reactions: boolean;
    threads: boolean;
    pinMessage: boolean;
    search: boolean;
  };
  
  // 集成
  integrations: {
    linkPreviews: boolean;
    embedDocuments: boolean;
    commandShortcuts: string[]; // /remind, /poll, etc.
  };
}

// @提及系统
interface MentionSystem {
  // 提及类型
  types: {
    user: string;      // @username
    group: string;     // @team @everyone
    document: string;   // @doc:docId
    task: string;       // @task:taskId
    comment: string;    // @comment:commentId
    timestamp: string;  // @time:12:34
  };
  
  // 通知策略
  notify: {
    push: boolean;
    email: boolean;
    inApp: boolean;
    digest: 'immediate' | 'hourly' | 'daily';
  };
}
```

### 8.2 审阅与审批工作流

```typescript
// 审阅工作流
interface ReviewWorkflow {
  // 审阅类型
  types: {
    peerReview: WorkflowConfig;     // 同行评审
    approvalChain: WorkflowConfig;  // 审批链
    signOff: WorkflowConfig;        // 签字确认
    qaReview: WorkflowConfig;       // QA评审
  };
  
  // 工作流配置
  config: {
    stages: ReviewStage[];
    autoAdvance: boolean;
    reminders: boolean;
    escalation: boolean;
  };
}

interface ReviewStage {
  id: string;
  name: string;
  reviewers: string[]; // userIds
  
  // 规则
  rules: {
    minApprovals: number;
    mustInclude: string[]; // 必须通过的审核人
    anyOf: string[][];     // 任一即可
    
    // 时间限制
    deadline?: number; // hours
    autoRejectAfter?: number;
  };
  
  // 动作
  actions: {
    onApprove: WorkflowAction[];
    onReject: WorkflowAction[];
    onTimeout: WorkflowAction[];
  };
}

// 审批动作
interface WorkflowAction {
  type: 
    | 'notify'
    | 'move_to_stage'
    | 'update_status'
    | 'publish'
    | 'webhook'
    | 'create_task';
  config: object;
}
```

### 8.3 通知偏好系统

```typescript
// 通知系统
interface NotificationSystem {
  // 通知类型
  types: {
    // 项目相关
    project: ['invite', 'update', 'milestone', 'complete'];
    
    // 任务相关
    task: ['assigned', 'due_soon', 'overdue', 'completed', 'commented'];
    
    // 文档相关
    document: ['shared', 'mentioned', 'edited', 'commented', 'locked'];
    
    // 团队相关
    team: ['member_joined', 'member_left', 'role_changed'];
    
    // 系统
    system: ['maintenance', 'update', 'billing'];
  };
  
  // 通知渠道
  channels: {
    push: {
      enabled: boolean;
      quietHours: { start: string; end: string };
    };
    email: {
      enabled: boolean;
      frequency: 'immediate' | 'digest' | 'weekly';
      digestTime: string; // 摘要发送时间
    };
    inApp: {
      enabled: boolean;
      badge: boolean;
      sound: boolean;
    };
    mobile: {
      enabled: boolean;
      criticalOnly: boolean;
    };
  };
  
  // 智能通知
  smart: {
    priorityDetection: boolean; // 自动检测重要通知
    contextAware: boolean;      // 根据用户当前状态调整
    doNotDisturb: {
      calendarSync: boolean;
      focusMode: boolean;
      manual: boolean;
    };
  };
}
```

---

## 9. 云端工作空间

### 9.1 存储架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    云端存储架构                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                    存储层级                              │  │
│   ├─────────────────────────────────────────────────────────┤  │
│   │                                                         │  │
│   │   ┌──────────┐   ┌──────────┐   ┌──────────┐         │  │
│   │   │  热存储   │──▶│  温存储   │──▶│  冷存储   │         │  │
│   │   │ Hot      │   │ Warm     │   │ Cold     │         │  │
│   │   │ (SSD)    │   │ (HDD)    │   │ (Archive)│         │  │
│   │   └──────────┘   └──────────┘   └──────────┘         │  │
│   │        │              │              │                │  │
│   │   活跃项目       近期项目        归档项目              │  │
│   │   <7天访问      7-90天         >90天                 │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                    同步策略                                │  │
│   ├─────────────────────────────────────────────────────────┤  │
│   │                                                         │  │
│   │   本地 ──▶ 边缘节点 ──▶ 区域中心 ──▶ 全球存储          │  │
│   │   (Client)   (CDN)      (Region)      (Global)        │  │
│   │                                                         │  │
│   │   ├─ 实时同步: 文档内容                                  │  │
│   │   ├─ 快速同步: 项目元数据                                │  │
│   │   ├─ 后台同步: 大文件                                    │  │
│   │   └─ 按需加载: 历史版本                                  │  │
│   │                                                         │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 9.2 自动保存与备份

```typescript
// 保存系统
interface SaveSystem {
  // 自动保存策略
  autoSave: {
    interval: number;      // 默认 30 秒
    onBlur: boolean;       // 失去焦点时保存
    onIdle: boolean;       // 空闲时保存
    onNavigation: boolean;  // 导航前保存
  };
  
  // 版本快照
  snapshots: {
    frequency: 'edit' | 'time' | 'manual';
    keepCount: number;     // 保留版本数
    compression: boolean;
    
    // 智能快照
    smart: {
      onSignificantChange: boolean;
      onCheckpoint: boolean;
      beforeCollaborativeEdit: boolean;
    };
  };
  
  // 备份策略
  backup: {
    local: {
      enabled: boolean;
      maxSize: number; // MB
    };
    cloud: {
      enabled: boolean;
      regions: string[]; // 多区域备份
      encryption: boolean;
    };
    external: {
      providers: ('gdrive' | 'dropbox' | 'onedrive')[];
      frequency: 'realtime' | 'daily' | 'weekly';
    };
  };
}

// 恢复机制
interface RecoverySystem {
  // 恢复点
  checkpoints: {
    automatic: Snapshot[];
    manual: Snapshot[];
    system: Snapshot[]; // 系统维护前自动创建
  };
  
  // 恢复选项
  restore: {
    fullRestore: (checkpointId: string) => Promise<void>;
    partialRestore: (checkpointId: string, paths: string[]) => Promise<void>;
    compareAndSelect: (checkpoints: string[]) => Promise<MergeResult>;
  };
  
  // 灾难恢复
  disasterRecovery: {
    rpo: number; // 恢复点目标 (分钟)
    rto: number; // 恢复时间目标 (分钟)
    lastBackup: Date;
    backupIntegrity: boolean;
  };
}
```

### 9.3 本地缓存策略

```typescript
// 缓存系统
interface CacheSystem {
  // 缓存类型
  types: {
    // 内存缓存
    memory: {
      maxSize: number; // MB
      ttl: number;     // seconds
      lru: boolean;
    };
    
    // 磁盘缓存
    disk: {
      maxSize: number; // MB
      location: string;
      compression: boolean;
    };
    
    // 浏览器缓存
    browser: {
      serviceWorker: boolean;
      cacheApi: boolean;
      indexedDB: boolean;
    };
  };
  
  // 缓存策略
  strategy: {
    // 预加载
    prefetch: {
      currentProject: 'all' | 'recent' | 'essential';
      nextLikely: boolean; // 预测下一个可能打开的内容
    };
    
    // 保留策略
    retention: {
      pinned: string[];           // 始终保留
      recent: { count: number; }; // 最近访问
      frequency: { minAccesses: number; }; // 访问频率
    };
    
    // 清理策略
    eviction: {
      onLowStorage: 'lru' | 'lfu' | 'size';
      onAppClose: boolean;
      periodicCleanup: boolean;
    };
  };
}

// 离线支持
interface OfflineSupport {
  // 离线模式
  mode: 'readonly' | 'limited' | 'full';
  
  // 离线能力
  capabilities: {
    edit: boolean;
    create: boolean;
    delete: boolean;
    comment: boolean;
    search: boolean; // 本地索引
  };
  
  // 同步队列
  syncQueue: {
    maxSize: number;
    priority: ('content' | 'metadata' | 'comment')[
    compression: boolean;
    conflictResolution: ConflictStrategy;
  };
}
```

### 9.4 大文件传输优化

```typescript
// 大文件传输
interface LargeFileTransfer {
  // 分块上传
  chunkedUpload: {
    chunkSize: number; // MB
    concurrency: number; // 并行块数
    retryAttempts: number;
    checksum: 'md5' | 'sha256';
  };
  
  // 断点续传
  resume: {
    enabled: boolean;
    expiration: number; // 未完成上传过期时间
    autoResume: boolean;
  };
  
  // 传输优化
  optimization: {
    compression: boolean;
    deltaTransfer: boolean; // 仅传输差异
    p2pTransfer: boolean;   // 团队内 P2P
    cdnAcceleration: boolean;
  };
  
  // 进度与恢复
  progress: {
    reporting: 'percentage' | 'bytes' | 'detailed';
    speedLimit?: number; // KB/s
    pauseResume: boolean;
  };
}

// 文件传输 UI
interface TransferUI {
  // 传输列表
  transfers: {
    active: Transfer[];
    queued: Transfer[];
    completed: Transfer[];
    failed: Transfer[];
  };
  
  // 操作
  actions: {
    pause: (transferId: string) => void;
    resume: (transferId: string) => void;
    cancel: (transferId: string) => void;
    retry: (transferId: string) => void;
    prioritize: (transferId: string) => void;
  };
}
```

---

## 10. 用户界面设计

### 10.1 设计原则

```
┌─────────────────────────────────────────────────────────────────┐
│                    ECHO 协作工具 UI 设计原则                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 上下文感知                                                   │
│     - 界面根据当前任务自动调整                                    │
│     - 智能显示相关工具和协作成员                                  │
│     - 减少不必要的导航和切换                                      │
│                                                                 │
│  2. 渐进式揭示                                                   │
│     - 基础功能始终可见                                            │
│     - 高级功能按需展开                                            │
│     - 避免一次性展示过多选项                                      │
│                                                                 │
│  3. 协作可视化                                                   │
│     - 谁在编辑一目了然                                            │
│     - 实时变更即时反馈                                            │
│     - 冲突优雅呈现，易于解决                                      │
│                                                                 │
│  4. 专注模式                                                     │
│     - 一键进入无干扰创作                                          │
│     - 智能折叠无关内容                                            │
│     - 支持分屏对比编辑                                            │
│                                                                 │
│  5. 尊重创作者                                                   │
│     - 不中断创作的流畅体验                                        │
│     - 保存状态始终可见                                            │
│     - 所有权和贡献清晰可辨                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 核心界面布局

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ECHO Logo  │  项目导航  │  搜索      │  通知  │  团队  │  头像           │
├─────────────┴───────────┴────────────┴────────┴────────┴─────────────────┤
│                                                                             │
│  ┌──────────┐  ┌──────────────────────────────────────────────────────┐  │
│  │          │  │                                      │  协作栏       │  │
│  │  项目    │  │                                      ├───────────────┤  │
│  │  导航    │  │                                      │ • 在线成员    │  │
│  │          │  │         主编辑区域                    │ • 活动状态    │  │
│  │  📁 文件 │  │                                      │ • 评论面板    │  │
│  │  📋 任务 │  │                                      │ • 历史版本    │  │
│  │  📊 看板 │  │                                      │ • 分享        │  │
│  │  📅 日历 │  │                                      │               │  │
│  │  ⚙️ 设置 │  │                                      │               │  │
│  │          │  │                                      │               │  │
│  ├──────────┤  │                                      │               │  │
│  │  快捷    │  │                                      │               │  │
│  │  操作    │  │                                      │               │  │
│  │          │  │                                      │               │  │
│  │ [+ 新建] │  │                                      │               │  │
│  │ [⌘ K]    │  │                                      │               │  │
│  │          │  │                                      │               │  │
│  └──────────┘  └──────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  状态栏: 最后保存 2秒前 │  同步中... │  贡献者: 3人 │  存储: 45%   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.3 协作状态可视化

```typescript
// 协作状态 UI 组件
interface CollaborationUI {
  // 顶部协作栏
  header: {
    // 在线成员头像
    presence: {
      showAvatar: boolean;
      showStatus: boolean;
      maxVisible: number;
      overflow: 'dropdown' | 'scroll';
    };
    
    // 共享按钮
    share: {
      visibility: 'private' | 'team' | 'link' | 'public';
      copyLink: boolean;
      inviteDialog: boolean;
    };
    
    // 关注按钮
    follow: {
      following: string | null; // 正在跟随的用户
      followMe: boolean; // 邀请他人跟随
    };
  };
  
  // 实时指示器
  indicators: {
    // 同步状态
    sync: {
      states: ['saved', 'saving', 'syncing', 'offline', 'conflict'];
      position: 'toolbar' | 'statusbar' | 'floating';
    };
    
    // 变更提示
    changes: {
      showToast: boolean;
      showBadge: boolean;
      playSound: boolean;
    };
    
    // 冲突警告
    conflict: {
      banner: boolean;
      inline: boolean;
      modal: boolean;
    };
  };
  
  // 光标渲染
  cursors: {
    style: 'flag' | 'line' | 'block';
    showName: boolean;
    smoothAnimation: boolean;
    hideDelay: number;
  };
}
```

### 10.4 响应式与多端适配

```typescript
// 响应式布局配置
interface ResponsiveConfig {
  // 断点
  breakpoints: {
    mobile: 768;
    tablet: 1024;
    desktop: 1440;
    wide: 1920;
  };
  
  // 布局模式
  layouts: {
    mobile: {
      sidebar: 'drawer' | 'hidden';
      toolbar: 'floating' | 'bottom';
      panels: 'sheet' | 'fullscreen';
      navigation: 'bottom' | 'hidden';
    };
    tablet: {
      sidebar: 'collapsed' | 'drawer';
      toolbar: 'fixed';
      panels: 'split' | 'overlay';
      navigation: 'sidebar';
    };
    desktop: {
      sidebar: 'expanded';
      toolbar: 'fixed';
      panels: 'split';
      navigation: 'sidebar';
    };
  };
  
  // 触控优化
  touch: {
    gestureNavigation: boolean;
    pullToRefresh: boolean;
    pinchToZoom: boolean;
    longPressMenu: boolean;
    hapticFeedback: boolean;
  };
}
```

---

## 11. 与 ECHO 权利的深度集成

### 11.1 协作创作的权益追踪

```typescript
// 贡献追踪系统
interface ContributionTracking {
  // 自动追踪维度
  autoTrack: {
    // 时间投入
    time: {
      activeEditing: number; // 活跃编辑时间
      presence: number;      // 在线时间
      review: number;        // 审阅时间
    };
    
    // 内容产出
    content: {
      additions: number;     // 新增内容
      deletions: number;     // 删除内容
      modifications: number;   // 修改次数
      comments: number;      // 评论数
    };
    
    // 质量指标
    quality: {
      acceptedEdits: number;
      rejectedEdits: number;
      praiseReceived: number;
      issuesResolved: number;
    };
  };
  
  // 权益分配建议
  distribution: {
    // 基于活动的权重计算
    calculateWeight: (contributions: Contribution[]) => number;
    
    // 智能建议
    suggestions: {
      basedOn: 'activity' | 'agreement' | 'expertise' | 'reputation';
      confidence: number;
      reasoning: string[];
    };
    
    // 协商工具
    negotiation: {
      proposal: (proposedShares: Map<string, number>) => void;
      vote: () => VoteResult;
      lock: () => void; // 锁定分配
    };
  };
}
```

### 11.2 作品归属链

```typescript
// 归属链系统
interface AttributionChain {
  // 作品节点
  nodes: {
    workId: string;
    version: string;
    type: 'original' | 'remix' | 'collaboration' | 'derivative';
    
    // 创作者
    creators: {
      userId: string;
      role: string;
      contribution: number; // 百分比
      rightId: string;
    }[];
    
    // 父作品
    parents: string[];
    
    // 子作品（衍生）
    children: string[];
    
    // 使用素材
    assets: {
      assetId: string;
      source: 'internal' | 'external' | 'marketplace';
      license: string;
      attribution: string;
    }[];
  }[];
  
  // 可视化
  visualization: {
    tree: 'vertical' | 'horizontal' | 'radial';
    details: 'compact' | 'full';
    filter: 'all' | 'direct' | 'upstream' | 'downstream';
  };
}
```

### 11.3 协作协议与智能合约

```typescript
// 协作协议模板
interface CollaborationAgreement {
  // 协议类型
  type: 
    | 'equal_partnership'      // 平等合伙
    | 'lead_contributor'       // 主导贡献
    | 'work_for_hire'          // 雇佣工作
    | 'revenue_share'          // 收益分成
    | 'custom';
  
  // 权利条款
  terms: {
    // 所有权
    ownership: {
      structure: 'joint' | 'split' | 'assigned';
      splits?: Map<string, number>;
      licensing: 'exclusive' | 'non-exclusive' | 'creative-commons';
    };
    
    // 收益分配
    revenue: {
      model: 'percentage' | 'fixed' | 'hybrid';
      splits: Map<string, number>;
      platformFee: number;
      distribution: 'immediate' | 'threshold' | 'schedule';
    };
    
    // 决策机制
    governance: {
      type: 'unanimous' | 'majority' | 'lead_decides' | 'voting';
      votingWeights?: Map<string, number>;
    };
    
    // 退出机制
    exit: {
      noticePeriod: number; // days
      buyoutOption: boolean;
      valuationMethod: 'last_sale' | 'appraisal' | 'agreed';
    };
  };
  
  // 智能合约绑定
  smartContract: {
    network: 'ethereum' | 'polygon' | 'solana' | 'echo_chain';
    contractAddress: string;
    abi: object;
    
    // 自动执行
    automation: {
      revenueSplit: boolean;
      royaltyDistribution: boolean;
      votingExecution: boolean;
    };
  };
}
```

---

## 12. 技术实现路线图

### 12.1 阶段规划

| 阶段 | 时间 | 核心功能 | 技术重点 |
|------|------|---------|---------|
| **MVP** | 2-3月 | 基础协作编辑、简单项目管理、团队邀请 | Yjs CRDT、WebSocket、基础权限 |
| **V1** | 4-6月 | 完整项目管理、看板/甘特图、评论系统 | 甘特图引擎、通知系统、历史版本 |
| **V2** | 7-9月 | 模板市场、高级权限、审批工作流 | 模板引擎、工作流引擎、推荐系统 |
| **V3** | 10-12月 | 实时音视频、AI辅助、智能合约集成 | WebRTC、AI服务、区块链集成 |

### 12.2 关键技术决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 协作引擎 | Yjs + 自研 OT | 成熟稳定 + 灵活定制 |
| 实时传输 | WebSocket + WebRTC | 可靠 + P2P优化 |
| 存储 | PostgreSQL + S3 + Redis | 关系数据 + 文件 + 缓存 |
| 前端框架 | React + TypeScript | 生态成熟 + 类型安全 |
| 移动端 | React Native + WebView | 跨平台 + 快速迭代 |

---

## 13. 安全与隐私设计

### 13.1 数据安全

```typescript
// 安全架构
interface SecurityArchitecture {
  // 传输安全
  transport: {
    encryption: 'TLS1.3';
    certificatePinning: boolean;
    websocketSecure: true;
  };
  
  // 存储安全
  storage: {
    atRest: 'AES-256-GCM';
    keyManagement: 'HSM' | 'KMS';
    fieldLevelEncryption: string[]; // 敏感字段
  };
  
  // 访问控制
  access: {
    authentication: 'SSO' | 'OAuth2' | 'MFA';
    authorization: 'RBAC' | 'ABAC';
    audit: {
      enabled: true;
      retention: '1year';
      tamperProof: true;
    };
  };
}
```

### 13.2 隐私保护

- **最小权限原则**：只收集协作必需的数据
- **数据本地化**：用户可选择数据存储区域
- **导出与删除**：一键导出/删除所有个人数据
- **匿名协作**：支持匿名贡献（权益仍可通过密钥证明）

---

## 附录：术语表

| 术语 | 定义 |
|------|------|
| CRDT | Conflict-free Replicated Data Type，无冲突复制数据类型 |
| OT | Operational Transformation，操作转换 |
| WIP | Work In Progress，进行中 |
| ACL | Access Control List，访问控制列表 |
| RBAC | Role-Based Access Control，基于角色的访问控制 |
| P2P | Peer-to-Peer，点对点 |
| CDN | Content Delivery Network，内容分发网络 |
| RPO/RTO | Recovery Point/Time Objective，恢复点/时间目标 |

---

*设计版本: 1.0*  
*最后更新: 2026-04-18*  
*设计师: ECHO 协作工具设计组*
