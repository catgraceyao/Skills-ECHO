# ECHO 开发者终端 - 沙箱架构与PoU验证设计

**版本**: v1.0 | **日期**: 2026-04-21 | **状态**: 详细设计

---

## 一、设计原则

### 1.1 三层边界

```
┌─────────────────────────────────────────────────────────────────┐
│                    ECHO 网络（公域）                            │
│  • 链上规则层（Layer 1）                                        │
│  • ECHO验证网络（Layer 2）                                      │
│  • 结算与审计                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 验证 ZKP / 执行结算
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   结算沙箱（ECHO控制）                           │
│  • 验证ZKP证明有效性                                            │
│  • 执行实际扣费                                                  │
│  • 按四权分配收益                                                │
│  • 生成链上状态更新                                              │
│  • ECHO可审计、可验证                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 返回证明 + 结算结果
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   创作者沙箱（私域）★                           │
│  • Skill核心逻辑执行                                             │
│  • 私有模型运行                                                  │
│  • 输入数据明文                                                  │
│  • 输出内容明文                                                  │
│  • 生成ZKP证明（不暴露内容）                                     │
│  • ★ ECHO永不进入此层 ★                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 请求调用 + 授权凭证
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   入口沙箱（ECHO控制）                           │
│  • 验证用户余额                                                  │
│  • 预扣费用                                                      │
│  • 检查四权配置（用/扩）                                         │
│  • 路由到创作者沙箱                                              │
│  • ECHO可审计、可验证                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 用户请求
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         用户                                     │
│  • 发起使用请求                                                  │
│  • 提供授权凭证                                                  │
│  • 接收执行结果                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**核心原则**: 创作者沙箱是私域，ECHO永不进入。ECHO只在边界（入口/结算）验证，不接触内容。

---

## 二、三层沙箱架构详细设计

### 2.1 入口沙箱（Ingress Sandbox）

```typescript
interface IngressSandbox {
  // 职责：请求验证与路由
  
  async processRequest(request: UserRequest): Promise<RoutedRequest> {
    // 1. 身份验证
    const user = await verifyIdentity(request.auth_token);
    
    // 2. 余额检查
    const balance = await getBalance(user.id);
    const estimatedCost = estimateCost(request.skill_id, request.params);
    if (balance < estimatedCost) {
      throw new Error("INSUFFICIENT_BALANCE");
    }
    
    // 3. 预扣费用
    const precharge = await precharge(user.id, estimatedCost);
    
    // 4. 四权检查 - 用权
    const blueprint = await getBlueprint(request.skill_id);
    if (blueprint.yong.level === 0) {
      throw new Error("USAGE_DENIED");
    }
    
    // 5. 四权检查 - 扩权（平台白名单）
    const platform = detectPlatform(request);
    if (!blueprint.kuo.platforms.includes(platform)) {
      throw new Error("PLATFORM_NOT_ALLOWED");
    }
    
    // 6. 检查用户授权凭证
    const authCredential = await getAuthCredential(user.id, request.skill_id);
    if (!authCredential || authCredential.quota.remaining <= 0) {
      throw new Error("NO_AUTHORIZATION");
    }
    
    // 7. 路由到创作者沙箱
    const sandbox = await selectSandbox(request.skill_id);
    
    return {
      ...request,
      precharge_id: precharge.id,
      auth_credential: authCredential,
      target_sandbox: sandbox,
      ingress_timestamp: Date.now()
    };
  }
}
```

### 2.2 创作者沙箱（Creator Sandbox）★ 私域

```typescript
interface CreatorSandbox {
  // 职责：执行Skill核心逻辑，生成ZKP证明
  // ★ 重要：ECHO网络不进入此沙箱，不接触明文数据
  
  async executeSkill(
    routedRequest: RoutedRequest,
    skillPackage: SkillPackage
  ): Promise<ExecutionResult> {
    const startTime = Date.now();
    
    // 1. 加载Skill
    const skill = await loadSkill(skillPackage);
    
    // 2. 注入运行时上下文
    const context = createExecutionContext({
      auth: routedRequest.auth_credential,
      rights: skillPackage.blueprint,
      sandbox: { id: this.id, region: this.region },
      emit: this.eventEmitter,
      callUpstream: this.upstreamCaller,
      generateProof: this.zkpGenerator
    });
    
    // 3. 执行Skill核心逻辑 ★ 私域执行，ECHO看不见
    const result = await skill.handler(routedRequest, context);
    
    const duration = Date.now() - startTime;
    
    // 4. 生成执行日志
    const executionLog = {
      request_id: routedRequest.request_id,
      skill_id: routedRequest.skill_id,
      sandbox_id: this.id,
      start_time: startTime,
      duration_ms: duration,
      compute_units: result.usage.compute_units,
      memory_mb: result.usage.memory_mb,
      input_hash: hash(routedRequest.params),
      output_hash: hash(result.data),
      // ★ 不包含明文数据，只包含哈希
    };
    
    // 5. 生成ZKP证明
    const proof = await this.zkpGenerator.generate(executionLog);
    // 证明内容：
    // - 执行确实发生（时间、资源消耗）
    // - 满足四权配置（未超限、未越权）
    // - 不包含：输入数据、模型参数、输出内容
    
    // 6. 生成UsageOccurred事件
    const usageEvent = {
      type: "UsageOccurred",
      event_id: generateEventId(),
      asset_id: routedRequest.skill_id,
      user_id: routedRequest.user_id,
      timestamp: Date.now(),
      context: {
        duration_ms: duration,
        compute_units: result.usage.compute_units,
        quality_score: result.usage.quality_score || 0.5,
        sandbox_id: this.id,
      },
      cost: calculateActualCost(result.usage, skillPackage.blueprint),
      proof: proof,
      signatures: {
        sandbox: sign(executionLog, this.privateKey),
        user: routedRequest.user_signature
      }
    };
    
    // 7. 发送事件到结算沙箱（异步）
    this.eventBus.send("to_settlement", usageEvent);
    
    // 8. 返回结果给用户
    return {
      result,
      proof_hash: proof.hash  // 只返回证明哈希
    };
  }
}
```

### 2.3 结算沙箱（Settlement Sandbox）

```typescript
interface SettlementSandbox {
  // 职责：验证证明、执行结算、更新链上状态
  
  async settleUsage(usageEvent: UsageEvent): Promise<SettlementResult> {
    // 1. 验证ZKP证明
    const isValidProof = await this.zkpVerifier.verify(usageEvent.proof);
    if (!isValidProof) {
      // 证明无效 → 标记争议
      await this.disputeManager.createDispute({
        type: "INVALID_PROOF",
        event: usageEvent,
        reason: "ZKP verification failed"
      });
      return { status: "disputed" };
    }
    
    // 2. 验证签名
    const sandboxPubKey = await getSandboxPublicKey(usageEvent.context.sandbox_id);
    const isValidSignature = verify(usageEvent, sandboxPubKey);
    if (!isValidSignature) {
      throw new Error("INVALID_SIGNATURE");
    }
    
    // 3. 验证数据合理性
    const isReasonable = this.reasonablenessCheck(usageEvent);
    if (!isReasonable) {
      // 统计异常 → 标记待审查（不是直接拒绝，BA模式）
      await this.anomalyDetector.flag(usageEvent);
    }
    
    // 4. 计算实际费用
    const blueprint = await getBlueprint(usageEvent.asset_id);
    const actualCost = calculateCost(usageEvent.context, blueprint);
    
    // 5. 执行扣费（从预扣到实际）
    const chargeResult = await this.ledger.charge({
      user_id: usageEvent.user_id,
      asset_id: usageEvent.asset_id,
      amount: actualCost,
      precharge_id: usageEvent.precharge_id
    });
    
    // 6. 收益分配
    const distribution = await this.distributeRevenue({
      asset_id: usageEvent.asset_id,
      amount: actualCost,
      blueprint: blueprint,
      usage_event: usageEvent
    });
    
    // 7. 更新链上状态
    await this.chainAnchor.update({
      asset_id: usageEvent.asset_id,
      usage_count_delta: 1,
      revenue_delta: actualCost,
      last_used_at: usageEvent.timestamp
    });
    
    // 8. 生成结算事件
    const settlementEvent = {
      type: "RevenueDistributed",
      event_id: generateEventId(),
      parent_event: usageEvent.event_id,
      asset_id: usageEvent.asset_id,
      user_id: usageEvent.user_id,
      distribution: distribution,
      timestamp: Date.now()
    };
    
    // 9. 广播到事件流
    this.eventBus.publish("echo.events", settlementEvent);
    
    return {
      status: "settled",
      cost: actualCost,
      distribution,
      proof_verified: true
    };
  }
  
  // 收益分配逻辑
  async distributeRevenue(params: DistributionParams): Promise<Distribution> {
    const { asset_id, amount, blueprint, usage_event } = params;
    
    // 1. 扣除协议费
    const protocolFee = amount * 0.001;  // 0.1%
    const remaining = amount - protocolFee;
    
    // 2. 验证者池分配
    const validatorPool = amount * 0.009;  // 0.9%
    
    // 3. 创作者分配
    let creatorShare = remaining - validatorPool;
    
    // 4. 上游衍生分配（检查衍生链）
    const upstreamChain = await getUpstreamChain(asset_id);
    let upstreamTotal = 0;
    
    for (const upstream of upstreamChain) {
      const split = upstream.blueprint.yan.rules.split;
      const upstreamShare = amount * split;
      upstreamTotal += upstreamShare;
      
      // 向上游创作者转账
      await this.ledger.transfer({
        from: "pool",
        to: upstream.creator_id,
        amount: upstreamShare,
        reason: "derivative_royalty",
        source_event: usage_event.event_id
      });
    }
    
    // 5. 扣除上游分成后的创作者份额
    creatorShare -= upstreamTotal;
    
    // 6. 益权份额分配（如果已解锁）
    if (blueprint.yi.level > 0) {
      const investorShares = await getInvestorShares(asset_id);
      for (const investor of investorShares) {
        const investorShare = creatorShare * investor.percentage;
        await this.ledger.transfer({
          from: "pool",
          to: investor.address,
          amount: investorShare,
          reason: "investment_return",
          source_event: usage_event.event_id
        });
      }
    }
    
    // 7. 最终创作者到账
    await this.ledger.transfer({
      from: "pool",
      to: blueprint.metadata.creator.address,
      amount: creatorShare,
      reason: "creator_revenue",
      source_event: usage_event.event_id
    });
    
    return {
      total: amount,
      protocol: protocolFee,
      validators: validatorPool,
      upstream: upstreamTotal,
      creator: creatorShare,
      breakdown: upstreamChain.map(u => ({
        asset_id: u.asset_id,
        creator: u.creator_id,
        split: u.blueprint.yan.rules.split,
        amount: amount * u.blueprint.yan.rules.split
      }))
    };
  }
}
```

---

## 三、沙箱类型与隔离级别

### 3.1 沙箱类型矩阵

| 类型 | 运行时 | 隔离级别 | 启动时间 | 适用场景 | 安全性 |
|------|--------|----------|----------|----------|--------|
| **WebAssembly** | WASM runtime | 内存安全 | <100ms | 纯计算、数据处理 | ★★★★★ |
| **容器** | gVisor/Kata | 系统调用过滤 | 1-3s | 需要IO、网络 | ★★★★☆ |
| **裸机** | Firecracker | 硬件虚拟化 | 100-300ms | 高性能、AI推理 | ★★★★★ |
| **外部** | 创作者自建 | 网络边界 | N/A | 私有部署、合规 | ★★★☆☆ |

### 3.2 WebAssembly沙箱

```typescript
// 最轻量级的沙箱，适合纯计算型Skill
class WASMSandbox implements CreatorSandbox {
  runtime: "wasm";
  engine: "wasmer" | "wasmtime" | "deno";
  
  async execute(request: SkillRequest, wasmModule: WASMModule): Promise<SkillResponse> {
    // 1. 实例化WASM模块
    const instance = await WebAssembly.instantiate(wasmModule, {
      // 宿主环境导入
      env: {
        // 仅暴露安全的宿主函数
        log: (ptr: number, len: number) => this.hostLog(ptr, len),
        emit_event: (ptr: number, len: number) => this.hostEmitEvent(ptr, len),
        call_upstream: (ptr: number, len: number) => this.hostCallUpstream(ptr, len),
        get_time: () => Date.now(),
        // 不暴露：文件系统、网络、环境变量
      }
    });
    
    // 2. 注入内存限制
    const memory = new WebAssembly.Memory({
      initial: 10,      // 640KB初始
      maximum: 100,     // 6.4MB最大
    });
    
    // 3. 执行（CPU时间限制）
    const result = await this.runWithTimeout(
      () => instance.exports.handler(request),
      30000  // 30秒超时
    );
    
    return result;
  }
}
```

### 3.3 容器沙箱（gVisor）

```dockerfile
# gVisor容器沙箱 Dockerfile
FROM scratch

# 最小化基础镜像
COPY --from=builder /app /app
COPY --from=builder /lib /lib

# 无shell、无包管理器
# 所有系统调用经过gVisor过滤

# 资源限制
ENV MEMORY_LIMIT=512m
ENV CPU_LIMIT=1.0
ENV TIMEOUT=30s

# 网络限制（仅允许出站连接到ECHO网络）
ENV ALLOWED_ENDPOINTS="echo-network.internal:443"

# 入口点
ENTRYPOINT ["/app/skill-runner"]
```

```yaml
# gVisor runsc配置
apiVersion: "v1"
spec:
  runtime: "runsc"
  security:
    # 系统调用过滤
    seccomp:
      defaultAction: "SCMP_ACT_ERRNO"
      allowedSyscalls:
        - read
        - write
        - close
        - exit
        - exit_group
        - mmap
        - munmap
        - brk
        # 不允许：open, socket, connect, execve...
    
    # 文件系统隔离
    rootfs:
      readOnly: true
      tmpfs:
        - "/tmp"
    
    # 网络隔离
    network:
      mode: "host"  # 经过gVisor过滤
      allowedHosts:
        - "echo-network.internal"
    
    # 资源限制
    resources:
      memory: "512m"
      cpu: "1000m"
      pids: 10
```

### 3.4 裸机沙箱（Firecracker）

```typescript
// 高性能需求（AI推理、视频处理）
class FirecrackerSandbox implements CreatorSandbox {
  runtime: "firecracker";
  
  async execute(request: SkillRequest, vmImage: VMImage): Promise<SkillResponse> {
    // 1. 启动MicroVM
    const vm = await this.firecracker.createVM({
      kernelImage: "vmlinux-5.10",
      rootfs: vmImage,
      
      // 资源配置
      vcpuCount: 2,
      memSizeMib: 2048,
      
      // 网络配置（仅允许与入口/结算沙箱通信）
      networkInterfaces: [{
        iface_id: "eth0",
        guest_mac: "AA:FC:00:00:00:01",
        host_dev_name: "tap0"
      }],
      
      // 无磁盘、无额外设备
      drives: []
    });
    
    // 2. 发送请求到VM内
    const result = await vm.sendRequest(request);
    
    // 3. 销毁VM（无状态，一次性）
    await vm.destroy();
    
    return result;
  }
}
```

### 3.5 创作者自建沙箱（外部注册）

```typescript
// 创作者拥有自己的服务器，通过API接入ECHO网络
interface ExternalSandbox {
  // 注册到ECHO网络
  async register(config: ExternalConfig): Promise<Registration> {
    // 1. 验证创作者身份
    const creator = await verifyIdentity(config.creator_address);
    
    // 2. 健康检查
    const health = await fetch(`${config.endpoint}/health`);
    if (!health.ok) throw new Error("SANDBOX_UNHEALTHY");
    
    // 3. 能力测试
    const capabilities = await this.testCapabilities(config.endpoint);
    
    // 4. 生成API密钥
    const apiKey = generateSecureKey();
    
    // 5. 注册到网络
    return {
      sandbox_id: `external_${hash(config.endpoint)}`,
      endpoint: config.endpoint,
      api_key_hash: hash(apiKey),
      capabilities,
      status: "active"
    };
  }
  
  // 调用外部沙箱
  async call(request: SkillRequest, sandbox: ExternalSandbox): Promise<SkillResponse> {
    // 1. 发送请求（加密传输）
    const response = await fetch(sandbox.endpoint, {
      method: "POST",
      headers: {
        "X-ECHO-API-Key": sandbox.api_key,
        "X-ECHO-Request-ID": request.request_id
      },
      body: JSON.stringify(request)
    });
    
    // 2. 接收结果 + ZKP证明
    const { result, proof } = await response.json();
    
    // 3. 验证证明
    const isValid = await verifyProof(proof, sandbox.public_key);
    if (!isValid) throw new Error("EXTERNAL_PROOF_INVALID");
    
    return result;
  }
}
```

---

## 四、ZKP集成方案

### 4.1 ZKP框架选择

| 框架 | 证明生成速度 | 验证成本 | 生态成熟度 | 推荐场景 |
|------|-----------|---------|-----------|---------|
| **Risc0** | 中等 | 低 | ★★★★☆ | 通用计算证明 |
| **SP1** | 快 | 低 | ★★★☆☆ | 高性能场景 |
| **Circom/snarkjs** | 慢 | 低 | ★★★★★ | 自定义电路 |
| **Mina (o1js)** | 中等 | 极低 | ★★★☆☆ | 简洁证明 |

**MVP推荐**: Risc0（成熟度高，工具链完善）
**V1.5**: 支持SP1作为高性能选项

### 4.2 证明内容设计

```
ZKP证明的内容（公开输入）：
  ✓ asset_id: Skill标识
  ✓ user_id: 用户标识（哈希）
  ✓ timestamp: 执行时间戳
  ✓ duration_ms: 执行时长
  ✓ compute_units: 计算单元消耗
  ✓ input_hash: 输入数据哈希
  ✓ output_hash: 输出数据哈希
  ✓ memory_mb: 内存消耗
  ✓ rights_hash: 四权配置哈希
  ✓ sandbox_signature: 沙箱签名

ZKP证明不泄露（私有输入）：
  ✗ input_data: 输入数据明文
  ✗ output_data: 输出数据明文
  ✗ model_parameters: AI模型参数
  ✗ execution_trace: 完整执行 trace
  ✗ intermediate_states: 中间状态
```

### 4.3 证明生成流程

```typescript
// 在创作者沙箱内执行
class ZKPGenerator {
  framework: "risc0";
  
  async generate(executionLog: ExecutionLog): Promise<ZKPProof> {
    // 1. 准备证明输入
    const publicInputs = {
      asset_id: executionLog.skill_id,
      user_id_hash: hash(executionLog.user_id),
      timestamp: executionLog.start_time,
      duration_ms: executionLog.duration_ms,
      compute_units: executionLog.compute_units,
      input_hash: executionLog.input_hash,
      output_hash: executionLog.output_hash,
      memory_mb: executionLog.memory_mb,
      rights_hash: executionLog.rights_hash
    };
    
    const privateInputs = {
      // 这些不会被泄露
      input_data: executionLog.input_data,
      output_data: executionLog.output_data,
      execution_trace: executionLog.trace
    };
    
    // 2. 生成证明
    const proof = await risc0.prove({
      guestCode: this.guestProgram,
      publicInputs,
      privateInputs
    });
    
    // 3. 返回证明（可公开验证，但不泄露私有输入）
    return {
      type: "risc0-receipt",
      data: proof.receipt,
      hash: hash(proof.receipt),
      publicInputs,
      // 不包含 privateInputs
    };
  }
}

// Guest Program（Risc0 zkVM内执行）
// 这段代码在zkVM内执行，验证执行的正确性
function guestProgram() {
  // 1. 读取公开输入
  const assetId = env::read();
  const duration = env::read();
  const inputHash = env::read();
  const outputHash = env::read();
  
  // 2. 读取私有输入
  const inputData = env::read();
  const outputData = env::read();
  
  // 3. 验证哈希匹配
  assert(sha256(inputData) === inputHash);
  assert(sha256(outputData) === outputHash);
  
  // 4. 验证执行在合理范围内
  assert(duration > 0);
  assert(duration < 300000);  // 不超过5分钟
  
  // 5. 输出公开输出
  env::commit({
    assetId,
    duration,
    inputHash,
    outputHash,
    verified: true
  });
}
```

### 4.4 验证流程

```typescript
// 在结算沙箱内执行
class ZKPVerifier {
  async verify(proof: ZKPProof): Promise<boolean> {
    if (proof.type === "risc0-receipt") {
      // 1. 验证证明有效性
      const isValid = await risc0.verify(proof.data);
      if (!isValid) return false;
      
      // 2. 验证公开输入与声明一致
      const receipt = risc0.decodeReceipt(proof.data);
      assert(receipt.publicInputs.asset_id === proof.publicInputs.asset_id);
      assert(receipt.publicInputs.timestamp === proof.publicInputs.timestamp);
      
      // 3. 验证执行合理性
      const isReasonable = this.reasonablenessCheck(receipt.publicInputs);
      if (!isReasonable) {
        // 统计异常，标记但不直接拒绝（BA模式）
        this.anomalyDetector.flag(receipt);
      }
      
      return true;
    }
    
    return false;
  }
}
```

---

## 五、PoU（Proof of Use）证明生成

### 5.1 PoU数据结构

```typescript
interface ProofOfUse {
  // 基础信息
  event_id: string;              // 事件唯一ID
  type: "UsageOccurred";
  version: "1.0";
  
  // 参与方
  asset_id: string;              // 被使用的Skill
  user_id: string;               // 使用者
  sandbox_id: string;            // 执行沙箱
  
  // 时间信息
  timestamp: number;             // 事件发生时间（Unix ms）
  timezone: string;              // 时区（用于合规审计）
  
  // 使用详情
  context: {
    // 执行上下文
    task_type: string;            // 任务类型（如"generate_poem"）
    quality_score: number;        // 质量评分（0-1）
    
    // 资源消耗
    duration_ms: number;          // 执行时长
    compute_units: number;        // 标准化计算单元
    memory_mb: number;            // 内存峰值
    tokens_in?: number;           // 输入token数（LLM类）
    tokens_out?: number;          // 输出token数
    
    // 沙箱信息
    sandbox_type: "wasm" | "container" | "baremetal" | "external";
    sandbox_region: string;         // 沙箱地理位置
    
    // 调用链（如果是编排调用）
    call_chain?: string[];         // [parent_request_id, ...]
    orchestration_id?: string;     // 所属编排任务
  };
  
  // 费用信息
  cost: {
    amount: number;               // 费用金额
    currency: "ECHO";
    breakdown: {
      base: number;               // 基础费用
      compute: number;            // 计算资源费用
      premium: number;            // 溢价（如高峰时段）
    };
    
    // 预扣信息
    precharge_id: string;         // 预扣ID
    precharge_amount: number;      // 预扣金额
    actual_amount: number;         // 实际金额
    refund_amount?: number;       // 退款金额（预扣>实际时）
  };
  
  // 证明信息
  proof: {
    type: "zk-SNARK" | "zk-STARK" | "risc0";
    hash: string;                 // 证明哈希
    public_inputs: Record<string, any>;
    // 证明数据本身很大，存储在链下
    storage_ref: string;           // IPFS hash / Arweave ID
  };
  
  // 签名链
  signatures: {
    // 沙箱签名（证明执行确实发生）
    sandbox: {
      key_id: string;              // 沙箱公钥标识
      signature: string;           // 签名
      algorithm: "Ed25519";
      timestamp: number;
    };
    
    // 用户签名（确认使用）
    user: {
      key_id: string;
      signature: string;
      algorithm: "Ed25519";
      timestamp: number;
    };
    
    // 入口沙箱签名（证明请求经过校验）
    ingress?: {
      key_id: string;
      signature: string;
      algorithm: "Ed25519";
      timestamp: number;
    };
  };
  
  // 状态
  status: "pending" | "verified" | "disputed" | "confirmed" | "rejected";
  
  // 争议信息（如有）
  dispute?: {
    dispute_id: string;
    reason: string;
    challenger: string;
    evidence: string[];
    resolution?: "upheld" | "overturned";
  };
  
  // 链上锚定（确认后）
  anchor?: {
    chain: "echo";
    block_height: number;
    tx_hash: string;
    anchored_at: number;
  };
}
```

### 5.2 签名链设计

```
用户请求
  │
  ▼
入口沙箱验证 + 签名
  │ sign(ingress_data, ingress_key)
  ▼
创作者沙箱执行 + 签名
  │ sign(execution_log, sandbox_key)
  ▼
用户确认结果 + 签名
  │ sign(result_hash, user_key)
  ▼
结算沙箱验证 + 结算
  │
  ▼
PoU完整 = { 数据 + 三层签名 }
```

### 5.3 批量PoU策略

```typescript
// 高频调用场景（如聊天机器人）
class BatchPoUManager {
  batchSize: number = 100;        // 每100个事件批量提交
  batchTimeout: number = 60000;  // 或每60秒提交一次
  
  async addEvent(event: UsageEvent): Promise<void> {
    this.buffer.push(event);
    
    if (this.buffer.length >= this.batchSize || 
        Date.now() - this.lastFlush > this.batchTimeout) {
      await this.flush();
    }
  }
  
  async flush(): Promise<void> {
    // 1. 构建Merkle树
    const leaves = this.buffer.map(e => hash(e));
    const merkleTree = buildMerkleTree(leaves);
    const merkleRoot = merkleTree.root;
    
    // 2. 生成批量证明
    const batchProof = {
      type: "batch-merkle",
      root: merkleRoot,
      count: this.buffer.length,
      events: this.buffer.map((e, i) => ({
        event: e,
        merkleProof: merkleTree.getProof(i)
      }))
    };
    
    // 3. 提交到验证网络
    await this.validatorNetwork.submitBatch(batchProof);
    
    // 4. 链上锚定（仅锚定Merkle根）
    await this.chainAnchor.anchor(merkleRoot);
    
    // 5. 清空缓冲区
    this.buffer = [];
    this.lastFlush = Date.now();
  }
}
```

---

## 六、验证节点网络

### 6.1 验证者注册

```typescript
interface ValidatorRegistration {
  // 基本信息
  validator_id: string;
  address: string;               // 区块链地址
  public_key: string;
  
  // 质押
  stake: {
    amount: number;              // 质押ECHO数量
    locked_until: number;         // 解锁时间
  };
  
  // 使用历史（验证者必须有使用历史，不能纯质押）
  usage_history: {
    total_usage_count: number;   // 总使用次数（作为用户）
    total_usage_value: number;   // 总使用金额
    first_usage_at: number;
    last_usage_at: number;
  };
  
  // 验证能力
  capabilities: {
    sandbox_types: string[];      // 可验证的沙箱类型
    zkp_frameworks: string[];     // 支持的ZKP框架
    max_throughput: number;      // 最大验证吞吐量（事件/秒）
  };
  
  // 统计
  stats: {
    total_verified: number;       // 总验证事件数
    accuracy_rate: number;        // 准确率（0-1）
    avg_response_time: number;    // 平均响应时间（ms）
    reputation_score: number;     // 信誉分（0-1）
  };
}

// 注册条件
function canRegister(candidate: Candidate): boolean {
  // 1. 最低质押
  if (candidate.stake.amount < MIN_STAKE) return false;
  
  // 2. 必须有使用历史（关键：不能纯质押获得权力）
  if (candidate.usage_history.total_usage_count < MIN_USAGE_COUNT) return false;
  if (candidate.usage_history.total_usage_value < MIN_USAGE_VALUE) return false;
  
  // 3. 验证能力
  if (candidate.capabilities.zkp_frameworks.length === 0) return false;
  
  return true;
}
```

### 6.2 权重计算

```typescript
function calculateValidatorWeight(validator: Validator): number {
  // 权重 = 50%使用历史 + 30%验证准确率 + 10%质押 + 10%活跃度
  
  const usageScore = Math.min(
    validator.usage_history.total_usage_value / MAX_USAGE_VALUE,
    1.0
  ) * 0.5;
  
  const accuracyScore = validator.stats.accuracy_rate * 0.3;
  
  const stakeScore = Math.min(
    validator.stake.amount / MAX_STAKE,
    1.0
  ) * 0.1;
  
  // 活跃度：最近7天的验证次数 / 平均
  const recentUsage = getRecentUsage(validator, "7d");
  const avgUsage = getAverageUsage("7d");
  const activityScore = Math.min(recentUsage / avgUsage, 1.0) * 0.1;
  
  return usageScore + accuracyScore + stakeScore + activityScore;
}
```

### 6.3 验证流程

```
PoU事件提交
  │
  ▼
分配到验证者委员会（随机选择 + 权重加权）
  │
  ▼
每个验证者独立验证
  ├── 验证ZKP证明有效性
  ├── 验证签名链完整性
  ├── 检查数据合理性
  └── 投票：VALID / INVALID / ABSTAIN
  │
  ▼
聚合投票结果
  ├── ≥2/3 VALID → 通过
  ├── ≥1/3 INVALID → 争议
  └── 其他 → 扩展验证委员会
  │
  ▼
进入7天挑战期
  ├── 任何人可提交争议
  ├── 争议需附带证据
  └── 挑战期结束无争议 → 确认上链
```

### 6.4 罚没机制

| 场景 | 罚没比例 | 说明 |
|------|---------|------|
| 验证错误（ honest mistake）| 10-50% | 统计误差允许，但系统性错误罚没 |
| 恶意伪造证明 | 100% | 全部质押罚没，永久禁入 |
| 长期离线 | 5-20% | 连续7天无响应 |
| 串通作弊 | 100% | 多方合谋验证 |

```typescript
function calculatePenalty(violation: Violation): Penalty {
  switch (violation.type) {
    case "VERIFICATION_ERROR":
      // 根据错误频率计算
      const errorRate = violation.validator.stats.error_rate;
      if (errorRate > 0.5) return { percent: 100, ban: true };
      if (errorRate > 0.2) return { percent: 50, ban: false };
      return { percent: 10, ban: false };
      
    case "FORGERY":
      return { percent: 100, ban: true };
      
    case "OFFLINE":
      const offlineDays = violation.duration / 86400;
      return { percent: Math.min(offlineDays * 2, 20), ban: false };
      
    case "COLLUSION":
      return { percent: 100, ban: true };
      
    default:
      return { percent: 0, ban: false };
  }
}
```

---

## 七、事件流生成

### 7.1 事件类型定义

```typescript
// 沙箱内产生的所有事件类型

type EchoEvent =
  | AssetRegistered
  | UsageOccurred
  | DeploymentEvent
  | DerivativeCreated
  | CitationEvent
  | ShiStateChanged
  | PolicyAdjusted
  | RevenueDistributed
  | DisputeCreated
  | DisputeResolved
  | ValidatorRegistered
  | ValidatorSlashed;

// 核心事件：使用发生
interface UsageOccurred {
  type: "UsageOccurred";
  event_id: string;
  
  // 参与方
  asset_id: string;
  user_id: string;
  sandbox_id: string;
  
  // 时间
  timestamp: number;
  
  // 使用详情
  context: {
    task_type: string;
    quality_score: number;
    duration_ms: number;
    compute_units: number;
    memory_mb: number;
    sandbox_type: string;
    sandbox_region: string;
    call_chain?: string[];
  };
  
  // 费用
  cost: {
    amount: number;
    currency: "ECHO";
    precharge_id: string;
  };
  
  // 证明
  proof: {
    type: string;
    hash: string;
    storage_ref: string;
  };
  
  // 签名
  signatures: {
    sandbox: Signature;
    user: Signature;
  };
}

// 部署事件（用于空间维度计算）
interface DeploymentEvent {
  type: "DeploymentEvent";
  event_id: string;
  asset_id: string;
  sandbox_id: string;
  sandbox_type: string;
  sandbox_region: string;
  deployed_by: string;           // 部署者（通常是创作者）
  timestamp: number;
}

// 衍生创建事件（用于关系维度计算）
interface DerivativeCreated {
  type: "DerivativeCreated";
  event_id: string;
  from_asset_id: string;           // 上游Skill
  to_asset_id: string;            // 新衍生Skill
  creator_id: string;
  derivation_type: "extends" | "uses" | "composes";
  timestamp: number;
}

// 引用事件（用于关系维度计算）
interface CitationEvent {
  type: "CitationEvent";
  event_id: string;
  from_asset_id: string;          // 引用者
  to_asset_id: string;            // 被引用者
  citation_context: string;        // 引用场景
  timestamp: number;
}

// 势状态变更事件
interface ShiStateChanged {
  type: "ShiStateChanged";
  event_id: string;
  asset_id: string;
  from: {
    hexagram: string;
    coordinate: [number, number, number];
  };
  to: {
    hexagram: string;
    coordinate: [number, number, number];
  };
  trigger: string;                 // 触发原因
  timestamp: number;
}

// 收益分配事件
interface RevenueDistributed {
  type: "RevenueDistributed";
  event_id: string;
  parent_event: string;            // 关联的UsageOccurred
  asset_id: string;
  user_id: string;
  distribution: {
    total: number;
    protocol: number;
    validators: number;
    upstream: number;
    creator: number;
    breakdown: Array<{
      asset_id: string;
      creator: string;
      amount: number;
    }>;
  };
  timestamp: number;
}
```

### 7.2 事件流存储架构

```
Kafka事件流（真相来源）
  ├── Topic: echo.events.usage
  ├── Topic: echo.events.deployment
  ├── Topic: echo.events.derivative
  ├── Topic: echo.events.citation
  ├── Topic: echo.events.shi
  ├── Topic: echo.events.revenue
  └── Topic: echo.events.dispute

PostgreSQL（事件持久化）
  ├── 索引：按asset_id + timestamp
  ├── 保留策略：热数据7天，温数据90天，冷数据归档到IPFS
  └── 分区：按月份分区

Redis（状态缓存）
  ├── asset:{id}:usage_count → 累计使用次数
  ├── asset:{id}:revenue_total → 累计收益
  ├── asset:{id}:shi_state → 当前势状态
  └── 可重建：丢失后从Kafka重新计算
```

### 7.3 事件发送流程

```typescript
class EventBus {
  async publish(event: EchoEvent): Promise<void> {
    // 1. 签名事件
    const signedEvent = {
      ...event,
      signature: sign(event, this.privateKey)
    };
    
    // 2. 发送到Kafka
    await this.kafkaProducer.send({
      topic: this.getTopic(event.type),
      messages: [{
        key: event.asset_id,
        value: JSON.stringify(signedEvent),
        headers: {
          "event-type": event.type,
          "event-version": "1.0",
          "sandbox-id": event.sandbox_id || "unknown"
        }
      }]
    });
    
    // 3. 异步写入PostgreSQL（持久化）
    this.asyncPersist(signedEvent);
    
    // 4. 更新Redis缓存（热数据）
    this.updateCache(event);
  }
  
  private getTopic(eventType: string): string {
    const mapping = {
      "UsageOccurred": "echo.events.usage",
      "DeploymentEvent": "echo.events.deployment",
      "DerivativeCreated": "echo.events.derivative",
      "CitationEvent": "echo.events.citation",
      "ShiStateChanged": "echo.events.shi",
      "RevenueDistributed": "echo.events.revenue",
      "PolicyAdjusted": "echo.events.policy",
    };
    return mapping[eventType] || "echo.events.misc";
  }
}
```

### 7.4 事件签名与不可篡改性

```typescript
// 每个事件由产生它的沙箱签名
function signEvent(event: EchoEvent, privateKey: string): SignedEvent {
  // 1. 规范化事件数据（排除已有签名字段）
  const canonical = canonicalize({
    type: event.type,
    event_id: event.event_id,
    asset_id: event.asset_id,
    timestamp: event.timestamp,
    // ... 其他字段
  });
  
  // 2. 计算哈希
  const hash = sha256(canonical);
  
  // 3. 签名
  const signature = sign(hash, privateKey);
  
  return {
    ...event,
    signature: {
      hash,
      signature,
      algorithm: "Ed25519",
      signer: derivePublicKey(privateKey)
    }
  };
}

// 验证事件
function verifyEvent(signedEvent: SignedEvent, publicKey: string): boolean {
  // 1. 重新计算哈希
  const canonical = canonicalize({
    type: signedEvent.type,
    event_id: signedEvent.event_id,
    // ...
  });
  const hash = sha256(canonical);
  
  // 2. 验证哈希匹配
  if (hash !== signedEvent.signature.hash) return false;
  
  // 3. 验证签名
  return verify(hash, signedEvent.signature.signature, publicKey);
}
```

---

## 八、7天挑战期机制

### 8.1 挑战期流程

```
PoU验证通过
  │
  ▼
进入7天挑战期
  ├── 状态: pending → challenged_available
  ├── 事件广播到全网
  └── 任何人可提交挑战
  │
  ├── 7天内无挑战
  │     └── 自动确认 → 状态: confirmed → 链上锚定
  │
  └── 7天内有挑战
        ├── 挑战者提交证据
        ├── 扩展验证委员会（更多验证者参与）
        ├── 证据审查
        └── 投票裁决
              ├── 维持原判 → 挑战者罚没押金
              └── 推翻原判 → 原验证者罚没
```

### 8.2 争议类型

| 争议类型 | 说明 | 证据要求 |
|---------|------|---------|
| **假执行** | 声称执行未真实发生 | 沙箱日志、网络抓包 |
| **数据篡改** | 声称输入/输出被篡改 | 原始数据哈希对比 |
| **四权违规** | 声称未按蓝图执行 | 蓝图配置 vs 实际执行 |
| **收益分配错误** | 声称分配金额有误 | 计算过程、汇率证据 |
| **刷量** | 声称使用数据造假 | 使用模式分析、关联分析 |

### 8.3 仲裁机制

```typescript
interface DisputeArbitration {
  // 争议创建
  async createDispute(challenge: Challenge): Promise<Dispute> {
    // 1. 验证挑战者押金
    if (challenge.deposit < MIN_CHALLENGE_DEPOSIT) {
      throw new Error("INSUFFICIENT_DEPOSIT");
    }
    
    // 2. 锁定原PoU
    await this.lockPoU(challenge.target_event_id);
    
    // 3. 创建争议
    const dispute = {
      dispute_id: generateId(),
      target_event: challenge.target_event_id,
      challenger: challenge.challenger,
      type: challenge.type,
      evidence: challenge.evidence,
      deposit: challenge.deposit,
      status: "open",
      created_at: Date.now()
    };
    
    // 4. 扩展验证委员会（随机选择高权重验证者）
    const jury = await this.selectJury(11);  // 11人陪审团
    
    return { ...dispute, jury };
  }
  
  // 裁决
  async resolve(disputeId: string, juryVotes: Vote[]): Promise<Resolution> {
    const dispute = await this.getDispute(disputeId);
    
    // 1. 统计投票
    const forCount = juryVotes.filter(v => v.verdict === "for").length;
    const againstCount = juryVotes.filter(v => v.verdict === "against").length;
    
    // 2. 裁决规则
    if (forCount >= 7) {
      // 维持原PoU
      await this.confirmPoU(dispute.target_event);
      await this.slashChallenger(dispute.challenger, dispute.deposit);
      return { verdict: "upheld", reason: "Jury voted to uphold" };
    } else if (againstCount >= 7) {
      // 推翻原PoU
      await this.rejectPoU(dispute.target_event);
      await this.slashValidators(dispute.target_event);
      await this.returnDeposit(dispute.challenger, dispute.deposit);
      return { verdict: "overturned", reason: "Jury voted to overturn" };
    } else {
      // 平局 → 延长挑战期或引入更多验证者
      return { verdict: "extended", reason: "Inconclusive jury vote" };
    }
  }
}
```

---

## 九、性能与优化

### 9.1 延迟优化

```
优化前（同步结算）：
  用户请求 → 入口验证(50ms) → 沙箱执行(1000ms) → ZKP生成(500ms) 
    → 结算验证(200ms) → 链上锚定(3000ms) → 返回结果
  总计: ~4750ms

优化后（异步结算）：
  用户请求 → 入口验证(50ms) → 沙箱执行(1000ms) → 返回结果(1050ms)
    → ZKP生成(500ms，后台)
    → 结算验证(200ms，后台)
    → 链上锚定(3000ms，批量)
  总计: ~1050ms（用户体验）
```

### 9.2 缓存策略

```typescript
class MultiTierCache {
  // L1: 本地内存缓存（最热数据）
  l1: Map<string, CacheEntry> = new Map();
  
  // L2: Redis集群（热数据）
  l2: RedisClient;
  
  // L3: PostgreSQL（温数据）
  l3: PostgreSQLClient;
  
  // L4: IPFS/Arweave（冷数据，归档）
  l4: IPFSClient;
  
  async get(key: string): Promise<any> {
    // 1. 查L1
    if (this.l1.has(key)) {
      return this.l1.get(key).value;
    }
    
    // 2. 查L2
    const l2Value = await this.l2.get(key);
    if (l2Value) {
      this.l1.set(key, { value: l2Value, ttl: 60000 });
      return l2Value;
    }
    
    // 3. 查L3
    const l3Value = await this.l3.query(key);
    if (l3Value) {
      this.l2.set(key, l3Value, "EX", 3600);
      return l3Value;
    }
    
    // 4. 查L4（罕见）
    const l4Value = await this.l4.get(key);
    if (l4Value) {
      this.l3.insert(key, l4Value);
      return l4Value;
    }
    
    return null;
  }
}
```

---

## 十、故障归属与SLA

### 10.1 分层故障归属

| 故障 | 归属 | ECHO责任 | 创作者责任 |
|------|------|---------|-----------|
| 入口沙箱不可用 | ECHO层 | 100% | 0% |
| 结算延迟 | ECHO层 | 100% | 0% |
| Skill执行错误 | 创作者层 | 0% | 100% |
| Skill性能差 | 创作者层 | 0% | 100% |
| ZKP生成失败 | 创作者层 | 0% | 100% |
| 网络传输失败 | 取决于 | 50% | 50% |

### 10.2 SLA承诺

```
ECHO层承诺:
  - 入口可用性: 99.9%
  - 结算延迟: P99 < 5秒
  - 验证延迟: P99 < 30秒
  - 链上锚定: 每10分钟批量锚定

创作者层承诺（建议）:
  - Skill响应延迟: P99 < 3秒（由创作者设定）
  - Skill可用性: 99%（由创作者设定）
  - 错误率: < 1%（由创作者设定）
```

---

> **设计参考**: 沙箱架构参考 Cloudflare Workers 的隔离模型 + Stripe 的结算可靠性 + Bitcoin 的PoW验证激励。目标：创作者完全主权 + 用户完全信任 + 网络完全透明。
