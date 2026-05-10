# ECHO 系统模拟器 —— 核心数据结构与状态模型

> ECHO（Echo Copyright Hybrid Ownership）是一个使用权生命周期网络。本文档定义其运行时所需的全部核心数据结构、状态模型、验证算法与状态机。所有定义以 JSON Schema 形式给出，并辅以伪代码描述核心算法。

---

## 目录

1. [常量与枚举定义](#1-常量与枚举定义)
2. [核心数据模型](#2-核心数据模型)
   - Asset（资产）
   - User（用户）
   - VerificationEvent（验证事件）
   - Transaction（交易/分润）
   - RuleTemplate（规则模板）
   - ShiPosition（势位计算）
3. [验证图（Verification Graph）](#3-验证图)
4. [资产生命周期状态机](#4-资产生命周期状态机)
5. [四权验证引擎](#5-四权验证引擎)
6. [势图接管引擎](#6-势图接管引擎)

---

## 1. 常量与枚举定义

### 1.1 四权力（Four Powers）

四权力是 ECHO 的核心权限维度，每资产拥有独立的四权配置：

| 权力 | 含义 | 位偏移 |
|------|------|--------|
| **用 (Use)** | 谁可以接触/消费该资产 | 0 |
| **扩 (Spread)** | 可以传播到多远范围 | 4 |
| **衍 (Derive)** | 可以以何种方式修改/派生 | 8 |
| **益 (Benefit)** | 分润与收益分配规则 | 12 |

每权力使用 4 位（可表达 0~15），恰好容纳六档位编码。四权整体使用一个 16 位整数存储。

```
四权位掩码格式（16-bit）：
  15 14 13 12 | 11 10 9 8 | 7 6 5 4 | 3 2 1 0
  -----------+----------+---------+-------
     益        衍         扩        用
```

### 1.2 六档位（Six Levels）

档位采用位掩码编码，支持组合（如 `己|亲` 表示"己+亲"范围）：

| 档位 | 值 | 位掩码 | 含义 |
|------|-----|--------|------|
| **禁 (FORBIDDEN)** | 0 | `0b0000` | 完全禁止，无人可执行 |
| **己 (SELF)** | 1 | `0b0001` | 仅限创作者本人 |
| **亲 (KINSHIP)** | 2 | `0b0010` | 创作者指定的亲密关系圈 |
| **约 (CONTRACT)** | 4 | `0b0100` | 通过规则模板/合约约定的范围 |
| **法 (LAW)** | 8 | `0b1000` | 平台规则/法律框架允许的范围 |
| **公 (PUBLIC)** | 15 | `0b1111` | 完全公开，任何人 |

```javascript
const LEVEL_MASK = {
  FORBIDDEN: 0,   // 0b0000
  SELF:      1,   // 0b0001
  KINSHIP:   2,   // 0b0010
  CONTRACT:  4,   // 0b0100
  LAW:       8,   // 0b1000
  PUBLIC:    15   // 0b1111 (所有位全开)
};
```

### 1.3 验证事件类型

| 类型 | 含义 | 语义深度基准 |
|------|------|-------------|
| **reference** | 引用/提及 | 0.3 |
| **remix** | 混剪/改编 | 0.6 |
| **integrate** | 整合/嵌入 | 0.8 |
| **fork** | 分叉/衍生新资产 | 1.0 |

### 1.3 生命阶段（Life Stages）

| 阶段 | 势位分数 P | 编码值 |
|------|-----------|--------|
| **潜藏 (Latent)** | P < 20 | 0 |
| **显现 (Manifest)** | 20 ≤ P < 40 | 1 |
| **生长 (Growth)** | 40 ≤ P < 60 | 2 |
| **大成 (Mature)** | 60 ≤ P < 80 | 3 |
| **转化 (Transform)** | P ≥ 80 | 4 |

### 1.4 用户角色

| 角色 | 说明 |
|------|------|
| **creator** | 资产创作者，拥有初始四权配置权 |
| **user** | 普通消费者/使用者 |
| **platform** | 平台节点，负责验证与分润执行 |
| **derivative** | 派生资产创作者（fork 事件的发起者） |

---

## 2. 核心数据模型

### 2.1 Asset（资产）

资产是 ECHO 网络中的核心节点。每一个作品、内容片段或数据对象都是资产。

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Asset",
  "description": "ECHO 网络中的资产对象",
  "type": "object",
  "required": ["asset_id", "creator_id", "four_powers", "shi_takeover", "created_at", "content_hash"],
  "properties": {
    "asset_id": {
      "type": "string",
      "description": "全局唯一资产标识符，UUIDv4",
      "example": "asset_7f8a9b2c-3d4e-5f6a-7b8c-9d0e1f2a3b4c"
    },
    "creator_id": {
      "type": "string",
      "description": "创作者用户ID",
      "example": "user_a1b2c3d4"
    },
    "content_hash": {
      "type": "string",
      "description": "内容哈希，用于链上锚定和内容完整性验证",
      "example": "sha256:a3f5c8..."
    },
    "four_powers": {
      "type": "object",
      "description": "四权力配置（当前生效配置）",
      "required": ["use", "spread", "derive", "benefit"],
      "properties": {
        "use": {
          "type": "integer",
          "description": "用权档位掩码",
          "minimum": 0,
          "maximum": 15,
          "example": 15
        },
        "spread": {
          "type": "integer",
          "description": "扩权档位掩码",
          "minimum": 0,
          "maximum": 15,
          "example": 7
        },
        "derive": {
          "type": "integer",
          "description": "衍权档位掩码",
          "minimum": 0,
          "maximum": 15,
          "example": 3
        },
        "benefit": {
          "type": "integer",
          "description": "益权档位掩码",
          "minimum": 0,
          "maximum": 15,
          "example": 5
        }
      }
    },
    "four_powers_raw": {
      "type": "integer",
      "description": "四权压缩存储值（16位），用于快速比较和索引",
      "example": 1553
    },
    "shi_takeover": {
      "type": "object",
      "description": "势图接管设置：是否启用、各阶段目标配置",
      "required": ["enabled", "stage_configs"],
      "properties": {
        "enabled": {
          "type": "boolean",
          "description": "是否启用势图接管",
          "default": true
        },
        "stage_configs": {
          "type": "object",
          "description": "各生命阶段的四权目标配置（只开放，不收紧）",
          "properties": {
            "latent":   { "$ref": "#/properties/four_powers" },
            "manifest": { "$ref": "#/properties/four_powers" },
            "growth":   { "$ref": "#/properties/four_powers" },
            "mature":   { "$ref": "#/properties/four_powers" },
            "transform":{ "$ref": "#/properties/four_powers" }
          }
        }
      }
    },
    "shi_position": {
      "type": "object",
      "description": "当前势位计算结果（只读，由引擎定期更新）",
      "properties": {
        "score": { "type": "number", "description": "综合势位分数 P" },
        "stage": { "type": "integer", "description": "生命阶段编码" },
        "stage_name": { "type": "string" }
      }
    },
    "rule_template_id": {
      "type": ["string", "null"],
      "description": "引用的规则模板ID（约档/法档场景）",
      "example": "tpl_abc123"
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "description": "创建时间 ISO 8601"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time"
    },
    "version": {
      "type": "integer",
      "description": "资产版本号，每次四权变更或内容更新时递增",
      "default": 1
    },
    "metadata": {
      "type": "object",
      "description": "扩展元数据",
      "properties": {
        "title": { "type": "string" },
        "content_type": { "type": "string", "enum": ["text", "image", "audio", "video", "code", "data", "mixed"] },
        "tags": { "type": "array", "items": { "type": "string" } },
        "language": { "type": "string" }
      }
    }
  }
}
```

**示例实例：**

```json
{
  "asset_id": "asset_7f8a9b2c-3d4e-5f6a-7b8c-9d0e1f2a3b4c",
  "creator_id": "user_creator_alice",
  "content_hash": "sha256:a3f5c8e7d2b1a4f6c9d8e7b6a5f4c3d2e1b0a9f8",
  "four_powers": {
    "use": 15,
    "spread": 7,
    "derive": 3,
    "benefit": 5
  },
  "four_powers_raw": 1553,
  "shi_takeover": {
    "enabled": true,
    "stage_configs": {
      "latent":    { "use": 1,  "spread": 0,  "derive": 0,  "benefit": 1 },
      "manifest":  { "use": 3,  "spread": 1,  "derive": 1,  "benefit": 3 },
      "growth":    { "use": 7,  "spread": 3,  "derive": 3,  "benefit": 7 },
      "mature":    { "use": 15, "spread": 7,  "derive": 7,  "benefit": 15 },
      "transform": { "use": 15, "spread": 15, "derive": 15, "benefit": 15 }
    }
  },
  "shi_position": {
    "score": 45.2,
    "stage": 2,
    "stage_name": "growth"
  },
  "rule_template_id": null,
  "created_at": "2026-05-10T04:00:00Z",
  "updated_at": "2026-05-10T10:30:00Z",
  "version": 3,
  "metadata": {
    "title": "ECHO 概念图",
    "content_type": "image",
    "tags": ["design", "system", "echo"],
    "language": "zh-CN"
  }
}
```

---

### 2.2 User（用户）

用户是 ECHO 网络中的行为主体。用户通过四权配置定义自己在网络中的权利边界。

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "User",
  "description": "ECHO 网络中的用户账户",
  "type": "object",
  "required": ["user_id", "role", "balance", "reputation"],
  "properties": {
    "user_id": {
      "type": "string",
      "description": "全局唯一用户标识符"
    },
    "display_name": {
      "type": "string",
      "description": "用户显示名称"
    },
    "role": {
      "type": "string",
      "enum": ["creator", "user", "platform", "derivative"],
      "description": "用户在系统中的角色"
    },
    "roles": {
      "type": "array",
      "description": "用户可以拥有多个角色（位掩码数组）",
      "items": {
        "type": "string",
        "enum": ["creator", "user", "platform", "derivative"]
      }
    },
    "balance": {
      "type": "object",
      "description": "账户余额",
      "properties": {
        "amount": {
          "type": "number",
          "description": "余额数量",
          "default": 0
        },
        "currency": {
          "type": "string",
          "description": "代币类型",
          "default": "ECHO"
        },
        "escrow": {
          "type": "number",
          "description": "托管中金额（待结算）",
          "default": 0
        }
      }
    },
    "reputation": {
      "type": "object",
      "description": "声誉体系",
      "properties": {
        "score": {
          "type": "number",
          "description": "综合声誉分数 0~100",
          "default": 50
        },
        "history": {
          "type": "object",
          "description": "声誉历史向量",
          "properties": {
            "creation_count": { "type": "integer", "default": 0 },
            "positive_interactions": { "type": "integer", "default": 0 },
            "negative_flags": { "type": "integer", "default": 0 },
            "verified_events": { "type": "integer", "default": 0 },
            "successful_derivatives": { "type": "integer", "default": 0 }
          }
        }
      }
    },
    "kinship_list": {
      "type": "array",
      "description": "亲档位关系圈（user_id 列表）",
      "items": { "type": "string" }
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "last_active": {
      "type": "string",
      "format": "date-time"
    },
    "wallet_address": {
      "type": ["string", "null"],
      "description": "链上钱包地址（可选）"
    }
  }
}
```

**示例实例：**

```json
{
  "user_id": "user_creator_alice",
  "display_name": "Alice",
  "role": "creator",
  "roles": ["creator", "user"],
  "balance": {
    "amount": 1250.50,
    "currency": "ECHO",
    "escrow": 80.00
  },
  "reputation": {
    "score": 78.5,
    "history": {
      "creation_count": 12,
      "positive_interactions": 340,
      "negative_flags": 2,
      "verified_events": 89,
      "successful_derivatives": 7
    }
  },
  "kinship_list": ["user_bob", "user_charlie", "user_dave"],
  "created_at": "2026-01-15T08:00:00Z",
  "last_active": "2026-05-10T12:00:00Z",
  "wallet_address": "0xAbCdEf1234567890"
}
```

---

### 2.3 VerificationEvent（验证事件）

验证事件是验证图中的边。每一次引用、混剪、整合或分叉都产生一条验证事件。

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "VerificationEvent",
  "description": "资产之间的验证关系事件",
  "type": "object",
  "required": ["event_id", "type", "subject_asset", "object_asset", "timestamp", "platform_id"],
  "properties": {
    "event_id": {
      "type": "string",
      "description": "全局唯一事件标识符"
    },
    "type": {
      "type": "string",
      "enum": ["reference", "remix", "integrate", "fork"],
      "description": "验证事件类型"
    },
    "subject_asset": {
      "type": "string",
      "description": "主体资产ID（发起验证的资产/派生资产）"
    },
    "object_asset": {
      "type": "string",
      "description": "客体资产ID（被验证引用的源资产）"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "事件发生时间"
    },
    "platform_id": {
      "type": "string",
      "description": "验证平台节点ID"
    },
    "user_id": {
      "type": ["string", "null"],
      "description": "触发该事件的用户ID（fork/remix 通常有）"
    },
    "semantic_depth": {
      "type": "number",
      "description": "语义深度系数 0~1",
      "minimum": 0,
      "maximum": 1
    },
    "weight": {
      "type": "number",
      "description": "事件权重（语义深度 × 时间衰减），由引擎计算"
    },
    "on_chain": {
      "type": "boolean",
      "description": "是否已上链锚定",
      "default": false
    },
    "chain_tx_hash": {
      "type": ["string", "null"],
      "description": "链上交易哈希"
    },
    "context": {
      "type": "object",
      "description": "验证上下文",
      "properties": {
        "description": { "type": "string" },
        "source_url": { "type": "string" },
        "extracted_quotes": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "text": { "type": "string" },
              "position": { "type": "integer" }
            }
          }
        }
      }
    }
  }
}
```

**示例实例：**

```json
{
  "event_id": "evt_3a4b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d",
  "type": "remix",
  "subject_asset": "asset_new_remix_123",
  "object_asset": "asset_7f8a9b2c-3d4e-5f6a-7b8c-9d0e1f2a3b4c",
  "timestamp": "2026-05-10T08:15:30Z",
  "platform_id": "platform_echo_main",
  "user_id": "user_creator_bob",
  "semantic_depth": 0.65,
  "weight": 0.52,
  "on_chain": true,
  "chain_tx_hash": "0x1234abcd5678efgh",
  "context": {
    "description": "对原始ECHO概念图进行风格化重绘",
    "source_url": "https://echo.network/remix/123",
    "extracted_quotes": [
      { "text": "四权力模型", "position": 1 }
    ]
  }
}
```

---

### 2.4 Transaction（交易/分润）

交易记录资产的收益流转。ECHO 的分润发生在每次验证事件触发时，按照四权中的"益"配置执行。

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Transaction",
  "description": "ECHO 网络中的分润/交易记录",
  "type": "object",
  "required": ["tx_id", "from", "to", "amount", "type", "timestamp"],
  "properties": {
    "tx_id": {
      "type": "string",
      "description": "全局唯一交易标识符"
    },
    "from": {
      "type": "string",
      "description": "转出方用户ID或平台ID"
    },
    "to": {
      "type": "string",
      "description": "接收方用户ID"
    },
    "amount": {
      "type": "number",
      "description": "交易金额"
    },
    "currency": {
      "type": "string",
      "default": "ECHO"
    },
    "type": {
      "type": "string",
      "enum": ["usage_fee", "spread_reward", "derive_license", "benefit_share", "platform_fee", "settlement", "refund"],
      "description": "交易类型"
    },
    "associated_asset": {
      "type": ["string", "null"],
      "description": "关联资产ID"
    },
    "associated_event": {
      "type": ["string", "null"],
      "description": "触发该交易的验证事件ID"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time"
    },
    "status": {
      "type": "string",
      "enum": ["pending", "confirmed", "failed", "reversed"],
      "default": "pending"
    },
    "settlement": {
      "type": "object",
      "description": "分润计算详情",
      "properties": {
        "total_pool": { "type": "number" },
        "creator_share": { "type": "number" },
        "referrer_share": { "type": "number" },
        "platform_share": { "type": "number" },
        "derivative_share": { "type": "number" }
      }
    }
  }
}
```

**示例实例：**

```json
{
  "tx_id": "tx_9f8e7d6c-5b4a-3c2d-1e0f-9a8b7c6d5e4f",
  "from": "platform_echo_main",
  "to": "user_creator_alice",
  "amount": 12.50,
  "currency": "ECHO",
  "type": "benefit_share",
  "associated_asset": "asset_7f8a9b2c-3d4e-5f6a-7b8c-9d0e1f2a3b4c",
  "associated_event": "evt_3a4b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d",
  "timestamp": "2026-05-10T08:15:35Z",
  "status": "confirmed",
  "settlement": {
    "total_pool": 25.00,
    "creator_share": 12.50,
    "referrer_share": 0,
    "platform_share": 2.50,
    "derivative_share": 10.00
  }
}
```

---

### 2.5 RuleTemplate（规则模板）

规则模板是可复用的四权配置方案，由用户创建并在市场中流通。嵌入约档和法档使用。

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "RuleTemplate",
  "description": "ECHO 规则市场中的规则模板",
  "type": "object",
  "required": ["template_id", "name", "creator_id", "default_powers", "pricing"],
  "properties": {
    "template_id": {
      "type": "string",
      "description": "全局唯一模板标识符"
    },
    "name": {
      "type": "string",
      "description": "模板名称"
    },
    "description": {
      "type": "string",
      "description": "模板描述"
    },
    "creator_id": {
      "type": "string",
      "description": "模板创建者用户ID"
    },
    "default_powers": {
      "type": "object",
      "description": "模板默认四权配置",
      "properties": {
        "use": { "type": "integer", "minimum": 0, "maximum": 15 },
        "spread": { "type": "integer", "minimum": 0, "maximum": 15 },
        "derive": { "type": "integer", "minimum": 0, "maximum": 15 },
        "benefit": { "type": "integer", "minimum": 0, "maximum": 15 }
      }
    },
    "pricing": {
      "type": "object",
      "description": "模板定价信息",
      "properties": {
        "type": {
          "type": "string",
          "enum": ["free", "one_time", "subscription", "usage_based"]
        },
        "amount": { "type": "number" },
        "currency": { "type": "string", "default": "ECHO" },
        "usage_rate": {
          "type": "object",
          "description": "按使用量计费时的费率",
          "properties": {
            "per_view": { "type": "number" },
            "per_spread": { "type": "number" },
            "per_derivative": { "type": "number" }
          }
        }
      }
    },
    "usage_count": {
      "type": "integer",
      "description": "被引用的次数",
      "default": 0
    },
    "rating": {
      "type": "object",
      "description": "评分信息",
      "properties": {
        "average": { "type": "number", "minimum": 0, "maximum": 5 },
        "count": { "type": "integer" }
      }
    },
    "tags": {
      "type": "array",
      "items": { "type": "string" }
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "is_verified": {
      "type": "boolean",
      "description": "是否经过平台审核",
      "default": false
    }
  }
}
```

**示例实例：**

```json
{
  "template_id": "tpl_creative_commons_echo",
  "name": "ECHO 创作共用宽松版",
  "description": "允许公开使用、传播和派生，要求署名并按约定分润",
  "creator_id": "user_platform_official",
  "default_powers": {
    "use": 15,
    "spread": 15,
    "derive": 7,
    "benefit": 3
  },
  "pricing": {
    "type": "free",
    "amount": 0,
    "currency": "ECHO",
    "usage_rate": {
      "per_view": 0,
      "per_spread": 0.001,
      "per_derivative": 0.01
    }
  },
  "usage_count": 3420,
  "rating": {
    "average": 4.7,
    "count": 156
  },
  "tags": ["open", "attribution", "popular"],
  "created_at": "2026-03-01T00:00:00Z",
  "is_verified": true
}
```

---

### 2.6 ShiPosition（势位计算）

势位是资产在 ECHO 网络中的综合影响力度量。势位计算结果是势图接管引擎的输入。

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "ShiPosition",
  "description": "资产势位计算结果",
  "type": "object",
  "required": ["asset_id", "score", "stage", "dimensions"],
  "properties": {
    "asset_id": {
      "type": "string",
      "description": "关联资产ID"
    },
    "score": {
      "type": "number",
      "description": "综合势位分数 P (0~100)",
      "minimum": 0,
      "maximum": 100
    },
    "stage": {
      "type": "integer",
      "description": "生命阶段编码",
      "minimum": 0,
      "maximum": 4
    },
    "stage_name": {
      "type": "string",
      "enum": ["latent", "manifest", "growth", "mature", "transform"]
    },
    "dimensions": {
      "type": "object",
      "description": "各维度原始值",
      "required": ["time_density", "centrality", "semantic_cross"],
      "properties": {
        "time_density": {
          "type": "number",
          "description": "时间密度 T (0~100)"
        },
        "centrality": {
          "type": "number",
          "description": "中心性 S (0~100)"
        },
        "semantic_cross": {
          "type": "number",
          "description": "语义跨越 C (0~100)"
        }
      }
    },
    "calculation": {
      "type": "object",
      "description": "计算详情",
      "properties": {
        "formula": {
          "type": "string",
          "description": "使用的计算公式"
        },
        "weights": {
          "type": "object",
          "properties": {
            "time_density": { "type": "number" },
            "centrality": { "type": "number" },
            "semantic_cross": { "type": "number" }
          }
        },
        "computed_at": {
          "type": "string",
          "format": "date-time"
        },
        "verification_count": {
          "type": "integer",
          "description": "参与计算的验证事件数量"
        }
      }
    },
    "trend": {
      "type": "object",
      "description": "势位变化趋势",
      "properties": {
        "direction": { "type": "string", "enum": ["rising", "falling", "stable"] },
        "velocity": { "type": "number", "description": "变化速度（分数/天）" }
      }
    }
  }
}
```

**示例实例：**

```json
{
  "asset_id": "asset_7f8a9b2c-3d4e-5f6a-7b8c-9d0e1f2a3b4c",
  "score": 45.2,
  "stage": 2,
  "stage_name": "growth",
  "dimensions": {
    "time_density": 52.0,
    "centrality": 38.5,
    "semantic_cross": 41.0
  },
  "calculation": {
    "formula": "P = 0.4*T + 0.4*S + 0.2*C",
    "weights": {
      "time_density": 0.4,
      "centrality": 0.4,
      "semantic_cross": 0.2
    },
    "computed_at": "2026-05-10T12:00:00Z",
    "verification_count": 23
  },
  "trend": {
    "direction": "rising",
    "velocity": 2.3
  }
}
```

---

## 3. 验证图（Verification Graph）

### 3.1 数据结构

验证图 G = (V, E, W) 以**邻接表**形式存储，支持高效的前向/反向遍历：

```
VerificationGraph {
  // 顶点集合：资产ID -> 资产元数据
  vertices: Map<asset_id, VertexMeta>

  // 出边邻接表：资产ID -> [OutgoingEdge]
  adjacency_out: Map<asset_id, Array<Edge>>

  // 入边邻接表：资产ID -> [IncomingEdge]（用于反向追溯）
  adjacency_in:  Map<asset_id, Array<Edge>>

  // 边索引：event_id -> Edge（快速查找）
  edge_index: Map<event_id, Edge>
}

VertexMeta {
  asset_id: string
  created_at: timestamp
  first_seen: timestamp
  last_verified: timestamp
  total_out_degree: int
  total_in_degree: int
}

Edge {
  event_id: string
  type: EventType          // reference | remix | integrate | fork
  from: asset_id           // subject_asset
  to: asset_id             // object_asset
  timestamp: timestamp
  semantic_depth: float    // 0~1
  weight: float            // 语义深度 × 时间衰减
  on_chain: bool
}
```

### 3.2 伪代码：核心算法

#### 算法 A：添加验证边

```
function addEdge(graph, event):
  // 1. 确保顶点存在
  if not graph.vertices.has(event.subject_asset):
    createVertex(graph, event.subject_asset)
  if not graph.vertices.has(event.object_asset):
    createVertex(graph, event.object_asset)

  // 2. 计算权重：语义深度 × 时间衰减
  age = now() - event.timestamp
  decay = exp(-lambda * age)    // lambda: 衰减系数，默认 0.001/秒
  weight = event.semantic_depth * decay

  // 3. 创建边对象
  edge = {
    event_id: event.event_id,
    type: event.type,
    from: event.subject_asset,
    to: event.object_asset,
    timestamp: event.timestamp,
    semantic_depth: event.semantic_depth,
    weight: weight,
    on_chain: event.on_chain
  }

  // 4. 插入邻接表
  graph.adjacency_out[event.subject_asset].append(edge)
  graph.adjacency_in[event.object_asset].append(edge)
  graph.edge_index[event.event_id] = edge

  // 5. 更新顶点元数据
  graph.vertices[event.subject_asset].total_out_degree += 1
  graph.vertices[event.object_asset].total_in_degree += 1
  graph.vertices[event.object_asset].last_verified = now()

  return edge
```

#### 算法 B：计算中心性（PageRank 变体）

ECHO 使用带权重的 Personalized PageRank，以资产创作者为偏好向量：

```
function computeCentrality(graph, asset_id, iterations=100, damping=0.85):
  N = graph.vertices.size
  if N == 0: return 0

  // 初始化分数
  scores = Map<asset_id, float>
  for v in graph.vertices:
    scores[v] = 1.0 / N

  // 迭代收敛
  for i in 0..iterations:
    new_scores = Map<asset_id, float>

    for v in graph.vertices:
      score = (1 - damping) / N   // 随机跳转概率

      // 累加入边贡献（带权重）
      for edge in graph.adjacency_in[v]:
        from_node = edge.from
        out_edges = graph.adjacency_out[from_node]
        total_weight = sum(e.weight for e in out_edges)

        if total_weight > 0:
          contribution = damping * scores[from_node] * (edge.weight / total_weight)
          score += contribution

      new_scores[v] = score

    scores = new_scores

  // 归一化到 0~100
  max_score = max(scores.values)
  if max_score > 0:
    centrality = (scores[asset_id] / max_score) * 100
  else:
    centrality = 0

  return centrality
```

#### 算法 C：计算时间密度

```
function computeTimeDensity(graph, asset_id, window_days=30):
  now = currentTime()
  window_start = now - window_days * 86400

  events = graph.adjacency_in[asset_id] + graph.adjacency_out[asset_id]

  // 只统计窗口内的事件
  recent_events = filter(e => e.timestamp >= window_start, events)

  // 计算时间密度：事件频率的指数加权和
  if recent_events.empty:
    return 0

  weighted_sum = 0
  for event in recent_events:
    age_days = (now - event.timestamp) / 86400
    recency_weight = exp(-0.1 * age_days)
    weighted_sum += recency_weight * event.semantic_depth

  // 归一化：使用对数压缩避免极端值
  density = min(100, log(1 + weighted_sum * 10) * 20)
  return density
```

#### 算法 D：计算语义跨越

```
function computeSemanticCross(graph, asset_id):
  // 语义跨越 = 该资产连接到的不同语义域数量 / 最大可能域数
  // 简化实现：使用事件类型多样性 + 派生深度

  edges = graph.adjacency_in[asset_id]
  if edges.empty:
    return 0

  // 1. 事件类型多样性（香农熵）
  type_counts = countBy(e.type, edges)
  total = edges.length
  entropy = 0
  for (type, count) in type_counts:
    p = count / total
    entropy -= p * log(p, 2)

  max_entropy = log(4, 2)  // 4种事件类型
  type_diversity = (entropy / max_entropy) * 100

  // 2. 派生深度：该资产被 fork 后产生的派生链长度
  fork_depth = maxDerivativeDepth(graph, asset_id)
  depth_score = min(100, fork_depth * 20)

  // 3. 综合语义跨越
  semantic_cross = 0.6 * type_diversity + 0.4 * depth_score
  return min(100, semantic_cross)

function maxDerivativeDepth(graph, asset_id, visited=Set()):
  if asset_id in visited: return 0  // 防环
  visited.add(asset_id)

  fork_edges = filter(e => e.type == "fork", graph.adjacency_in[asset_id])
  if fork_edges.empty:
    return 0

  max_depth = 0
  for edge in fork_edges:
    depth = 1 + maxDerivativeDepth(graph, edge.from, visited)
    max_depth = max(max_depth, depth)

  return max_depth
```

#### 算法 E：综合势位计算

```
function computeShiPosition(graph, asset_id):
  T = computeTimeDensity(graph, asset_id)
  S = computeCentrality(graph, asset_id)
  C = computeSemanticCross(graph, asset_id)

  // 势位分数公式
  P = 0.4 * T + 0.4 * S + 0.2 * C

  // 确定生命阶段
  stage = determineStage(P)
  stage_name = stageNames[stage]

  return {
    asset_id: asset_id,
    score: P,
    stage: stage,
    stage_name: stage_name,
    dimensions: { time_density: T, centrality: S, semantic_cross: C },
    calculation: {
      formula: "P = 0.4*T + 0.4*S + 0.2*C",
      weights: { time_density: 0.4, centrality: 0.4, semantic_cross: 0.2 },
      computed_at: now(),
      verification_count: graph.adjacency_in[asset_id].length + graph.adjacency_out[asset_id].length
    }
  }
```

---

## 4. 资产生命周期状态机

### 4.1 状态转换图

```
                    ┌─────────────┐
         ┌─────────│   CREATED   │◄───── 资产创建
         │         └──────┬──────┘
         │                │
         │                │ 初始四权配置
         │                ▼
         │         ┌─────────────┐
         │         │   LATENT    │ P < 20
         │         │   (潜藏)    │
         │         └──────┬──────┘
         │                │ 势位 >= 20
         │                │
         │                ▼
         │         ┌─────────────┐
         │    ┌────│  MANIFEST   │ 20 ≤ P < 40
         │    │    │   (显现)    │
         │    │    └──────┬──────┘
         │    │           │ 势位 >= 40
         │    │           │
         │    │           ▼
         │    │    ┌─────────────┐
         │    │    │   GROWTH    │ 40 ≤ P < 60
         │    │    │   (生长)    │
         │    │    └──────┬──────┘
         │    │           │ 势位 >= 60
         │    │           │
         │    │           ▼
         │    │    ┌─────────────┐
         │    │    │   MATURE    │ 60 ≤ P < 80
         │    │    │   (大成)    │
         │    │    └──────┬──────┘
         │    │           │ 势位 >= 80
         │    │           │
         │    │           ▼
         │    │    ┌─────────────┐
         │    └───►│  TRANSFORM  │ P ≥ 80
         │         │   (转化)    │
         │         └──────┬──────┘
         │                │
         │                │ 可选择归档/衍生新资产
         │                ▼
         │         ┌─────────────┐
         └────────►│  ARCHIVED   │
                   └─────────────┘
```

### 4.2 伪代码：状态转换引擎

```
// 生命阶段阈值
STAGE_THRESHOLDS = [
  { stage: 0, name: "latent",    min: 0,  max: 20 },
  { stage: 1, name: "manifest",  min: 20, max: 40 },
  { stage: 2, name: "growth",    min: 40, max: 60 },
  { stage: 3, name: "mature",    min: 60, max: 80 },
  { stage: 4, name: "transform", min: 80, max: 100 }
]

function determineStage(score):
  for threshold in STAGE_THRESHOLDS:
    if score >= threshold.min and score < threshold.max:
      return threshold.stage
  return 4  // P ≥ 80 时返回 transform

function transitionStage(asset, new_shi_position):
  old_stage = asset.shi_position.stage
  new_stage = new_shi_position.stage

  if old_stage == new_stage:
    return { changed: false, from: old_stage, to: new_stage }

  // 记录转换
  transition = {
    asset_id: asset.asset_id,
    from_stage: old_stage,
    to_stage: new_stage,
    from_score: asset.shi_position.score,
    to_score: new_shi_position.score,
    timestamp: now()
  }

  // 更新资产状态
  asset.shi_position = new_shi_position
  asset.version += 1
  asset.updated_at = now()

  // 触发势图接管（如果启用）
  if asset.shi_takeover.enabled:
    applyShiTakeover(asset, new_stage)

  // 发出转换事件
  emit("asset_stage_transition", transition)

  return { changed: true, from: old_stage, to: new_stage, transition: transition }
```

### 4.3 状态转换事件定义

```json
{
  "title": "StageTransitionEvent",
  "type": "object",
  "properties": {
    "event_type": { "const": "asset_stage_transition" },
    "asset_id": { "type": "string" },
    "from_stage": { "type": "integer" },
    "to_stage": { "type": "integer" },
    "from_stage_name": { "type": "string" },
    "to_stage_name": { "type": "string" },
    "from_score": { "type": "number" },
    "to_score": { "type": "number" },
    "timestamp": { "type": "string", "format": "date-time" },
    "power_changes": {
      "type": "object",
      "description": "四权变化详情（势图接管触发时）"
    }
  }
}
```

---

## 5. 四权验证引擎

### 5.1 核心逻辑

给定一个用户、一个资产和一个操作，验证引擎判断该操作是否被允许。

```
// 操作到四权力的映射
OPERATION_TO_POWER = {
  "view":       "use",
  "download":   "use",
  "share":      "spread",
  "repost":     "spread",
  "remix":      "derive",
  "integrate":  "derive",
  "fork":       "derive",
  "tip":        "benefit",
  "purchase":   "benefit",
  "derivative_pay": "benefit"
}

// 档位检查：给定用户与资产的关系，判断是否满足档位要求
function checkLevel(user, asset, required_level_mask):
  // 禁：永远不允许
  if required_level_mask == LEVEL_MASK.FORBIDDEN:
    return false

  // 公：永远允许
  if required_level_mask == LEVEL_MASK.PUBLIC:
    return true

  // 己：仅创作者
  if (required_level_mask & LEVEL_MASK.SELF) and user.user_id == asset.creator_id:
    return true

  // 亲：在创作者亲密度列表中
  if (required_level_mask & LEVEL_MASK.KINSHIP):
    // 获取资产创作者
    creator = getUser(asset.creator_id)
    if user.user_id in creator.kinship_list:
      return true

  // 约：检查规则模板约束
  if (required_level_mask & LEVEL_MASK.CONTRACT):
    if asset.rule_template_id:
      template = getRuleTemplate(asset.rule_template_id)
      // 检查用户是否满足模板合约条件
      if checkContractConditions(user, template):
        return true

  // 法：检查平台规则/法律框架
  if (required_level_mask & LEVEL_MASK.LAW):
    if checkLegalCompliance(user, asset):
      return true

  return false
```

### 5.2 伪代码：四权验证引擎

```
function verifyOperation(user, asset, operation, context={}):
  // 1. 确定涉及的四权力
  power = OPERATION_TO_POWER[operation]
  if not power:
    return { allowed: false, reason: "unknown_operation" }

  // 2. 获取当前四权配置
  power_config = asset.four_powers[power]

  // 3. 检查档位
  level_ok = checkLevel(user, asset, power_config)

  if not level_ok:
    return {
      allowed: false,
      reason: "insufficient_level",
      power: power,
      required: power_config,
      user_id: user.user_id,
      asset_id: asset.asset_id
    }

  // 4. 检查额外约束（益权可能需要支付）
  if power == "benefit" and operation in ["purchase", "derivative_pay"]:
    payment_ok = checkPayment(user, asset, operation, context)
    if not payment_ok:
      return { allowed: false, reason: "insufficient_payment" }

  // 5. 检查派生权限（fork 操作需要验证源资产的衍权）
  if operation == "fork" and context.source_asset:
    source_asset = getAsset(context.source_asset)
    derive_ok = verifyOperation(user, source_asset, "fork", context)
    if not derive_ok.allowed:
      return { allowed: false, reason: "source_derive_denied", source: derive_ok }

  // 6. 通过
  return {
    allowed: true,
    power: power,
    level: power_config,
    asset_id: asset.asset_id,
    user_id: user.user_id,
    operation: operation,
    // 分润预览（如果是涉及益权的操作）
    benefit_preview: (power == "benefit") ? previewBenefit(asset, operation) : null
  }
```

### 5.3 档位检查详细逻辑

```
function checkLevel(user, asset, required_level_mask):
  // 快速路径
  if required_level_mask == 0:   return false  // 禁
  if required_level_mask == 15:  return true   // 公

  // 检查己
  if (required_level_mask & 1) and user.user_id == asset.creator_id:
    return true

  // 检查亲
  if (required_level_mask & 2):
    creator = getUser(asset.creator_id)
    if user.user_id in creator.kinship_list:
      return true

  // 检查约
  if (required_level_mask & 4):
    if asset.rule_template_id:
      template = getRuleTemplate(asset.rule_template_id)
      // 检查用户是否购买了模板/是否满足使用条件
      if userHasTemplateAccess(user.user_id, asset.rule_template_id):
        return true

  // 检查法
  if (required_level_mask & 8):
    // 平台级合规检查
    if user.reputation.score >= 30 and not user.is_banned:
      return true

  return false

// 压缩版四权编码/解码（用于存储优化）
function encodeFourPowers(powers):
  return (powers.benefit << 12) | (powers.derive << 8) | (powers.spread << 4) | powers.use

function decodeFourPowers(raw):
  return {
    use:    raw & 0x000F,
    spread: (raw >> 4) & 0x000F,
    derive: (raw >> 8) & 0x000F,
    benefit:(raw >> 12) & 0x000F
  }
```

---

## 6. 势图接管引擎

### 6.1 设计原则

势图接管遵循核心原则：**只开放，不收紧**。一旦四权配置因势位提升而放宽，即使资产势位后续下降（理论上不应发生，因为验证图是累积的），配置也不会自动回缩。创作者可手动收紧，但引擎只负责"推开门"。

### 6.2 状态机

```
势图接管状态机：

┌─────────────────────────────────────────┐
│           [TAKEOVER_DISABLED]           │
│            势图接管已禁用               │
└─────────────────────────────────────────┘
                   │
                   │ 启用势图接管
                   ▼
┌─────────────────────────────────────────┐
│           [TAKEOVER_ACTIVE]              │
│            势图接管运行中                │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ 触发条件：势位计算周期完成       │    │
│  │         且检测到阶段跃迁         │    │
│  └─────────────────────────────────┘    │
│                   │                     │
│                   ▼                     │
│  ┌─────────────────────────────────┐    │
│  │ [APPLYING_TARGET_CONFIG]         │    │
│  │ 应用目标阶段配置                  │    │
│  │                                   │    │
│  │ 规则：新配置 OR 旧配置            │    │
│  │ (位掩码取并集，只增不减)          │    │
│  └─────────────────────────────────┘    │
│                   │                     │
│                   ▼                     │
│  ┌─────────────────────────────────┐    │
│  │ [NOTIFYING]                      │    │
│  │ 通知创作者四权已自动调整          │    │
│  │ 提供手动覆盖选项                  │    │
│  └─────────────────────────────────┘    │
│                   │                     │
│                   ▼                     │
│  ┌─────────────────────────────────┐    │
│  │ [WAITING_OVERRIDE]                 │    │
│  │ 等待创作者手动调整（72小时）      │    │
│  │ 超时后自动锁定                    │    │
│  └─────────────────────────────────┘    │
│                   │                     │
│                   ▼                     │
│  ┌─────────────────────────────────┐    │
│  │ [LOCKED]                           │    │
│  │ 配置锁定，等待下一次阶段跃迁      │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### 6.3 伪代码：势图接管引擎

```
function applyShiTakeover(asset, new_stage):
  if not asset.shi_takeover.enabled:
    return { applied: false, reason: "takeover_disabled" }

  stage_names = ["latent", "manifest", "growth", "mature", "transform"]
  stage_name = stage_names[new_stage]

  // 获取目标配置
  target_config = asset.shi_takeover.stage_configs[stage_name]
  if not target_config:
    return { applied: false, reason: "no_target_config" }

  current = asset.four_powers

  // 核心规则：只开放，不收紧（位掩码取并集）
  new_powers = {
    use:    current.use    | target_config.use,    // OR 运算，取并集
    spread: current.spread | target_config.spread,
    derive: current.derive | target_config.derive,
    benefit:current.benefit| target_config.benefit
  }

  // 检查是否有实际变化
  changed = (new_powers.use    != current.use) ||
            (new_powers.spread != current.spread) ||
            (new_powers.derive != current.derive) ||
            (new_powers.benefit!= current.benefit)

  if not changed:
    return { applied: false, reason: "no_change_needed", stage: stage_name }

  // 记录变化
  power_changes = {
    use:    { from: current.use,    to: new_powers.use },
    spread: { from: current.spread, to: new_powers.spread },
    derive: { from: current.derive, to: new_powers.derive },
    benefit:{ from: current.benefit, to: new_powers.benefit }
  }

  // 应用新配置
  asset.four_powers = new_powers
  asset.four_powers_raw = encodeFourPowers(new_powers)
  asset.version += 1
  asset.updated_at = now()

  // 发送通知
  notifyCreator(asset.creator_id, {
    type: "shi_takeover_applied",
    asset_id: asset.asset_id,
    stage: stage_name,
    power_changes: power_changes,
    // 提供72小时覆盖窗口
    override_deadline: now() + 72 * 3600
  })

  return {
    applied: true,
    stage: stage_name,
    power_changes: power_changes,
    override_window_hours: 72
  }

// 创作者手动覆盖
function overrideTakeover(asset, creator_id, manual_powers):
  // 验证权限
  if creator_id != asset.creator_id:
    return { success: false, reason: "unauthorized" }

  // 验证窗口是否仍然开放
  // （实际实现中需检查上次接管时间）

  // 创作者可以收紧或放宽，不受"只开放"限制
  // 因为这是人工意志，不是自动化决策
  asset.four_powers = manual_powers
  asset.four_powers_raw = encodeFourPowers(manual_powers)
  asset.version += 1
  asset.updated_at = now()

  // 标记为手动覆盖，暂停该阶段的自动接管
  asset.shi_takeover.overridden_at = now()

  return { success: true, manual_powers: manual_powers }
```

### 6.4 势图接管配置 JSON Schema

```json
{
  "title": "ShiTakeoverConfig",
  "type": "object",
  "properties": {
    "enabled": {
      "type": "boolean",
      "default": true,
      "description": "是否启用势图接管"
    },
    "stage_configs": {
      "type": "object",
      "description": "各阶段目标配置",
      "properties": {
        "latent": {
          "type": "object",
          "properties": {
            "use": { "type": "integer", "default": 1 },
            "spread": { "type": "integer", "default": 0 },
            "derive": { "type": "integer", "default": 0 },
            "benefit": { "type": "integer", "default": 1 }
          }
        },
        "manifest": {
          "type": "object",
          "properties": {
            "use": { "type": "integer", "default": 3 },
            "spread": { "type": "integer", "default": 1 },
            "derive": { "type": "integer", "default": 1 },
            "benefit": { "type": "integer", "default": 3 }
          }
        },
        "growth": {
          "type": "object",
          "properties": {
            "use": { "type": "integer", "default": 7 },
            "spread": { "type": "integer", "default": 3 },
            "derive": { "type": "integer", "default": 3 },
            "benefit": { "type": "integer", "default": 7 }
          }
        },
        "mature": {
          "type": "object",
          "properties": {
            "use": { "type": "integer", "default": 15 },
            "spread": { "type": "integer", "default": 7 },
            "derive": { "type": "integer", "default": 7 },
            "benefit": { "type": "integer", "default": 15 }
          }
        },
        "transform": {
          "type": "object",
          "properties": {
            "use": { "type": "integer", "default": 15 },
            "spread": { "type": "integer", "default": 15 },
            "derive": { "type": "integer", "default": 15 },
            "benefit": { "type": "integer", "default": 15 }
          }
        }
      }
    },
    "override_window_hours": {
      "type": "integer",
      "default": 72,
      "description": "创作者覆盖窗口时长"
    },
    "overridden_at": {
      "type": ["string", "null"],
      "format": "date-time",
      "description": "上次手动覆盖时间"
    },
    "history": {
      "type": "array",
      "description": "接管历史记录",
      "items": {
        "type": "object",
        "properties": {
          "timestamp": { "type": "string", "format": "date-time" },
          "from_stage": { "type": "string" },
          "to_stage": { "type": "string" },
          "power_changes": { "type": "object" },
          "was_overridden": { "type": "boolean" }
        }
      }
    }
  }
}
```

---

## 7. 索引与查询设计

### 7.1 推荐索引

```
// Asset 集合
Index: { creator_id: 1 }
Index: { "shi_position.stage": 1 }
Index: { "shi_position.score": -1 }
Index: { four_powers_raw: 1 }        // 支持按四权配置筛选
Index: { created_at: -1 }
Index: { rule_template_id: 1 }

// VerificationEvent 集合
Index: { subject_asset: 1, timestamp: -1 }
Index: { object_asset: 1, timestamp: -1 }
Index: { type: 1 }
Index: { on_chain: 1 }
Index: { user_id: 1 }

// Transaction 集合
Index: { from: 1, timestamp: -1 }
Index: { to: 1, timestamp: -1 }
Index: { associated_asset: 1 }
Index: { associated_event: 1 }
Index: { status: 1 }

// ShiPosition 集合（或作为 Asset 内嵌文档）
Index: { score: -1 }
Index: { stage: 1, score: -1 }
Index: { "dimensions.centrality": -1 }
```

### 7.2 关键查询模式

```
// 1. 查询某资产的所有派生资产
find all edges where type="fork" and to=target_asset_id
-> 返回所有 from（即派生资产）

// 2. 查询某资产的验证路径（追溯）
DFS/BFS on adjacency_in starting from asset_id
-> 返回所有上游引用关系

// 3. 按四权筛选可访问资产
query assets where
  four_powers.use & user_access_mask > 0
  and shi_position.stage >= min_stage

// 4. 势位排行榜
sort assets by shi_position.score descending
  where created_at > cutoff_date
```

---

## 8. 数据流时序图

```
用户创建资产              验证事件产生              势位计算                势图接管
     │                        │                      │                     │
     │ 1. createAsset()       │                      │                     │
     ├───────────────────────►│                      │                     │
     │ ◄────────asset_id──────┤                      │                     │
     │                        │                      │                     │
     │                        │ 2. 用户引用/混剪      │                     │
     │                        ├─────────────────────►│                     │
     │                        │ ◄─────event_id─────┤                     │
     │                        │                      │                     │
     │                        │                      │ 3. 定时任务触发      │
     │                        │                      ├───────►             │
     │                        │                      │       │             │
     │                        │                      │ 4. computeShiPosition()│
     │                        │                      │       │             │
     │                        │                      │ ◄─────┤             │
     │                        │                      │       │             │
     │                        │                      │ 5. 阶段跃迁？         │
     │                        │                      ├───────┤             │
     │                        │                      │       │             │
     │                        │                      │ Yes   │             │
     │                        │                      ├───────┼────────────►│
     │                        │                      │       │             │
     │                        │                      │       │ 6. applyShiTakeover()
     │                        │                      │       │             │
     │ 7. 通知创作者          │                      │       │ ◄───────────┤
     │◄─────────────────────┼──────────────────────┼───────┼─────────────┤
     │                        │                      │       │             │
     │ 8. 可选：手动覆盖       │                      │       │             │
     ├───────────────────────►│                      │       │             │
```

---

## 9. 附录：完整四权档位矩阵

下表展示一个资产可能的四权配置示例及其含义：

| 四权配置 (use/spread/derive/benefit) | 含义解读 |
|--------------------------------------|---------|
| `1/0/0/1` | 仅限创作者自己使用，禁止传播和派生，收益归己 |
| `15/1/0/1` | 任何人可查看，仅创作者可传播，禁止派生，收益归己 |
| `15/15/1/3` | 完全公开，可自由传播，仅创作者可派生，收益按合约分配 |
| `15/15/7/15` | 完全开放，任何人可传播和派生（需满足约档），收益公有 |
| `15/15/15/15` | 完全公有域，无任何限制 |
| `3/3/1/3` | 创作者+亲友可用，同范围可传播，仅创作者可派生，合约收益 |

---

## 10. 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-05-10 | 初始设计文档，覆盖全部 6 个核心数据模型、验证图算法、生命周期状态机、四权验证引擎和势图接管引擎 |

---

> *"使用权不是所有权的残影，而是数字原生世界的根本权利。"* — ECHO 设计哲学
