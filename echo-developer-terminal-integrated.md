# ECHO 开发者终端 - 完整方向方案

**版本**: v2.0 | **日期**: 2026-04-21 | **状态**: 整合文档

---

## 一、方向概述

### 1.1 目标

为开发者提供从 **Skill 开发 → 四权配置 → ECHO 化 → 沙箱部署 → PoU 验证** 的完整工具链与文档。

### 1.2 三个核心问题

| 问题 | 答案 |
|------|------|
| **开发环境** | `echo dev` CLI + IDE 插件 + 运行时模拟器 |
| **四权配置** | `blueprint.yaml` + `echo config` 向导 + 冲突检测 |
| **沙箱/PoU** | 三层沙箱（入口/创作者/结算）+ ZKP 验证 + 事件流 |

---

## 二、系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        开发者体验层                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ CLI工具  │  │ IDE插件  │  │ 蓝图编辑器│  │ 模拟器   │    │
│  │ echo dev │  │ VS Code  │  │ Web UI   │  │ echo sim │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       协议集成层                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │ 四权配置引擎  │  │ 蓝图版本管理  │  │ 冲突检测器  │        │
│  │ Rights Engine │  │ Soft Fork    │  │ Validator   │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        沙箱网络层                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ 入口沙箱 │  │ 创作者   │  │ 结算沙箱 │  │ 验证节点 │    │
│  │ Ingress  │  │ 沙箱     │  │Settlement│  │Validator │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
│         │            │            │            │              │
│         └────────────┴────────────┴────────────┘              │
│                         事件流 (Kafka)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       ECHO 网络层                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ 链上登记  │  │ 收益分配  │  │ 状态锚定  │  │ ShiGraph │    │
│  │Registry  │  │ Splitter │  │ Anchor   │  │ Engine   │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 三、模块接口定义

### 3.1 模块间接口

```typescript
// 模块1 <-> 模块2: 四权配置接口
interface BlueprintAPI {
  // 从开发环境传入
  create(blueprint: Blueprint): ValidationResult;
  
  // 沙箱查询
  getEffectivePolicy(assetId: string, version?: string): EffectivePolicy;
  
  // 版本管理
  getVersions(assetId: string): BlueprintVersion[];
  createFork(assetId: string, changes: BlueprintDelta): Blueprint;
}

// 模块2 <-> 模块3: 沙箱执行接口
interface SandboxAPI {
  // 沙箱注册
  registerSandbox(config: SandboxConfig): SandboxRegistration;
  
  // 执行请求
  execute(request: ExecutionRequest): ExecutionResult;
  
  // ZKP证明
  generateProof(execution: ExecutionResult): ZKPProof;
  verifyProof(proof: ZKPProof): boolean;
}

// 模块3 <-> 网络层: 事件流接口
interface EventStreamAPI {
  // 发布事件
  publish(event: EchoEvent): void;
  
  // 订阅事件
  subscribe(filter: EventFilter, handler: EventHandler): Subscription;
  
  // 查询历史
  queryHistory(assetId: string, timeRange: TimeRange): EchoEvent[];
}
```

### 3.2 数据流

```
开发者创建Skill
  │
  ├──> 开发环境 (echo dev)
  │       ├── 代码编写
  │       ├── 本地测试 (echo test)
  │       └── 模拟调用 (echo sim)
  │
  ├──> 四权配置 (echo config)
  │       ├── YAML配置
  │       ├── 冲突检测
  │       └── 64卦预览
  │
  ├──> ECHO化打包 (echo build)
  │       ├── 签名
  │       ├── 依赖解析
  │       └── 生成 .echo 包
  │
  └──> 登记 (echo register)
          ├── 上传到IPFS
          ├── 链上登记
          ├── ShiGraph初始化
          └── 部署到沙箱
                  │
                  ├──> 入口沙箱验证
                  ├──> 创作者沙箱执行
                  ├──> ZKP证明生成
                  └──> 结算沙箱验证 + 分配
                          │
                          └──> 链上锚定 + ShiGraph更新
```

---

## 四、开发工作流

### 4.1 5分钟快速启动

```bash
# 1. 安装
curl -fsSL https://echo.dev/install | sh

# 2. 创建Skill
echo dev init my-skill --template poem
# 输出: 已创建 my-skill/ 目录，包含示例代码

# 3. 开发
cd my-skill
echo dev run
# 本地测试运行

# 4. 配置四权
echo config --wizard
# 交互式配置

# 5. 登记
echo build
echo register
# 完成！Skill已上链
```

### 4.2 完整工作流

```
Day 1: 环境搭建
  - 安装 CLI
  - 配置身份
  - 选择模板

Day 2-3: 开发
  - 编写代码
  - 本地测试
  - 模拟调用

Day 4: 配置
  - 四权配置
  - 冲突检测
  - 收益模拟

Day 5: 部署
  - 打包签名
  - 链上登记
  - 沙箱部署
  - 测试调用

Day 6+: 运营
  - 监控使用
  - 调整四权
  - 版本迭代
```

---

## 五、与 ECHO Claw 的衔接

### 5.1 衔接点

```
开发者终端 ──────► ECHO Claw
    │                │
    │ 登记后的Skill   │ 通过 ShiGraph 被发现
    │                │
    │ 四权配置        │ 被 Rights Engine 执行
    │                │
    │ 沙箱部署        │ 被 Sandbox Mesh 调度
    │                │
    │ 事件流         │ 被 ShiGraph 消费
    │                │
    │ ZKP证明        │ 被验证节点验证
```

### 5.2 统一数据格式

```typescript
// 跨模块统一使用的事件格式
interface EchoEvent {
  event_id: string;
  type: "UsageOccurred" | "DerivativeCreated" | "DeploymentEvent" | ...;
  asset_id: string;
  timestamp: number;
  context: Record<string, any>;
  signatures: Record<string, string>;
}

// 统一的四权配置格式
interface Blueprint {
  version: string;
  yong: UsageRights;
  yan: DerivativeRights;
  kuo: ExpansionRights;
  yi: BenefitRights;
  metadata: SkillMetadata;
}

// 统一的Skill包格式
interface SkillPackage {
  skill_json: object;
  blueprint_yaml: string;
  code: Record<string, string>;
  assets: Record<string, Buffer>;
  signatures: PackageSignatures;
}
```

---

## 六、详细文档索引

| 文档 | 内容 | 规模 |
|------|------|------|
| `echo-developer-terminal-agent1-dev-env.md` | Skill 开发环境（CLI、模板、运行时、模拟器） | 24KB |
| `echo-developer-terminal-agent2-blueprint.md` | 四权配置与 ECHO 化（YAML Schema、编辑器、登记） | 32KB |
| `echo-developer-terminal-agent3-sandbox-pou.md` | 沙箱架构与 PoU 验证（三层沙箱、ZKP、事件流） | 35KB |

---

> 本整合文档引用了上述3份子文档的详细设计。完整实现细节请查阅对应文档。
