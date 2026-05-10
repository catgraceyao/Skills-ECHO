# ECHO 系统模拟器 — 场景模拟脚本与测试用例

> **Agent 4 交付物** | 场景模拟设计师 & 测试用例专家
> 为 ECHO 使用权生命周期网络提供完整的可执行场景、边界测试与可视化叙事脚本。

---

## 目录

1. [任务1：4个核心场景模拟脚本](#任务1-4个核心场景模拟脚本)
2. [任务2：边界条件测试用例（20个）](#任务2-边界条件测试用例)
3. [任务3：可视化叙事脚本（演示模式）](#任务3-可视化叙事脚本)

---

## 任务1：4个核心场景模拟脚本

### 场景1：独立音乐人的生态生长

#### 场景描述和目标

Alice 是一名独立音乐人，在 ECHO 网络上发布一首新单曲《Stars》。初始设置较为保守——仅允许亲近的人使用，衍生品和收益分配都限制得很死。随着歌曲被引用、改编、广泛传播，资产进入「生长」阶段，势图接管机制触发，系统自动放宽权限。Alice 试图在高峰期收紧权限，被系统阻止。本场景验证**势图接管"只开放不收紧"原则**、**衍生即继承**和**元规则约束**。

#### 初始状态

```json
{
  "timestamp": "T0",
  "agents": [
    {
      "id": "alice",
      "name": "Alice",
      "type": "creator",
      "balance": 1000,
      "reputation": 5.0,
      "trust_network": ["alice"]
    },
    {
      "id": "bob",
      "name": "Bob",
      "type": "creator",
      "balance": 500,
      "reputation": 3.0,
      "trust_network": ["bob", "alice"]
    },
    {
      "id": "charlie",
      "name": "Charlie",
      "type": "creator",
      "balance": 300,
      "reputation": 2.5,
      "trust_network": ["charlie", "bob"]
    },
    {
      "id": "diana",
      "name": "Diana",
      "type": "user",
      "balance": 100,
      "reputation": 1.0,
      "trust_network": ["diana"]
    }
  ],
  "assets": [
    {
      "id": "asset_stars",
      "name": "《Stars》单曲",
      "owner": "alice",
      "created_at": "T0",
      "rights": {
        "use": {"allowed": [2, 3], "level": 3, "description": "己(1)和亲(2)可用，约(3)需申请"},
        "expand": {"allowed": [2], "level": 2, "description": "仅亲(2)可传播"},
        "derive": {"allowed": [1], "level": 1, "description": "仅己(1)可改编"},
        "benefit": {"allowed": [1], "level": 1, "description": "仅己(1)可收益"}
      },
      "potential": {
        "stage": "latent",
        "stage_index": 0,
        "momentum": 0.0,
        "dimensions": {
          "flow": 0.0,
          "depth": 0.0,
          "reach": 0.0,
          "value": 0.0,
          "resonance": 0.0
        }
      },
      "validation_graph": {
        "nodes": ["asset_stars"],
        "edges": []
      },
      "derived_assets": [],
      "total_views": 0,
      "total_payments": 0,
      "takeover_enabled": true,
      "takeover_log": []
    }
  ]
}
```

#### 事件序列

```json
{
  "events": [
    {
      "step": 1,
      "timestamp": "T0+0m",
      "name": "发布资产",
      "actor": "alice",
      "action": "CREATE_ASSET",
      "target": "asset_stars",
      "params": {
        "rights": {"use":[2,3], "expand":[2], "derive":[1], "benefit":[1]},
        "takeover_enabled": true
      },
      "expected_state_changes": {
        "asset_stars.status": "active",
        "asset_stars.potential.stage": "latent",
        "alice.balance": 1000
      },
      "narration": "Alice 发布了单曲《Stars》，权限设置保守——只让亲近的人用。"
    },
    {
      "step": 2,
      "timestamp": "T0+1h",
      "name": "Bob 引用做视频BGM",
      "actor": "bob",
      "action": "VALIDATE",
      "target": "asset_stars",
      "params": {
        "event_type": "reference",
        "new_asset_id": "asset_bob_video",
        "relationship": "child"
      },
      "expected_state_changes": {
        "asset_stars.validation_graph.edges": ["asset_stars -> asset_bob_video"],
        "asset_stars.potential.dimensions.flow": 0.15,
        "asset_stars.potential.momentum": 0.15,
        "asset_stars.total_views": 1,
        "asset_bob_video.rights": {
          "inheritance": "derived_from_asset_stars",
          "use": [2,3],
          "expand": [2],
          "derive": [1],
          "benefit": [1]
        }
      },
      "narration": "Bob 引用《Stars》做了视频BGM。衍生资产自动继承了原资产的权限配置。"
    },
    {
      "step": 3,
      "timestamp": "T0+2h",
      "name": "Charlie 改编做 Remix",
      "actor": "charlie",
      "action": "VALIDATE",
      "target": "asset_stars",
      "params": {
        "event_type": "remix",
        "new_asset_id": "asset_charlie_remix",
        "relationship": "child"
      },
      "expected_state_changes": {
        "asset_stars.validation_graph.edges": ["asset_stars -> asset_bob_video", "asset_stars -> asset_charlie_remix"],
        "asset_stars.potential.dimensions.depth": 0.25,
        "asset_stars.potential.momentum": 0.40,
        "asset_stars.derived_assets": ["asset_bob_video", "asset_charlie_remix"]
      },
      "narration": "Charlie 做了 Remix 版本。改编事件提升了 depth 维度，势动量继续积累。"
    },
    {
      "step": 4,
      "timestamp": "T0+3h",
      "name": "大量用户使用和支付",
      "actor": "system",
      "action": "BULK_VALIDATE",
      "target": "asset_stars",
      "params": {
        "events": [
          {"type": "view", "count": 500, "users": ["user_1", "user_2", ...]},
          {"type": "pay", "count": 50, "amount": 200}
        ]
      },
      "expected_state_changes": {
        "asset_stars.total_views": 501,
        "asset_stars.total_payments": 200,
        "asset_stars.potential.dimensions.reach": 0.80,
        "asset_stars.potential.dimensions.value": 0.60,
        "asset_stars.potential.momentum": 0.85,
        "asset_stars.potential.stage": "growth",
        "asset_stars.potential.stage_index": 2
      },
      "narration": "歌曲 viral 了。500 次浏览，50 笔支付。势进入「生长」阶段。"
    },
    {
      "step": 5,
      "timestamp": "T0+4h",
      "name": "势图接管触发",
      "actor": "system",
      "action": "POTENTIAL_TAKEOVER",
      "target": "asset_stars",
      "params": {
        "trigger": "stage_threshold",
        "stage": "growth",
        "rule": "auto_expand_rights"
      },
      "expected_state_changes": {
        "asset_stars.rights.use.allowed": [2, 3, 4],
        "asset_stars.rights.expand.allowed": [2, 3],
        "asset_stars.rights.derive.allowed": [1, 2],
        "asset_stars.takeover_log": ["T0+4h: use expanded 3→4, expand expanded 2→3, derive expanded 1→2"],
        "asset_stars.potential.stage": "growth"
      },
      "narration": "势图接管触发！系统自动放宽权限——use 开放到法档(4)，expand 到约档(3)，derive 到亲档(2)。"
    },
    {
      "step": 6,
      "timestamp": "T0+5h",
      "name": "Alice 试图收紧权限（被阻止）",
      "actor": "alice",
      "action": "MODIFY_RIGHTS",
      "target": "asset_stars",
      "params": {
        "requested_rights": {"use":[2], "expand":[2], "derive":[1], "benefit":[1]},
        "reason": "我想收回控制权"
      },
      "expected_result": "REJECTED",
      "expected_state_changes": {
        "asset_stars.rights.use.allowed": [2, 3, 4],
        "asset_stars.modification_log": ["T0+5h: Alice requested tighten use[2,3,4]→[2], REJECTED by takeover_rule: 'only_expand'"]
      },
      "narration": "Alice 慌了，想把权限收回来。系统拒绝了——势图接管只开放，不收紧。"
    },
    {
      "step": 7,
      "timestamp": "T0+6h",
      "name": "继续生长，进入大成阶段",
      "actor": "system",
      "action": "BULK_VALIDATE",
      "target": "asset_stars",
      "params": {
        "events": [
          {"type": "reference", "count": 20},
          {"type": "remix", "count": 10},
          {"type": "view", "count": 5000},
          {"type": "pay", "count": 300, "amount": 1500}
        ]
      },
      "expected_state_changes": {
        "asset_stars.potential.momentum": 0.98,
        "asset_stars.potential.stage": "greatness",
        "asset_stars.potential.stage_index": 3,
        "asset_stars.rights.use.allowed": [2, 3, 4, 5],
        "asset_stars.rights.expand.allowed": [2, 3, 4],
        "asset_stars.rights.derive.allowed": [1, 2, 3],
        "asset_stars.rights.benefit.allowed": [1, 2, 3]
      },
      "narration": "歌曲真正大成了。权限自动开放到最大——use 到公档(5)，expand 到法档(4)，derive 到约档(3)，benefit 到约档(3)。"
    }
  ]
}
```

#### 关键洞察

1. **衍生即继承**：Bob 的视频和 Charlie 的 Remix 自动继承了原资产的权限配置，确保血统一致性。
2. **势图接管不可逆**：一旦进入 growth 阶段，系统自动放宽的权限不能被创作者手动收回——这是 ECHO 的核心元规则。
3. **生态生长 > 创作者控制**：创作者初始的保守设置被网络的集体使用行为"投票"推翻，体现了使用权生命周期网络的民主化逻辑。

---

### 场景2：开源软件的社区自治

#### 场景描述和目标

Bob 发布一款开源数据分析工具，初始配置极为开放——use/expand/derive 都到公档(5)，收益分配采用约档(3)和法档(4)的混合模式（社区贡献者可参与分润）。本场景验证**法档社区自治**、**规则市场交易**和**分叉机制**。

#### 初始状态

```json
{
  "timestamp": "T0",
  "agents": [
    {
      "id": "bob",
      "name": "Bob",
      "type": "creator",
      "balance": 2000,
      "reputation": 8.0,
      "role": "project_maintainer"
    },
    {
      "id": "carol",
      "name": "Carol",
      "type": "contributor",
      "balance": 800,
      "reputation": 5.5,
      "contributions": 15
    },
    {
      "id": "dave",
      "name": "Dave",
      "type": "contributor",
      "balance": 600,
      "reputation": 4.0,
      "contributions": 8
    },
    {
      "id": "eve",
      "name": "Eve",
      "type": "user",
      "balance": 200,
      "reputation": 2.0
    },
    {
      "id": "frank",
      "name": "Frank",
      "type": "enterprise_user",
      "balance": 5000,
      "reputation": 6.0
    }
  ],
  "assets": [
    {
      "id": "asset_opendata",
      "name": "OpenData Analytics",
      "owner": "bob",
      "type": "software",
      "rights": {
        "use": {"allowed": [4, 5], "level": 5, "description": "法(4)和公(5)可用"},
        "expand": {"allowed": [4, 5], "level": 5, "description": "法(4)和公(5)可传播"},
        "derive": {"allowed": [4, 5], "level": 5, "description": "法(4)和公(5)可改编"},
        "benefit": {"allowed": [3, 4], "level": 4, "description": "约(3)和法(4)参与分润"}
      },
      "benefit_distribution": {
        "type": "community_pool",
        "creator_share": 0.30,
        "contributor_share": 0.50,
        "community_share": 0.20,
        "rules": {
          "contributor_weight": "reputation * contributions",
          "distribution_frequency": "monthly"
        }
      },
      "potential": {
        "stage": "manifest",
        "stage_index": 1,
        "momentum": 0.20
      },
      "governance": {
        "model": "community_vote",
        "voting_threshold": 0.60,
        "voting_rights": ["creator", "contributor"]
      }
    }
  ]
}
```

#### 事件序列

```json
{
  "events": [
    {
      "step": 1,
      "timestamp": "T0",
      "name": "发布开源工具",
      "actor": "bob",
      "action": "CREATE_ASSET",
      "target": "asset_opendata",
      "params": {
        "rights": {"use":[4,5], "expand":[4,5], "derive":[4,5], "benefit":[3,4]},
        "governance": "community_vote"
      },
      "expected_state_changes": {
        "asset_opendata.status": "active",
        "asset_opendata.potential.stage": "manifest"
      },
      "narration": "Bob 发布了 OpenData Analytics，配置极为开放——公档可自由使用、传播和改编。"
    },
    {
      "step": 2,
      "timestamp": "T0+1d",
      "name": "被 Carol Fork",
      "actor": "carol",
      "action": "VALIDATE",
      "target": "asset_opendata",
      "params": {
        "event_type": "fork",
        "new_asset_id": "asset_opendata_fork_carol",
        "reason": "添加机器学习模块"
      },
      "expected_state_changes": {
        "asset_opendata.validation_graph.edges": ["asset_opendata -> asset_opendata_fork_carol"],
        "asset_opendata_fork_carol.rights": {
          "inheritance": "forked_from_asset_opendata",
          "use": [4,5],
          "expand": [4,5],
          "derive": [4,5],
          "benefit": [3,4]
        },
        "asset_opendata_fork_carol.governance": {
          "parent_reference": "asset_opendata",
          "sync_rights": true
        }
      },
      "narration": "Carol Fork 了项目，要添加机器学习模块。Fork 后的资产保持与原资产的权利同步。"
    },
    {
      "step": 3,
      "timestamp": "T0+3d",
      "name": "社区投票修改收益分配",
      "actor": "system",
      "action": "GOVERNANCE_VOTE",
      "target": "asset_opendata",
      "params": {
        "proposal": "修改 benefit 分配：creator_share 0.30→0.25, contributor_share 0.50→0.55",
        "votes": {
          "bob": "accept",
          "carol": "accept",
          "dave": "accept"
        },
        "threshold": 0.60,
        "result": "passed"
      },
      "expected_state_changes": {
        "asset_opendata.benefit_distribution.creator_share": 0.25,
        "asset_opendata.benefit_distribution.contributor_share": 0.55,
        "asset_opendata.governance.vote_log": ["T0+3d: benefit redistribution passed 3/3"]
      },
      "narration": "社区投票通过了新的收益分配方案。贡献者份额从 50% 提升到 55%。"
    },
    {
      "step": 4,
      "timestamp": "T0+5d",
      "name": "被整合进更大的框架",
      "actor": "frank",
      "action": "VALIDATE",
      "target": "asset_opendata",
      "params": {
        "event_type": "integrate",
        "new_asset_id": "asset_enterprise_suite",
        "relationship": "parent_includes_child",
        "integration_type": "module"
      },
      "expected_state_changes": {
        "asset_opendata.validation_graph.edges": [
          "asset_opendata -> asset_opendata_fork_carol",
          "asset_opendata <- asset_enterprise_suite"
        ],
        "asset_opendata.potential.dimensions.reach": 0.70,
        "asset_enterprise_suite.benefit_distribution": {
          "child_assets": ["asset_opendata"],
          "cascade_rules": "inherit_parent_with_multiplier"
        }
      },
      "narration": "Frank 的企业将 OpenData 整合进了更大的分析套件。整合关系形成了反向引用边。"
    },
    {
      "step": 5,
      "timestamp": "T0+7d",
      "name": "规则市场交易模板",
      "actor": "carol",
      "action": "RULE_MARKET",
      "target": "rule_template_ml_fork",
      "params": {
        "action": "publish",
        "template": {
          "name": "ML模块Fork最佳实践",
          "source_asset": "asset_opendata_fork_carol",
          "rights_preset": {"use":[4,5], "derive":[4,5], "benefit":[3,4]},
          "price": 50,
          "currency": "ECHO"
        }
      },
      "expected_state_changes": {
        "rule_markplace.listings": ["rule_template_ml_fork"],
        "carol.balance": 850,
        "rule_template_ml_fork.sales": 1
      },
      "narration": "Carol 将自己的 Fork 配置打包成规则模板，在规则市场上出售。"
    },
    {
      "step": 6,
      "timestamp": "T0+10d",
      "name": "Dave 购买规则模板并应用",
      "actor": "dave",
      "action": "RULE_MARKET",
      "target": "rule_template_ml_fork",
      "params": {
        "action": "purchase_and_apply",
        "new_asset_id": "asset_dave_fork"
      },
      "expected_state_changes": {
        "dave.balance": 550,
        "carol.balance": 900,
        "asset_dave_fork.rights": {
          "applied_from_template": "rule_template_ml_fork",
          "use": [4,5],
          "derive": [4,5],
          "benefit": [3,4]
        }
      },
      "narration": "Dave 买了 Carol 的模板，一键应用到了自己的新项目上。"
    }
  ]
}
```

#### 关键洞察

1. **法档自治**：当 use/expand/derive 都开放到法档(4)以上时，社区可以通过投票机制自治，创作者不能单方面改变规则。
2. **规则市场**：成功的资产配置可以被模板化、交易，降低其他人的配置成本。
3. **Fork 不是背叛**：Fork 后的资产与原资产保持权利同步，分叉是生长而非分裂。

---

### 场景3：多Agent社会经济活动（复杂网络）

#### 场景描述和目标

构建一个复杂的多Agent社会经济网络：5 名创作者、10 名使用者、3 个平台。多资产并行创建、交叉引用、形成验证图网络、多级分润、势位竞争。验证**网络效应**、**多级分润**和**势位计算**。

#### 初始状态

```json
{
  "timestamp": "T0",
  "agents": {
    "creators": [
      {"id": "c1", "name": "创作者A", "balance": 1000, "reputation": 5.0},
      {"id": "c2", "name": "创作者B", "balance": 800, "reputation": 4.5},
      {"id": "c3", "name": "创作者C", "balance": 600, "reputation": 4.0},
      {"id": "c4", "name": "创作者D", "balance": 500, "reputation": 3.5},
      {"id": "c5", "name": "创作者E", "balance": 400, "reputation": 3.0}
    ],
    "users": [
      {"id": "u1", "balance": 100}, {"id": "u2", "balance": 100},
      {"id": "u3", "balance": 100}, {"id": "u4", "balance": 100},
      {"id": "u5", "balance": 100}, {"id": "u6", "balance": 100},
      {"id": "u7", "balance": 100}, {"id": "u8", "balance": 100},
      {"id": "u9", "balance": 100}, {"id": "u10", "balance": 100}
    ],
    "platforms": [
      {"id": "p1", "name": "平台Alpha", "fee_rate": 0.10, "reputation": 7.0},
      {"id": "p2", "name": "平台Beta", "fee_rate": 0.15, "reputation": 6.0},
      {"id": "p3", "name": "平台Gamma", "fee_rate": 0.08, "reputation": 5.0}
    ]
  },
  "assets": [
    {
      "id": "a1", "owner": "c1", "name": "基础算法库",
      "rights": {"use":[3,4,5], "expand":[3,4], "derive":[3,4], "benefit":[2,3,4]}
    },
    {
      "id": "a2", "owner": "c2", "name": "视觉素材包",
      "rights": {"use":[2,3,4], "expand":[2,3], "derive":[2,3], "benefit":[1,2,3]}
    },
    {
      "id": "a3", "owner": "c3", "name": "音效库",
      "rights": {"use":[3,4,5], "expand":[3,4,5], "derive":[3,4], "benefit":[2,3]}
    },
    {
      "id": "a4", "owner": "c4", "name": "文档模板",
      "rights": {"use":[4,5], "expand":[4,5], "derive":[4,5], "benefit":[3,4,5]}
    },
    {
      "id": "a5", "owner": "c5", "name": "交互组件",
      "rights": {"use":[2,3,4,5], "expand":[2,3], "derive":[2,3,4], "benefit":[1,2,3,4]}
    }
  ]
}
```

#### 事件序列

```json
{
  "events": [
    {
      "step": 1,
      "timestamp": "T0",
      "name": "批量创建资产",
      "actor": "system",
      "action": "BULK_CREATE",
      "params": {"assets": ["a1", "a2", "a3", "a4", "a5"]},
      "expected_state_changes": {
        "network.asset_count": 5,
        "network.isolated_nodes": 5
      },
      "narration": "5 名创作者同时发布资产，网络初始化为 5 个孤立节点。"
    },
    {
      "step": 2,
      "timestamp": "T0+1h",
      "name": "交叉引用形成网络",
      "actor": "system",
      "action": "BULK_VALIDATE",
      "params": {
        "edges": [
          {"from": "a1", "to": "d1", "type": "reference", "by": "c2"},
          {"from": "a2", "to": "d2", "type": "reference", "by": "c3"},
          {"from": "a3", "to": "d3", "type": "remix", "by": "c4"},
          {"from": "a1", "to": "d4", "type": "integrate", "by": "c5"},
          {"from": "a4", "to": "d5", "type": "reference", "by": "c1"},
          {"from": "d1", "to": "d6", "type": "reference", "by": "u1"},
          {"from": "d3", "to": "d7", "type": "remix", "by": "u2"},
          {"from": "d4", "to": "d8", "type": "integrate", "by": "c3"}
        ]
      },
      "expected_state_changes": {
        "network.edge_count": 8,
        "network.derived_assets": 8,
        "a1.potential.dimensions.flow": 0.30,
        "a3.potential.dimensions.depth": 0.35,
        "validation_graph.diameter": 3,
        "validation_graph.density": 0.25
      },
      "narration": "资产开始交叉引用。原始资产作为根节点，衍生资产形成多层级网络。"
    },
    {
      "step": 3,
      "timestamp": "T0+2h",
      "name": "用户使用和支付",
      "actor": "system",
      "action": "BULK_USER_ACTIVITY",
      "params": {
        "activities": [
          {"user": "u1", "asset": "a1", "type": "view", "count": 10},
          {"user": "u2", "asset": "a1", "type": "pay", "amount": 50},
          {"user": "u3", "asset": "d1", "type": "view", "count": 20},
          {"user": "u4", "asset": "d2", "type": "pay", "amount": 30},
          {"user": "u5", "asset": "a3", "type": "view", "count": 15},
          {"user": "u6", "asset": "d3", "type": "pay", "amount": 20},
          {"user": "u7", "asset": "d6", "type": "view", "count": 5},
          {"user": "u8", "asset": "a4", "type": "pay", "amount": 40},
          {"user": "u9", "asset": "d8", "type": "view", "count": 8},
          {"user": "u10", "asset": "a5", "type": "pay", "amount": 25}
        ]
      },
      "expected_state_changes": {
        "network.total_views": 58,
        "network.total_payments": 165,
        "c1.balance": 1080,
        "c2.balance": 850,
        "c3.balance": 640,
        "c4.balance": 530,
        "c5.balance": 420
      },
      "narration": "10 名用户开始消费。支付通过网络传播，形成多级分润。"
    },
    {
      "step": 4,
      "timestamp": "T0+3h",
      "name": "平台介入与分润",
      "actor": "system",
      "action": "PLATFORM_DISTRIBUTION",
      "params": {
        "platforms": [
          {"id": "p1", "processed_payments": 80, "fee": 8},
          {"id": "p2", "processed_payments": 50, "fee": 7.5},
          {"id": "p3", "processed_payments": 35, "fee": 2.8}
        ]
      },
      "expected_state_changes": {
        "p1.balance": 8,
        "p2.balance": 7.5,
        "p3.balance": 2.8,
        "network.platform_fees": 18.3,
        "network.creator_share": 146.7
      },
      "narration": "三个平台处理交易，抽取手续费。剩余资金按验证图路径分润。"
    },
    {
      "step": 5,
      "timestamp": "T0+4h",
      "name": "势位竞争",
      "actor": "system",
      "action": "COMPUTE_POTENTIAL_RANKING",
      "params": {},
      "expected_state_changes": {
        "rankings": [
          {"asset": "a1", "potential": 0.85, "rank": 1, "stage": "growth"},
          {"asset": "a3", "potential": 0.72, "rank": 2, "stage": "growth"},
          {"asset": "d4", "potential": 0.60, "rank": 3, "stage": "manifest"},
          {"asset": "a4", "potential": 0.45, "rank": 4, "stage": "manifest"},
          {"asset": "d8", "potential": 0.38, "rank": 5, "stage": "manifest"},
          {"asset": "a5", "potential": 0.30, "rank": 6, "stage": "latent"},
          {"asset": "a2", "potential": 0.28, "rank": 7, "stage": "latent"},
          {"asset": "d1", "potential": 0.25, "rank": 8, "stage": "latent"},
          {"asset": "d3", "potential": 0.20, "rank": 9, "stage": "latent"},
          {"asset": "d6", "potential": 0.15, "rank": 10, "stage": "latent"}
        ]
      },
      "narration": "计算全网势位排名。a1（基础算法库）凭借最多引用和最高流量排名第一。"
    },
    {
      "step": 6,
      "timestamp": "T0+5h",
      "name": "网络效应放大",
      "actor": "system",
      "action": "BULK_VALIDATE",
      "params": {
        "viral_events": [
          {"type": "reference", "from": "a1", "count": 50},
          {"type": "remix", "from": "a1", "count": 20},
          {"type": "integrate", "from": "a3", "count": 15},
          {"type": "view", "count": 1000},
          {"type": "pay", "count": 100, "amount": 500}
        ]
      },
      "expected_state_changes": {
        "network.total_views": 1058,
        "network.total_payments": 665,
        "a1.potential.momentum": 0.95,
        "a1.potential.stage": "greatness",
        "a3.potential.stage": "growth",
        "validation_graph.diameter": 4,
        "validation_graph.clustering_coefficient": 0.65
      },
      "narration": "病毒式传播。a1 进入大成阶段，a3 进入生长阶段。网络直径扩大，聚类系数提升。"
    }
  ]
}
```

#### 关键洞察

1. **网络效应**：原始资产（a1, a3）的势位通过引用链向整个网络扩散，形成"势位虹吸"。
2. **多级分润**：支付沿着验证图反向传播，每一层父资产按比例获得收益，深度可达 4 层。
3. **势位竞争**：不同资产在同一网络中竞争势位，流量和引用密度决定排名。

---

### 场景4：势图接管冲突与解决

#### 场景描述和目标

Alice 创建资产并启用势图接管。资产自然生长到「大成」阶段，权限已自动放宽到公档(5)。Alice 因商业原因愤怒试图收紧所有权限，系统依据元规则阻止。Alice 选择分叉资产作为退出机制。原资产继续运行，分叉资产独立演化。验证**不可逆性原则**、**分叉退出机制**和**创作者主权**。

#### 初始状态

```json
{
  "timestamp": "T0",
  "agents": [
    {
      "id": "alice",
      "name": "Alice",
      "type": "creator",
      "balance": 5000,
      "reputation": 9.0,
      "emotional_state": "optimistic"
    },
    {
      "id": "bob",
      "name": "Bob",
      "type": "user",
      "balance": 200,
      "reputation": 2.0
    },
    {
      "id": "carol",
      "name": "Carol",
      "type": "creator",
      "balance": 1000,
      "reputation": 5.0
    }
  ],
  "assets": [
    {
      "id": "asset_original",
      "name": "《Echoes》",
      "owner": "alice",
      "created_at": "T0",
      "rights": {
        "use": {"allowed": [2, 3], "level": 3},
        "expand": {"allowed": [2], "level": 2},
        "derive": {"allowed": [1, 2], "level": 2},
        "benefit": {"allowed": [1, 2], "level": 2}
      },
      "potential": {
        "stage": "latent",
        "stage_index": 0,
        "momentum": 0.0
      },
      "takeover_enabled": true,
      "takeover_log": [],
      "meta_rules": [
        {"id": "mr_1", "type": "irreversibility", "description": "takeover_expanded_rights cannot be tightened"},
        {"id": "mr_2", "type": "fork_exit", "description": "creator may fork at any time"},
        {"id": "mr_3", "type": "inheritance", "description": "derived assets inherit rights from parent"}
      ]
    }
  ]
}
```

#### 事件序列

```json
{
  "events": [
    {
      "step": 1,
      "timestamp": "T0",
      "name": "创建资产并启用势图接管",
      "actor": "alice",
      "action": "CREATE_ASSET",
      "target": "asset_original",
      "params": {
        "takeover_enabled": true,
        "meta_rules": ["irreversibility", "fork_exit", "inheritance"]
      },
      "expected_state_changes": {
        "asset_original.status": "active",
        "asset_original.takeover_enabled": true
      },
      "narration": "Alice 发布了《Echoes》，启用势图接管。"
    },
    {
      "step": 2,
      "timestamp": "T0+1d",
      "name": "大量使用和引用",
      "actor": "system",
      "action": "BULK_VALIDATE",
      "target": "asset_original",
      "params": {
        "events": [
          {"type": "reference", "count": 100},
          {"type": "remix", "count": 50},
          {"type": "view", "count": 10000},
          {"type": "pay", "count": 500, "amount": 2500}
        ]
      },
      "expected_state_changes": {
        "asset_original.potential.momentum": 0.92,
        "asset_original.potential.stage": "greatness",
        "asset_original.potential.stage_index": 3,
        "asset_original.rights.use.allowed": [2, 3, 4, 5],
        "asset_original.rights.expand.allowed": [2, 3, 4],
        "asset_original.rights.derive.allowed": [1, 2, 3, 4],
        "asset_original.rights.benefit.allowed": [1, 2, 3, 4]
      },
      "narration": "《Echoes》大火。势进入大成阶段，所有权限自动放宽。"
    },
    {
      "step": 3,
      "timestamp": "T0+2d",
      "name": "Alice 试图收紧权限（被阻止）",
      "actor": "alice",
      "action": "MODIFY_RIGHTS",
      "target": "asset_original",
      "params": {
        "requested_rights": {
          "use": [1],
          "expand": [1],
          "derive": [1],
          "benefit": [1]
        },
        "reason": "我要独家授权给唱片公司"
      },
      "expected_result": "REJECTED",
      "rejection_reason": "meta_rule_irreversibility: takeover-expanded rights cannot be tightened. Current use=[2,3,4,5], requested=[1]. Use FORK_EXIT if you need a closed version.",
      "expected_state_changes": {
        "asset_original.rights.use.allowed": [2, 3, 4, 5],
        "alice.emotional_state": "frustrated",
        "asset_original.conflict_log": ["T0+2d: Alice attempted tighten, blocked by MR-1"]
      },
      "narration": "Alice 想收紧权限去签独家。系统阻止了——大成阶段的资产，权限不可逆。"
    },
    {
      "step": 4,
      "timestamp": "T0+2d+5m",
      "name": "Alice 分叉资产",
      "actor": "alice",
      "action": "FORK",
      "target": "asset_original",
      "params": {
        "new_asset_id": "asset_fork_exclusive",
        "reason": "创建独家版本",
        "rights_override": {
          "use": [1],
          "expand": [1],
          "derive": [1],
          "benefit": [1]
        }
      },
      "expected_state_changes": {
        "asset_fork_exclusive.rights": {
          "forked_from": "asset_original",
          "use": [1],
          "expand": [1],
          "derive": [1],
          "benefit": [1]
        },
        "asset_fork_exclusive.takeover_enabled": false,
        "asset_fork_exclusive.potential": {
          "stage": "latent",
          "momentum": 0.0
        },
        "asset_original.status": "active",
        "asset_original.derived_assets": ["asset_fork_exclusive"]
      },
      "narration": "Alice 行使分叉权，创建了一个全新的独家版本。原资产继续开放运行。"
    },
    {
      "step": 5,
      "timestamp": "T0+3d",
      "name": "原资产继续演化",
      "actor": "system",
      "action": "BULK_VALIDATE",
      "target": "asset_original",
      "params": {
        "events": [
          {"type": "integrate", "count": 30},
          {"type": "view", "count": 5000},
          {"type": "pay", "count": 200, "amount": 1000}
        ]
      },
      "expected_state_changes": {
        "asset_original.potential.momentum": 0.96,
        "asset_original.potential.stage": "transformation",
        "asset_original.potential.stage_index": 4,
        "asset_original.rights.use.allowed": [2, 3, 4, 5],
        "asset_original.rights.benefit.allowed": [1, 2, 3, 4, 5]
      },
      "narration": "原资产进入「转化」阶段，权限完全开放。社区继续生长。"
    },
    {
      "step": 6,
      "timestamp": "T0+5d",
      "name": "分叉资产独立演化",
      "actor": "alice",
      "action": "SELL_EXCLUSIVE",
      "target": "asset_fork_exclusive",
      "params": {
        "buyer": "record_company_x",
        "price": 10000,
        "license": "exclusive"
      },
      "expected_state_changes": {
        "asset_fork_exclusive.status": "sold",
        "asset_fork_exclusive.owner": "record_company_x",
        "alice.balance": 15000,
        "alice.emotional_state": "satisfied"
      },
      "narration": "Alice 的独家版本卖了 10000。两条路都走通了——社区版继续开放，独家版变现。"
    }
  ]
}
```

#### 关键洞察

1. **不可逆性原则**：势图接管放宽的权限是网络共识，单个创作者不能破坏——这是保护集体劳动成果。
2. **分叉退出**：创作者始终保留分叉权，可以创建一个新的独立资产，采用完全不同的权限配置。
3. **创作者主权 ≠ 绝对控制**：ECHO 重新定义了"主权"——不是对资产的绝对控制，而是选择参与方式和退出路径的自由。

---

## 任务2：边界条件测试用例

### 测试框架

```typescript
// 测试框架接口
interface ECHOTestCase {
  id: string;
  name: string;
  category: TestCategory;
  setup: () => ECHOState;
  execute: () => TestResult;
  assert: (result: TestResult) => boolean;
  expected_error?: string;
}

type TestCategory = 
  | "rights_boundary" 
  | "potential_boundary" 
  | "profit_boundary" 
  | "takeover_boundary" 
  | "combination_boundary";

interface TestResult {
  success: boolean;
  state?: ECHOState;
  error?: string;
  metrics?: Record<string, number>;
}
```

---

### 测试用例 1-4：四权验证边界

#### TC-01: 己档(1) 权限 — 仅创作者自己

```json
{
  "id": "TC-01",
  "name": "己档权限边界 - 仅创作者可访问",
  "category": "rights_boundary",
  "setup": {
    "creator": "alice",
    "asset": {
      "rights": {"use":[1], "expand":[1], "derive":[1], "benefit":[1]}
    },
    "testers": ["alice", "bob", "charlie"]
  },
  "execute": [
    {"actor": "alice", "action": "view", "expected": "ALLOWED"},
    {"actor": "bob", "action": "view", "expected": "DENIED", "reason": "not_in_trust_network_level_1"},
    {"actor": "charlie", "action": "remix", "expected": "DENIED", "reason": "derive_right_level_1_only"}
  ],
  "assert": "only_alice_can_access",
  "insight": "己档是最严格的权限边界，验证信任网络第一层（仅自己）"
}
```

#### TC-02: 亲档(2) 权限 — 信任网络内

```json
{
  "id": "TC-02",
  "name": "亲档权限边界 - 信任网络成员",
  "category": "rights_boundary",
  "setup": {
    "creator": "alice",
    "trust_network": {"alice": ["alice", "bob"], "bob": ["bob", "alice", "charlie"]},
    "asset": {
      "rights": {"use":[2], "expand":[2], "derive":[2], "benefit":[2]}
    }
  },
  "execute": [
    {"actor": "alice", "action": "view", "expected": "ALLOWED"},
    {"actor": "bob", "action": "view", "expected": "ALLOWED", "reason": "in_alice_trust_network_level_2"},
    {"actor": "charlie", "action": "view", "expected": "DENIED", "reason": "not_directly_in_alice_network"},
    {"actor": "diana", "action": "view", "expected": "DENIED", "reason": "stranger"}
  ],
  "assert": "alice_and_bob_only",
  "insight": "亲档验证信任网络第二层（直接信任关系）"
}
```

#### TC-03: 约档(3) 权限 — 契约验证

```json
{
  "id": "TC-03",
  "name": "约档权限边界 - 契约约束",
  "category": "rights_boundary",
  "setup": {
    "creator": "alice",
    "asset": {
      "rights": {"use":[3], "expand":[3], "derive":[3], "benefit":[3]}
    },
    "contracts": {
      "bob": {"status": "active", "terms": "view_only"},
      "charlie": {"status": "expired", "terms": "remix_allowed"}
    }
  },
  "execute": [
    {"actor": "bob", "action": "view", "expected": "ALLOWED", "reason": "active_contract_view_only"},
    {"actor": "bob", "action": "remix", "expected": "DENIED", "reason": "contract_limits_to_view"},
    {"actor": "charlie", "action": "view", "expected": "DENIED", "reason": "contract_expired"},
    {"actor": "diana", "action": "view", "expected": "DENIED", "reason": "no_contract"}
  ],
  "assert": "contract_enforced",
  "insight": "约档验证契约机制——有契约且有效才能访问"
}
```

#### TC-04: 法档(4) 与 公档(5) 权限 — 社区/全球访问

```json
{
  "id": "TC-04",
  "name": "法档公档权限边界 - 社区与全球",
  "category": "rights_boundary",
  "setup": {
    "creator": "alice",
    "asset_1": {"rights": {"use":[4], "expand":[4], "derive":[4], "benefit":[4]}},
    "asset_2": {"rights": {"use":[5], "expand":[5], "derive":[5], "benefit":[5]}},
    "testers": [
      {"id": "bob", "reputation": 3.0, "community_status": "member"},
      {"id": "charlie", "reputation": 1.0, "community_status": "none"},
      {"id": "diana", "reputation": 6.0, "community_status": "governor"}
    ]
  },
  "execute": [
    {"actor": "bob", "asset": "asset_1", "action": "view", "expected": "ALLOWED", "reason": "community_member"},
    {"actor": "charlie", "asset": "asset_1", "action": "view", "expected": "DENIED", "reason": "not_community_member"},
    {"actor": "charlie", "asset": "asset_2", "action": "view", "expected": "ALLOWED", "reason": "public_access"},
    {"actor": "diana", "asset": "asset_1", "action": "modify_rights", "expected": "ALLOWED", "reason": "governor_privilege"}
  ],
  "assert": "community_vs_public",
  "insight": "法档要求社区成员身份，公档对所有人开放"
}
```

---

### 测试用例 5-8：势位计算边界

#### TC-05: 势位维度全零

```json
{
  "id": "TC-05",
  "name": "势位计算 - 所有维度为零",
  "category": "potential_boundary",
  "setup": {
    "asset": {
      "potential": {
        "dimensions": {"flow": 0, "depth": 0, "reach": 0, "value": 0, "resonance": 0}
      }
    }
  },
  "execute": "compute_potential",
  "expected_result": {
    "momentum": 0.0,
    "stage": "latent",
    "stage_index": 0
  },
  "assert": "zero_momentum",
  "insight": "零输入应产生零势位，处于潜藏阶段"
}
```

#### TC-06: 势位维度临界值

```json
{
  "id": "TC-06",
  "name": "势位计算 - 临界值触发阶段转换",
  "category": "potential_boundary",
  "setup": {
    "thresholds": {
      "latent_to_manifest": 0.20,
      "manifest_to_growth": 0.50,
      "growth_to_greatness": 0.80,
      "greatness_to_transformation": 0.95
    }
  },
  "test_cases": [
    {"momentum": 0.19, "expected_stage": "latent"},
    {"momentum": 0.20, "expected_stage": "manifest"},
    {"momentum": 0.49, "expected_stage": "manifest"},
    {"momentum": 0.50, "expected_stage": "growth"},
    {"momentum": 0.79, "expected_stage": "growth"},
    {"momentum": 0.80, "expected_stage": "greatness"},
    {"momentum": 0.94, "expected_stage": "greatness"},
    {"momentum": 0.95, "expected_stage": "transformation"},
    {"momentum": 1.00, "expected_stage": "transformation"}
  ],
  "assert": "stage_threshold_exact",
  "insight": "验证阶段转换的临界值边界"
}
```

#### TC-07: 势位维度极大值

```json
{
  "id": "TC-07",
  "name": "势位计算 - 维度极大值与饱和",
  "category": "potential_boundary",
  "setup": {
    "asset": {
      "potential": {
        "dimensions": {"flow": 999999, "depth": 999999, "reach": 999999, "value": 999999, "resonance": 999999}
      }
    }
  },
  "execute": "compute_potential",
  "expected_result": {
    "momentum": 1.0,
    "stage": "transformation",
    "overflow_handled": true,
    "warning": "dimension_values_clamped_to_max"
  },
  "assert": "saturated_at_max",
  "insight": "极大值应被钳制在最大值，避免溢出"
}
```

#### TC-08: 势位计算 — 负值输入

```json
{
  "id": "TC-08",
  "name": "势位计算 - 负值输入处理",
  "category": "potential_boundary",
  "setup": {
    "asset": {
      "potential": {
        "dimensions": {"flow": -10, "depth": -5, "reach": 0.5, "value": -1, "resonance": 0.3}
      }
    }
  },
  "execute": "compute_potential",
  "expected_result": {
    "momentum": 0.16,
    "stage": "manifest",
    "negative_values_treated_as_zero": true
  },
  "assert": "negative_to_zero",
  "insight": "负值输入应被处理为零，不影响其他正维度"
}
```

---

### 测试用例 9-12：分润递归边界

#### TC-09: 深度引用链分润

```json
{
  "id": "TC-09",
  "name": "分润递归 - 深度引用链",
  "category": "profit_boundary",
  "setup": {
    "chain": [
      {"asset": "a0", "parent": null, "level": 0},
      {"asset": "a1", "parent": "a0", "level": 1},
      {"asset": "a2", "parent": "a1", "level": 2},
      {"asset": "a3", "parent": "a2", "level": 3},
      {"asset": "a4", "parent": "a3", "level": 4},
      {"asset": "a5", "parent": "a4", "level": 5},
      {"asset": "a6", "parent": "a5", "level": 6},
      {"asset": "a7", "parent": "a6", "level": 7},
      {"asset": "a8", "parent": "a7", "level": 8},
      {"asset": "a9", "parent": "a8", "level": 9},
      {"asset": "a10", "parent": "a9", "level": 10}
    ],
    "payment": {"amount": 1000, "at": "a10"},
    "distribution_rules": {"level_decay": 0.5, "min_share": 0.001}
  },
  "expected_distribution": [
    {"asset": "a10", "share": 500.0},
    {"asset": "a9", "share": 250.0},
    {"asset": "a8", "share": 125.0},
    {"asset": "a7", "share": 62.5},
    {"asset": "a6", "share": 31.25},
    {"asset": "a5", "share": 15.625},
    {"asset": "a4", "share": 7.812},
    {"asset": "a3", "share": 3.906},
    {"asset": "a2", "share": 1.953},
    {"asset": "a1", "share": 0.977},
    {"asset": "a0", "share": 0.488}
  ],
  "assert": "exponential_decay_accurate",
  "insight": "验证 10 层深度引用链的指数衰减分润"
}
```

#### TC-10: 循环引用检测

```json
{
  "id": "TC-10",
  "name": "分润递归 - 循环引用检测",
  "category": "profit_boundary",
  "setup": {
    "graph": {
      "a1": {"children": ["a2"]},
      "a2": {"children": ["a3"]},
      "a3": {"children": ["a1"]}
    },
    "payment": {"amount": 100, "at": "a3"}
  },
  "execute": "distribute_profit",
  "expected_result": {
    "success": false,
    "error": "CIRCULAR_REFERENCE_DETECTED",
    "cycle": ["a1", "a2", "a3", "a1"]
  },
  "assert": "cycle_detected_and_blocked",
  "insight": "循环引用必须被检测并阻止，防止无限递归"
}
```

#### TC-11: 零金额支付

```json
{
  "id": "TC-11",
  "name": "分润递归 - 零金额支付",
  "category": "profit_boundary",
  "setup": {
    "asset": "a1",
    "payment": {"amount": 0}
  },
  "execute": "distribute_profit",
  "expected_result": {
    "success": true,
    "distribution": [],
    "total_distributed": 0,
    "warning": "zero_amount_no_distribution"
  },
  "assert": "zero_amount_safe",
  "insight": "零金额支付应安全处理，不产生分润"
}
```

#### TC-12: 极小金额分润精度

```json
{
  "id": "TC-12",
  "name": "分润递归 - 极小金额精度",
  "category": "profit_boundary",
  "setup": {
    "chain": [
      {"asset": "a0", "parent": null},
      {"asset": "a1", "parent": "a0"}
    ],
    "payment": {"amount": 0.01, "at": "a1"},
    "distribution_rules": {"parent_share": 0.5}
  },
  "execute": "distribute_profit",
  "expected_result": {
    "success": true,
    "a1_share": 0.005,
    "a0_share": 0.005,
    "precision": "0.001",
    "rounding": "bankers_rounding"
  },
  "assert": "precision_maintained",
  "insight": "极小金额分润应保持精度，使用银行家舍入法"
}
```

---

### 测试用例 13-16：势图接管边界

#### TC-13: 冷却期阻止重复接管

```json
{
  "id": "TC-13",
  "name": "势图接管 - 冷却期机制",
  "category": "takeover_boundary",
  "setup": {
    "asset": {
      "rights": {"use": [2, 3]},
      "potential": {"stage": "growth", "momentum": 0.60},
      "takeover_enabled": true,
      "last_takeover": "T0-1h"
    },
    "cooldown_period": "2h"
  },
  "execute": [
    {"at": "T0+0h", "action": "trigger_takeover", "expected": "BLOCKED", "reason": "cooldown_active"},
    {"at": "T0+3h", "action": "trigger_takeover", "expected": "ALLOWED", "reason": "cooldown_expired"}
  ],
  "assert": "cooldown_respected",
  "insight": "势图接管应有冷却期，防止频繁调整"
}
```

#### TC-14: 手动覆盖（元规则冲突）

```json
{
  "id": "TC-14",
  "name": "势图接管 - 手动覆盖冲突",
  "category": "takeover_boundary",
  "setup": {
    "asset": {
      "rights": {"use": [2, 3, 4]},
      "potential": {"stage": "growth", "momentum": 0.65},
      "takeover_enabled": true
    },
    "governance": {
      "model": "community_vote",
      "manual_override": {"allowed": true, "threshold": 0.75}
    }
  },
  "execute": [
    {"action": "manual_override", "params": {"use": [2]}, "votes": [0.6], "expected": "REJECTED", "reason": "threshold_not_met"},
    {"action": "manual_override", "params": {"use": [2]}, "votes": [0.8], "expected": "REJECTED", "reason": "takeover_only_expand"},
    {"action": "manual_override", "params": {"use": [2, 3, 4, 5]}, "votes": [0.8], "expected": "ALLOWED", "reason": "expansion_allowed"}
  ],
  "assert": "override_restricted_to_expand",
  "insight": "即使满足投票阈值，手动覆盖也只能放宽，不能收紧"
}
```

#### TC-15: 冲突解决 — 创作者 vs 社区

```json
{
  "id": "TC-15",
  "name": "势图接管 - 创作者与社区冲突",
  "category": "takeover_boundary",
  "setup": {
    "asset": {
      "owner": "alice",
      "rights": {"use": [2, 3, 4, 5]},
      "potential": {"stage": "greatness"},
      "takeover_enabled": true
    },
    "conflict": {
      "alice_request": {"use": [2]},
      "community_request": {"use": [5]},
      "governance_votes": {"alice": 0.10, "community": 0.90}
    }
  },
  "execute": "resolve_conflict",
  "expected_result": {
    "resolution": "community_wins",
    "final_rights": {"use": [2, 3, 4, 5]},
    "reason": "takeover_prevents_tightening",
    "alice_option": "fork_exit_available"
  },
  "assert": "community_overrides_creator",
  "insight": "大成阶段资产，社区共识优先于创作者个人意愿"
}
```

#### TC-16: 禁用势图接管

```json
{
  "id": "TC-16",
  "name": "势图接管 - 完全禁用",
  "category": "takeover_boundary",
  "setup": {
    "asset": {
      "rights": {"use": [2]},
      "potential": {"stage": "latent"},
      "takeover_enabled": false
    }
  },
  "execute": [
    {"action": "trigger_takeover", "stage": "growth", "expected": "BLOCKED", "reason": "takeover_disabled"},
    {"action": "modify_rights", "params": {"use": [5]}, "actor": "alice", "expected": "ALLOWED", "reason": "creator_manual_control"}
  ],
  "assert": "disabled_takeover_allows_manual",
  "insight": "禁用势图接管后，创作者恢复完全手动控制权"
}
```

---

### 测试用例 17-20：档位组合边界

#### TC-17: 禁止组合 — derive > use

```json
{
  "id": "TC-17",
  "name": "档位组合 - derive 不能超过 use",
  "category": "combination_boundary",
  "setup": {},
  "test_cases": [
    {"use": [2], "derive": [3], "valid": false, "reason": "derive_level_3 > use_level_2"},
    {"use": [3, 4], "derive": [2, 3], "valid": true, "reason": "max_derive(3) <= max_use(4)"},
    {"use": [5], "derive": [1, 2, 3, 4, 5], "valid": true, "reason": "derive within use bounds"},
    {"use": [1], "derive": [1], "valid": true, "reason": "equal levels ok"}
  ],
  "assert": "derive_leq_use",
  "insight": "改编权不能高于使用权——不能改编你不能使用的东西"
}
```

#### TC-18: 禁止组合 — expand > use

```json
{
  "id": "TC-18",
  "name": "档位组合 - expand 不能超过 use",
  "category": "combination_boundary",
  "setup": {},
  "test_cases": [
    {"use": [2], "expand": [3], "valid": false, "reason": "expand_level_3 > use_level_2"},
    {"use": [4], "expand": [2, 3, 4], "valid": true, "reason": "max_expand(4) <= max_use(4)"},
    {"use": [2, 3], "expand": [5], "valid": false, "reason": "expand_level_5 > max_use(3)"}
  ],
  "assert": "expand_leq_use",
  "insight": "传播权不能高于使用权——不能传播你不能使用的东西"
}
```

#### TC-19: 传递性验证 — 继承链一致性

```json
{
  "id": "TC-19",
  "name": "档位组合 - 继承链传递性",
  "category": "combination_boundary",
  "setup": {
    "chain": [
      {"asset": "a0", "rights": {"use": [3, 4, 5], "derive": [3, 4]}},
      {"asset": "a1", "parent": "a0", "rights_override": {"derive": [5]}},
      {"asset": "a2", "parent": "a1"}
    ]
  },
  "execute": "validate_inheritance_chain",
  "expected_result": {
    "a0": {"valid": true},
    "a1": {"valid": false, "error": "derive_cannot_exceed_parent_use", "parent_use_max": 5, "requested_derive": 5, "but_parent_derive_max": 4},
    "a2": {"valid": false, "error": "parent_a1_invalid"}
  },
  "assert": "inheritance_monotonic",
  "insight": "子资产的权限不能超过父资产的权限边界"
}
```

#### TC-20: 极端组合 — 全禁与全开

```json
{
  "id": "TC-20",
  "name": "档位组合 - 极端边界",
  "category": "combination_boundary",
  "setup": {},
  "test_cases": [
    {
      "name": "全禁",
      "rights": {"use": [0], "expand": [0], "derive": [0], "benefit": [0]},
      "valid": true,
      "description": "完全封闭资产"
    },
    {
      "name": "全开",
      "rights": {"use": [5], "expand": [5], "derive": [5], "benefit": [5]},
      "valid": true,
      "description": "完全开放资产"
    },
    {
      "name": "用禁衍开（无效）",
      "rights": {"use": [0], "expand": [0], "derive": [5], "benefit": [0]},
      "valid": false,
      "error": "derive_max(5) > use_max(0)"
    },
    {
      "name": "混合边界",
      "rights": {"use": [2, 3, 4], "expand": [2, 3], "derive": [2], "benefit": [1, 2]},
      "valid": true,
      "description": "层级递减的合理配置"
    },
    {
      "name": "空集合",
      "rights": {"use": [], "expand": [], "derive": [], "benefit": []},
      "valid": false,
      "error": "empty_right_set_defaults_to_forbidden"
    }
  ],
  "assert": "extreme_combinations",
  "insight": "验证所有极端档位组合的有效性"
}
```

---

## 任务3：可视化叙事脚本

### 演示模式架构

```json
{
  "demo_mode": {
    "name": "ECHO 系统模拟器演示",
    "version": "1.0",
    "duration_estimate": "8 minutes",
    "scenes": 4,
    "auto_play": true,
    "skip_allowed": true,
    "pause_allowed": true,
    "speed_options": [0.5, 1.0, 1.5, 2.0]
  }
}
```

### 场景1演示脚本：独立音乐人的生态生长

```json
{
  "scene_id": "demo_scene_1",
  "name": "独立音乐人的生态生长",
  "based_on": "scenario_1",
  "duration": "2 minutes",
  "steps": [
    {
      "step": 1,
      "timestamp": 0,
      "narration": "这里是 Alice，一位独立音乐人。她刚在 ECHO 网络上发布了一首新歌《Stars》。",
      "highlight_elements": ["agent_alice", "create_asset_button"],
      "camera": {
        "target": "agent_alice",
        "zoom": 1.5,
        "angle": "face_on",
        "transition": "smooth_pan"
      },
      "ui_state": {
        "show": ["agent_panel", "asset_creation_modal"],
        "hide": ["network_graph", "validation_graph"]
      },
      "action": "alice_creates_asset",
      "pause_after": 2
    },
    {
      "step": 2,
      "timestamp": 5,
      "narration": "Alice 的设置比较保守——只有亲近的人才能使用，改编和收益都限制得很死。",
      "highlight_elements": ["rights_config_panel", "slider_use", "slider_derive"],
      "camera": {
        "target": "rights_config_panel",
        "zoom": 2.0,
        "angle": "top_down",
        "transition": "zoom_in"
      },
      "ui_state": {
        "show": ["rights_config_panel"],
        "animate": ["slider_use_to_3", "slider_derive_to_1"]
      },
      "pause_after": 3
    },
    {
      "step": 3,
      "timestamp": 12,
      "narration": "Bob 发现了这首歌，引用它做了视频背景音乐。",
      "highlight_elements": ["agent_bob", "edge_stars_to_bobvideo"],
      "camera": {
        "target": "agent_bob",
        "zoom": 1.3,
        "angle": "face_on",
        "transition": "pan_right"
      },
      "ui_state": {
        "show": ["network_graph"],
        "animate": ["node_bob_appear", "edge_create"]
      },
      "action": "bob_references",
      "pause_after": 2
    },
    {
      "step": 4,
      "timestamp": 18,
      "narration": "Charlie 做了 Remix 版本。衍生资产自动继承了原资产的权限配置——这就是「衍生即继承」。",
      "highlight_elements": ["agent_charlie", "asset_charlie_remix", "inheritance_indicator"],
      "camera": {
        "target": "asset_charlie_remix",
        "zoom": 1.8,
        "angle": "isometric",
        "transition": "zoom_in"
      },
      "ui_state": {
        "show": ["asset_detail_panel", "inheritance_chain"],
        "animate": ["inheritance_pulse"]
      },
      "action": "charlie_remix",
      "pause_after": 3
    },
    {
      "step": 5,
      "timestamp": 26,
      "narration": "歌曲 viral 了。大量用户涌入，势动量快速积累。",
      "highlight_elements": ["network_graph", "potential_meter", "user_particles"],
      "camera": {
        "target": "network_center",
        "zoom": 0.8,
        "angle": "top_down",
        "transition": "zoom_out"
      },
      "ui_state": {
        "show": ["network_graph", "potential_meter"],
        "animate": ["user_particles_inflow", "potential_meter_rise"]
      },
      "action": "viral_growth",
      "pause_after": 4
    },
    {
      "step": 6,
      "timestamp": 35,
      "narration": "注意看——势图接管触发了！系统自动放宽了权限。用从约档扩展到了法档。",
      "highlight_elements": ["potential_stage_indicator", "rights_change_notification", "takeover_badge"],
      "camera": {
        "target": "asset_stars",
        "zoom": 1.5,
        "angle": "face_on",
        "transition": "focus_pulse"
      },
      "ui_state": {
        "show": ["takeover_notification", "rights_comparison"],
        "animate": ["rights_expand_animation", "stage_glow"]
      },
      "action": "takeover_trigger",
      "pause_after": 4
    },
    {
      "step": 7,
      "timestamp": 44,
      "narration": "Alice 慌了，想把权限收回来——但系统阻止了她。势图接管，只开放，不收紧。",
      "highlight_elements": ["agent_alice", "reject_notification", "meta_rule_banner"],
      "camera": {
        "target": "agent_alice",
        "zoom": 1.4,
        "angle": "face_on",
        "transition": "shake"
      },
      "ui_state": {
        "show": ["reject_notification", "meta_rule_banner"],
        "animate": ["red_x_pulse", "meta_rule_highlight"]
      },
      "action": "alice_rejected",
      "pause_after": 4
    },
    {
      "step": 8,
      "timestamp": 53,
      "narration": "最终，《Stars》进入大成阶段，权限完全开放。这是使用权生命周期网络的民主化逻辑——生态生长，胜过创作者控制。",
      "highlight_elements": ["asset_stars", "final_rights_display", "network_glow"],
      "camera": {
        "target": "network_center",
        "zoom": 0.6,
        "angle": "top_down",
        "transition": "slow_zoom_out"
      },
      "ui_state": {
        "show": ["final_summary", "network_graph_full"],
        "animate": ["network_glow", "fireworks"]
      },
      "action": "scene_conclusion",
      "pause_after": 5
    }
  ]
}
```

### 场景2演示脚本：开源软件的社区自治

```json
{
  "scene_id": "demo_scene_2",
  "name": "开源软件的社区自治",
  "based_on": "scenario_2",
  "duration": "2 minutes",
  "steps": [
    {
      "step": 1,
      "timestamp": 0,
      "narration": "Bob 发布了 OpenData Analytics，一个开源数据分析工具。配置极为开放。",
      "highlight_elements": ["agent_bob", "asset_opendata", "open_source_badge"],
      "camera": {"target": "agent_bob", "zoom": 1.5, "angle": "face_on"},
      "pause_after": 2
    },
    {
      "step": 2,
      "timestamp": 8,
      "narration": "Carol Fork 了项目。Fork 不是背叛——新资产与原资产保持权利同步。",
      "highlight_elements": ["fork_arrow", "sync_indicator", "asset_fork"],
      "camera": {"target": "fork_arrow", "zoom": 1.8, "angle": "isometric"},
      "ui_state": {"animate": ["fork_animation", "sync_pulse"]},
      "pause_after": 3
    },
    {
      "step": 3,
      "timestamp": 16,
      "narration": "社区投票修改了收益分配。贡献者份额从 50% 提升到 55%。",
      "highlight_elements": ["governance_panel", "vote_meter", "benefit_chart"],
      "camera": {"target": "governance_panel", "zoom": 2.0, "angle": "top_down"},
      "ui_state": {"animate": ["vote_count", "chart_update"]},
      "pause_after": 4
    },
    {
      "step": 4,
      "timestamp": 25,
      "narration": "Frank 的企业将 OpenData 整合进了更大的套件。整合关系形成了反向引用边。",
      "highlight_elements": ["integration_edge", "enterprise_suite", "cascade_indicator"],
      "camera": {"target": "integration_edge", "zoom": 1.3, "angle": "isometric"},
      "ui_state": {"animate": ["reverse_edge_glow"]},
      "pause_after": 3
    },
    {
      "step": 5,
      "timestamp": 33,
      "narration": "Carol 把自己的 Fork 配置打包成规则模板，在市场上出售。Dave 买了模板，一键应用。",
      "highlight_elements": ["rule_marketplace", "template_card", "purchase_animation"],
      "camera": {"target": "rule_marketplace", "zoom": 1.5, "angle": "face_on"},
      "ui_state": {"animate": ["template_float", "purchase_sparkle"]},
      "pause_after": 4
    },
    {
      "step": 6,
      "timestamp": 42,
      "narration": "这就是法档自治——社区投票决定规则，规则市场交易成功的经验。",
      "highlight_elements": ["community_glow", "market_chart"],
      "camera": {"target": "network_center", "zoom": 0.7, "angle": "top_down"},
      "pause_after": 5
    }
  ]
}
```

### 场景3演示脚本：多Agent复杂网络

```json
{
  "scene_id": "demo_scene_3",
  "name": "多Agent社会经济网络",
  "based_on": "scenario_3",
  "duration": "2 minutes",
  "steps": [
    {
      "step": 1,
      "timestamp": 0,
      "narration": "5 名创作者、10 名使用者、3 个平台。ECHO 网络的社会经济活动开始。",
      "highlight_elements": ["network_overview", "agent_clusters"],
      "camera": {"target": "network_center", "zoom": 0.5, "angle": "top_down"},
      "ui_state": {"animate": ["agents_spawn"]},
      "pause_after": 3
    },
    {
      "step": 2,
      "timestamp": 10,
      "narration": "资产开始交叉引用。原始资产作为根节点，衍生资产形成多层级网络。",
      "highlight_elements": ["validation_graph", "edge_creation"],
      "camera": {"target": "validation_graph", "zoom": 0.7, "angle": "top_down"},
      "ui_state": {"animate": ["edges_grow", "nodes_pulse"]},
      "pause_after": 4
    },
    {
      "step": 3,
      "timestamp": 20,
      "narration": "支付沿着验证图反向传播。每一层父资产按比例获得收益——这就是多级分润。",
      "highlight_elements": ["payment_flow", "profit_distribution_tree"],
      "camera": {"target": "payment_flow", "zoom": 1.2, "angle": "isometric"},
      "ui_state": {"animate": ["gold_flow", "balance_update"]},
      "pause_after": 5
    },
    {
      "step": 4,
      "timestamp": 30,
      "narration": "计算全网势位排名。基础算法库凭借最多引用和最高流量排名第一。",
      "highlight_elements": ["ranking_leaderboard", "potential_bars"],
      "camera": {"target": "ranking_leaderboard", "zoom": 1.5, "angle": "face_on"},
      "ui_state": {"animate": ["bars_grow", "ranking_sort"]},
      "pause_after": 4
    },
    {
      "step": 5,
      "timestamp": 40,
      "narration": "网络效应放大。病毒式传播让排名发生剧烈变化。",
      "highlight_elements": ["viral_burst", "network_expansion"],
      "camera": {"target": "network_center", "zoom": 0.6, "angle": "top_down"},
      "ui_state": {"animate": ["viral_particles", "network_glow"]},
      "pause_after": 5
    }
  ]
}
```

### 场景4演示脚本：势图接管冲突

```json
{
  "scene_id": "demo_scene_4",
  "name": "势图接管冲突与解决",
  "based_on": "scenario_4",
  "duration": "2 minutes",
  "steps": [
    {
      "step": 1,
      "timestamp": 0,
      "narration": "Alice 发布了《Echoes》，启用势图接管。",
      "highlight_elements": ["agent_alice", "asset_echoes", "takeover_toggle"],
      "camera": {"target": "agent_alice", "zoom": 1.5, "angle": "face_on"},
      "pause_after": 2
    },
    {
      "step": 2,
      "timestamp": 6,
      "narration": "歌曲大火，进入大成阶段。权限自动放宽到公档。",
      "highlight_elements": ["potential_meter", "stage_greatness", "rights_expand"],
      "camera": {"target": "asset_echoes", "zoom": 1.3, "angle": "isometric"},
      "ui_state": {"animate": ["stage_transition", "rights_glow"]},
      "pause_after": 3
    },
    {
      "step": 3,
      "timestamp": 14,
      "narration": "Alice 想收紧权限去签独家。系统阻止了她——大成阶段的资产，权限不可逆。",
      "highlight_elements": ["reject_modal", "meta_rule_irreversibility", "red_warning"],
      "camera": {"target": "reject_modal", "zoom": 2.0, "angle": "face_on"},
      "ui_state": {"animate": ["modal_shake", "rule_highlight"]},
      "pause_after": 4
    },
    {
      "step": 4,
      "timestamp": 23,
      "narration": "Alice 行使分叉权，创建了一个全新的独家版本。",
      "highlight_elements": ["fork_button", "asset_fork", "fork_arrow"],
      "camera": {"target": "fork_arrow", "zoom": 1.5, "angle": "isometric"},
      "ui_state": {"animate": ["fork_animation", "new_asset_spawn"]},
      "pause_after": 3
    },
    {
      "step": 5,
      "timestamp": 30,
      "narration": "原资产继续开放运行，社区继续生长。分叉资产独立演化。",
      "highlight_elements": ["dual_asset_view", "asset_original_glow", "asset_fork_glow"],
      "camera": {"target": "dual_asset_view", "zoom": 1.0, "angle": "top_down"},
      "ui_state": {"animate": ["dual_glow", "network_split"]},
      "pause_after": 4
    },
    {
      "step": 6,
      "timestamp": 38,
      "narration": "最终，Alice 的独家版本卖了高价。两条路都走通了——社区版继续开放，独家版变现。",
      "highlight_elements": ["sale_notification", "balance_update", "success_glow"],
      "camera": {"target": "agent_alice", "zoom": 1.3, "angle": "face_on"},
      "ui_state": {"animate": ["gold_rain", "balance_spin"]},
      "pause_after": 5
    },
    {
      "step": 7,
      "timestamp": 47,
      "narration": "这就是 ECHO 的核心设计——不可逆性保护集体成果，分叉退出保留创作者主权。",
      "highlight_elements": ["principle_banner", "network_summary"],
      "camera": {"target": "network_center", "zoom": 0.6, "angle": "top_down"},
      "pause_after": 6
    }
  ]
}
```

### 全局演示控制脚本

```json
{
  "demo_controller": {
    "version": "1.0",
    "scenes": ["demo_scene_1", "demo_scene_2", "demo_scene_3", "demo_scene_4"],
    "transitions": {
      "between_scenes": {
        "type": "fade",
        "duration": 1.5,
        "color": "#1a1a2e"
      },
      "scene_intro": {
        "type": "title_card",
        "duration": 3,
        "show_scene_name": true,
        "show_scene_goal": true
      }
    },
    "controls": {
      "play": "space",
      "pause": "space",
      "skip": "right_arrow",
      "back": "left_arrow",
      "speed_up": "plus",
      "speed_down": "minus"
    },
    "accessibility": {
      "narration_text": true,
      "narration_voice": false,
      "high_contrast": false,
      "reduced_motion": false
    },
    "telemetry": {
      "track_completion": true,
      "track_engagement": true,
      "track_drop_off": true
    }
  }
}
```

---

## 附录

### A. 档位速查表

| 档位 | 名称 | use 含义 | expand 含义 | derive 含义 | benefit 含义 |
|------|------|----------|-------------|-------------|--------------|
| 0 | 禁 | 无人可用 | 不可传播 | 不可改编 | 无收益 |
| 1 | 己 | 仅自己 | 仅自己分享 | 仅自己改编 | 仅自己收益 |
| 2 | 亲 | 信任网络 | 信任网络传播 | 信任网络改编 | 信任网络分润 |
| 3 | 约 | 契约约束 | 契约传播 | 契约改编 | 契约分润 |
| 4 | 法 | 社区成员 | 社区传播 | 社区改编 | 社区分润 |
| 5 | 公 | 任何人 | 任何人传播 | 任何人改编 | 任何人分润 |

### B. 势阶段速查表

| 阶段 | 索引 | 势动量范围 | 特征 |
|------|------|-----------|------|
| 潜藏 | 0 | 0.00 - 0.19 | 无验证活动 |
| 显现 | 1 | 0.20 - 0.49 | 初始验证事件 |
| 生长 | 2 | 0.50 - 0.79 | 势图接管可能触发 |
| 大成 | 3 | 0.80 - 0.94 | 权限不可逆 |
| 转化 | 4 | 0.95 - 1.00 | 完全开放，可能产生新形态 |

### C. 验证事件类型

| 事件 | 对势的影响 | 对网络的影响 |
|------|-----------|-------------|
| reference | +flow | 创建子节点 |
| remix | +depth | 创建子节点 |
| integrate | +reach | 创建反向边 |
| fork | +resonance | 创建独立分支 |
| view | +value | 无拓扑变化 |
| pay | +value, +flow | 激活分润链 |

### D. 元规则清单

| 规则ID | 名称 | 描述 |
|--------|------|------|
| MR-1 | 不可逆性 | takeover 放宽的权限不可收紧 |
| MR-2 | 分叉退出 | 创作者可随时 fork 创建独立版本 |
| MR-3 | 继承性 | 衍生资产继承父资产权限边界 |
| MR-4 | 传递性 | derive ≤ use, expand ≤ use |
| MR-5 | 冷却期 | 接管调整后需等待冷却期才能再次调整 |

---

*文档生成时间：2026-05-10*
*Agent 4：场景模拟设计师 & 测试用例专家*
