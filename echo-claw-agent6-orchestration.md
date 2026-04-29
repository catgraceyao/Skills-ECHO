# ECHO Claw - Agent编排与四权调用设计

**版本**: v1.0 | **日期**: 2026-04-21 | **状态**: 详细设计

---

## 一、Agent编排架构

### 1.1 编排流程

```
用户意图: "写一首关于春天的诗，翻译成英文，然后朗读"

   │
   ▼
┌─────────────────────────────────────────────────────────────┐
│                   意图理解 (Intent Parser)                   │
│                                                              │
│  分解为3个步骤:                                               │
│  1. generate_poem(theme="春天", style="唐诗")                │
│  2. translate(text=step1.output, target="英文")              │
│  3. tts(text=step2.output, voice="标准女声")                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────────────────┐
│                   任务图构建 (Task Graph)                     │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ Skill A      │───→│ Skill B      │───→│ Skill C      │  │
│  │ 写诗         │    │ 翻译         │    │ TTS          │  │
│  │              │    │              │    │              │  │
│  │ output: poem │    │ input: poem  │    │ input: text  │  │
│  │              │    │ output: text │    │ output: audio│  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│                                                              │
│  依赖: A → B → C (线性链)                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────────────────┐
│                   编排执行 (Orchestrator)                     │
│                                                              │
│  Step 1: 调用 Skill A                                        │
│    ├── 四权检查: 用权? ✓ 扩权? ✓                              │
│    ├── 费用预估: 0.01 ECHO                                    │
│    ├── 执行调用                                               │
│    └── 结果: {poem: "春眠不觉晓..."}                         │
│                                                              │
│  Step 2: 调用 Skill B (用Step1输出作为输入)                   │
│    ├── 四权检查: 用权? ✓                                      │
│    ├── 数据流: step1.output.poem → step2.input.text           │
│    ├── 费用预估: 0.02 ECHO                                    │
│    ├── 执行调用                                               │
│    └── 结果: {text: "Spring sleep is unaware of dawn..."}   │
│                                                              │
│  Step 3: 调用 Skill C                                        │
│    ├── 四权检查: 用权? ✓                                      │
│    ├── 数据流: step2.output.text → step3.input.text           │
│    ├── 费用预估: 0.01 ECHO                                    │
│    ├── 执行调用                                               │
│    └── 结果: {audio_url: "..."}                              │
│                                                              │
│  总费用: 0.04 ECHO                                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
   │
   ▼
用户收到: 诗歌原文 + 英文翻译 + 朗读音频
```

### 1.2 编排引擎核心设计

```typescript
interface Orchestrator {
  // 执行编排
  async orchestrate(
    intent: string,
    options?: OrchestrationOptions
  ): Promise<OrchestrationResult>;
  
  // 执行预定义编排
  async executeGraph(
    graph: TaskGraph,
    context: ExecutionContext
  ): Promise<ExecutionResult>;
  
  // 动态编排（运行时决策）
  async dynamicOrchestrate(
    intent: string,
    context: ExecutionContext
  ): Promise<OrchestrationResult>;
}

interface TaskGraph {
  nodes: TaskNode[];
  edges: TaskEdge[];
  
  // 执行策略
  strategy: "sequential" | "parallel" | "mixed";
  
  // 错误处理
  errorHandling: {
    mode: "fail_fast" | "continue" | "retry";
    maxRetries: number;
    fallback?: TaskNode;
  };
}

interface TaskNode {
  id: string;
  skill_id: string;
  blueprint_version?: string;
  
  // 输入映射
  inputMapping: {
    [paramName: string]: string;   // "theme": "step1.output.theme"
  };
  
  // 输出映射
  outputMapping: {
    [resultKey: string]: string; // "poem": "result.poem"
  };
  
  // 条件执行
  condition?: string;              // "step1.output.quality > 0.8"
  
  // 超时
  timeout: number;
}

interface TaskEdge {
  from: string;
  to: string;
  
  // 数据流
  dataFlow: {
    fromOutput: string;
    toInput: string;
  }[];
}
```

---

## 二、四权调用引擎

### 2.1 调用流程

```typescript
class RightsEngine {
  async executeCall(
    request: SkillCallRequest,
    callerContext: CallerContext
  ): Promise<SkillCallResult> {
    // 1. 获取Skill蓝图
    const blueprint = await this.getBlueprint(
      request.skill_id,
      request.blueprint_version
    );
    
    // 2. 四权检查 - 用权
    const usageCheck = this.checkUsageRights(blueprint, callerContext);
    if (!usageCheck.allowed) {
      return { status: "DENIED", reason: usageCheck.reason };
    }
    
    // 3. 四权检查 - 扩权
    const expansionCheck = this.checkExpansionRights(blueprint, callerContext);
    if (!expansionCheck.allowed) {
      return { status: "DENIED", reason: expansionCheck.reason };
    }
    
    // 4. 四权检查 - 衍权（如果本次调用是用于衍生）
    if (callerContext.isDerivative) {
      const derivativeCheck = this.checkDerivativeRights(blueprint, callerContext);
      if (!derivativeCheck.allowed) {
        return { status: "DENIED", reason: derivativeCheck.reason };
      }
    }
    
    // 5. 四权检查 - 益权（费用计算）
    const cost = this.calculateCost(blueprint, request.params, callerContext);
    
    // 6. 检查余额
    const balance = await this.getBalance(callerContext.user_id);
    if (balance < cost.estimated) {
      return { status: "DENIED", reason: "INSUFFICIENT_BALANCE" };
    }
    
    // 7. 预扣费用
    const precharge = await this.precharge(callerContext.user_id, cost.estimated);
    
    // 8. 检查授权凭证
    const authCredential = await this.getAuthCredential(
      callerContext.user_id,
      request.skill_id
    );
    if (!authCredential || authCredential.quota.remaining <= 0) {
      return { status: "DENIED", reason: "NO_AUTHORIZATION" };
    }
    
    // 9. 路由到沙箱
    const sandbox = await this.selectSandbox(request.skill_id);
    
    // 10. 执行
    const result = await this.callSandbox(request, sandbox, {
      ...callerContext,
      precharge_id: precharge.id,
      auth_credential: authCredential
    });
    
    // 11. 计算实际费用
    const actualCost = this.calculateActualCost(result.usage, blueprint);
    
    // 12. 结算
    await this.settle({
      user_id: callerContext.user_id,
      skill_id: request.skill_id,
      amount: actualCost,
      precharge_id: precharge.id,
      usage: result.usage
    });
    
    // 13. 生成PoU
    const pou = await this.generatePoU(request, result, actualCost);
    
    return {
      status: "SUCCESS",
      data: result.data,
      cost: actualCost,
      pou_hash: pou.hash
    };
  }
  
  // 用权检查
  private checkUsageRights(
    blueprint: Blueprint,
    context: CallerContext
  ): RightsCheckResult {
    // 1. 检查用权是否启用
    if (!blueprint.yong.enabled) {
      return { allowed: false, reason: "USAGE_DISABLED" };
    }
    
    // 2. 检查用权等级
    if (blueprint.yong.level === 0) {
      return { allowed: false, reason: "USAGE_LEVEL_ZERO" };
    }
    
    // 3. 检查白名单
    if (blueprint.yong.access_control.whitelist.length > 0) {
      if (!blueprint.yong.access_control.whitelist.includes(context.user_id)) {
        return { allowed: false, reason: "NOT_IN_WHITELIST" };
      }
    }
    
    // 4. 检查黑名单
    if (blueprint.yong.access_control.blacklist.includes(context.user_id)) {
      return { allowed: false, reason: "IN_BLACKLIST" };
    }
    
    // 5. 检查身份验证要求
    if (blueprint.yong.access_control.require_auth && !context.authenticated) {
      return { allowed: false, reason: "AUTH_REQUIRED" };
    }
    
    // 6. 检查时间窗口
    if (blueprint.yong.conditions) {
      const timeCondition = blueprint.yong.conditions.find(
        c => c.type === "time_window"
      );
      if (timeCondition) {
        const hour = new Date().getHours();
        if (hour < timeCondition.allowed_hours[0] || 
            hour > timeCondition.allowed_hours[1]) {
          return { allowed: false, reason: "OUTSIDE_TIME_WINDOW" };
        }
      }
    }
    
    return { allowed: true };
  }
  
  // 扩权检查
  private checkExpansionRights(
    blueprint: Blueprint,
    context: CallerContext
  ): RightsCheckResult {
    // 1. 检查平台白名单
    const platform = context.platform || "echo";
    if (!blueprint.kuo.platforms.includes(platform)) {
      return { allowed: false, reason: "PLATFORM_NOT_ALLOWED" };
    }
    
    // 2. 检查可见性
    if (blueprint.kuo.visibility === "private") {
      if (context.user_id !== blueprint.metadata.creator.address) {
        return { allowed: false, reason: "PRIVATE_SKILL" };
      }
    }
    
    return { allowed: true };
  }
  
  // 衍权检查
  private checkDerivativeRights(
    blueprint: Blueprint,
    context: CallerContext
  ): RightsCheckResult {
    // 1. 检查衍权是否启用
    if (!blueprint.yan.enabled) {
      return { allowed: false, reason: "DERIVATIVE_DISABLED" };
    }
    
    // 2. 检查是否允许衍生
    if (!blueprint.yan.rules.allow_derivative) {
      return { allowed: false, reason: "DERIVATIVE_NOT_ALLOWED" };
    }
    
    // 3. 检查衍生深度
    const currentDepth = context.derivation_depth || 0;
    if (currentDepth >= blueprint.yan.rules.max_depth) {
      return { allowed: false, reason: "MAX_DERIVATIVE_DEPTH_REACHED" };
    }
    
    // 4. 检查是否需要审批
    if (blueprint.yan.rules.require_approval) {
      const isApproved = await this.checkApproval(
        blueprint.metadata.creator.address,
        context.user_id
      );
      if (!isApproved) {
        return { allowed: false, reason: "APPROVAL_REQUIRED" };
      }
    }
    
    // 5. 检查冷却期
    if (blueprint.yan.cooldown) {
      const lastDerivative = await this.getLastDerivative(
        context.user_id,
        context.skill_id
      );
      if (lastDerivative) {
        const cooldownMs = parseDuration(blueprint.yan.cooldown.between_derivatives);
        if (Date.now() - lastDerivative < cooldownMs) {
          return { allowed: false, reason: "COOLDOWN_ACTIVE" };
        }
      }
    }
    
    return { allowed: true };
  }
  
  // 费用计算
  private calculateCost(
    blueprint: Blueprint,
    params: any,
    context: CallerContext
  ): CostEstimate {
    const pricing = blueprint.yong.pricing;
    
    switch (pricing.model) {
      case "per_call":
        return { estimated: pricing.price, currency: pricing.currency };
        
      case "per_minute":
        const estimatedDuration = context.estimated_duration || 60;
        return {
          estimated: pricing.price * (estimatedDuration / 60),
          currency: pricing.currency
        };
        
      case "per_token":
        const estimatedTokens = this.estimateTokens(params);
        return {
          estimated: pricing.price * estimatedTokens,
          currency: pricing.currency
        };
        
      case "tiered":
        const usageCount = context.monthly_usage_count || 0;
        const tier = pricing.tiers.find(
          t => usageCount >= t.threshold
        ) || pricing.tiers[pricing.tiers.length - 1];
        return { estimated: tier.price, currency: pricing.currency };
        
      case "freemium":
        const freeQuota = pricing.freemium.free_quota;
        const usedQuota = context.monthly_usage_count || 0;
        if (usedQuota < freeQuota) {
          return { estimated: 0, currency: pricing.currency };
        }
        return {
          estimated: pricing.freemium.overage_price,
          currency: pricing.currency
        };
        
      case "subscription":
        const plan = context.subscription_plan;
        if (!plan) {
          return { estimated: Infinity, currency: pricing.currency };
        }
        const quotaRemaining = plan.quota - (context.monthly_usage_count || 0);
        if (quotaRemaining > 0) {
          return { estimated: 0, currency: pricing.currency };
        }
        return {
          estimated: plan.overage_price || pricing.price,
          currency: pricing.currency
        };
        
      default:
        return { estimated: 0, currency: "ECHO" };
    }
  }
}
```

### 2.2 收益分配执行

```typescript
class RevenueDistribution {
  async distribute(
    skillId: string,
    amount: number,
    usageEvent: UsageEvent
  ): Promise<DistributionResult> {
    const blueprint = await this.getBlueprint(skillId);
    
    // 1. 扣除协议费
    const protocolFee = amount * 0.001;
    await this.transferToProtocol(protocolFee);
    
    // 2. 验证者池
    const validatorPool = amount * 0.009;
    await this.transferToValidatorPool(validatorPool);
    
    // 3. 上游衍生分配
    const upstreamChain = await this.getUpstreamChain(skillId);
    let upstreamTotal = 0;
    const upstreamBreakdown = [];
    
    for (const upstream of upstreamChain) {
      const split = upstream.blueprint.yan.rules.split;
      const upstreamShare = amount * split;
      upstreamTotal += upstreamShare;
      
      await this.transfer({
        to: upstream.creator_id,
        amount: upstreamShare,
        reason: "derivative_royalty",
        source: usageEvent.event_id
      });
      
      upstreamBreakdown.push({
        asset_id: upstream.asset_id,
        creator: upstream.creator_id,
        split,
        amount: upstreamShare
      });
    }
    
    // 4. 益权份额分配（如果已解锁）
    let investorTotal = 0;
    if (blueprint.yi.level > 0) {
      const investorShares = await this.getInvestorShares(skillId);
      const creatorShareAfterUpstream = amount - protocolFee - validatorPool - upstreamTotal;
      
      for (const investor of investorShares) {
        const investorShare = creatorShareAfterUpstream * investor.percentage;
        investorTotal += investorShare;
        
        await this.transfer({
          to: investor.address,
          amount: investorShare,
          reason: "investment_return",
          source: usageEvent.event_id
        });
      }
    }
    
    // 5. 创作者最终到账
    const creatorShare = amount - protocolFee - validatorPool - upstreamTotal - investorTotal;
    await this.transfer({
      to: blueprint.metadata.creator.address,
      amount: creatorShare,
      reason: "creator_revenue",
      source: usageEvent.event_id
    });
    
    return {
      total: amount,
      protocol: protocolFee,
      validators: validatorPool,
      upstream: {
        total: upstreamTotal,
        breakdown: upstreamBreakdown
      },
      investors: investorTotal,
      creator: creatorShare
    };
  }
}
```

---

## 三、编排文件格式

### 3.1 YAML编排定义

```yaml
# orchestration.yaml
version: "1.0"
name: "诗歌翻译朗读"
description: "写诗、翻译、朗读一条龙"

# 步骤定义
steps:
  - id: "step1"
    name: "写诗"
    skill_id: "skill_poet_alice"
    blueprint_version: "1.0.0-a7f3e"
    
    input:
      theme: "$.user_input.theme"
      style: "$.user_input.style"
    
    output:
      poem: "$.result.poem"
    
    timeout: 30000
    
  - id: "step2"
    name: "翻译"
    skill_id: "skill_translator_bob"
    
    input:
      text: "$.step1.output.poem"
      target_language: "英文"
    
    output:
      translated: "$.result.text"
    
    timeout: 30000
    
    # 条件执行
    condition: "$.step1.output.quality > 0.7"
    
  - id: "step3"
    name: "朗读"
    skill_id: "skill_tts_carol"
    
    input:
      text: "$.step2.output.translated"
      voice: "标准女声"
    
    output:
      audio: "$.result.audio_url"
    
    timeout: 60000

# 执行策略
strategy: "sequential"  # sequential | parallel | mixed

# 错误处理
error_handling:
  mode: "fail_fast"     # fail_fast | continue | retry
  max_retries: 2
  
  fallback:
    - step_id: "step2"
      fallback_skill: "skill_basic_translator"
      condition: "timeout"

# 数据流
data_flow:
  - from: "step1"
    to: "step2"
    mappings:
      - from: "poem"
        to: "text"
        
  - from: "step2"
    to: "step3"
    mappings:
      - from: "translated"
        to: "text"

# 费用预估
 cost_estimation:
   auto: true
   # 或手动指定
   # steps:
   #   - step_id: "step1"
   #     estimated_cost: 0.01
```

### 3.2 JSON编排定义

```json
{
  "version": "1.0",
  "name": "诗歌翻译朗读",
  "steps": [
    {
      "id": "step1",
      "skill_id": "skill_poet_alice",
      "input": {
        "theme": "$.user_input.theme"
      },
      "output": {
        "poem": "$.result.poem"
      }
    }
  ],
  "connections": [
    {
      "from": "step1",
      "to": "step2",
      "mapping": {
        "poem": "text"
      }
    }
  ]
}
```

---

## 四、复杂编排模式

### 4.1 并行执行

```
用户意图: "同时生成一首诗、一幅画、一段音乐"

┌─────────────────────────────────────────────────────────────┐
│                   并行编排 (Parallel)                         │
│                                                              │
│     ┌──────────────┐                                        │
│     │   输入处理     │                                        │
│     │              │                                        │
│     │ theme="春天" │                                        │
│     └──────┬───────┘                                        │
│            │                                                 │
│     ┌──────┼──────┐                                         │
│     │      │      │                                         │
│     ▼      ▼      ▼                                         │
│ ┌──────┐ ┌──────┐ ┌──────┐                                │
│ │写诗   │ │画画   │ │作曲   │                                │
│ │0.01   │ │0.02  │ │0.015 │                                │
│ │      │ │      │ │      │                                │
│ └──────┘ └──────┘ └──────┘                                │
│     │      │      │                                         │
│     └──────┼──────┘                                         │
│            │                                                 │
│     ┌──────▼──────┐                                         │
│     │  结果聚合    │                                         │
│     │            │                                         │
│     │ {poem,     │                                         │
│     │  image,    │                                         │
│     │  music}    │                                         │
│     └─────────────┘                                         │
│                                                              │
│  总费用: max(0.01, 0.02, 0.015) = 0.02 ECHO (并行取最大)     │
│  总时间: max(时间1, 时间2, 时间3)                             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 条件分支

```yaml
# 条件编排
steps:
  - id: "classify"
    skill_id: "skill_intent_classifier"
    input:
      text: "$.user_input"
    output:
      intent: "$.result.intent"
      confidence: "$.result.confidence"

  - id: "route"
    type: "condition"
    branches:
      - condition: "$.classify.output.intent == 'poetry'"
        steps:
          - id: "write_poem"
            skill_id: "skill_poet"
            input:
              theme: "$.user_input.theme"
      
      - condition: "$.classify.output.intent == 'image'"
        steps:
          - id: "draw_image"
            skill_id: "skill_artist"
            input:
              description: "$.user_input.description"
      
      - condition: "default"
        steps:
          - id: "chat"
            skill_id: "skill_chatbot"
            input:
              message: "$.user_input"
```

### 4.3 循环执行

```yaml
# 迭代优化
steps:
  - id: "generate"
    skill_id: "skill_generator"
    input:
      prompt: "$.user_input.prompt"
    output:
      result: "$.result"

  - id: "evaluate"
    skill_id: "skill_evaluator"
    input:
      content: "$.generate.output.result"
    output:
      score: "$.result.score"

  - id: "improve"
    skill_id: "skill_improver"
    input:
      content: "$.generate.output.result"
      feedback: "$.evaluate.output.feedback"
    output:
      improved: "$.result"

  # 循环直到质量达标
  loop:
    max_iterations: 5
    condition: "$.evaluate.output.score < 0.9"
    continue_with: "$.improve.output.improved"
```

### 4.4 错误恢复

```yaml
error_handling:
  mode: "retry"
  max_retries: 3
  backoff: "exponential"  # exponential | linear | fixed
  
  # 按错误类型处理
  error_map:
    TIMEOUT:
      action: "retry"
      delay: 5000
      
    RATE_LIMIT:
      action: "retry"
      delay: 60000
      
    INSUFFICIENT_BALANCE:
      action: "fail"
      message: "余额不足，请充值"
      
    SKILL_UNAVAILABLE:
      action: "fallback"
      fallback_skill: "skill_backup"
      
    USAGE_DENIED:
      action: "fail"
      message: "无使用权限"

# 全局fallback
fallback:
  - skill_id: "skill_error_handler"
    input:
      error: "$.error"
      context: "$.context"
```

---

## 五、自然语言编排

### 5.1 Intent Parser

```typescript
class IntentParser {
  async parse(intent: string): Promise<ParsedIntent> {
    // 使用LLM或规则引擎解析意图
    
    // 示例输入: "写一首关于春天的诗，翻译成英文，然后朗读"
    // 解析结果:
    const parsed = {
      steps: [
        {
          action: "generate_poem",
          params: { theme: "春天" },
          skill_hint: "poetry"
        },
        {
          action: "translate",
          params: { target: "英文" },
          input_from: "step1",
          skill_hint: "translation"
        },
        {
          action: "text_to_speech",
          params: {},
          input_from: "step2",
          skill_hint: "tts"
        }
      ],
      
      // 发现的歧义
      ambiguities: [
        {
          param: "style",
          options: ["唐诗", "现代诗", "宋词"],
          default: "唐诗"
        }
      ]
    };
    
    return parsed;
  }
  
  // Skill匹配
  async matchSkills(parsedIntent: ParsedIntent): Promise<SkillMatch[]> {
    const matches = [];
    
    for (const step of parsedIntent.steps) {
      // 1. 查询ShiGraph
      const candidates = await this.shiGraph.query({
        filters: {
          tags: [step.skill_hint],
          rights: { yong: { min: 1 } }
        },
        sort: { field: "potential", direction: "desc" },
        pagination: { limit: 5, offset: 0 }
      });
      
      // 2. 语义匹配
      const scored = candidates.results.map(skill => ({
        skill,
        semantic_score: this.semanticMatch(step, skill),
        rights_score: this.rightsCompatibility(step, skill),
        cost_score: this.costEfficiency(step, skill),
        reliability_score: skill.stats.accuracy_rate
      }));
      
      // 3. 综合排序
      scored.sort((a, b) => {
        const scoreA = a.semantic_score * 0.4 + 
                       a.rights_score * 0.3 + 
                       a.cost_score * 0.2 + 
                       a.reliability_score * 0.1;
        const scoreB = b.semantic_score * 0.4 + 
                       b.rights_score * 0.3 + 
                       b.cost_score * 0.2 + 
                       b.reliability_score * 0.1;
        return scoreB - scoreA;
      });
      
      matches.push({
        step_id: step.action,
        matched_skills: scored.slice(0, 3)
      });
    }
    
    return matches;
  }
}
```

### 5.2 CLI自然语言编排

```bash
# 自然语言调用
echo-claw run "写一首关于春天的诗，翻译成英文，然后朗读"

# 输出:
# 解析意图...
# ✓ 发现3个步骤:
#   1. 写诗 (主题: 春天)
#   2. 翻译 (目标: 英文)
#   3. 朗读
#
# 匹配Skill...
#   1. 写诗 → skill_poet_alice (势能: 0.78, 价格: 0.01)
#   2. 翻译 → skill_translator_bob (势能: 0.65, 价格: 0.02)
#   3. 朗读 → skill_tts_carol (势能: 0.82, 价格: 0.01)
#
# 预估费用: 0.04 ECHO
# 确认执行? [Y/n] Y
#
# 执行中...
# [1/3] 写诗... ✓ (用时 1.2s)
# [2/3] 翻译... ✓ (用时 0.8s)
# [3/3] 朗读... ✓ (用时 2.1s)
#
# ✅ 完成!
# 诗歌: 春眠不觉晓，处处闻啼鸟...
# 翻译: Spring sleep is unaware of dawn...
# 音频: [播放按钮]
#
# 实际费用: 0.04 ECHO
```

---

## 六、智能合约集成

### 6.1 合约接口

```solidity
// ECHO Orchestrator Contract
interface IECHOOrchestrator {
    // 注册编排
    function registerOrchestration(
        bytes32 orchestrationId,
        bytes32[] memory skillIds,
        bytes memory blueprint
    ) external returns (bool);
    
    // 执行编排
    function executeOrchestration(
        bytes32 orchestrationId,
        bytes memory params
    ) external payable returns (bytes memory);
    
    // 查询编排状态
    function getOrchestrationStatus(bytes32 orchestrationId)
        external
        view
        returns (
            uint256 totalSteps,
            uint256 completedSteps,
            uint256 totalCost,
            bool isComplete
        );
    
    // 事件
    event OrchestrationRegistered(bytes32 indexed orchestrationId, address indexed creator);
    event OrchestrationStarted(bytes32 indexed orchestrationId, address indexed executor);
    event StepCompleted(bytes32 indexed orchestrationId, uint256 stepIndex, bytes32 skillId);
    event OrchestrationCompleted(bytes32 indexed orchestrationId, uint256 totalCost);
}

// ECHO Rights Engine Contract
interface IECHORightsEngine {
    // 四权检查
    function checkRights(
        bytes32 skillId,
        address user,
        uint8 rightType,      // 0=yong, 1=yan, 2=kuo, 3=yi
        bytes memory context
    ) external view returns (bool allowed, string memory reason);
    
    // 计算费用
    function calculateCost(
        bytes32 skillId,
        bytes memory params,
        address user
    ) external view returns (uint256 cost);
    
    // 执行收益分配
    function distributeRevenue(
        bytes32 skillId,
        uint256 amount,
        bytes32 usageEventId
    ) external returns (bool);
    
    // 事件
    event RightsChecked(bytes32 indexed skillId, address indexed user, bool allowed);
    event RevenueDistributed(bytes32 indexed skillId, uint256 amount, uint256 creatorShare);
}
```

### 6.2 编排上链

```typescript
// 将编排定义锚定到链上
class OrchestrationAnchor {
  async anchor(orchestration: OrchestrationDefinition): Promise<AnchorResult> {
    // 1. 计算编排哈希
    const hash = sha256(JSON.stringify(orchestration));
    
    // 2. 提交到链上
    const tx = await this.contract.registerOrchestration(
      hash,
      orchestration.steps.map(s => s.skill_id),
      JSON.stringify(orchestration)
    );
    
    return {
      orchestration_id: hash,
      tx_hash: tx.hash,
      status: "registered"
    };
  }
  
  // 验证编排完整性
  async verify(orchestrationId: string): Promise<boolean> {
    // 1. 获取链上记录
    const onChain = await this.contract.getOrchestration(orchestrationId);
    
    // 2. 获取本地定义
    const local = await this.loadOrchestration(orchestrationId);
    
    // 3. 验证哈希匹配
    const localHash = sha256(JSON.stringify(local));
    return localHash === onChain.hash;
  }
}
```

---

## 七、费用预估与预算控制

### 7.1 预估算法

```typescript
class CostEstimator {
  async estimateOrchestration(
    orchestration: OrchestrationDefinition,
    context: ExecutionContext
  ): Promise<CostEstimate> {
    let totalMin = 0;
    let totalMax = 0;
    const breakdown = [];
    
    for (const step of orchestration.steps) {
      // 1. 获取Skill蓝图
      const blueprint = await this.getBlueprint(step.skill_id);
      
      // 2. 计算单步费用范围
      const stepCost = this.estimateStepCost(step, blueprint, context);
      
      totalMin += stepCost.min;
      totalMax += stepCost.max;
      
      breakdown.push({
        step_id: step.id,
        skill_id: step.skill_id,
        min: stepCost.min,
        max: stepCost.max,
        pricing_model: blueprint.yong.pricing.model
      });
    }
    
    // 3. 考虑并行执行（取最大而非求和）
    if (orchestration.strategy === "parallel") {
      const parallelGroups = this.groupParallelSteps(orchestration);
      totalMin = parallelGroups.reduce(
        (sum, group) => sum + Math.max(...group.map(s => s.min)),
        0
      );
      totalMax = parallelGroups.reduce(
        (sum, group) => sum + Math.max(...group.map(s => s.max)),
        0
      );
    }
    
    return {
      total_min: totalMin,
      total_max: totalMax,
      breakdown,
      currency: "ECHO"
    };
  }
}
```

### 7.2 预算控制

```typescript
class BudgetController {
  async checkBudget(
    userId: string,
    estimate: CostEstimate,
    options?: BudgetOptions
  ): Promise<BudgetCheck> {
    // 1. 获取用户预算设置
    const budget = await this.getUserBudget(userId);
    
    // 2. 检查单次限额
    if (budget.per_call_limit && estimate.total_max > budget.per_call_limit) {
      return {
        allowed: false,
        reason: "EXCEEDS_PER_CALL_LIMIT",
        limit: budget.per_call_limit,
        requested: estimate.total_max
      };
    }
    
    // 3. 检查日限额
    const dailyUsage = await this.getDailyUsage(userId);
    if (budget.daily_limit && dailyUsage + estimate.total_max > budget.daily_limit) {
      return {
        allowed: false,
        reason: "EXCEEDS_DAILY_LIMIT",
        limit: budget.daily_limit,
        used: dailyUsage,
        requested: estimate.total_max
      };
    }
    
    // 4. 检查余额
    const balance = await this.getBalance(userId);
    if (balance < estimate.total_max) {
      return {
        allowed: false,
        reason: "INSUFFICIENT_BALANCE",
        balance,
        requested: estimate.total_max
      };
    }
    
    return { allowed: true };
  }
}
```

---

## 八、监控与调试

### 8.1 编排追踪

```typescript
interface OrchestrationTrace {
  orchestration_id: string;
  status: "running" | "completed" | "failed";
  
  steps: Array<{
    step_id: string;
    skill_id: string;
    status: "pending" | "running" | "completed" | "failed";
    
    // 时间
    started_at?: number;
    completed_at?: number;
    duration_ms?: number;
    
    // 输入输出
    input?: any;
    output?: any;
    error?: string;
    
    // 费用
    estimated_cost: number;
    actual_cost?: number;
    
    // 四权检查
    rights_check: {
      yong: boolean;
      yan: boolean;
      kuo: boolean;
      yi: boolean;
    };
    
    // 执行详情
    sandbox_id?: string;
    proof_hash?: string;
  }>;
  
  // 总计
  total_estimated_cost: number;
  total_actual_cost?: number;
  total_duration_ms?: number;
}
```

### 8.2 CLI监控

```bash
# 查看编排状态
echo-claw status orchestration_12345

# 输出:
# ╔════════════════════════════════════════════════════════════╗
# ║  编排: 诗歌翻译朗读                                          ║
# ║  ID: orchestration_12345                                     ║
# ║  状态: 运行中                                                ║
# ╠════════════════════════════════════════════════════════════╣
# ║                                                            ║
# ║  [1/3] 写诗                                                 ║
# ║  ├─ 状态: ✅ 完成 (1.2s)                                    ║
# ║  ├─ Skill: skill_poet_alice                                 ║
# ║  ├─ 预估: 0.01 ECHO                                        ║
# ║  ├─ 实际: 0.01 ECHO                                        ║
# ║  ├─ 沙箱: sandbox_001                                       ║
# ║  └─ 证明: 0xabc...                                          ║
# ║                                                            ║
# ║  [2/3] 翻译                                                 ║
# ║  ├─ 状态: 🔄 运行中 (0.5s)                                  ║
# ║  ├─ Skill: skill_translator_bob                             ║
# ║  ├─ 预估: 0.02 ECHO                                        ║
# ║  └─ 输入: "春眠不觉晓..."                                   ║
# ║                                                            ║
# ║  [3/3] 朗读                                                 ║
# ║  ├─ 状态: ⏳ 等待                                           ║
# ║  └─ 依赖: step2                                             ║
# ║                                                            ║
# ║  总预估: 0.04 ECHO                                         ║
# ║  总实际: 0.01 ECHO (进行中)                                  ║
# ║                                                            ║
# ╚════════════════════════════════════════════════════════════╝

# 查看历史编排
echo-claw history --orchestrations

# 调试模式（显示详细日志）
echo-claw run "写诗" --debug
```

---

## 九、安全与权限

### 9.1 编排权限

```typescript
interface OrchestrationPermission {
  // 谁可以创建编排
  create: "anyone" | "verified" | "creators_only";
  
  // 谁可以执行编排
  execute: "anyone" | "authorized" | "owner_only";
  
  // 编排中的Skill权限继承
  skill_permissions: "inherit" | "override" | "union";
  
  // 最大步骤数（防DOS）
  max_steps: number;
  
  // 最大费用（防资金风险）
  max_cost: number;
}
```

### 9.2 防滥用机制

```typescript
class AbusePrevention {
  // 检查编排是否滥用
  async checkAbuse(orchestration: OrchestrationDefinition): Promise<AbuseCheck> {
    // 1. 检查循环依赖
    const hasCycle = this.detectCycle(orchestration);
    if (hasCycle) {
      return { safe: false, reason: "CYCLIC_DEPENDENCY" };
    }
    
    // 2. 检查步骤数
    if (orchestration.steps.length > MAX_STEPS) {
      return { safe: false, reason: "TOO_MANY_STEPS" };
    }
    
    // 3. 检查费用上限
    const estimate = await this.estimator.estimateOrchestration(orchestration);
    if (estimate.total_max > MAX_ORCHESTRATION_COST) {
      return { safe: false, reason: "COST_TOO_HIGH" };
    }
    
    // 4. 检查重复调用（防刷）
    const repeatedSkills = this.findRepeatedSkills(orchestration);
    if (repeatedSkills.length > 0) {
      return {
        safe: false,
        reason: "REPEATED_SKILL_CALLS",
        details: repeatedSkills
      };
    }
    
    return { safe: true };
  }
}
```

---

## 十、路线图

| 阶段 | 功能 | 时间 |
|------|------|------|
| MVP | 基础编排（线性链）+ 费用预估 + 四权检查 | 8周 |
| V1.0 | 并行编排 + 条件分支 + 错误恢复 + 自然语言解析 | 16周 |
| V1.5 | 循环执行 + 动态编排 + 预算控制 + 调试工具 | 24周 |
| V2.0 | AI自动编排 + 预测优化 + 编排市场 + 复合Skill | 36周 |

---

> **设计参考**: 编排设计参考 Apache Airflow 的任务流 + Stripe 的支付流程 + AWS Step Functions 的状态机。目标：让复杂的Skill调用像搭积木一样简单，且每一步都受四权保护。
