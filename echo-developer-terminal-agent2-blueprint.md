# ECHO 开发者终端 - 四权配置与Skill ECHO化设计

**版本**: v1.0 | **日期**: 2026-04-21 | **状态**: 详细设计

---

## 一、核心概念澄清

### 1.1 "登记"替代"铸造"

传统区块链用"铸造"（Mint）表示创建资产。ECHO用**"登记"**（Register）：

- **铸造** = 资产诞生，所有权确立
- **登记** = 资产纳入网络，开启生命周期

登记不创造所有权，而是宣告："这个Skill存在，它的使用规则如下。"

### 1.2 "流转"替代"转移"

传统区块链用"转移"（Transfer）表示所有权变更。ECHO用**"流转"**（Flow）：

- **转移** = 所有权从A到B
- **流转** = 使用权从A到B（使用权传递，非所有权买卖）

### 1.3 蓝图即宪法

四权蓝图是创作者对Skill的"宪法"。ECHO网络强制执行这部宪法，但创作者可以随时修改（软分叉）。

---

## 二、四权蓝图规范（YAML Schema）

### 2.1 完整YAML结构

```yaml
# blueprint.yaml - 四权权属蓝图
version: "1.0.0"                    # 蓝图版本（支持软分叉）
created_at: "2026-04-21T10:00:00Z"
updated_at: "2026-04-21T10:00:00Z"

# === 用 (Usage) - 使用权 ===
yong:
  enabled: true                     # 是否允许直接使用
  level: 3                          # 0-5，开放程度
  
  pricing:
    model: "per_call"               # per_call | per_minute | per_token | tiered | freemium | subscription
    price: 0.01                     # 基础价格（ECHO）
    currency: "ECHO"
    
    # per_call: 每次调用固定价格
    # per_minute: 按执行时长计费（per_second精度）
    # per_token: 按输入+输出token计费（LLM类）
    # tiered: 阶梯定价（前100次0.01，之后0.008）
    # freemium: 免费额度 + 超额收费
    # subscription: 订阅制（月付/年付）
    
    tiers:                          # tiered模型时使用
      - threshold: 0
        price: 0.01
      - threshold: 1000
        price: 0.008
      - threshold: 10000
        price: 0.005
        
    freemium:                       # freemium模型时使用
      free_quota: 100               # 每月免费调用次数
      free_period: "month"
      overage_price: 0.01
      
    subscription:                   # subscription模型时使用
      plans:
        - name: "基础版"
          price: 9.99
          period: "month"
          quota: 500
        - name: "专业版"
          price: 29.99
          period: "month"
          quota: 2000
          
  quotas:
    per_user:                        # 单用户配额
      max_calls: 1000                # 每月最大调用次数
      period: "month"
    global:                          # 全局配额
      max_calls: 100000              # 每月总调用上限
      period: "month"
      
  access_control:
    whitelist: []                    # 允许的用户ID列表（空=所有人）
    blacklist: []                    # 禁止的用户ID列表
    require_auth: false              # 是否需要身份验证
    
  conditions:                        # 使用条件
    - type: "platform"
      platforms: ["echo", "api", "mobile"]
    - type: "time_window"
      allowed_hours: [0, 23]         # 24小时允许
    - type: "rate_limit"
      requests_per_second: 10

# === 衍 (Derivative) - 衍生权 ===
yan:
  enabled: true
  level: 3                          # 0-5，开放程度
  
  rules:
    allow_derivative: true            # 是否允许创建衍生作品
    require_approval: false           # 是否需要创作者审批
    
    # 衍生收益分成
    split: 0.15                     # 衍生作品收益的15%归上游
    min_split: 0.05                 # 最低分成比例（防止零分成）
    max_split: 0.50                 # 最高分成比例
    
    # 衍生深度限制
    max_depth: 2                    # 最多衍生2层（孙作品）
    
    # 衍生条件
    conditions:
      - type: "attribution"
        require_credit: true          # 必须署名
        credit_format: "基于 {original_name} by {original_author}"
      - type: "license"
        license_type: "echo-derivative"
      - type: "compatibility"
        # 检查衍生作品的衍权配置是否兼容上游
        # 例如：上游split=0.15，衍生作品split=0.10
        # 则总split = 0.15 + 0.10 = 0.25，需要检查是否≤1.0
        
  # 衍生审批工作流（require_approval=true时使用）
  approval:
    auto_approve_if:                  # 自动审批条件
      - creator_reputation > 0.8      # 创作者信誉分>0.8
      - previous_derivatives < 5     # 之前衍生作品<5
    manual_approval_timeout: "7d"     # 7天不审批自动拒绝
    
  # 冷却期
  cooldown:
    between_derivatives: "24h"        # 同一创作者两次衍生间隔

# === 扩 (Expansion) - 扩展权 ===
kuo:
  enabled: true
  level: 3                          # 0-5，开放程度
  
  visibility: "indexed"             # public | indexed | private | unlisted
  # public: 所有人可见，可在发现机制中出现
  # indexed: 可通过搜索找到，但不主动推荐
  # private: 仅创作者和授权用户可见
  # unlisted: 有链接即可访问，不出现在任何发现机制
  
  platforms:
    allowed: ["echo", "api", "webhook"]
    blocked: []
    
  # 发现机制控制
  discovery:
    allow_search: true                # 允许被搜索
    allow_recommendation: true        # 允许被推荐
    allow_trending: true              # 允许出现在趋势榜
    
  # 跨平台授权
  cross_platform:
    - platform: "api"
      require_api_key: true
      rate_limit: 1000                # 每小时请求数
    - platform: "webhook"
      require_webhook_secret: true
      
  # 扩展条件
  conditions:
    - type: "quality_gate"
      min_quality_score: 0.7          # 质量分>0.7才能扩展
    - type: "shigraph_gate"
      min_stage: "SPROUT"              # 至少进入萌芽期才能扩展

# === 益 (Benefit) - 收益权 ===
yi:
  enabled: true
  level: 0                          # 0-5，冷启动期通常锁定
  
  # 解锁条件（渐进解锁）
  unlock:
    conditions:
      - type: "usage_count"
        threshold: 500              # 使用500次后解锁
      - type: "time_alive"
        threshold: "30d"            # 运行30天后解锁
      - type: "quality_average"
        threshold: 0.8              # 平均质量分>0.8
      - type: "verification_rate"
        threshold: 0.95             # 验证通过率>95%
    
    # 满足以上任一条件即可解锁（或全部？可配置）
    require_all: false
    
  # 收益份额
  shares:
    total: 1000                       # 总份额1000份
    creator_reserve: 500              # 创作者保留500份
    available: 500                    # 可出售500份
    
  # 份额交易
  trading:
    enabled: true
    price_model: "market"             # market | fixed | dutch_auction
    initial_price: 10.0               # 初始单价（ECHO/份）
    min_price: 1.0
    max_price: 1000.0
    
    # 自动定价（基于使用数据）
    auto_price:
      enabled: true
      formula: "base_price * usage_momentum * quality_factor"
      update_frequency: "daily"
      
  # 收益分配（使用后的分配）
  distribution:
    creator: 0.99                     # 99%归创作者
    validator_pool: 0.009             # 0.9%归验证者池
    protocol: 0.001                 # 0.1%归ECHO协议
    
    # 多层级衍生分配
    upstream_split: 0.15            # 上游分15%（由衍权配置覆盖）

# === 元数据 ===
metadata:
  name: "智能写诗助手"
  description: "基于风格和主题的唐诗生成器"
  tags: ["文本生成", "诗歌", "中文", "AI"]
  category: "creative"
  
  # 语义描述（用于发现）
  semantic:
    capabilities:
      - domain: "text-generation"
        actions: ["generate-poem", "analyze-poem"]
        input_types: ["object"]
        output_types: ["object"]
        
    # 输入输出Schema摘要
    input_summary: "{theme: string, style: enum, length?: number}"
    output_summary: "{poem: string, analysis: string}"
    
  # 创作者信息
  creator:
    name: "Alice"
    contact: "alice@example.com"
    reputation: 0.92                  # 信誉分（0-1）
    
  # 版本历史
  versions:
    - version: "1.0.0"
      created_at: "2026-04-21"
      changelog: "初始版本"
```

### 2.2 JSON Schema校验定义

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "ECHO Blueprint Schema",
  "type": "object",
  "required": ["version", "yong", "yan", "kuo", "yi"],
  "properties": {
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$"
    },
    "yong": {
      "type": "object",
      "properties": {
        "enabled": { "type": "boolean" },
        "level": { "type": "integer", "minimum": 0, "maximum": 5 },
        "pricing": {
          "type": "object",
          "properties": {
            "model": {
              "type": "string",
              "enum": ["per_call", "per_minute", "per_token", "tiered", "freemium", "subscription"]
            },
            "price": { "type": "number", "minimum": 0 }
          },
          "required": ["model", "price"]
        }
      },
      "required": ["enabled", "level", "pricing"]
    },
    "yan": {
      "type": "object",
      "properties": {
        "enabled": { "type": "boolean" },
        "level": { "type": "integer", "minimum": 0, "maximum": 5 },
        "rules": {
          "type": "object",
          "properties": {
            "allow_derivative": { "type": "boolean" },
            "split": { "type": "number", "minimum": 0, "maximum": 1 },
            "max_depth": { "type": "integer", "minimum": 0, "maximum": 10 }
          }
        }
      }
    },
    "kuo": {
      "type": "object",
      "properties": {
        "enabled": { "type": "boolean" },
        "level": { "type": "integer", "minimum": 0, "maximum": 5 },
        "visibility": {
          "type": "string",
          "enum": ["public", "indexed", "private", "unlisted"]
        }
      }
    },
    "yi": {
      "type": "object",
      "properties": {
        "enabled": { "type": "boolean" },
        "level": { "type": "integer", "minimum": 0, "maximum": 5 },
        "unlock": {
          "type": "object",
          "properties": {
            "conditions": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "type": { "type": "string" },
                  "threshold": {}
                }
              }
            }
          }
        }
      }
    }
  }
}
```

---

## 三、蓝图编辑器设计

### 3.1 CLI交互式配置（echo config wizard）

```bash
$ echo config --wizard

═══════════════════════════════════════════════════
        ECHO 四权配置向导
═══════════════════════════════════════════════════

当前Skill: 智能写诗助手

第一部分：用权（谁可以用？付多少钱？）
───────────────────────────────────────────────────

Q1: 你希望别人怎么使用你的Skill?
   1) 🔓 完全免费，希望被广泛使用
   2) 💰 每次使用收少量费用
   3) 🎫 先免费试用，满意后付费
   4) 📅 订阅制（月付/年付）
   5) 🏢 仅特定用户/企业可用
   6) 🔒 完全私有，不对外开放
   
> 2

Q2: 每次调用定价多少？（单位：ECHO ≈ RMB）
   💡 参考：类似Skill平均价格 0.01-0.05 ECHO
   
   1) 0.001 ECHO（几乎免费）
   2) 0.01 ECHO（约1分钱）⭐ 推荐
   3) 0.05 ECHO（约5分钱）
   4) 0.1 ECHO（约1毛钱）
   5) 自定义...
   
> 2

Q3: 是否有免费额度？
   
   1) 无免费额度（每次必付）
   2) 每月前100次免费 ⭐ 推荐
   3) 每月前500次免费
   4) 完全免费
   5) 自定义...
   
> 2

✓ 用权配置:
   定价: 0.01 ECHO/次
   免费额度: 100次/月
   开放程度: 3/5（开放使用）

第二部分：衍权（别人能改吗？怎么分账？）
───────────────────────────────────────────────────

Q4: 允许别人基于你的Skill创建新Skill吗？
   1) ✅ 允许，鼓励衍生
   2) ✅ 允许，但需要我审批
   3) ✅ 允许，但收取分成
   4) ❌ 不允许
   5) 🤔 我不知道...（查看案例）
   
> 1

Q5: 衍生作品收益怎么分？
   💡 当有人基于你的Skill创建新Skill并被使用时，
      收益会自动按此比例分配。
   
   1) 10%归我（鼓励生态）
   2) 15%归我 ⭐ 推荐
   3) 20%归我
   4) 30%归我（保护原创）
   5) 自定义...
   
> 2

Q6: 最多允许衍生几层？
   1) 1层（直接衍生）
   2) 2层 ⭐ 推荐（衍生作品的衍生作品）
   3) 3层
   4) 无限制
   
> 2

✓ 衍权配置:
   允许衍生: 是
   分成比例: 15%
   最大衍生深度: 2层
   开放程度: 3/5（鼓励衍生）

第三部分：扩权（在哪些地方出现？）
───────────────────────────────────────────────────

Q7: 希望Skill在哪里被发现？
   1) 🌐 ECHO网络 + API + 所有平台
   2) 🔍 ECHO网络 + 可被搜索 ⭐ 推荐
   3) 🔗 ECHO网络内可见
   4) 🔒 仅通过链接访问（不公开）
   5) 🚫 完全私有
   
> 2

Q8: 是否需要身份验证？
   1) 不需要（匿名可用）
   2) 需要登录（记录使用）⭐ 推荐
   3) 需要授权（我审批每个用户）
   
> 2

✓ 扩权配置:
   可见性: indexed（可搜索）
   平台: ECHO + API
   开放程度: 3/5（公开索引）

第四部分：益权（怎么赚钱？）
───────────────────────────────────────────────────

Q9: 希望何时解锁收益权？
   💡 冷启动期锁定，防止投机者炒作。
      达到一定使用量后自动解锁。
   
   1) 立即解锁（不推荐）
   2) 使用500次后解锁 ⭐ 推荐
   3) 使用1000次后解锁
   4) 运行30天后解锁
   5) 手动解锁（我控制）
   
> 2

Q10: 是否允许投资者购买收益份额？
   💡 出售未来收益份额，换取启动资金。
      投资者获得使用产生的被动收入。
   
   1) 允许 ⭐ 推荐
   2) 不允许
   
> 1

Q11: 总份额多少？出售多少？保留多少？
   
   总份额: 1000份
   出售: 500份（50%）⭐ 推荐
   保留: 500份（50%）
   
   初始单价: 10 ECHO/份
   
> 回车确认

═══════════════════════════════════════════════════
        配置预览
═══════════════════════════════════════════════════

┌─────────────────────────────────────────────────┐
│ 用权: 开放使用，0.01 ECHO/次，100次免费/月       │
│ 衍权: 允许衍生，15%分成，最多2层                 │
│ 扩权: 可搜索，ECHO+API平台                       │
│ 益权: 500次使用后解锁，1000份，出售500份         │
└─────────────────────────────────────────────────┘

💰 收益预测（基于类似Skill）:
   月使用1000次 → 月收入约 9 ECHO
   月使用5000次 → 月收入约 45 ECHO
   月使用10000次 → 月收入约 90 ECHO
   
   衍生收益（估计）:
   1个衍生作品被使用1000次 → 被动收入 1.5 ECHO
   
⚠️ 冲突检测: 通过 ✓
⚠️ 64卦约束预览: 
   当前: 坤卦（潜藏期）→ 无强制约束
   下一阶段: 屯卦（萌芽期）→ 衍权建议≥2
   大成期: 咸卦 → 衍权强制≥3，扩权强制≥3

保存配置? [Y/n] > Y
✓ blueprint.yaml 已生成
✓ 可手动编辑: vim blueprint.yaml
✓ 可重新配置: echo config
```

### 3.2 Web可视化编辑器

```
┌─────────────────────────────────────────────────────────────┐
│  ECHO Blueprint Studio                    [保存] [预览] [?]  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  四权雷达图                                           │  │
│  │                                                       │  │
│  │           用                                          │  │
│  │          /|\                                         │  │
│  │         / | \        当前配置                         │  │
│  │        /  |  \       ─────────                        │  │
│  │       /   |   \      用: ████░░ 3/5                 │  │
│  │  扩 ─────┼───── 衍   衍: ████░░ 3/5                 │  │
│  │       \   |   /      扩: ████░░ 3/5                 │  │
│  │        \  |  /       益: ░░░░░░ 0/5 (锁定)          │  │
│  │         \ | /                                        │  │
│  │          \|/                                          │  │
│  │           益                                          │  │
│  │                                                       │  │
│  │  🌱 坤卦（潜藏期）                                    │  │
│  │  势位: 初九·初九·初九                                │  │
│  │  使用: 0次 | 衍生: 0个 | 部署: 1平台                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ 💰 用权       │  │ 🔀 衍权       │  │ 🌐 扩权       │   │
│  │              │  │              │  │              │   │
│  │ 定价: 0.01   │  │ 允许: ✓      │  │ 可见性: 公开  │   │
│  │ 免费: 100/月  │  │ 分成: 15%    │  │ 平台: ECHO    │   │
│  │ 限制: 无      │  │ 深度: 2层    │  │ 搜索: ✓       │   │
│  │ [编辑]       │  │ [编辑]       │  │ [编辑]       │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 💎 益权                                              │  │
│  │                                                      │  │
│  │ 状态: 🔒 锁定（冷启动期）                             │  │
│  │ 解锁条件: 使用500次                                   │  │
│  │ 进度: 0/500 (0%)                                     │  │
│  │                                                      │  │
│  │ 份额: 1000份                                         │  │
│  │ 出售: 500份 @ 10 ECHO/份                             │  │
│  │ 保留: 500份                                          │  │
│  │                                                      │  │
│  │ [编辑]                                               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 📊 收益模拟器                                         │  │
│  │                                                      │  │
│  │ 月使用次数: [━━━━━●────] 5000                        │  │
│  │ 平均质量分: [━━━━●─────] 0.85                        │  │
│  │ 衍生作品数: [━━●───────] 3                           │  │
│  │                                                      │  │
│  │ 预测月收入: 52.5 ECHO                                │  │
│  │ ├─ 直接调用: 45 ECHO                                 │  │
│  │ ├─ 衍生分润: 7.5 ECHO                                │  │
│  │ └─ 投资者份额: 0 ECHO（未解锁）                       │  │
│  │                                                      │  │
│  │ 解锁后月收入: 105 ECHO                               │  │
│  │ （投资者份额带来额外被动收入）                         │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 五个活法模板

```yaml
# 模板1: 影响力优先（免费传播）
template_influence:
  name: "影响力优先"
  description: "完全免费，最大化传播和影响力"
  yong:
    enabled: true
    level: 5
    pricing:
      model: "freemium"
      price: 0
      freemium:
        free_quota: 999999
  yan:
    enabled: true
    level: 5
    rules:
      allow_derivative: true
      split: 0.05          # 极低分成，鼓励衍生
      max_depth: 5
  kuo:
    enabled: true
    level: 5
    visibility: "public"
  yi:
    enabled: false         # 不开启收益权
    level: 0

# 模板2: 收入优先（收费使用）
template_revenue:
  name: "收入优先"
  description: "每次使用收费，最大化直接收入"
  yong:
    enabled: true
    level: 3
    pricing:
      model: "per_call"
      price: 0.05
  yan:
    enabled: false         # 禁止衍生，保护独家性
    level: 0
  kuo:
    enabled: true
    level: 3
    visibility: "indexed"
  yi:
    enabled: true
    level: 1
    unlock:
      conditions:
        - type: "usage_count"
          threshold: 200

# 模板3: 生态优先（鼓励衍生）
template_ecosystem:
  name: "生态优先"
  description: "鼓励衍生，通过生态扩张获得被动收入"
  yong:
    enabled: true
    level: 3
    pricing:
      model: "per_call"
      price: 0.01
  yan:
    enabled: true
    level: 5
    rules:
      allow_derivative: true
      split: 0.20          # 较高分成，吸引衍生
      max_depth: 3
  kuo:
    enabled: true
    level: 4
    visibility: "public"
  yi:
    enabled: true
    level: 2
    unlock:
      conditions:
        - type: "usage_count"
          threshold: 300

# 模板4: 保护优先（严格控制）
template_protection:
  name: "保护优先"
  description: "严格控制使用，保护核心知识产权"
  yong:
    enabled: true
    level: 1
    pricing:
      model: "per_call"
      price: 0.10
    access_control:
      require_auth: true
      whitelist: []          # 空=需要手动审批
  yan:
    enabled: false
    level: 0
  kuo:
    enabled: true
    level: 1
    visibility: "private"
  yi:
    enabled: false
    level: 0

# 模板5: 实验优先（快速试错）
template_experiment:
  name: "实验优先"
  description: "先免费测试市场反应，后调整策略"
  yong:
    enabled: true
    level: 4
    pricing:
      model: "freemium"
      price: 0.01
      freemium:
        free_quota: 500
  yan:
    enabled: true
    level: 3
    rules:
      allow_derivative: true
      split: 0.10
      max_depth: 2
  kuo:
    enabled: true
    level: 3
    visibility: "indexed"
  yi:
    enabled: false
    level: 0
```

---

## 四、冲突检测引擎

### 4.1 上下游收益分配冲突

```typescript
// 核心算法：检查衍生链上的收益分配是否数学可行
function validateRevenueChain(blueprintChain: Blueprint[]): ValidationResult {
  // 示例：Alice → Bob → Carol（三层）
  // Alice.split = 0.15
  // Bob.split = 0.20
  // Carol.split = 0.10
  // 
  // 当Carol的作品被使用时：
  // 总split = 0.15 + 0.20 + 0.10 = 0.45 ✓ (≤1.0)
  // 
  // 但如果：
  // Alice.split = 0.50
  // Bob.split = 0.40
  // Carol.split = 0.20
  // 总split = 0.50 + 0.40 + 0.20 = 1.10 ✗ (>1.0，数学不可行)
  
  let totalSplit = 0;
  const chain = [];
  
  for (const bp of blueprintChain) {
    totalSplit += bp.yan.rules.split;
    chain.push({
      creator: bp.metadata.creator.name,
      split: bp.yan.rules.split,
      cumulative: totalSplit
    });
    
    if (totalSplit > 1.0) {
      return {
        valid: false,
        error: "REVENUE_OVERFLOW",
        message: `收益分配总和 ${totalSplit} 超过 100%，数学不可行`,
        chain,
        suggestion: "请调整衍生链上的分成比例，确保总和≤100%"
      };
    }
  }
  
  return { valid: true, chain };
}
```

### 4.2 四权组合合理性检查

```typescript
function validateRightsCombination(bp: Blueprint): ValidationResult {
  const warnings = [];
  const errors = [];
  
  // 检查1: 用权=0但衍权>0（没人能用，但允许衍生？）
  if (bp.yong.level === 0 && bp.yan.level > 0) {
    warnings.push({
      code: "UNUSED_DERIVATIVE",
      message: "用权=0（禁止直接使用），但衍权>0（允许衍生）。衍生作品也无法直接调用。",
      severity: "warning"
    });
  }
  
  // 检查2: 衍权=5但用权=0（完全开放衍生但禁止直接使用）
  if (bp.yan.level === 5 && bp.yong.level < 2) {
    warnings.push({
      code: "DERIVATIVE_WITHOUT_USAGE",
      message: "衍权完全开放，但用权受限。衍生作品可能因用权不足而无法运行。",
      severity: "warning"
    });
  }
  
  // 检查3: 扩权=0但用权>0（能用但找不到？）
  if (bp.kuo.level === 0 && bp.yong.level > 0) {
    warnings.push({
      code: "INVISIBLE_USABLE",
      message: "用权>0（允许使用），但扩权=0（不可发现）。用户只能通过直接链接使用。",
      severity: "info"
    });
  }
  
  // 检查4: 益权解锁条件过于苛刻
  if (bp.yi.unlock?.conditions?.length > 3) {
    warnings.push({
      code: "STRICT_UNLOCK",
      message: "解锁条件过多，可能导致长期无法解锁。建议简化。",
      severity: "warning"
    });
  }
  
  // 检查5: 分成比例过高导致生态排斥
  if (bp.yan.rules.split > 0.5) {
    warnings.push({
      code: "HIGH_SPLIT",
      message: "分成比例>50%，可能抑制衍生作品的创作动力。",
      severity: "warning",
      suggestion: "建议将分成比例控制在10-30%之间"
    });
  }
  
  // 检查6: 定价与质量不匹配（基于同类Skill数据）
  const similarSkills = getSimilarSkills(bp);
  const avgPrice = similarSkills.reduce((s, sk) => s + sk.yong.pricing.price, 0) / similarSkills.length;
  if (bp.yong.pricing.price > avgPrice * 3) {
    warnings.push({
      code: "HIGH_PRICE",
      message: `定价 ${bp.yong.pricing.price} 是同类Skill平均价格 (${avgPrice}) 的3倍以上。`,
      severity: "warning"
    });
  }
  
  return { valid: errors.length === 0, errors, warnings };
}
```

### 4.3 64卦约束预览

```typescript
function previewHexagramConstraints(bp: Blueprint, currentShi: Hexagram): ConstraintPreview {
  // 获取当前卦象的约束
  const currentConstraints = HEXAGRAM_RULES[currentShi];
  
  // 计算实际生效配置
  const effective = calculateEffectivePolicy(bp, currentShi);
  
  // 预览下一阶段约束
  const nextHexagrams = getAdjacentHexagrams(currentShi);
  const previews = nextHexagrams.map(h => ({
    hexagram: h.name,
    stage: h.stage,
    constraints: HEXAGRAM_RULES[h],
    effectiveIfTransition: calculateEffectivePolicy(bp, h),
    conflicts: detectConflicts(bp, HEXAGRAM_RULES[h])
  }));
  
  return {
    current: {
      hexagram: currentShi.name,
      stage: currentShi.stage,
      constraints: currentConstraints,
      effective
    },
    upcoming: previews,
    recommendation: generateRecommendation(bp, currentShi, previews)
  };
}

// 示例输出
{
  "current": {
    "hexagram": "坤卦",
    "stage": "SEED",
    "constraints": { "yong": { "min": 0, "max": 5 }, "yan": { "min": 0, "max": 2 } },
    "effective": { "yong": 3, "yan": 3, "kuo": 3, "yi": 0 }
  },
  "upcoming": [
    {
      "hexagram": "屯卦",
      "stage": "SPROUT",
      "constraints": { "yan": { "min": 1, "max": 3 } },
      "effectiveIfTransition": { "yong": 3, "yan": 3, "kuo": 3, "yi": 0 },
      "conflicts": []
    },
    {
      "hexagram": "咸卦",
      "stage": "MATURE",
      "constraints": { "yan": { "min": 3, "max": 5 }, "kuo": { "min": 3, "max": 5 } },
      "effectiveIfTransition": { "yong": 3, "yan": 3, "kuo": 3, "yi": 2 },
      "conflicts": [],
      "note": "建议提前将衍权设为≥3，避免变势时强制调整"
    }
  ],
  "recommendation": "当前配置合理。建议在进入大成期前将衍权和扩权提升至≥3，以符合物理法则要求。"
}
```

---

## 五、Skill登记（Register）流程

### 5.1 登记 vs 铸造

```
传统铸造 (Mint):
  创作者 → 上传NFT元数据 → 智能合约铸造 → 获得TokenID
  含义: "我拥有这个资产"

ECHO登记 (Register):
  创作者 → 上传Skill包 → 生成AssetID → 链上记录蓝图
  含义: "这个Skill存在，使用规则如下"
  
关键区别:
  - 登记不产生所有权凭证（无Token）
  - 登记开启的是"生命周期"而非"所有权记录"
  - 登记后Asset可以在任何沙箱部署（不锁定到特定位置）
```

### 5.2 登记流程

```
Step 1: 准备登记材料
  ├── Skill包（skill.json + code/ + assets/ + blueprint.yaml）
  ├── 创作者身份验证（私钥签名）
  └── 依赖声明（上游Skill引用）

Step 2: 上传Skill包
  ├── 上传到IPFS（内容寻址）
  └── 获取内容哈希: QmXyz...

Step 3: 生成AssetID
  ├── 输入: 创作者地址 + 内容哈希 + 时间戳
  └── 输出: AssetID = "skill_{hash_prefix}_{timestamp}"
  示例: skill_7a3f9b2e_20260421

Step 4: 链上登记
  ├── 调用 EchoRegistry.register()
  ├── 参数: { assetId, contentHash, blueprintHash, creator, timestamp }
  └── 事件: AssetRegistered(assetId, creator, timestamp)

Step 5: 初始状态设定
  ├── ShiGraph初始化: 坤卦（潜藏期）
  ├── 势位: 初九·初九·初九
  └── 事件: ShiStateChanged(assetId, "坤", [0,0,0])

Step 6: 部署到沙箱
  ├── 选择目标沙箱（默认 + 备用）
  ├── 沙箱拉取Skill包并部署
  └── 事件: DeploymentEvent(assetId, sandboxId)

Step 7: 完成
  ├── 返回: { assetId, status: "active", endpoint: "..." }
  └── Skill进入生命周期（开始积累使用数据）
```

### 5.3 登记验证

```typescript
interface RegisterValidation {
  // 1. 代码审计（可选，不强制）
  codeAudit?: {
    enabled: boolean;           // 是否启用代码审计
    auditor: string;            // 审计方
    result: "pass" | "fail" | "warning";
    reportHash: string;
  };
  
  // 2. 蓝图完整性检查（强制）
  blueprintValidation: {
    schemaValid: boolean;       // 符合JSON Schema
    conflicts: Conflict[];        // 冲突列表
    warnings: Warning[];         // 警告列表
    hexagramPreview: Preview;    // 64卦约束预览
  };
  
  // 3. 依赖检查（强制）
  dependencyCheck: {
    allResolved: boolean;       // 所有依赖可解析
    missing: string[];           // 缺失依赖
    versionConflicts: Conflict[]; // 版本冲突
  };
  
  // 4. 签名验证（强制）
  signatureValidation: {
    valid: boolean;
    signer: string;             // 创作者地址
    timestamp: number;
  };
  
  // 5. 内容哈希验证（强制）
  contentValidation: {
    hash: string;
    matches: boolean;           // 上传内容与声明哈希匹配
  };
}
```

---

## 六、版本管理（软分叉机制）

### 6.1 版本号规范

```
版本号格式: {semver}-{blueprint_hash_short}

示例: 1.2.3-a7f3e

semver (语义化版本):
  MAJOR: 不兼容的API变更
  MINOR: 向后兼容的功能添加
  PATCH: 向后兼容的问题修复

blueprint_hash_short (蓝图哈希):
  四权配置的短哈希，用于精确识别规则版本
```

### 6.2 软分叉规则

```
创作者更新蓝图:
  v1.0.0-a7f3e → v1.1.0-b2e9c（修改用权定价）

行为:
  ┌──────────────────────────────────────────────────┐
  │  旧授权（v1.0.0-a7f3e）                           │
  │  ├── 用户Bob: 剩余100次配额（按旧定价0.01）        │
  │  └── 继续沿用旧版本直到配额耗尽或过期              │
  │                                                  │
  │  新授权（v1.1.0-b2e9c）                           │
  │  ├── 用户Carol: 新配额（按新定价0.02）           │
  │  └── 自动使用新版本                               │
  └──────────────────────────────────────────────────┘

数据存储:
  Redis: skill_001:v1.0.0-a7f3e:config（旧版本缓存）
  Redis: skill_001:v1.1.0-b2e9c:config（新版本缓存）
  PostgreSQL: blueprints表（所有版本持久化）
```

### 6.3 授权凭证带版本号

```typescript
interface AuthCredential {
  auth_id: string;
  user_id: string;
  asset_id: string;
  blueprint_version: "1.0.0-a7f3e";  // 关键：绑定版本
  
  // 授权详情
  rights_snapshot: {
    yong: { level: 3, price: 0.01, quota: 100 };
    yan: { level: 3, split: 0.15 };
    kuo: { level: 3, visibility: "indexed" };
    yi: { level: 0 };
  };
  
  // 使用限额
  quota: {
    total: 100;
    remaining: 87;
    period: "month";
    reset_at: "2026-05-01T00:00:00Z";
  };
  
  // 有效期
  issued_at: number;
  expires_at: number;
  
  // 签名
  signature: string;              // 创作者签名
  network_signature: string;      // ECHO网络签名
}

// 查询有效配置时
function getEffectiveConfig(assetId: string, authCredential: AuthCredential): Blueprint {
  // 1. 获取授权绑定的版本
  const version = authCredential.blueprint_version;
  
  // 2. 查询该版本的配置
  const config = getBlueprintByVersion(assetId, version);
  
  // 3. 返回（不是最新版本，是授权时的版本）
  return config;
}
```

### 6.4 旧版本清理策略

```typescript
function cleanupOldVersions(assetId: string): CleanupResult {
  // 1. 查询所有活跃授权的版本
  const activeAuths = getActiveAuthorizations(assetId);
  const activeVersions = new Set(activeAuths.map(a => a.blueprint_version));
  
  // 2. 查询所有已存储的版本
  const allVersions = getAllBlueprintVersions(assetId);
  
  // 3. 找出无活跃授权的旧版本
  const deletable = allVersions.filter(v => !activeVersions.has(v));
  
  // 4. 保留最近3个版本（即使无活跃授权，用于历史查询）
  const recentVersions = allVersions.slice(-3);
  const toDelete = deletable.filter(v => !recentVersions.includes(v));
  
  // 5. 清理
  for (const version of toDelete) {
    // 删除Redis缓存
    deleteRedisCache(`${assetId}:${version}:config`);
    
    // PostgreSQL标记为archived（不物理删除，用于审计）
    archiveBlueprint(assetId, version);
  }
  
  return {
    kept: activeVersions.size + recentVersions.length,
    archived: toDelete.length,
    saved: toDelete.length * ESTIMATED_CACHE_SIZE
  };
}
```

---

## 七、ECHO化打包规范

### 7.1 包结构

```
myskill-v1.0.0.echo（ZIP格式）
├── skill.json              # 元数据（必需）
├── blueprint.yaml          # 四权蓝图（必需）
├── code/                   # 代码（必需）
│   ├── index.js            # 入口点
│   ├── lib/                # 依赖库
│   └── package.json        # 依赖声明
├── assets/                 # 资源文件（可选）
│   ├── model.bin           # AI模型
│   ├── vocab.json          # 词典
│   └── config.json         # 模型配置
├── schemas/                # Schema定义（推荐）
│   ├── input.json          # 输入JSON Schema
│   └── output.json         # 输出JSON Schema
├── README.md               # 文档（推荐）
├── LICENSE                 # 许可证（推荐）
└── .echoignore            # 忽略文件（可选）
```

### 7.2 skill.json 规范

```json
{
  "echo_version": "1.0",
  "skill": {
    "id": null,
    "name": "智能写诗助手",
    "version": "1.0.0",
    "description": "基于风格和主题的唐诗生成器",
    "author": "alice@example.com",
    "license": "ECHO-Derivative-1.0",
    
    "runtime": {
      "type": "wasm",
      "entry": "code/index.js",
      "engine": "deno",
      "engine_version": "1.40"
    },
    
    "resources": {
      "memory_mb": 512,
      "timeout_ms": 30000,
      "cpu_shares": 1024
    },
    
    "interfaces": {
      "protocol": "http",
      "input_format": "json",
      "output_format": "json",
      "streaming": false
    },
    
    "dependencies": [
      {
        "skill_id": "skill_nlp_tokenizer_v1",
        "version_range": "^2.0.0",
        "optional": false
      }
    ],
    
    "capabilities": [
      {
        "domain": "text-generation",
        "action": "generate-poem",
        "input_types": ["object"],
        "output_types": ["object"]
      }
    ],
    
    "tags": ["文本生成", "诗歌", "中文", "AI"],
    
    "signatures": {
      "content_hash": "sha256:abc123...",
      "blueprint_hash": "sha256:def456...",
      "creator_signature": "0x signer_signature..."
    }
  }
}
```

### 7.3 签名机制

```typescript
// 创作者签名流程
function signSkillPackage(skillPackage: SkillPackage, privateKey: string): SignedPackage {
  // 1. 计算内容哈希
  const contentHash = sha256(skillPackage.code + skillPackage.assets);
  
  // 2. 计算蓝图哈希
  const blueprintHash = sha256(skillPackage.blueprint);
  
  // 3. 组合签名消息
  const message = `${contentHash}:${blueprintHash}:${skillPackage.metadata.timestamp}`;
  
  // 4. 签名
  const signature = sign(message, privateKey);
  
  return {
    ...skillPackage,
    signatures: {
      content_hash: contentHash,
      blueprint_hash: blueprintHash,
      creator_signature: signature,
      timestamp: Date.now()
    }
  };
}

// ECHO网络验证流程
function verifySkillPackage(signedPackage: SignedPackage, creatorPublicKey: string): boolean {
  // 1. 验证内容哈希（确保内容未被篡改）
  const actualContentHash = sha256(signedPackage.code + signedPackage.assets);
  if (actualContentHash !== signedPackage.signatures.content_hash) {
    throw new Error("CONTENT_HASH_MISMATCH");
  }
  
  // 2. 验证蓝图哈希
  const actualBlueprintHash = sha256(signedPackage.blueprint);
  if (actualBlueprintHash !== signedPackage.signatures.blueprint_hash) {
    throw new Error("BLUEPRINT_HASH_MISMATCH");
  }
  
  // 3. 验证创作者签名
  const message = `${signedPackage.signatures.content_hash}:${signedPackage.signatures.blueprint_hash}:${signedPackage.metadata.timestamp}`;
  if (!verify(message, signedPackage.signatures.creator_signature, creatorPublicKey)) {
    throw new Error("SIGNATURE_INVALID");
  }
  
  return true;
}
```

### 7.4 依赖管理

```yaml
# 上游Skill引用声明
dependencies:
  - skill_id: "skill_nlp_tokenizer_v1"
    version_range: "^2.0.0"        # 语义化版本范围
    optional: false                # 是否可选
    
    # 衍生关系声明
    derivative_relationship:
      type: "extends"              # extends | uses | composes
      description: "使用tokenizer进行预处理"
      
    # 收益分成（由上游衍权配置覆盖，此处为声明）
    revenue_share:
      upstream_split: 0.15           # 声明知道上游分15%
      
  - skill_id: "skill_sentiment_v1"
    version_range: "~1.2.0"
    optional: true
    derivative_relationship:
      type: "uses"
      description: "可选：情感分析增强"
```

---

## 八、登记后的生命周期

### 8.1 完整状态流转

```
登记 (Register)
  ↓
坤卦（潜藏期）
  ├── 使用: 0
  ├── 衍生: 0
  ├── 部署: 1平台
  └── 约束: 无
  ↓（开始使用）
屯卦（萌芽期）
  ├── 使用: 10-100
  ├── 衍生: 0-3
  ├── 部署: 1-2平台
  └── 约束: 衍权建议≥1
  ↓（持续使用）
泰卦（成长期）
  ├── 使用: 100-500
  ├── 衍生: 3-10
  ├── 部署: 2-3平台
  └── 约束: 衍权建议≥2，扩权建议≥2
  ↓（进入大成）
咸卦（大成期）
  ├── 使用: 500+
  ├── 衍生: 10+
  ├── 部署: 3+平台
  └── 约束: 衍权强制≥3，扩权强制≥3，益权建议解锁
  ↓（周期尾声）
乾卦（转化期）
  ├── 使用: 高频但稳定
  ├── 衍生: 生态成熟
  ├── 部署: 全域
  └── 约束: 全面开放，准备新生
  ↓（休眠或分叉）
艮卦（止息期）/ 分叉
```

### 8.2 事件流记录

```
AssetRegistered
  ├── asset_id: skill_poet_alice
  ├── creator: alice
  ├── blueprint_hash: 0xabc...
  ├── content_hash: 0xdef...
  └── timestamp: 1745200000

ShiStateChanged
  ├── asset_id: skill_poet_alice
  ├── from: { hexagram: "坤", coordinate: [0,0,0] }
  ├── to: { hexagram: "屯", coordinate: [1,1,1] }
  ├── trigger: "usage_threshold"
  └── timestamp: 1745800000

PolicyAdjusted
  ├── asset_id: skill_poet_alice
  ├── from: { yan: { level: 2, split: 0.10 } }
  ├── to: { yan: { level: 3, split: 0.15 } }
  ├── reason: "hexagram_constraint"
  ├── triggered_by: "咸卦"
  └── timestamp: 1746400000

DerivativeCreated
  ├── from: skill_poet_alice
  ├── to: skill_marketing_copy
  ├── creator: carol
  └── timestamp: 1746000000
```

---

## 九、待决策事项

| 事项 | 选项 | 推荐 |
|------|------|------|
| 登记费用 | 免费 / 小额防垃圾 | 免费（价值来自使用，不是登记） |
| 蓝图大小限制 | 1MB / 10MB / 无限制 | 10MB（YAML压缩后通常<100KB） |
| 版本保留策略 | 保留全部 / 保留N个 / 保留活跃 | 保留活跃+最近3个 |
| 软分叉通知 | 自动通知所有用户 / 仅通知受影响用户 | 仅通知受影响用户 |
| 依赖版本锁定 | 精确版本 / 语义化范围 / 最新 | 语义化范围（创作者可控） |

---

> **设计参考**: 四权配置参考 Stripe 的 Pricing Table 清晰度 + npm 的 package.json 简洁性 + Creative Commons 许可证的灵活性。目标让创作者在5分钟内完成配置，且配置即法律。
