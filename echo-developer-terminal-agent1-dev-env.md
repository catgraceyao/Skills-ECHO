# ECHO 开发者终端 - Skill开发环境设计

**版本**: v1.0 | **日期**: 2026-04-21 | **状态**: 详细设计

---

## 一、设计原则

### 1.1 主权优先

开发者的代码属于开发者。ECHO不控制、不审核、不托管核心逻辑。开发者工具链必须让创作者能在任何沙箱运行自己的Skill，随时可以迁移。

### 1.2 协议原生

所有工具深度集成ECHO协议概念：四权配置、事件流、PoU验证、ShiGraph。不是外挂，是原生支持。

### 1.3 渐进复杂

新手用CLI向导5分钟创建一个Skill。高级用户手写YAML精确控制每一个细节。工具链不替代思考，只是降低门槛。

---

## 二、echo-cli 命令行工具

### 2.1 命令结构

```bash
echo --version                    # 显示版本和当前网络状态
echo init [template]              # 初始化新项目
echo dev                          # 启动本地开发沙箱
echo test                         # 运行测试套件
echo build                        # 打包Skill（ECHO化）
echo deploy [target]              # 部署到指定沙箱
echo config                       # 交互式四权配置向导
echo register                     # 登记Skill到ECHO网络
echo status [asset-id]            # 查看Skill势位状态
echo inspect [asset-id]           # 查看Skill详细信息
echo upgrade [asset-id]           # 升级Skill版本（软分叉）
echo logs [asset-id]              # 查看使用日志
echo simulate                     # 模拟调用（本地测试）
```

### 2.2 配置文件 echo.yaml

```yaml
# echo.yaml - ECHO Skill 项目配置
skill:
  name: "智能写诗助手"
  version: "1.0.0"
  description: "基于上下文的唐诗生成器"
  author: "alice@example.com"
  
  # Skill类型决定运行环境
  type: "wasm"           # wasm | container | native | external
  
  # 入口点
  entry: "./dist/index.js"
  
  # 输入输出Schema
  input_schema: "./schemas/input.json"
  output_schema: "./schemas/output.json"
  
  # 依赖声明（上游Skill引用）
  dependencies:
    - skill_id: "skill_nlp_tokenizer_v1"
      version: "^2.0.0"
      
  # 资源需求
  resources:
    memory: "512MB"
    timeout: "30s"
    
  # 标签（用于发现和分类）
  tags:
    - "文本生成"
    - "诗歌"
    - "中文"
    - "AI"

# 四权蓝图（可由 echo config 交互生成）
blueprint:
  yong:                    # 用 - 使用权
    pricing_model: "per_call"
    price: 0.01            # ECHO
    quota: 1000            # 每月免费额度
    level: 3               # 0-5
    
  yan:                     # 衍 - 衍生权
    enabled: true
    split: 0.15            # 15%归上游
    max_depth: 2           # 最多2层衍生
    require_approval: false
    level: 3
    
  kuo:                     # 扩 - 扩展权
    visibility: "public"   # public | indexed | private
    platforms: ["echo", "api"]
    require_auth: false
    level: 3
    
  yi:                      # 益 - 收益权
    unlock_at: 500         # 使用500次后解锁
    total_shares: 1000
    tradable: true
    level: 0               # 冷启动期锁定

# 部署配置
deploy:
  default_sandbox: "echo-public-1"
  fallback_sandboxes: ["echo-public-2", "echo-public-3"]
  auto_scale: true
```

### 2.3 与包管理器集成

```bash
# npm 集成
npm install echo-sdk
npx echo init

# pip 集成
pip install echo-sdk
echo init --template python

# cargo 集成
cargo install echo-cli
echo init --template rust
```

---

## 三、echo-sdk 开发SDK

### 3.1 多语言架构

```
echo-sdk/
├── core/                    # 语言无关的核心协议定义
│   ├── schema/              # JSON Schema定义
│   ├── protobuf/            # Protobuf消息定义
│   └── spec/                # 接口规范文档
│
├── ts/                      # TypeScript SDK
│   ├── src/
│   │   ├── SkillDefinition.ts
│   │   ├── SkillHandler.ts
│   │   ├── SkillContext.ts
│   │   ├── EventEmitter.ts
│   │   └── ZKPGenerator.ts  # 预留接口
│   └── package.json
│
├── py/                      # Python SDK
│   ├── echo_sdk/
│   │   ├── skill.py
│   │   ├── context.py
│   │   ├── events.py
│   │   └── zkp.py
│   └── setup.py
│
├── rs/                      # Rust SDK
│   └── src/
│       ├── lib.rs
│       ├── skill.rs
│       └── context.rs
│
└── go/                      # Go SDK
    └── pkg/
        ├── skill.go
        └── context.go
```

### 3.2 TypeScript SDK 核心接口

```typescript
// ========== SkillDefinition ==========
// 描述一个Skill的元数据和接口契约

interface SkillDefinition {
  id?: string;              // 登记后由ECHO网络分配
  name: string;
  version: string;
  description: string;
  
  // 输入输出Schema（JSON Schema格式）
  inputSchema: JSONSchema;
  outputSchema: JSONSchema;
  
  // 能力声明（用于发现）
  capabilities: Capability[];
  
  // 依赖的上游Skill
  dependencies?: Dependency[];
  
  // 资源需求
  resources: ResourceRequirements;
  
  // 处理函数
  handler: SkillHandler;
}

type Capability = {
  domain: string;           // e.g. "text-generation"
  action: string;           // e.g. "generate-poem"
  inputTypes: string[];     // e.g. ["string", "object"]
  outputTypes: string[];    // e.g. ["string"]
};

// ========== SkillHandler ==========
// 开发者实现的核心逻辑

type SkillHandler = (
  request: SkillRequest,
  context: SkillContext
) => Promise<SkillResponse> | AsyncGenerator<SkillResponse>;

// ========== SkillRequest ==========
// 统一输入格式

interface SkillRequest {
  request_id: string;       // UUID
  skill_id: string;
  params: Record<string, any>;
  context: {
    user_id: string;
    session_id: string;
    previous_calls?: CallRecord[];
    metadata?: Record<string, any>;
  };
  timestamp: number;        // Unix timestamp (ms)
}

// ========== SkillResponse ==========
// 统一输出格式

interface SkillResponse {
  request_id: string;
  status: "success" | "error" | "partial";
  data?: any;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
  usage: {
    duration_ms: number;
    compute_units: number;    // 标准化计算单元
    memory_mb: number;
    tokens_in?: number;       // LLM类Skill
    tokens_out?: number;
  };
  // 流式输出标志
  streaming?: boolean;
  chunk_index?: number;
}

// ========== SkillContext ==========
// 运行时上下文，开发者可读取但不可修改

interface SkillContext {
  // 当前调用的四权配置快照
  rights: {
    yong: YongConfig;
    yan: YanConfig;
    kuo: KuoConfig;
    yi: YiConfig;
  };
  
  // 用户授权凭证
  auth: {
    user_id: string;
    auth_token: string;
    quota_remaining: number;
  };
  
  // 沙箱环境信息
  sandbox: {
    id: string;
    region: string;
    version: string;
  };
  
  // 事件发射器（用于生成UsageOccurred事件）
  emit: EventEmitter;
  
  // 日志
  log: Logger;
  
  // 上游Skill调用（用于衍生组合）
  callUpstream: (skillId: string, params: any) => Promise<any>;
  
  // ZKP证明生成（预留）
  generateProof: (executionLog: ExecutionLog) => Promise<ZKPProof>;
}
```

### 3.3 完整示例：写诗助手

```typescript
import { defineSkill, SkillContext } from "echo-sdk";

export default defineSkill({
  name: "智能写诗助手",
  version: "1.0.0",
  description: "基于风格和主题的唐诗生成器",
  
  inputSchema: {
    type: "object",
    properties: {
      theme: { type: "string", description: "诗歌主题" },
      style: { type: "string", enum: ["盛唐", "晚唐", "宋词"] },
      length: { type: "integer", minimum: 4, maximum: 100 }
    },
    required: ["theme", "style"]
  },
  
  outputSchema: {
    type: "object",
    properties: {
      poem: { type: "string" },
      analysis: { type: "string" }
    }
  },
  
  capabilities: [{
    domain: "text-generation",
    action: "generate-poem",
    inputTypes: ["object"],
    outputTypes: ["object"]
  }],
  
  async handler(request, context) {
    const { theme, style, length = 20 } = request.params;
    
    // 记录开始执行（生成事件）
    context.emit("execution.start", { theme, style });
    
    const startTime = Date.now();
    
    // 核心逻辑：调用私有模型生成诗歌
    // 注意：这段代码在创作者沙箱内运行，ECHO网络看不见
    const poem = await myPrivateModel.generate({
      prompt: `写一首${style}风格的诗，主题：${theme}`,
      maxLength: length
    });
    
    const duration = Date.now() - startTime;
    
    // 记录完成（生成UsageOccurred事件）
    context.emit("execution.complete", {
      duration_ms: duration,
      quality_score: 0.92
    });
    
    // 生成ZKP证明（证明执行发生，不暴露内容）
    const proof = await context.generateProof({
      startTime,
      duration,
      computeUnits: 150,
      inputHash: hash(request.params),
      outputHash: hash(poem),
    });
    
    return {
      request_id: request.request_id,
      status: "success",
      data: { poem, analysis: "这首诗描绘了..." },
      usage: {
        duration_ms: duration,
        compute_units: 150,
        memory_mb: 256
      }
    };
  }
});
```

---

## 四、本地开发沙箱

### 4.1 架构

```
本地开发沙箱（echo dev 启动）
├── 轻量级运行时
│   ├── Deno（TypeScript/Wasm首选）
│   └── Python虚拟环境
│
├── 模拟ECHO网络层
│   ├── 模拟四权配置校验
│   ├── 模拟收益分配计算
│   └── 模拟ShiGraph状态更新
│
├── 调试工具
│   ├── 调用日志（请求/响应/事件）
│   ├── 性能分析（CPU/内存/耗时）
│   ├── 四权模拟器（测试不同权限场景）
│   └── 事件查看器（UsageOccurred流）
│
└── 热重载
    ├── 代码变更自动重载
    ├── 配置变更实时生效
    └── 测试用例自动重跑
```

### 4.2 启动命令

```bash
$ echo dev

✓ 启动本地沙箱 (Deno runtime)
✓ 加载 Skill: 智能写诗助手 v1.0.0
✓ 模拟ECHO网络已连接
✓ 热重载已启用
✓ 调试面板: http://localhost:8080

可用端点:
  POST http://localhost:3000/call    # 调用Skill
  GET  http://localhost:3000/status  # 查看状态
  GET  http://localhost:8080         # 调试面板

测试调用:
  curl -X POST http://localhost:3000/call \
    -H "Content-Type: application/json" \
    -d '{"theme":"春天","style":"盛唐"}'
```

### 4.3 调试面板功能

```
调试面板 (http://localhost:8080)
├── 概览
│   ├── Skill名称/版本
│   ├── 当前四权配置
│   └── 模拟ShiGraph状态
│
├── 调用日志
│   ├── 请求详情
│   ├── 响应详情
│   ├── 执行耗时分解
│   └── 生成的事件列表
│
├── 四权模拟器
│   ├── 切换不同权限配置
│   ├── 测试收益分配计算
│   └── 预览64卦约束影响
│
├── 性能分析
│   ├── CPU使用率
│   ├── 内存占用
│   ├── 调用延迟分布
│   └── 吞吐量（QPS）
│
└── 事件流
    ├── UsageOccurred事件列表
    ├── 时间线视图
    └── 导出为JSON
```

---

## 五、测试框架

### 5.1 测试类型

```typescript
// ========== 单元测试 ==========
// 测试Skillhandler的核心逻辑

import { testSkill, mockContext } from "echo-sdk/testing";
import mySkill from "./skill";

testSkill("写诗助手", mySkill, () => {
  test("生成唐诗", async () => {
    const result = await testSkill.call({
      theme: "春天",
      style: "盛唐"
    });
    
    expect(result.status).toBe("success");
    expect(result.data.poem).toContain("春");
    expect(result.usage.duration_ms).toBeLessThan(5000);
  });
  
  test("无效输入返回错误", async () => {
    const result = await testSkill.call({
      theme: "春天"
      // 缺少style必填字段
    });
    
    expect(result.status).toBe("error");
    expect(result.error.code).toBe("VALIDATION_ERROR");
  });
});

// ========== 四权场景测试 ==========
// 测试不同权限配置下的行为

import { testWithRights } from "echo-sdk/testing";

testWithRights("不同权限场景", () => {
  test("用权=0时拒绝调用", async () => {
    const context = mockContext({
      rights: { yong: { level: 0 } }
    });
    
    await expect(testSkill.call({}, context))
      .rejects.toThrow("USAGE_DENIED");
  });
  
  test("衍权=5时允许无限制衍生", async () => {
    const context = mockContext({
      rights: { yan: { level: 5, split: 0 } }
    });
    
    const result = await testSkill.call({ theme: "测试" }, context);
    expect(result.status).toBe("success");
  });
  
  test("益权未解锁时收益锁定", async () => {
    const context = mockContext({
      rights: { yi: { level: 0, unlock_at: 1000 } },
      usage_count: 500  // 当前使用500次
    });
    
    const result = await testSkill.call({ theme: "测试" }, context);
    expect(result.revenue.distributable).toBe(false);
  });
});

// ========== 集成测试 ==========
// 测试端到端调用链

import { testOrchestration } from "echo-sdk/testing";

testOrchestration("多Skill编排", async () => {
  // 模拟：写诗 → 翻译 → 朗读
  const pipeline = [
    { skillId: "skill_poet", params: { theme: "春天" } },
    { skillId: "skill_translator", params: { target: "english" } },
    { skillId: "skill_tts", params: { voice: "female" } }
  ];
  
  const result = await testOrchestration.run(pipeline);
  
  expect(result.status).toBe("success");
  expect(result.finalOutput.audioUrl).toBeDefined();
  expect(result.totalCost).toBeGreaterThan(0);
  expect(result.revenueSplit).toMatchObject({
    "skill_poet": expect.any(Number),
    "skill_translator": expect.any(Number),
    "skill_tts": expect.any(Number)
  });
});

// ========== 性能测试 ==========

import { benchmark } from "echo-sdk/testing";

benchmark("写诗助手性能", async () => {
  const results = await benchmark.run({
    concurrentUsers: [1, 10, 50, 100],
    duration: "30s",
    warmup: "5s"
  }, {
    theme: "测试",
    style: "盛唐"
  });
  
  console.log(`
    P50延迟: ${results.latency.p50}ms
    P99延迟: ${results.latency.p99}ms
    吞吐量: ${results.throughput} QPS
    错误率: ${results.errorRate}%
  `);
});
```

### 5.2 测试运行器

```bash
$ echo test

运行测试套件:
  ✓ 单元测试 (12/12 passed)
  ✓ 四权场景测试 (8/8 passed)
  ✓ 集成测试 (3/3 passed)
  ✓ 性能测试 (基准已建立)

覆盖率:
  语句覆盖率: 94%
  分支覆盖率: 87%
  函数覆盖率: 100%

四权合规检查:
  ✓ 用权配置有效
  ✓ 衍权配置有效
  ✓ 扩权配置有效
  ✓ 益权配置有效
  ✓ 无冲突检测
```

---

## 六、接口标准

### 6.1 统一输入格式

```json
{
  "request_id": "req_2f7a9b3e1d5c",
  "skill_id": "skill_poet_alice_v1",
  "version": "1.0.0",
  "params": {
    "theme": "春天",
    "style": "盛唐",
    "length": 20
  },
  "context": {
    "user_id": "user_bob_123",
    "session_id": "sess_8a7f6e5d",
    "auth_token": "auth_xyz...",
    "previous_calls": [
      {
        "skill_id": "skill_analyzer",
        "request_id": "req_prev_001",
        "timestamp": 1745200000000
      }
    ],
    "metadata": {
      "client": "web",
      "locale": "zh-CN"
    }
  },
  "timestamp": 1745201000000,
  "blueprint_version": "1.0.0"
}
```

### 6.2 统一输出格式

```json
{
  "request_id": "req_2f7a9b3e1d5c",
  "status": "success",
  "data": {
    "poem": "春眠不觉晓，处处闻啼鸟...",
    "analysis": "这首诗描绘了..."
  },
  "error": null,
  "usage": {
    "duration_ms": 1250,
    "compute_units": 150,
    "memory_mb": 256,
    "tokens_in": 45,
    "tokens_out": 120
  },
  "cost": {
    "amount": 0.01,
    "currency": "ECHO",
    "breakdown": {
      "base": 0.01,
      "premium": 0
    }
  },
  "proof": {
    "type": "zk-SNARK",
    "hash": "0xabc...",
    "timestamp": 1745201001250
  }
}
```

### 6.3 流式输出

```typescript
// Server-Sent Events (SSE)
const response = await fetch("/call", {
  method: "POST",
  headers: { "Accept": "text/event-stream" },
  body: JSON.stringify(request)
});

const reader = response.body.getReader();
while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  
  const chunk = JSON.parse(new TextDecoder().decode(value));
  // chunk = { chunk_index, data: "...", status: "streaming" }
  display(chunk.data);
}
```

### 6.4 异步回调模式

```json
// 异步请求
{
  "request_id": "req_async_001",
  "skill_id": "skill_video_gen",
  "params": { "prompt": "生成视频" },
  "callback_url": "https://myapp.com/webhook/echo",
  "callback_token": "whsec_..."
}

// 回调通知
POST https://myapp.com/webhook/echo
{
  "request_id": "req_async_001",
  "status": "success",
  "data": { "video_url": "https://..." },
  "usage": { ... },
  "signature": "sig_..."
}
```

---

## 七、开发者工作流

### 7.1 从零到部署的完整流程

```bash
# Step 1: 初始化项目
$ echo init
? 选择模板: TypeScript (WebAssembly)
? Skill名称: 智能写诗助手
? 描述: 基于上下文的唐诗生成器
✓ 创建项目目录 my-echo-skill/
✓ 生成 echo.yaml
✓ 生成 src/index.ts
✓ 生成 schemas/input.json
✓ 生成 schemas/output.json

# Step 2: 实现核心逻辑
$ cd my-echo-skill
$ vim src/index.ts
# ...编写写诗逻辑...

# Step 3: 配置四权
$ echo config
? 你希望这个Skill被如何使用? 开放使用，每次付费
? 定价: 0.01 ECHO/次
? 是否允许衍生? 允许，收取15%分成
? 是否允许扩展? 允许在ECHO和API平台使用
? 收益权何时解锁? 使用500次后
✓ 生成 blueprint.yaml
✓ 冲突检测: 通过

# Step 4: 本地开发
$ echo dev
✓ 启动本地沙箱
✓ 热重载已启用
✓ 调试面板: http://localhost:8080

# 在另一个终端测试
$ curl -X POST http://localhost:3000/call \
  -d '{"theme":"春天","style":"盛唐"}'

# Step 5: 测试
$ echo test
✓ 12个单元测试通过
✓ 8个四权场景测试通过
✓ 3个集成测试通过

# Step 6: 打包（ECHO化）
$ echo build
✓ 编译 TypeScript → WebAssembly
✓ 打包资源文件
✓ 生成 skill.json（元数据）
✓ 签名: 0xabc...
✓ 内容哈希: sha256:xyz...
✓ 输出: dist/my-echo-skill-v1.0.0.echo

# Step 7: 登记到ECHO网络
$ echo register
? 确认四权配置 (预览)
? 确认部署沙箱: echo-public-1
✓ 上传Skill包
✓ 链上登记完成
✓ AssetID: skill_poet_alice_20260421
✓ 初始状态: 坤卦（潜藏期）
✓ 初始势位: 初九·初九·初九

# Step 8: 部署
$ echo deploy
✓ 部署到 echo-public-1
✓ 部署到 echo-public-2（备用）
✓ 健康检查通过
✓ Skill已可用: skill_poet_alice_20260421
```

### 7.2 CI/CD集成

```yaml
# .github/workflows/echo-ci.yml
name: ECHO Skill CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: echo-dev/setup@v1
        with:
          version: "latest"
      - run: echo install
      - run: echo test --coverage
      - run: echo validate --strict  # 严格模式校验

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: echo-dev/setup@v1
      - run: echo build
      - uses: actions/upload-artifact@v4
        with:
          name: echo-skill
          path: dist/*.echo

  deploy-staging:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: echo-skill
      - run: echo deploy --target staging --auto-yes

  deploy-production:
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    environment: production
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: echo-skill
      - run: echo deploy --target production --auto-yes
```

---

## 八、流式与异步支持

### 8.1 流式输出（SSE）

```typescript
import { defineSkill } from "echo-sdk";

export default defineSkill({
  name: "实时文本生成器",
  
  // 声明支持流式输出
  streaming: true,
  
  async *handler(request, context) {
    const { prompt } = request.params;
    
    // 使用生成器yield分块结果
    const stream = await myLLM.generateStream(prompt);
    
    let chunkIndex = 0;
    for await (const chunk of stream) {
      yield {
        request_id: request.request_id,
        status: "streaming",
        data: { text: chunk },
        chunk_index: chunkIndex++,
        usage: { 
          duration_ms: Date.now() - start,
          tokens_out: chunk.length 
        }
      };
    }
    
    // 最终chunk标记完成
    yield {
      request_id: request.request_id,
      status: "success",
      data: { done: true },
      usage: { duration_ms: Date.now() - start }
    };
  }
});
```

### 8.2 WebSocket实时连接

```typescript
// 支持长连接的Skill（如聊天机器人）
export default defineSkill({
  name: "对话助手",
  protocol: "websocket",  // 默认http
  
  async handler(ws, context) {
    ws.on("message", async (msg) => {
      const response = await processMessage(msg);
      ws.send(JSON.stringify(response));
    });
  }
});
```

---

## 九、多语言SDK设计规范

### 9.1 核心接口一致性

所有语言SDK必须实现以下接口：

| 接口 | TypeScript | Python | Rust | Go |
|------|-----------|--------|------|-----|
| `defineSkill` | `defineSkill(config)` | `@skill` 装饰器 | `skill!` 宏 | `DefineSkill(config)` |
| `SkillRequest` | 接口 | `dataclass` | `struct` | `struct` |
| `SkillResponse` | 接口 | `dataclass` | `struct` | `struct` |
| `SkillContext` | 接口 | `dataclass` | `struct` | `struct` |
| `emit` | `context.emit()` | `context.emit()` | `context.emit()` | `context.Emit()` |
| `callUpstream` | `await context.callUpstream()` | `await context.call_upstream()` | `context.call_upstream().await` | `context.CallUpstream()` |

### 9.2 Python SDK示例

```python
from echo_sdk import skill, SkillContext

@skill(
    name="智能写诗助手",
    version="1.0.0",
    input_schema={...},
    output_schema={...}
)
async def poem_generator(request, context: SkillContext):
    theme = request.params["theme"]
    style = request.params["style"]
    
    # 发射事件
    context.emit("execution.start", {"theme": theme})
    
    poem = await generate_poem(theme, style)
    
    context.emit("execution.complete", {
        "duration_ms": 1200,
        "quality_score": 0.92
    })
    
    return {
        "request_id": request.request_id,
        "status": "success",
        "data": {"poem": poem},
        "usage": {
            "duration_ms": 1200,
            "compute_units": 150
        }
    }
```

### 9.3 Rust SDK示例

```rust
use echo_sdk::{skill, SkillRequest, SkillContext, SkillResponse};

#[skill(
    name = "智能写诗助手",
    version = "1.0.0"
)]
async fn poem_generator(
    request: SkillRequest,
    context: SkillContext
) -> Result<SkillResponse, EchoError> {
    let theme = request.params["theme"].as_str()?;
    let style = request.params["style"].as_str()?;
    
    context.emit("execution.start", json!({"theme": theme})).await?;
    
    let poem = generate_poem(theme, style).await?;
    
    context.emit("execution.complete", json!({
        "duration_ms": 1200,
        "quality_score": 0.92
    })).await?;
    
    Ok(SkillResponse {
        request_id: request.request_id,
        status: Status::Success,
        data: Some(json!({"poem": poem})),
        usage: Usage {
            duration_ms: 1200,
            compute_units: 150,
            ..Default::default()
        },
        ..Default::default()
    })
}
```

---

## 十、开发者体验设计

### 10.1 错误消息

```bash
# ❌ 不好：技术细节堆砌
$ echo deploy
Error: HTTP 400 - invalid_blueprint_schema
Field 'yong.price' must be of type number but got string

# ✅ 好：可操作、有上下文
$ echo deploy
✗ 部署失败: 四权配置有问题

  问题: 用权定价格式错误
  位置: blueprint.yaml → yong → price
  当前值: "0.01" (字符串)
  期望值: 0.01 (数字)
  
  修复方法:
    1. 打开 blueprint.yaml
    2. 将 yong.price 改为数字: 0.01
    3. 重新运行: echo deploy
  
  或者运行交互式修复:
    echo config --fix
```

### 10.2 新手引导

```bash
$ echo init
👋 欢迎使用 ECHO! 这是你第一次创建Skill，我来引导你。

Step 1/5: 选择模板
  1. 简单API（HTTP请求处理）
  2. AI文本生成（LLM调用）
  3. 图像处理（图像变换）
  4. 数据分析（CSV/JSON处理）
  5. 从零开始
> 2

Step 2/5: 命名你的Skill
> 智能写诗助手

Step 3/5: 配置四权（不懂？选默认就好）
  你希望别人怎么使用你的Skill?
  1. 完全免费，希望被广泛使用 [影响力优先]
  2. 每次使用收少量费用 [收入优先]
  3. 允许别人基于它创建新Skill [生态优先]
  4. 先保护起来，以后再开放 [保护优先]
  5. 我想自己配置每个选项 [高级]
> 2

Step 4/5: 定价
  每次调用收费: 0.01 ECHO（约等于 0.01 RMB）
  这是类似Skill的平均价格，确定吗?
> y

Step 5/5: 完成！
  ✓ 项目已创建: my-echo-skill/
  ✓ 四权配置已保存
  
  下一步:
    cd my-echo-skill
    echo dev          # 启动开发沙箱
    echo test         # 运行测试
    echo deploy       # 部署到ECHO网络
```

### 10.3 本地开发沙箱事件流

```
[echo dev] 调试面板事件流示例

12:00:01  🔵 UsageOccurred
          用户: user_bob
          调用: skill_poet_alice_v1
          耗时: 1.2s
          费用: 0.01 ECHO
          
12:00:01  🟢 RevenueDistributed
          创作者: alice +0.0099 ECHO
          验证者: +0.00009 ECHO
          协议: +0.00001 ECHO
          
12:00:02  🟡 ShiGraphUpdate
          资产: skill_poet_alice_v1
          时间维: 1→2（稳定→活跃）
          势位变化: 初九→九二
          
12:05:30  🔵 UsageOccurred
          用户: user_carol
          调用: skill_poet_alice_v1（衍生作品）
          耗时: 2.1s
          费用: 0.02 ECHO
          
12:05:30  🟢 RevenueDistributed
          衍生创作者: carol +0.0168 ECHO
          上游创作者: alice +0.003 ECHO（衍权触发）
          验证者: +0.00018 ECHO
          协议: +0.00002 ECHO
```

---

## 十一、API参考

### 11.1 echo-cli 完整命令列表

```bash
echo init [options] <name>
  --template, -t        选择模板 (ts|py|rs|go|api|ai|image)
  --blueprint, -b       预加载蓝图文件
  --yes, -y             跳过确认

echo dev [options]
  --port, -p            本地端口 (默认3000)
  --debug-port, -d      调试面板端口 (默认8080)
  --network, -n         连接的网络 (local|testnet|mainnet)
  --hot-reload          热重载 (默认开启)
  --simulate-pou        模拟PoU验证 (默认开启)

echo test [options]
  --unit                仅运行单元测试
  --integration         仅运行集成测试
  --rights              仅运行四权场景测试
  --benchmark           运行性能测试
  --coverage            生成覆盖率报告
  --watch               文件变更时重跑

echo build [options]
  --target, -t          构建目标 (wasm|container|native)
  --optimize, -O        优化级别 (0|1|2|3)
  --output, -o          输出路径

echo deploy [options] [target]
  --sandbox, -s         目标沙箱ID
  --auto-yes, -y        自动确认
  --dry-run             模拟部署，不实际执行

echo register [options]
  --blueprint, -b       蓝图文件路径
  --force               强制重新登记
  --skip-validation     跳过验证（不推荐）

echo config [options]
  --wizard, -w          交互式向导（默认）
  --edit                直接编辑blueprint.yaml
  --preview             预览当前配置效果
  --simulate            模拟不同配置下的收益
  --fix                 自动修复配置错误

echo status [options] <asset-id>
  --shigraph            显示ShiGraph详细状态
  --history             显示使用历史
  --revenue             显示收益详情

echo inspect [options] <asset-id>
  --blueprint           显示蓝图详情
  --dependencies        显示依赖树
  --derived             显示衍生作品

echo upgrade [options] <asset-id>
  --blueprint, -b       新蓝图文件
  --soft                软分叉（默认）
  --hard                硬分叉（新建资产）

echo logs [options] <asset-id>
  --follow, -f          实时跟踪
  --since               起始时间
  --until               结束时间
  --format              输出格式 (json|table)

echo simulate [options]
  --skill, -s           模拟调用的Skill
  --params, -p          调用参数
  --user                模拟用户ID
  --count, -n           模拟调用次数
```

---

## 十二、与现有生态的兼容性

### 12.1 OpenAPI集成

```yaml
# 将现有OpenAPI服务包装为ECHO Skill
echo wrap openapi --url https://api.example.com/openapi.json

# 自动生成:
# - echo.yaml
# - 输入/输出Schema
# - 四权配置模板
```

### 12.2 OpenClaw Skill适配

```typescript
// 将OpenClaw Skill迁移到ECHO
import { adaptFromOpenClaw } from "echo-sdk/adapters";

export default adaptFromOpenClaw({
  // 原OpenClaw Skill定义
  openclawSkill: require("./openclaw-skill"),
  
  // ECHO四权配置
  blueprint: {
    yong: { price: 0.01, level: 3 },
    yan: { split: 0.1, level: 3 },
    kuo: { visibility: "public", level: 3 },
    yi: { unlock_at: 100, level: 0 }
  }
});
```

### 12.3 Docker镜像兼容

```dockerfile
# 基于Docker的Skill可以直接部署到ECHO
FROM my-existing-service:latest

# 添加ECHO适配层
COPY echo-adapter /echo-adapter
RUN /echo-adapter/install

# 暴露标准接口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1
```

---

## 十三、路线图

| 阶段 | 时间 | 目标 |
|------|------|------|
| MVP | 6周 | TS SDK + echo-cli基础命令 + 本地沙箱 |
| V1.0 | 12周 | 多语言SDK + Web编辑器 + CI/CD模板 |
| V1.5 | 20周 | ZKP集成 + 高级调试 + 性能分析 |
| V2.0 | 32周 | 完整IDE插件 + AI辅助开发 + 社区市场 |

---

> **设计参考**: 开发者体验参考 Stripe CLI 的简洁性 + Vercel 的部署流畅感 + npm 的生态丰富度。目标让开发者在5分钟内从零跑通第一个Skill。
