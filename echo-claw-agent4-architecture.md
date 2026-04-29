# ECHO Claw - 核心架构设计

**版本**: v1.0 | **日期**: 2026-04-21 | **状态**: 详细设计

---

## 一、定位与设计理念

### 1.1 ECHO Claw 是什么

ECHO Claw = **ECHO 原生分布式网络内的 "OpenClaw"**

它不是替代 OpenClaw，而是在 ECHO 网络内提供深度协议集成的 Agent 基础设施：

```
OpenClaw（通用层）              ECHO Claw（专用层）
    │                              │
    │ • 通用 Skill 调用            │ • ECHO 资产调用
    │ • 本地工具为主              │ • 分布式网络调用
    │ • 手动配置收益              │ • 自动四权分润
    │ • 无内置验证                │ • PoU 验证原生
    │ • 中心化发现                │ • ShiGraph 驱动发现
    │                             │
    └──────────────┬─────────────┘
                   │
              ┌────▼────┐
              │  共存   │
              │         │
              │ ECHO Claw│
              │ 作为    │
              │ OpenClaw│
              │ Skill   │
              │ 集群    │
              └─────────┘
```

### 1.2 与 OpenClaw 的关系

```
┌─────────────────────────────────────────────┐
│              OpenClaw 生态                  │
│                                             │
│  ┌─────────┐ ┌─────────┐ ┌─────────────┐  │
│  │ 本地工具 │ │ 远程API │ │ ECHO Claw   │  │
│  │         │ │         │ │ (Skill集群) │  │
│  └─────────┘ └─────────┘ └─────────────┘  │
│                              │              │
└──────────────────────────────┼──────────────┘
                               │
                      ┌────────▼────────┐
                      │   ECHO 网络      │
                      │  (分布式协议层)  │
                      └──────────────────┘
```

ECHO Claw 既可以作为 OpenClaw 生态中的一个 Skill 集群被调用，也可以独立部署作为 ECHO 网络的入口节点。

---

## 二、整体架构

### 2.1 架构全景

```
┌─────────────────────────────────────────────────────────────────┐
│                      用户接口层                                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ CLI      │ │ Web UI   │ │ API      │ │ 自然语言 │          │
│  │ echo-claw│ │ Dashboard│ │ REST     │ │ Agent聊天│          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Agent Hub（编排与调度）                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐          │
│  │ 意图理解      │ │ 任务分解      │ │ 执行编排      │          │
│  │ Intent       │ │ Task Graph   │ │ Orchestrator │          │
│  │ Parser       │ │ Builder      │ │              │          │
│  └──────────────┘ └──────────────┘ └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  四权调用引擎（Rights Engine）                    │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐          │
│  │ 权限校验      │ │ 费用计算      │ │ 收益分配      │          │
│  │ ACL Check    │ │ Cost Engine  │ │ Revenue Split│          │
│  └──────────────┘ └──────────────┘ └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    沙箱执行网络（Sandbox Mesh）                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ 调度器    │ │ 负载均衡  │ │ 故障转移  │ │ ZKP收集   │          │
│  │ Scheduler│ │ LB       │ │ Failover │ │ Collector│          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ECHO 网络层（分布式协议）                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ PoU验证   │ │ 链上结算  │ │ ShiGraph │ │ 状态锚定  │          │
│  │ Validators│ │ Settlement│ │ Engine   │ │ Anchor   │          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 核心组件

| 组件 | 职责 | 部署位置 |
|------|------|---------|
| **Gateway** | 请求入口、认证、路由 | 每个节点 |
| **Agent Hub** | 意图理解、任务编排 | 每个节点 |
| **Rights Engine** | 四权校验、费用计算 | 每个节点 |
| **Skill Registry** | Skill元数据缓存、ShiGraph查询 | 每个节点 |
| **Sandbox Mesh** | 沙箱调度、执行 | 分布式 |
| **Event Bus** | 事件收集、转发 | 每个节点 |
| **State Manager** | 本地状态、缓存 | 每个节点 |

---

## 三、节点类型设计

### 3.1 五类节点

```
┌─────────────────────────────────────────────────────────────────┐
│                      ECHO Claw 网络拓扑                         │
│                                                                 │
│   ┌─────────┐      ┌─────────┐      ┌─────────┐                │
│   │ User    │◄────►│ User    │◄────►│ User    │                │
│   │ Agent 1 │      │ Agent 2 │      │ Agent 3 │                │
│   └────┬────┘      └────┬────┘      └────┬────┘                │
│        │                │                │                     │
│        └────────────────┼────────────────┘                     │
│                         │                                      │
│                    ┌────▼────┐                                 │
│                    │  DHT   │  分布式哈希表                     │
│                    │ Router │  Skill发现路由                    │
│                    └────┬────┘                                 │
│                         │                                      │
│        ┌────────────────┼────────────────┐                     │
│        │                │                │                     │
│   ┌────▼────┐     ┌────▼────┐     ┌────▼────┐               │
│   │ Sandbox │     │ Sandbox │     │ Sandbox │               │
│   │ Node 1  │     │ Node 2  │     │ Node 3  │               │
│   └─────────┘     └─────────┘     └─────────┘               │
│                                                                 │
│   ┌─────────┐     ┌─────────┐     ┌─────────┐               │
│   │ Validator│     │ Validator│     │ Discovery│               │
│   │ Node 1  │     │ Node 2  │     │ Node 1  │               │
│   └─────────┘     └─────────┘     └─────────┘               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 用户节点（User Agent）

```typescript
interface UserNode {
  // 身份
  user_id: string;
  public_key: string;
  
  // 本地资产
  owned_skills: string[];          // 拥有的Skill列表
  auth_credentials: AuthCredential[];  // 授权凭证
  
  // 调用能力
  async callSkill(request: SkillRequest): Promise<SkillResponse>;
  async discoverSkills(query: DiscoveryQuery): Promise<Skill[]>;
  async orchestrate(intent: string): Promise<OrchestrationResult>;
  
  // 收益管理
  async getRevenue(): Promise<RevenueReport>;
  async withdraw(amount: number): Promise<WithdrawalResult>;
  
  // 网络参与
  async routeRequest(request: any): Promise<any>;  // 转发请求
  async cacheSkillMetadata(skill: Skill): Promise<void>;  // 缓存
}
```

### 3.3 沙箱节点（Sandbox Agent）

```typescript
interface SandboxNode {
  // 身份
  sandbox_id: string;
  type: "wasm" | "container" | "baremetal" | "external";
  region: string;
  capabilities: SandboxCapabilities;
  
  // 部署的Skill
  deployed_skills: Map<string, Deployment>;
  
  // 执行
  async execute(request: ExecutionRequest): Promise<ExecutionResult>;
  async healthCheck(): Promise<HealthStatus>;
  
  // 资源
  resources: {
    cpu_cores: number;
    memory_gb: number;
    storage_gb: number;
    network_bandwidth_mbps: number;
  };
  
  // 计量
  async meterUsage(execution: ExecutionResult): Promise<UsageMetrics>;
  async generateProof(execution: ExecutionResult): Promise<ZKPProof>;
}
```

### 3.4 验证节点（Validator）

```typescript
interface ValidatorNode {
  // 身份
  validator_id: string;
  public_key: string;
  
  // 质押
  stake: {
    amount: number;
    locked_until: number;
  };
  
  // 验证能力
  capabilities: {
    zkp_frameworks: string[];
    max_throughput: number;
  };
  
  // 验证
  async verifyPoU(pou: ProofOfUse): Promise<VerificationResult>;
  async vote(dispute: Dispute): Promise<Vote>;
  
  // 统计
  stats: {
    total_verified: number;
    accuracy_rate: number;
    reputation_score: number;
  };
}
```

### 3.5 发现节点（Discovery）

```typescript
interface DiscoveryNode {
  // ShiGraph维护
  async getShiState(assetId: string): Promise<ShiState>;
  async queryShiGraph(query: ShiQuery): Promise<ShiResult>;
  async getTrending(hexagram?: string): Promise<Skill[]>;
  
  // 关系网络
  async getRelatedSkills(skillId: string): Promise<Skill[]>;
  async getDerivationTree(skillId: string): Promise<Tree>;
  
  // 搜索
  async search(query: string, filters: SearchFilters): Promise<Skill[]>;
  async semanticSearch(vector: number[]): Promise<Skill[]>;
  
  // 索引
  async indexSkill(skill: Skill): Promise<void>;
  async updateShiState(assetId: string, state: ShiState): Promise<void>;
}
```

### 3.6 索引节点（Indexer）

```typescript
interface IndexerNode {
  // 索引数据
  skill_index: SearchIndex;
  creator_index: SearchIndex;
  tag_index: InvertedIndex;
  
  // 批量处理
  async indexBatch(events: EchoEvent[]): Promise<void>;
  async rebuildIndex(): Promise<void>;
  
  // 查询
  async query(query: IndexQuery): Promise<IndexResult>;
  
  // 同步
  async syncWithChain(): Promise<void>;
}
```

---

## 四、通信协议

### 4.1 协议栈

```
应用层
├── ECHO Protocol（消息格式、路由、发现）
├── Agent Orchestration Protocol（任务编排、事务）
└── Rights Verification Protocol（四权校验、收益分配）

传输层
├── gRPC over QUIC（主要，低延迟）
├── libp2p（P2P发现、NAT穿透）
└── WebSocket（浏览器客户端）

安全层
├── Noise Protocol（密钥交换）
├── Ed25519（签名）
└── TLS 1.3（传输加密）
```

### 4.2 消息格式

```protobuf
// echo.proto
syntax = "proto3";
package echo;

// 基础消息
message EchoMessage {
  string message_id = 1;
  string source_node = 2;
  string target_node = 3;
  MessageType type = 4;
  bytes payload = 5;
  int64 timestamp = 6;
  bytes signature = 7;
}

enum MessageType {
  SKILL_CALL = 0;
  SKILL_RESPONSE = 1;
  SKILL_DISCOVER = 2;
  POU_SUBMIT = 3;
  POU_VERIFY = 4;
  SHI_QUERY = 5;
  SHI_UPDATE = 6;
  REVENUE_SETTLE = 7;
  DISPUTE_CREATE = 8;
  DISPUTE_VOTE = 9;
  NODE_HEARTBEAT = 10;
}

// Skill调用请求
message SkillCallRequest {
  string request_id = 1;
  string skill_id = 2;
  string blueprint_version = 3;
  bytes params = 4;              // JSON序列化
  string user_id = 5;
  string auth_token = 6;
  bytes context = 7;             // 调用上下文
}

// Skill调用响应
message SkillCallResponse {
  string request_id = 1;
  string skill_id = 2;
  Status status = 3;
  bytes data = 4;
  bytes error = 5;
  UsageMetrics usage = 6;
  bytes proof = 7;
}

enum Status {
  SUCCESS = 0;
  ERROR = 1;
  TIMEOUT = 2;
  DENIED = 3;
  STREAMING = 4;
}

message UsageMetrics {
  int64 duration_ms = 1;
  int64 compute_units = 2;
  int64 memory_mb = 3;
  int64 tokens_in = 4;
  int64 tokens_out = 5;
}
```

### 4.3 发现协议

```typescript
// 本地发现（局域网内）
class LocalDiscovery {
  async discover(): Promise<Node[]> {
    // 使用mDNS广播
    const nodes = await mdns.query("_echo._tcp.local");
    return nodes.map(n => ({
      id: n.txt.node_id,
      address: n.address,
      port: n.port,
      type: n.txt.node_type,
      capabilities: JSON.parse(n.txt.capabilities)
    }));
  }
}

// 全局发现（DHT）
class GlobalDiscovery {
  dht: libp2p.DHT;
  
  async findSkill(skillId: string): Promise<Node[]> {
    // 在DHT中查询Skill位置
    const providers = await this.dht.findProviders(
      CID.create(skillId),
      { limit: 3 }
    );
    
    return providers.map(p => ({
      id: p.id,
      addresses: p.addrs,
      latency: await this.ping(p)
    }));
  }
  
  async registerSkill(skillId: string): Promise<void> {
    // 将自己注册为该Skill的提供者
    await this.dht.provide(CID.create(skillId));
  }
}
```

### 4.4 安全传输

```typescript
class SecureChannel {
  // Noise Protocol XX模式（双方匿名，双向认证）
  
  async establishConnection(peer: Node): Promise<SecureConnection> {
    // 1. 密钥交换
    const handshake = new NoiseXXHandshake();
    
    // 2. 发送ephemeral公钥
    const ephemeralKey = generateX25519KeyPair();
    await this.send(peer, { e: ephemeralKey.public });
    
    // 3. 接收对方ephemeral公钥
    const theirEphemeral = await this.receive(peer);
    
    // 4. 发送静态公钥 + 签名
    const staticKey = this.keyPair;
    const signature = sign(
      concat(ephemeralKey.public, theirEphemeral.e),
      staticKey.private
    );
    await this.send(peer, {
      s: staticKey.public,
      sig: signature
    });
    
    // 5. 接收对方静态公钥 + 签名
    const theirStatic = await this.receive(peer);
    
    // 6. 验证签名
    const isValid = verify(
      concat(theirEphemeral.e, ephemeralKey.public),
      theirStatic.sig,
      theirStatic.s
    );
    if (!isValid) throw new Error("INVALID_SIGNATURE");
    
    // 7. 派生会话密钥
    const sharedSecret = deriveSharedSecret(
      ephemeralKey.private,
      theirEphemeral.e,
      staticKey.private,
      theirStatic.s
    );
    
    return {
      encrypt: (data) => encrypt(data, sharedSecret),
      decrypt: (data) => decrypt(data, sharedSecret),
      peerIdentity: theirStatic.s
    };
  }
}
```

---

## 五、echo-claw CLI设计

### 5.1 命令结构

```bash
# ========== 初始化 ==========
echo-claw init
  --name              节点名称
  --type              节点类型 (user|sandbox|validator|discovery|indexer)
  --network           网络 (testnet|mainnet|local)

# ========== 节点管理 ==========
echo-claw start         # 启动节点
echo-claw stop          # 停止节点
echo-claw status        # 查看节点状态
echo-claw logs          # 查看日志
echo-claw config        # 编辑配置

# ========== Skill调用 ==========
echo-claw call <skill-id> [params]
  --params, -p          调用参数（JSON或文件）
  --async               异步调用
  --stream              流式输出
  --timeout             超时时间

echo-claw batch <skills-file>
  # 批量调用多个Skill

echo-claw simulate <skill-id>
  # 本地模拟调用（不消耗ECHO）

# ========== Skill发现 ==========
echo-claw discover
  --query, -q           搜索关键词
  --tag, -t             标签过滤
  --hexagram, -x        卦象过滤
  --stage, -s           生命周期阶段
  --price-max           最高价格
  --sort                排序方式

echo-claw trending      # 查看趋势Skill
echo-claw related <skill-id>  # 查看相关Skill

# ========== 资产管理 ==========
echo-claw assets
  --owned               我拥有的Skill
  --authorized          我有权使用的Skill
  --revenue             收益详情

echo-claw balance       # 查看ECHO余额
echo-claw deposit       # 充值
echo-claw withdraw      # 提现

# ========== 编排 ==========
echo-claw run <intent>
  # 自然语言意图 → 自动编排
  例: echo-claw run "写一首关于春天的诗，翻译成英文，然后朗读"

echo-claw orchestrate <orchestration-file>
  # 执行预定义的编排文件

# ========== 监控 ==========
echo-claw monitor
  --skill <id>          监控特定Skill
  --network             监控网络状态
  --revenue             监控收益

echo-claw history
  --calls               调用历史
  --revenue             收益历史

# ========== 治理 ==========
echo-claw vote <proposal-id>  # 投票
echo-claw propose             # 创建提案
echo-claw disputes            # 查看争议
```

### 5.2 配置文件

```yaml
# echo-claw.yaml - ECHO Claw 节点配置

node:
  name: "my-echo-node"
  type: "user"                    # user | sandbox | validator | discovery | indexer
  
  # 身份
  identity:
    private_key_path: "~/.echo/keys/node.key"
    public_key_path: "~/.echo/keys/node.pub"
    
  # 网络
  network:
    mode: "p2p"                   # p2p | client-server | hybrid
    bootstrap_peers:
      - "/dns4/bootstrap.echo.network/tcp/443"
    listen_addresses:
      - "/ip4/0.0.0.0/tcp/0"
    
  # 功能
  capabilities:
    user:
      max_concurrent_calls: 10
      cache_skills: true
      auto_discover: true
      
    sandbox:
      type: "wasm"
      max_concurrent_executions: 100
      resources:
        memory_limit: "4GB"
        cpu_limit: "4 cores"
        
    validator:
      zkp_frameworks: ["risc0", "sp1"]
      max_throughput: 1000
      
    discovery:
      index_update_interval: "1h"
      shi_recompute_interval: "1h"
      
    indexer:
      batch_size: 1000
      rebuild_interval: "24h"

  # 存储
  storage:
    path: "~/.echo/data"
    max_size: "10GB"
    
  # 缓存
  cache:
    skill_metadata_ttl: "1h"
    shi_state_ttl: "1h"
    auth_credentials_ttl: "24h"
    
  # ECHO网络连接
  echo_network:
    rpc_endpoint: "https://rpc.echo.network"
    chain_id: "echo-mainnet"
    
  # 日志
  logging:
    level: "info"                 # debug | info | warn | error
    format: "json"
    output: "stdout"
    file: "~/.echo/logs/node.log"
    
  # 监控
  metrics:
    enabled: true
    prometheus_port: 9090
```

### 5.3 与 OpenClaw CLI 的兼容性

```bash
# OpenClaw 调用 ECHO Skill（通过适配器）
openclaw skill call echo://skill_poet_alice
  --param theme="春天"
  --param style="盛唐"

# ECHO Claw 调用 OpenClaw 本地 Skill（通过桥接）
echo-claw call local://filesystem/read_file
  --param path="./data.txt"
```

---

## 六、状态管理

### 6.1 本地状态

```typescript
interface NodeState {
  // 已授权Skill列表
  authorized_skills: Map<string, AuthCredential>;
  
  // 调用历史
  call_history: CallRecord[];
  
  // 收益记录
  revenue_records: RevenueRecord[];
  
  // 网络状态
  known_peers: Map<string, PeerInfo>;
  
  // ShiGraph缓存
  shi_cache: Map<string, ShiState>;
  
  // Skill元数据缓存
  skill_metadata_cache: Map<string, SkillMetadata>;
}

interface AuthCredential {
  asset_id: string;
  blueprint_version: string;
  rights_snapshot: BlueprintSnapshot;
  quota: QuotaInfo;
  issued_at: number;
  expires_at: number;
  signature: string;
}
```

### 6.2 缓存策略

```typescript
class TieredStateCache {
  // L1: 内存缓存（最快，最不稳定）
  l1: LRUCache<string, any>;
  
  // L2: 本地文件（持久化，重启保留）
  l2: JSONFileStore;
  
  // L3: 网络同步（与ECHO网络保持一致）
  l3: ECHONetworkClient;
  
  async get(key: string): Promise<any> {
    // 1. 查L1
    const l1Value = this.l1.get(key);
    if (l1Value) return l1Value;
    
    // 2. 查L2
    const l2Value = await this.l2.read(key);
    if (l2Value) {
      this.l1.set(key, l2Value);
      return l2Value;
    }
    
    // 3. 查L3（网络）
    const l3Value = await this.l3.query(key);
    if (l3Value) {
      this.l2.write(key, l3Value);
      this.l1.set(key, l3Value);
      return l3Value;
    }
    
    return null;
  }
  
  // 批量同步
  async syncWithNetwork(): Promise<void> {
    // 1. 获取需要同步的keys
    const staleKeys = this.l1.getStaleKeys();
    
    // 2. 批量查询网络
    const updates = await this.l3.batchQuery(staleKeys);
    
    // 3. 更新缓存
    for (const [key, value] of updates) {
      this.l1.set(key, value);
      this.l2.write(key, value);
    }
  }
}
```

### 6.3 状态同步

```typescript
class StateAnchor {
  // 批量锚定到链上
  async anchorBatch(events: EchoEvent[]): Promise<AnchorResult> {
    // 1. 构建Merkle树
    const leaves = events.map(e => hash(e));
    const tree = buildMerkleTree(leaves);
    
    // 2. 提交Merkle根到链上
    const txHash = await this.chain.submit({
      type: "state_anchor",
      merkle_root: tree.root,
      event_count: events.length,
      timestamp: Date.now()
    });
    
    // 3. 存储证明
    return {
      tx_hash: txHash,
      merkle_root: tree.root,
      events: events.map((e, i) => ({
        event: e,
        proof: tree.getProof(i)
      }))
    };
  }
}
```

---

## 七、容错与高可用

### 7.1 多沙箱故障转移

```typescript
class FailoverManager {
  async callWithFailover(request: SkillRequest): Promise<SkillResponse> {
    // 1. 获取该Skill的所有可用沙箱
    const sandboxes = await this.discovery.findSandboxes(request.skill_id);
    
    // 2. 按延迟排序
    const sorted = sandboxes.sort((a, b) => a.latency - b.latency);
    
    // 3. 逐个尝试
    for (const sandbox of sorted) {
      try {
        const result = await this.callSandbox(request, sandbox);
        return result;
      } catch (error) {
        if (error.code === "TIMEOUT" || error.code === "UNAVAILABLE") {
          // 记录故障
          this.recordFailure(sandbox.id);
          continue;
        }
        throw error;  // 非网络错误，直接抛出
      }
    }
    
    throw new Error("ALL_SANDBOXES_UNAVAILABLE");
  }
}
```

### 7.2 网络分区处理

```typescript
class PartitionHandler {
  // 检测到网络分区时
  async handlePartition(): Promise<void> {
    // 1. 降级为本地模式
    this.mode = "partitioned";
    
    // 2. 使用本地缓存的授权凭证继续服务
    const localAuths = this.state.getLocalAuths();
    
    // 3. 限制功能
    this.disableFeatures([
      "new_authorizations",
      "revenue_withdrawal",
      "skill_registration"
    ]);
    
    // 4. 记录事件，等待网络恢复后同步
    this.bufferEvents();
    
    // 5. 定期检查网络恢复
    this.startRecoveryCheck();
  }
  
  async recover(): Promise<void> {
    // 1. 同步离线期间的事件
    await this.syncBufferedEvents();
    
    // 2. 刷新缓存
    await this.stateCache.syncWithNetwork();
    
    // 3. 恢复全功能
    this.mode = "normal";
  }
}
```

### 7.3 降级策略

```typescript
class DegradationManager {
  // 优雅降级阶梯
  levels = [
    {
      name: "normal",
      features: ["all"]
    },
    {
      name: "reduced_discovery",
      features: ["call", "local_cache"],
      disabled: ["shigraph_query", "trending"]
    },
    {
      name: "local_only",
      features: ["local_skills"],
      disabled: ["network_calls", "revenue_sync"]
    },
    {
      name: "emergency",
      features: ["read_only"],
      disabled: ["all_write"]
    }
  ];
  
  async degrade(level: string): Promise<void> {
    const config = this.levels.find(l => l.name === level);
    
    for (const feature of config.disabled) {
      await this.disable(feature);
    }
    
    this.notifyUser(`已降级到 ${level} 模式`);
  }
}
```

### 7.4 重试与指数退避

```typescript
class RetryPolicy {
  config = {
    maxRetries: 3,
    baseDelay: 1000,      // 1秒
    maxDelay: 30000,      // 30秒
    backoffMultiplier: 2,
    retryableErrors: [
      "TIMEOUT",
      "NETWORK_ERROR",
      "SANDBOX_UNAVAILABLE",
      "RATE_LIMIT"
    ]
  };
  
  async executeWithRetry<T>(
    operation: () => Promise<T>
  ): Promise<T> {
    let delay = this.config.baseDelay;
    
    for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        if (!this.config.retryableErrors.includes(error.code)) {
          throw error;  // 不可重试
        }
        
        if (attempt === this.config.maxRetries) {
          throw error;  // 重试耗尽
        }
        
        // 指数退避 + 抖动
        const jitter = Math.random() * 1000;
        await sleep(delay + jitter);
        delay = Math.min(delay * this.config.backoffMultiplier, this.config.maxDelay);
      }
    }
    
    throw new Error("UNREACHABLE");
  }
}
```

---

## 八、部署模式

### 8.1 本地节点（开发者/个人用户）

```bash
# 在个人电脑上运行
echo-claw init --type user --name my-laptop
echo-claw start

# 特点：
# - 轻量级（内存 < 512MB）
# - 本地缓存Skill元数据
# - 通过WebSocket或gRPC与网络通信
# - 支持离线使用（授权凭证本地缓存）
```

### 8.2 云端节点（服务器）

```yaml
# docker-compose.yml
version: "3"
services:
  echo-claw:
    image: echo/claw:latest
    ports:
      - "8080:8080"    # API
      - "9090:9090"    # Metrics
    volumes:
      - ./data:/data
      - ./config:/config
    environment:
      - NODE_TYPE=sandbox
      - SANDBOX_TYPE=wasm,container
      - MAX_EXECUTIONS=1000
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 8G
          cpus: '4'
```

### 8.3 P2P Mesh（去中心化网络）

```typescript
// 每个节点同时是用户、路由器、缓存
class P2PNode {
  // 启动时连接到种子节点
  async bootstrap(): Promise<void> {
    for (const seed of this.config.bootstrap_peers) {
      try {
        const conn = await this.connect(seed);
        await this.dht.bootstrap(conn);
        break;
      } catch (e) {
        continue;
      }
    }
  }
  
  // 路由请求到最近的节点
  async route(request: EchoMessage): Promise<void> {
    const target = await this.dht.findClosest(request.target_node, 3);
    
    for (const node of target) {
      try {
        await this.send(node, request);
        return;
      } catch (e) {
        continue;
      }
    }
  }
}
```

---

## 九、与 OpenClaw 集成

### 9.1 ECHO Claw 作为 OpenClaw Skill

```typescript
// OpenClaw 调用 ECHO Skill
// 通过 ECHO Claw 桥接

// ~/.openclaw/skills/echo-bridge/skill.json
{
  "name": "echo-bridge",
  "description": "Bridge to ECHO network",
  "version": "1.0.0",
  
  "functions": {
    "call_skill": {
      "description": "Call an ECHO Skill",
      "parameters": {
        "skill_id": { "type": "string" },
        "params": { "type": "object" }
      }
    },
    "discover_skills": {
      "description": "Discover ECHO Skills",
      "parameters": {
        "query": { "type": "string" }
      }
    }
  },
  
  "runtime": {
    "command": "echo-claw",
    "args": ["--server-mode"]
  }
}

// 使用
openclaw skill call echo-bridge.call_skill \
  --skill_id skill_poet_alice \
  --params '{"theme":"春天"}'
```

### 9.2 OpenClaw 本地工具调用 ECHO 网络

```typescript
// OpenClaw 本地 Skill 调用 ECHO 网络资源
import { callEchoSkill } from "echo-claw/sdk";

export default async function localSkillHandler(request) {
  // 本地处理
  const localResult = await processLocally(request);
  
  // 调用ECHO网络增强
  const echoResult = await callEchoSkill({
    skill_id: "skill_enhancer_v1",
    params: { input: localResult }
  });
  
  return echoResult;
}
```

---

## 十、路线图

| 阶段 | 时间 | 目标 |
|------|------|------|
| MVP | 8周 | CLI + 基础P2P网络 + WASM沙箱调度 |
| V1.0 | 16周 | 完整节点类型 + gRPC协议 + Rights Engine |
| V1.5 | 24周 | 多沙箱类型 + ZKP验证 + 离线模式 |
| V2.0 | 36周 | 完全去中心化 + 社区治理 + 高级编排 |

---

> **设计参考**: 网络架构参考 IPFS 的P2P发现 + libp2p 的传输抽象 + Bitcoin 的节点激励。目标：每个节点轻量、网络整体强大、创作者完全主权。
