# Layer 0: Rights Registry Contract Design

> **文档版本**: v1.0  
> **日期**: 2026-04-19  
> **关联文档**: ECHO-Five-Layers-Details.md, ECHO-Panorama-v2.md, ECHO-PRD-v1.0.md  
> **作者**: ECHO Protocol Architecture Team

---

## 1. Four-Rights Model Overview

### 1.1 四维权利模型概述

ECHO Protocol 的核心创新在于将数字资产的权利空间解构为四个正交维度：**使用权 (Use)**, **衍生权 (Der)**, **扩展权 (Ext)**, 和 **收益权 (Rev)**。这四个维度共同构成一个完整的权利配置空间，使创作者能够精细控制其作品的流转、使用和商业化。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     ECHO Four-Dimensional Rights Space                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│    Use (使用权)        Der (衍生权)        Ext (扩展权)       Rev (收益权) │
│    ┌─────┐             ┌─────┐             ┌─────┐            ┌─────┐   │
│    │调用 │             │改编 │             │接口 │            │分润 │   │
│    │租赁 │             │混合 │             │插件 │            │定价 │   │
│    │订阅 │             │引用 │             │集成 │            │结算 │   │
│    └─────┘             └─────┘             └─────┘            └─────┘   │
│                                                                         │
│    谁能用？             谁能改？             谁能扩展？          钱怎么分？  │
│    用多少？             改多少？             扩展边界？           谁得多少？  │
│    什么场景？           分多少？             接口规范？           何时结算？  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 权利维度详解

#### 1.2.1 使用权 (UseRight)

使用权定义了他人如何**消费**资产，包括调用、查看、执行等操作。

| 属性 | 说明 | 示例 |
|------|------|------|
| 定价模型 | 按次/订阅/一次性/免费/自定义 | API调用按次计费 |
| 使用范围 | 个人/商业/企业/教育/研究 | 个人学习免费，商业需授权 |
| 使用次数 | 有限/无限/按时段重置 | 每月1000次调用额度 |
| 使用场景 | 特定平台/地域/用途限制 | 仅限亚洲地区使用 |
| 转售权限 | 是否允许二次转售使用权 | 禁止转售 |

#### 1.2.2 衍生权 (DerRight)

衍生权控制他人基于原资产**创建新作品**的能力，包括改编、混合、引用等。

| 属性 | 说明 | 示例 |
|------|------|------|
| 允许衍生 | 完全开放/有条件/禁止 | 允许改编但需署名 |
| 上游分润 | 原作在新作品收益中的比例 | 衍生作品收益10%归原作者 |
| 最大深度 | 衍生链的最大层级 | 最多3层衍生 |
| 引用要求 | 必须保留的归属信息 | 必须保留原作者署名 |
| 衍生类型 | 允许的衍生方式 | 允许翻译、不允许改写 |

#### 1.2.3 扩展权 (ExtRight)

扩展权定义了资产如何被**技术集成**，通过API、插件、接口等方式扩展功能。

| 属性 | 说明 | 示例 |
|------|------|------|
| 接口开放 | 哪些接口对外可用 | 仅开放推理接口 |
| 安全级别 | 沙箱/受信环境/裸机 | 必须在隔离沙箱运行 |
| 扩展类型 | 允许的扩展形式 | 仅允许Web插件 |
| 认证要求 | 调用者身份验证要求 | 需实名认证开发者 |
| 资源限制 | CPU/内存/存储/时间限制 | 单次调用<30秒 |

#### 1.2.4 收益权 (RevRight)

收益权定义了资产产生经济价值时的**分配规则**。

| 属性 | 说明 | 示例 |
|------|------|------|
| 收益来源 | 使用费/订阅/授权/衍生分润 | 多种收益混合 |
| 分润比例 | 各参与方的分配比例 | 作者70%, 平台20%, 推荐人10% |
| 结算周期 | 实时/日结/周结/月结 | 日结到钱包 |
| 最低结算 | 最小结算金额阈值 | 满100元自动结算 |
| 结算币种 | 支持的稳定币/代币 | USDC, ETH, ECHO |

### 1.3 权利配置组合示例

```solidity
// 开源软件配置
OpenSourceConfig = {
    use: { model: FREE, transferable: false },
    der: { allowed: true, upstreamShare: 0, maxDepth: ∞ },
    ext: { interface: OPEN, security: SANDBOX },
    rev: { recipients: [author], shares: [100%] }
}

// 商业软件配置
CommercialConfig = {
    use: { model: SUBSCRIPTION, basePrice: 99$/mo, scope: COMMERCIAL },
    der: { allowed: false },
    ext: { interface: PARTIAL, security: WHITELIST },
    rev: { recipients: [author, platform], shares: [80%, 20%] }
}

// 内容创作配置 (音乐/图像/视频)
CreatorConfig = {
    use: { model: PER_USE, basePrice: 0.5$, scope: NON_COMMERCIAL },
    der: { allowed: true, upstreamShare: 15%, maxDepth: 3 },
    ext: { interface: API_ONLY },
    rev: { recipients: [author, platform, referrer], shares: [70%, 20%, 10%] }
}
```

---

## 2. Data Structures

### 2.1 核心数据结构

#### 2.1.1 RightsBundle - 四维权利容器

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title RightsBundle
 * @notice 四维权利配置容器，存储单个资产的完整权利配置
 */
struct RightsBundle {
    // 权利配置哈希 (用于快速比较和验证)
    bytes32 configHash;
    
    // 四维权利配置
    UseRight use;           // 使用权配置
    DerRight der;           // 衍生权配置  
    ExtRight ext;           // 扩展权配置
    RevRight rev;           // 收益权配置
    
    // 元数据
    uint256 createdAt;      // 创建时间戳
    uint256 updatedAt;      // 最后更新时间
    address configuredBy;   // 配置者地址
    bool isLocked;          // 是否锁定(防止修改)
    
    // 版本控制
    uint256 version;        // 配置版本号
    bytes32 previousConfig; // 前一版本哈希
}
```

#### 2.1.2 UseRight - 使用权结构

```solidity
/**
 * @title UseRight
 * @notice 使用权详细配置结构
 * @dev 采用紧凑存储布局优化Gas
 */
struct UseRight {
    // === 核心配置 (slot 1) ===
    PricingModel pricingModel;  // 1 byte: 定价模型类型
    uint88 basePrice;           // 11 bytes: 基础价格 (支持最大 3e26)
    uint16 platformFeeBps;     // 2 bytes: 平台费率 (基点, max 10000 = 100%)
    uint8 usageScope;          // 1 byte: 使用范围位图
    uint8 currency;            // 1 byte: 币种标识
    bool transferable;         // 1 byte: 是否可转售使用权
    bool isActive;             // 1 byte: 是否激活
    
    // === 使用限制 (slot 2) ===
    uint64 maxUsageCount;      // 8 bytes: 最大使用次数 (0=无限)
    uint64 usedCount;          // 8 bytes: 已使用次数
    uint64 resetPeriod;        // 8 bytes: 计数重置周期(秒)
    uint64 lastResetTime;      // 8 bytes: 上次重置时间
    
    // === 时间限制 (slot 3) ===
    uint64 validFrom;          // 8 bytes: 生效时间
    uint64 validUntil;         // 8 bytes: 过期时间 (0=永久)
    uint64 cooldownPeriod;     // 8 bytes: 调用冷却期
    uint64 lastUsedTime;       // 8 bytes: 上次使用时间
    
    // === 条件限制 (slot 4) ===
    bytes32 allowedPlatforms;  // 32 bytes: 允许的平台哈希集合
    bytes32 allowedRegions;    // 32 bytes: 允许的地区哈希集合
    
    // === 自定义参数 (slot 5) ===
    bytes32 customParams;      // 32 bytes: 自定义参数哈希
    address customValidator;   // 20 bytes: 自定义验证器合约
    
    // === 扩展配置指针 (slot 6) ===
    uint256 extendedConfigPtr; // 32 bytes: 扩展配置存储位置
}

/**
 * @title PricingModel
 * @notice 定价模型枚举
 */
enum PricingModel {
    FREE,           // 免费使用
    PER_USE,        // 按次计费
    SUBSCRIPTION,   // 订阅制 (周期性付费)
    ONE_TIME,       // 一次性买断
    TIERED,         // 阶梯定价 (用量越大单价越低)
    DYNAMIC,        // 动态定价 (市场决定)
    AUCTION,        // 拍卖定价
    CUSTOM          // 自定义定价(通过验证器)
}

/**
 * @title UsageScope
 * @notice 使用范围位图常量
 */
library UsageScope {
    uint8 constant PERSONAL = 1 << 0;        // 个人使用
    uint8 constant EDUCATIONAL = 1 << 1;     // 教育使用
    uint8 constant NON_PROFIT = 1 << 2;      // 非营利使用
    uint8 constant COMMERCIAL = 1 << 3;      // 商业使用
    uint8 constant ENTERPRISE = 1 << 4;      // 企业使用
    uint8 constant RESEARCH = 1 << 5;        // 研究使用
    uint8 constant DERIVATIVE = 1 << 6;      // 用于创建衍生作品
    uint8 constant PUBLIC_DOMAIN = 1 << 7;   // 公共领域使用
}
```

#### 2.1.3 DerRight - 衍生权结构

```solidity
/**
 * @title DerRight
 * @notice 衍生权详细配置结构
 * @dev 控制作品被改编、混合、引用的权限
 */
struct DerRight {
    // === 核心配置 (slot 1) ===
    bool allowed;              // 1 byte: 是否允许衍生
    uint8 derTypeBitmap;       // 1 byte: 允许的衍生类型位图
    uint16 upstreamShareBps;   // 2 bytes: 上游分润比例(基点)
    uint8 maxDepth;            // 1 byte: 最大衍生深度 (0=无限, 255=禁止)
    uint8 attributionType;       // 1 byte: 署名要求类型
    bool requiresApproval;     // 1 byte: 是否需要审批
    bool isActive;             // 1 byte: 是否激活
    
    // === 时间限制 (slot 2) ===
    uint64 validFrom;          // 8 bytes: 生效时间
    uint64 validUntil;         // 8 bytes: 过期时间
    uint64 lockInPeriod;       // 8 bytes: 锁定期(衍生后多久不能再次衍生)
    
    // === 统计信息 (slot 3) ===
    uint32 derivativeCount;    // 4 bytes: 直接衍生作品数量
    uint32 totalDescendants;   // 4 bytes: 所有后代作品数量
    uint64 firstDerivativeAt;    // 8 bytes: 首个衍生时间
    uint64 lastDerivativeAt;   // 8 bytes: 最后衍生时间
    
    // === 权限控制 (slot 4-5) ===
    bytes32 allowedCreators;   // 32 bytes: 允许的白名单创作者
    bytes32 blockedCreators;   // 32 bytes: 黑名单创作者
    
    // === 署名要求 (slot 6) ===
    bytes32 requiredAttribution; // 32 bytes: 必须包含的署名信息哈希
    uint8 minAttributionLevel;   // 1 byte: 最低署名级别
    
    // === 扩展配置指针 (slot 7) ===
    uint256 extendedConfigPtr;   // 32 bytes: 扩展配置存储位置
}

/**
 * @title DerType
 * @notice 衍生类型枚举
 */
enum DerType {
    ADAPTATION,     // 改编 (修改内容但保持核心)
    REMIX,          // 混音/混剪 (混合多个来源)
    TRANSLATION,    // 翻译
    ABRIDGMENT,     // 节选/摘要
    EXPANSION,      // 扩展/续写
    SEQUEL,         // 续集/续作
    PREQUEL,        // 前传
    SPIN_OFF,       // 外传/衍生剧
    FAN_ART,        // 同人创作
    CRITIQUE,       // 评论/批评
    PARODY,         // 戏仿/恶搞
    QUOTATION,      // 引用
    INSPIRATION     // 灵感借鉴 (最宽松的衍生)
}

/**
 * @title AttributionLevel
 * @notice 署名要求级别
 */
enum AttributionLevel {
    NONE,           // 无需署名
    MENTION,        // 提及即可
    CREDIT,         // 明确署名
    PROMINENT,      // 显著位置署名
    EXCLUSIVE       // 独占式(衍生作品必须主打原作)
}
```

#### 2.1.4 ExtRight - 扩展权结构

```solidity
/**
 * @title ExtRight
 * @notice 扩展权详细配置结构
 * @dev 控制资产通过API/插件/接口被技术集成的权限
 */
struct ExtRight {
    // === 核心配置 (slot 1) ===
    bool allowed;              // 1 byte: 是否允许扩展
    uint8 interfaceType;       // 1 byte: 接口类型位图
    uint8 securityLevel;       // 1 byte: 安全级别
    uint16 extFeeBps;          // 2 bytes: 扩展使用费(基点)
    bool requiresAuth;         // 1 byte: 是否需要认证
    bool rateLimited;          // 1 byte: 是否限流
    bool isActive;             // 1 byte: 是否激活
    
    // === 资源限制 (slot 2) ===
    uint32 maxCpuMs;           // 4 bytes: 最大CPU时间(ms)
    uint32 maxMemoryMb;        // 4 bytes: 最大内存(MB)
    uint32 maxStorageMb;       // 4 bytes: 最大存储(MB)
    uint32 maxNetworkCalls;    // 4 bytes: 最大网络调用次数
    
    // === 限流配置 (slot 3) ===
    uint32 requestsPerSecond;  // 4 bytes: 每秒请求数限制
    uint32 requestsPerMinute; // 4 bytes: 每分钟请求数限制
    uint32 requestsPerHour;   // 4 bytes: 每小时请求数限制
    uint32 requestsPerDay;    // 4 bytes: 每天请求数限制
    
    // === 时间限制 (slot 4) ===
    uint64 validFrom;          // 8 bytes: 生效时间
    uint64 validUntil;         // 8 bytes: 过期时间
    uint64 timeoutMs;          // 8 bytes: 调用超时(ms)
    
    // === API规范 (slot 5) ===
    bytes32 apiSpecHash;       // 32 bytes: API规范文档哈希
    bytes32 endpointList;      // 32 bytes: 允许的端点列表哈希
    
    // === 权限控制 (slot 6) ===
    bytes32 allowedApps;       // 32 bytes: 允许的应用白名单
    bytes32 blockedApps;       // 32 bytes: 禁止的应用黑名单
    
    // === 回调配置 (slot 7) ===
    address callbackContract;  // 20 bytes: 回调合约地址
    bytes4 callbackSelector;   // 4 bytes: 回调函数选择器
    
    // === 扩展配置指针 (slot 8) ===
    uint256 extendedConfigPtr; // 32 bytes: 扩展配置存储位置
}

/**
 * @title InterfaceType
 * @notice 接口类型位图常量
 */
library InterfaceType {
    uint8 constant REST_API = 1 << 0;       // REST API
    uint8 constant GRAPHQL = 1 << 1;        // GraphQL
    uint8 constant WEBSOCKET = 1 << 2;      // WebSocket
    uint8 constant GRPC = 1 << 3;           // gRPC
    uint8 constant PLUGIN = 1 << 4;         // 插件系统
    uint8 constant WEBHOOK = 1 << 5;        // Webhook
    uint8 constant SDK = 1 << 6;            // SDK集成
    uint8 constant EMBED = 1 << 7;          // 嵌入式
}

/**
 * @title SecurityLevel
 * @notice 安全级别枚举
 */
enum SecurityLevel {
    OPEN,           // 开放访问 (无需认证)
    API_KEY,        // API Key认证
    OAUTH,          // OAuth认证
    WHITELIST,      // 白名单(预批准)
    SANDBOX,        // 沙箱隔离执行
    CONFIDENTIAL,   // 机密级(零知识证明验证)
    ISOLATED        // 完全隔离(专用执行环境)
}
```

#### 2.1.5 RevRight - 收益权结构

```solidity
/**
 * @title RevRight
 * @notice 收益权详细配置结构
 * @dev 定义资产收益的分配规则和结算机制
 */
struct RevRight {
    // === 核心配置 (slot 1) ===
    uint8 recipientCount;      // 1 byte: 收益接收方数量(max 16)
    uint8 settlementTrigger;   // 1 byte: 结算触发类型
    uint16 platformFeeBps;     // 2 bytes: 平台抽成比例
    uint8 currencyPreference;  // 1 byte: 首选结算币种
    bool autoDistribute;       // 1 byte: 是否自动分配
    bool allowTips;            // 1 byte: 是否允许打赏
    bool isActive;             // 1 byte: 是否激活
    
    // === 阈值配置 (slot 2) ===
    uint128 minSettlement;     // 16 bytes: 最小结算金额
    uint128 maxRetention;     // 16 bytes: 最大留存金额
    
    // === 周期配置 (slot 3) ===
    uint64 settlementPeriod;   // 8 bytes: 结算周期(秒)
    uint64 lastSettlement;     // 8 bytes: 上次结算时间
    uint64 gracePeriod;        // 8 bytes: 宽限期(结算延迟容忍)
    
    // === 统计信息 (slot 4) ===
    uint128 totalRevenue;      // 16 bytes: 累计收益
    uint128 pendingRevenue;    // 16 bytes: 待结算收益
    
    // === 分润比例数组 (slot 5-6) ===
    // 使用压缩存储: 16个接收方，每个2字节比例 = 32字节
    bytes32 shareDistribution; // 32 bytes: 分润比例打包
    
    // === 接收方地址数组 (动态存储) ===
    // 存储在单独位置，通过recipientCount索引
    address[] recipients;      // 动态: 接收方地址列表
    
    // === 高级规则指针 (slot 7) ===
    uint256 advancedRulesPtr;  // 32 bytes: 高级分润规则存储位置
    
    // === 预留 (slot 8) ===
    bytes32 reserved;          // 32 bytes: 预留扩展
}

/**
 * @title SettlementTrigger
 * @notice 结算触发类型枚举
 */
enum SettlementTrigger {
    REALTIME,       // 实时结算 (每次收益立即分配)
    THRESHOLD,      // 阈值结算 (达到最小金额触发)
    SCHEDULED,      // 定时结算 (按固定周期)
    MANUAL,         // 手动结算 (需主动触发)
    HYBRID          // 混合 (定时+阈值)
}

/**
 * @title RevenueSource
 * @notice 收益来源类型
 */
enum RevenueSource {
    USAGE_FEE,      // 使用费
    SUBSCRIPTION,   // 订阅费
    LICENSE_FEE,    // 授权费
    DERIVATIVE_SHARE, // 衍生分润
    EXTENSION_FEE,  // 扩展使用费
    TIPS,           // 打赏
    ROYALTIES,      // 版税(二次销售)
    BOUNTY,         // 赏金/悬赏
    ADVERTISING,    // 广告分成
    SPONSORSHIP     // 赞助
}
```

### 2.2 辅助数据结构

#### 2.2.1 License - 授权许可结构

```solidity
/**
 * @title License
 * @notice 授权许可实例
 * @dev 记录特定用户对特定资产特定权利的授权
 */
struct License {
    // === 标识信息 (slot 1) ===
    uint256 licenseId;         // 32 bytes: 授权ID (唯一)
    uint256 assetId;           // 32 bytes: 关联资产ID
    
    // === 授权信息 (slot 2) ===
    address grantor;           // 20 bytes: 授权方
    address grantee;           // 20 bytes: 被授权方
    uint8 rightType;           // 1 byte: 权利类型 (Use/Der/Ext/Rev)
    uint8 licenseType;         // 1 byte: 授权类型
    
    // === 范围限制 (slot 3) ===
    uint88 usageLimit;         // 11 bytes: 使用次数限制
    uint88 usedCount;          // 11 bytes: 已使用次数
    uint8 scopeFlags;          // 1 byte: 范围限制标志
    uint16 customFeeBps;       // 2 bytes: 自定义费率调整
    
    // === 时间限制 (slot 4) ===
    uint64 validFrom;          // 8 bytes: 生效时间
    uint64 validUntil;         // 8 bytes: 过期时间
    uint64 lastUsedAt;         // 8 bytes: 最后使用时间
    uint64 grantedAt;          // 8 bytes: 授权时间
    
    // === 状态与条件 (slot 5) ===
    bool isActive;             // 1 byte: 是否有效
    bool isRevocable;          // 1 byte: 是否可撤销
    bool isTransferable;       // 1 byte: 是否可转让
    bytes32 conditionsHash;    // 32 bytes: 授权条件哈希
    
    // === 关联信息 (slot 6) ===
    uint256 parentLicenseId;   // 32 bytes: 父授权ID(衍生继承)
    bytes32 derivationProof;   // 32 bytes: 衍生证明哈希
    
    // === 扩展数据指针 (slot 7) ===
    uint256 extendedDataPtr;   // 32 bytes: 扩展数据位置
}

/**
 * @title RightType
 * @notice 权利类型枚举
 */
enum RightType {
    NONE,           // 0: 无权利
    USE,            // 1: 使用权
    DER,            // 2: 衍生权
    EXT,            // 3: 扩展权
    REV,            // 4: 收益权
    ALL             // 5: 全部权利(所有权转让)
}

/**
 * @title LicenseType
 * @notice 授权类型枚举
 */
enum LicenseType {
    INDIVIDUAL,     // 个人授权
    ORGANIZATION,   // 组织授权
    ENTERPRISE,     // 企业授权
    EDUCATIONAL,    // 教育授权
    RESEARCH,       // 研究授权
    DERIVATIVE,     // 衍生授权
    EXTENSION,      // 扩展授权
    BULK            // 批量授权
}
```

#### 2.2.2 RightsDependency - 权利依赖结构

```solidity
/**
 * @title RightsDependency
 * @notice 权利依赖关系图节点
 * @dev 用于构建和管理资产间的权利依赖图
 */
struct RightsDependency {
    // === 节点标识 (slot 1) ===
    uint256 assetId;           // 32 bytes: 当前资产ID
    uint256 parentAssetId;     // 32 bytes: 父资产ID (0=原创)
    
    // === 依赖类型 (slot 2) ===
    uint8 depType;             // 1 byte: 依赖类型
    uint8 depth;               // 1 byte: 在依赖树中的深度
    uint16 upstreamShareBps;   // 2 bytes: 向上游分润比例
    bool isDirect;             // 1 byte: 是否直接依赖
    bool hasMultipleParents;   // 1 byte: 是否有多个父资产(混合作品)
    
    // === 树结构 (slot 3-4) ===
    uint256[] ancestors;         // 动态: 所有祖先资产ID
    uint256[] directChildren;  // 动态: 直接子资产ID
    uint256[] allDescendants;  // 动态: 所有后代资产ID
    
    // === 依赖详情 (slot 5) ===
    bytes32 dependencyProof;   // 32 bytes: 依赖证明哈希
    bytes32 contributionRatio; // 32 bytes: 贡献比例(多父时)
    
    // === 统计信息 (slot 6) ===
    uint32 childrenCount;      // 4 bytes: 直接子资产数
    uint32 totalDescendants;   // 4 bytes: 总后代数
    uint64 createdAt;          // 8 bytes: 依赖关系建立时间
    uint64 lastUpdated;        // 8 bytes: 最后更新时间
    
    // === 冲突标记 (slot 7) ===
    bool hasConflict;          // 1 byte: 是否存在权利冲突
    uint8 conflictSeverity;    // 1 byte: 冲突严重程度
    bytes32 conflictDetails;   // 32 bytes: 冲突详情哈希
}

/**
 * @title DependencyType
 * @notice 依赖类型枚举
 */
enum DependencyType {
    NONE,
    DIRECT_DERIVATIVE,      // 直接衍生
    INDIRECT_DERIVATIVE,    // 间接衍生(通过其他作品)
    COMPOSITE,              // 组合/混合作品
    REFERENCE,              // 引用/参考
    INSPIRATION,            // 灵感来源
    REQUIRED_DEP,           // 必需依赖(如代码库依赖)
    OPTIONAL_DEP            // 可选依赖
}
```

#### 2.2.3 ConflictRecord - 权利冲突记录

```solidity
/**
 * @title ConflictRecord
 * @notice 权利冲突检测记录
 * @dev 记录检测到的权利冲突及解决方案
 */
struct ConflictRecord {
    // === 冲突标识 (slot 1) ===
    uint256 conflictId;        // 32 bytes: 冲突ID
    uint256 assetIdA;          // 32 bytes: 资产A ID
    uint256 assetIdB;          // 32 bytes: 资产B ID
    
    // === 冲突详情 (slot 2) ===
    uint8 conflictType;        // 1 byte: 冲突类型
    uint8 severity;            // 1 byte: 严重程度 (1-5)
    uint8 rightTypeInvolved;   // 1 byte: 涉及的权利类型
    bool isResolved;           // 1 byte: 是否已解决
    bool isBlocking;           // 1 byte: 是否阻塞操作
    
    // === 冲突描述 (slot 3-4) ===
    bytes32 descriptionHash;   // 32 bytes: 冲突描述哈希
    bytes32 suggestedFixHash; // 32 bytes: 建议修复方案哈希
    
    // === 时间信息 (slot 5) ===
    uint64 detectedAt;         // 8 bytes: 检测到的时间
    uint64 resolvedAt;         // 8 bytes: 解决时间 (0=未解决)
    uint64 expiresAt;          // 8 bytes: 冲突过期时间
    address detectedBy;        // 20 bytes: 检测者地址
    
    // === 解决方案 (slot 6) ===
    uint8 resolutionType;      // 1 byte: 解决方案类型
    bytes32 resolutionProof;   // 32 bytes: 解决证明哈希
    address resolvedBy;        // 20 bytes: 解决者地址
    
    // === 关联信息 (slot 7) ===
    uint256[] relatedAssets;   // 动态: 相关资产列表
    uint256 parentConflictId;  // 32 bytes: 父冲突ID(级联冲突)
}

/**
 * @title ConflictType
 * @notice 冲突类型枚举
 */
enum ConflictType {
    NONE,
    // 使用权冲突
    USE_SCOPE_OVERLAP,      // 使用范围重叠
    USE_EXCLUSIVE_VIOLATION, // 独占使用被侵犯
    USE_PLATFORM_CONFLICT,  // 平台限制冲突
    
    // 衍生权冲突
    DER_CHAIN_DEPTH,        // 衍生链深度超限
    DER_ATTRIBUTION_MISSING, // 署名要求未满足
    DER_RECIPROCAL,         // 双向衍生(循环依赖)
    
    // 扩展权冲突
    EXT_API_INCOMPATIBLE,   // API不兼容
    EXT_SECURITY_LEVEL,     // 安全级别冲突
    EXT_RATE_LIMIT,         // 限流冲突
    
    // 收益权冲突
    REV_SHARE_MISMATCH,     // 分润比例不匹配
    REV_SETTLEMENT_CYCLE,   // 结算周期冲突
    REV_CURRENCY_MISMATCH,  // 币种冲突
    
    // 复合冲突
    MULTI_RIGHT_OVERLAP,    // 多权利重叠
    UPSTREAM_DOWNSTREAM,    // 上下游权利矛盾
    CIRCULAR_DEPENDENCY,    // 循环依赖
    EXCLUSIVE_INCOMPATIBLE  // 排他性权利不兼容
}
```

### 2.3 存储优化布局

```solidity
/**
 * @title RightsStorage
 * @notice 权利数据存储布局优化
 * @dev 采用分层存储策略优化Gas成本
 */
library RightsStorage {
    
    // === 热存储 (频繁访问，保持在storage slot 0-5) ===
    struct HotStorage {
        mapping(uint256 => RightsBundle) assetRights;     // assetId -> rights
        mapping(uint256 => License) licenses;               // licenseId -> license
        mapping(bytes32 => uint256) licenseLookup;          // hash -> licenseId
        uint256 totalLicenses;
        uint256 totalAssets;
        bool paused;
    }
    
    // === 温存储 (中等频率访问) ===
    struct WarmStorage {
        mapping(uint256 => RightsDependency) dependencyGraph; // assetId -> deps
        mapping(uint256 => uint256[]) assetLicenses;            // assetId -> licenseIds[]
        mapping(address => uint256[]) userLicenses;             // user -> licenseIds[]
        mapping(uint256 => ConflictRecord) conflicts;           // conflictId -> record
    }
    
    // === 冷存储 (低频访问，历史数据) ===
    struct ColdStorage {
        mapping(uint256 => bytes32[]) rightsHistory;           // assetId -> configHashes[]
        mapping(uint256 => bytes32[]) licenseHistory;          // licenseId -> events[]
        mapping(bytes32 => bool) deprecatedConfigs;             // hash -> isDeprecated
    }
    
    // === 缓存优化 (内存映射加速) ===
    struct CacheLayer {
        mapping(uint256 => RightsBundle) rightsCache;
        mapping(uint256 => bool) cacheValid;
        uint256[] cacheKeys;
        uint256 maxCacheSize;
    }
}
```

---

## 3. License Management Functions

### 3.1 授权生命周期

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ILicenseManager
 * @notice 授权管理接口定义
 * @dev 定义完整的授权生命周期管理
 */
interface ILicenseManager {
    
    //////////////////////////////////////////////////////////////
    // 授权创建
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 授予使用权
     * @param assetId 资产ID
     * @param grantee 被授权方地址
     * @param scope 使用范围配置
     * @param duration 授权持续时间(秒, 0=永久)
     * @param usageLimit 使用次数限制(0=无限)
     * @return licenseId 新创建的授权ID
     */
    function grantUseLicense(
        uint256 assetId,
        address grantee,
        UsageScope scope,
        uint64 duration,
        uint88 usageLimit
    ) external payable returns (uint256 licenseId);
    
    /**
     * @notice 授予衍生权
     * @param assetId 资产ID
     * @param grantee 被授权方地址
     * @param allowedTypes 允许的衍生类型位图
     * @param upstreamShareBps 向上游分润比例(基点)
     * @param maxDepth 最大衍生深度
     * @return licenseId 新创建的授权ID
     */
    function grantDerLicense(
        uint256 assetId,
        address grantee,
        uint8 allowedTypes,
        uint16 upstreamShareBps,
        uint8 maxDepth
    ) external payable returns (uint256 licenseId);
    
    /**
     * @notice 授予扩展权
     * @param assetId 资产ID
     * @param grantee 被授权方地址
     * @param interfaceTypes 允许的接口类型位图
     * @param securityLevel 要求的安全级别
     * @param rateLimit 限流配置
     * @return licenseId 新创建的授权ID
     */
    function grantExtLicense(
        uint256 assetId,
        address grantee,
        uint8 interfaceTypes,
        SecurityLevel securityLevel,
        RateLimitConfig calldata rateLimit
    ) external payable returns (uint256 licenseId);
    
    /**
     * @notice 批量授权
     * @param assetId 资产ID
     * @param grantees 被授权方地址数组
     * @param rightType 权利类型
     * @param scopes 范围配置数组
     * @param durations 持续时间数组
     * @return licenseIds 新创建的授权ID数组
     */
    function batchGrantLicenses(
        uint256 assetId,
        address[] calldata grantees,
        RightType rightType,
        bytes32[] calldata scopes,
        uint64[] calldata durations
    ) external payable returns (uint256[] memory licenseIds);
    
    /**
     * @notice 创建带继承的授权(用于衍生作品)
     * @param parentLicenseId 父授权ID
     * @param childAssetId 子资产ID
     * @param grantee 被授权方
     * @param inheritedRights 继承的权利位图
     * @return licenseId 新创建的授权ID
     */
    function grantInheritedLicense(
        uint256 parentLicenseId,
        uint256 childAssetId,
        address grantee,
        uint8 inheritedRights
    ) external returns (uint256 licenseId);
    
    //////////////////////////////////////////////////////////////
    // 授权验证
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 验证授权有效性
     * @param licenseId 授权ID
     * @return isValid 是否有效
     */
    function verifyLicense(uint256 licenseId) 
        external 
        view 
        returns (bool isValid);
    
    /**
     * @notice 验证特定操作的授权
     * @param assetId 资产ID
     * @param operator 操作者地址
     * @param rightType 权利类型
     * @param operation 操作码
     * @return isAuthorized 是否授权
     * @return licenseId 匹配的授权ID
     */
    function verifyOperationAuthorization(
        uint256 assetId,
        address operator,
        RightType rightType,
        bytes4 operation
    ) external view returns (bool isAuthorized, uint256 licenseId);
    
    /**
     * @notice 检查使用权限并记录使用
     * @param assetId 资产ID
     * @param user 用户地址
     * @param usageType 使用类型
     * @return isAllowed 是否允许
     * @return licenseId 使用的授权ID
     */
    function checkAndRecordUsage(
        uint256 assetId,
        address user,
        uint8 usageType
    ) external returns (bool isAllowed, uint256 licenseId);
    
    /**
     * @notice 批量验证多个授权
     * @param licenseIds 授权ID数组
     * @return validityArray 有效性数组
     */
    function batchVerifyLicenses(uint256[] calldata licenseIds)
        external
        view
        returns (bool[] memory validityArray);
    
    /**
     * @notice 获取授权详细信息
     * @param licenseId 授权ID
     * @return license 授权详情
     */
    function getLicenseDetails(uint256 licenseId)
        external
        view
        returns (License memory license);
    
    /**
     * @notice 获取用户的所有有效授权
     * @param user 用户地址
     * @param assetId 资产ID (0=查询所有资产)
     * @return licenseIds 授权ID数组
     */
    function getUserLicenses(
        address user,
        uint256 assetId
    ) external view returns (uint256[] memory licenseIds);
    
    //////////////////////////////////////////////////////////////
    // 授权撤销与过期
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 撤销授权
     * @param licenseId 授权ID
     * @param reason 撤销原因代码
     */
    function revokeLicense(uint256 licenseId, uint8 reason) external;
    
    /**
     * @notice 批量撤销授权
     * @param licenseIds 授权ID数组
     * @param reason 撤销原因代码
     */
    function batchRevokeLicenses(
        uint256[] calldata licenseIds,
        uint8 reason
    ) external;
    
    /**
     * @notice 设置授权过期
     * @param licenseId 授权ID
     */
    function expireLicense(uint256 licenseId) external;
    
    /**
     * @notice 延长授权有效期
     * @param licenseId 授权ID
     * @param extension 延长时间(秒)
     */
    function extendLicense(
        uint256 licenseId,
        uint64 extension
    ) external payable;
    
    /**
     * @notice 修改授权使用限制
     * @param licenseId 授权ID
     * @param newUsageLimit 新的使用限制
     */
    function modifyUsageLimit(
        uint256 licenseId,
        uint88 newUsageLimit
    ) external;
    
    /**
     * @notice 转让授权给新地址
     * @param licenseId 授权ID
     * @param newGrantee 新被授权方
     */
    function transferLicense(
        uint256 licenseId,
        address newGrantee
    ) external;
    
    /**
     * @notice 清理过期授权(任何人可调用，用于Gas回收)
     * @param licenseIds 授权ID数组
     * @return cleanedCount 清理的数量
     */
    function cleanupExpiredLicenses(
        uint256[] calldata licenseIds
    ) external returns (uint256 cleanedCount);
    
    //////////////////////////////////////////////////////////////
    // 事件定义
    //////////////////////////////////////////////////////////////
    
    event LicenseGranted(
        uint256 indexed licenseId,
        uint256 indexed assetId,
        address indexed grantor,
        address grantee,
        RightType rightType,
        uint64 validUntil
    );
    
    event LicenseRevoked(
        uint256 indexed licenseId,
        address indexed revokedBy,
        uint8 reason
    );
    
    event LicenseExpired(
        uint256 indexed licenseId,
        uint64 expiredAt
    );
    
    event LicenseExtended(
        uint256 indexed licenseId,
        uint64 newValidUntil
    );
    
    event UsageRecorded(
        uint256 indexed licenseId,
        uint256 indexed assetId,
        address indexed user,
        uint8 usageType,
        uint64 timestamp
    );
    
    event LicenseTransferred(
        uint256 indexed licenseId,
        address indexed from,
        address indexed to
    );
}
```

### 3.2 授权管理实现

```solidity
/**
 * @title LicenseManager
 * @notice 授权管理合约实现
 */
contract LicenseManager is ILicenseManager, AccessControl, Pausable {
    
    using RightsStorage for RightsStorage.HotStorage;
    using RightsStorage for RightsStorage.WarmStorage;
    
    RightsStorage.HotStorage private hotStorage;
    RightsStorage.WarmStorage private warmStorage;
    
    IEchoCore public echoCore;
    IRightsRegistry public rightsRegistry;
    
    uint256 private constant LICENSE_ID_OFFSET = 1000000;
    uint256 private nextLicenseId;
    
    modifier onlyAssetOwner(uint256 assetId) {
        require(
            echoCore.ownerOf(assetId) == msg.sender,
            "LicenseManager: not asset owner"
        );
        _;
    }
    
    modifier validLicense(uint256 licenseId) {
        require(
            hotStorage.licenses[licenseId].licenseId == licenseId,
            "LicenseManager: invalid license"
        );
        _;
    }
    
    constructor(address _echoCore, address _rightsRegistry) {
        echoCore = IEchoCore(_echoCore);
        rightsRegistry = IRightsRegistry(_rightsRegistry);
        nextLicenseId = LICENSE_ID_OFFSET;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function grantUseLicense(
        uint256 assetId,
        address grantee,
        UsageScope scope,
        uint64 duration,
        uint88 usageLimit
    ) external payable override onlyAssetOwner(assetId) returns (uint256) {
        
        RightsBundle memory rights = rightsRegistry.getRights(assetId);
        require(rights.use.isActive, "LicenseManager: use right not active");
        require(rights.use.pricingModel != PricingModel.FREE || msg.value >= rights.use.basePrice,
            "LicenseManager: insufficient payment"
        );
        
        uint256 licenseId = nextLicenseId++;
        uint64 validUntil = duration == 0 ? type(uint64).max : uint64(block.timestamp) + duration;
        
        License memory license = License({
            licenseId: licenseId,
            assetId: assetId,
            grantor: msg.sender,
            grantee: grantee,
            rightType: uint8(RightType.USE),
            licenseType: uint8(LicenseType.INDIVIDUAL),
            usageLimit: usageLimit,
            usedCount: 0,
            scopeFlags: uint8(scope),
            customFeeBps: 0,
            validFrom: uint64(block.timestamp),
            validUntil: validUntil,
            lastUsedAt: 0,
            grantedAt: uint64(block.timestamp),
            isActive: true,
            isRevocable: true,
            isTransferable: rights.use.transferable,
            conditionsHash: bytes32(0),
            parentLicenseId: 0,
            derivationProof: bytes32(0),
            extendedDataPtr: 0
        });
        
        hotStorage.licenses[licenseId] = license;
        warmStorage.assetLicenses[assetId].push(licenseId);
        warmStorage.userLicenses[grantee].push(licenseId);
        hotStorage.totalLicenses++;
        
        emit LicenseGranted(
            licenseId,
            assetId,
            msg.sender,
            grantee,
            RightType.USE,
            validUntil
        );
        
        return licenseId;
    }
    
    function verifyLicense(uint256 licenseId)
        external
        view
        override
        validLicense(licenseId)
        returns (bool)
    {
        License memory license = hotStorage.licenses[licenseId];
        
        if (!license.isActive) return false;
        if (block.timestamp < license.validFrom) return false;
        if (block.timestamp > license.validUntil) return false;
        if (license.usageLimit > 0 && license.usedCount >= license.usageLimit) return false;
        
        return true;
    }
    
    function checkAndRecordUsage(
        uint256 assetId,
        address user,
        uint8 usageType
    ) external override whenNotPaused returns (bool, uint256) {
        
        uint256[] memory userLicenseIds = warmStorage.userLicenses[user];
        
        for (uint256 i = 0; i < userLicenseIds.length; i++) {
            License storage license = hotStorage.licenses[userLicenseIds[i]];
            
            if (license.assetId != assetId) continue;
            if (license.rightType != uint8(RightType.USE)) continue;
            if (!license.isActive) continue;
            if (block.timestamp > license.validUntil) continue;
            if (license.usageLimit > 0 && license.usedCount >= license.usageLimit) continue;
            
            // 检查使用类型是否在授权范围内
            if ((license.scopeFlags & usageType) == 0) continue;
            
            // 更新使用记录
            license.usedCount++;
            license.lastUsedAt = uint64(block.timestamp);
            
            emit UsageRecorded(
                license.licenseId,
                assetId,
                user,
                usageType,
                uint64(block.timestamp)
            );
            
            return (true, license.licenseId);
        }
        
        return (false, 0);
    }
    
    function revokeLicense(uint256 licenseId, uint8 reason)
        external
        override
        validLicense(licenseId)
    {
        License storage license = hotStorage.licenses[licenseId];
        
        require(
            msg.sender == license.grantor || 
            msg.sender == echoCore.ownerOf(license.assetId) ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "LicenseManager: not authorized to revoke"
        );
        
        require(license.isRevocable, "LicenseManager: license not revocable");
        
        license.isActive = false;
        
        emit LicenseRevoked(licenseId, msg.sender, reason);
    }
    
    function cleanupExpiredLicenses(uint256[] calldata licenseIds)
        external
        override
        returns (uint256)
    {
        uint256 cleaned = 0;
        
        for (uint256 i = 0; i < licenseIds.length; i++) {
            License storage license = hotStorage.licenses[licenseIds[i]];
            
            if (license.licenseId == 0) continue;
            if (block.timestamp <= license.validUntil) continue;
            if (license.usageLimit > 0 && license.usedCount < license.usageLimit) continue;
            
            license.isActive = false;
            cleaned++;
            
            emit LicenseExpired(licenseIds[i], uint64(block.timestamp));
        }
        
        return cleaned;
    }
    
    // ... 其他函数实现省略，遵循相同模式
}
```

---

## 4. Rights Inheritance System

### 4.1 继承架构设计

```solidity
/**
 * @title IRightsInheritance
 * @notice 权利继承系统接口
 * @dev 管理衍生作品的权利继承链
 */
interface IRightsInheritance {
    
    //////////////////////////////////////////////////////////////
    // 继承链管理
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 注册衍生关系
     * @param childAssetId 子资产ID
     * @param parentAssetId 父资产ID
     * @param depType 依赖类型
     * @param contributionBps 贡献比例(多父时使用)
     */
    function registerDerivation(
        uint256 childAssetId,
        uint256 parentAssetId,
        DependencyType depType,
        uint16 contributionBps
    ) external;
    
    /**
     * @notice 注册多父衍生(混合作品)
     * @param childAssetId 子资产ID
     * @param parentAssetIds 父资产ID数组
     * @param contributions 各父资产贡献比例数组
     * @param depType 依赖类型
     */
    function registerMultiParentDerivation(
        uint256 childAssetId,
        uint256[] calldata parentAssetIds,
        uint16[] calldata contributions,
        DependencyType depType
    ) external;
    
    /**
     * @notice 获取资产的所有祖先
     * @param assetId 资产ID
     * @return ancestorIds 祖先资产ID数组(按距离排序)
     * @return distances 距离数组(1=直接父资产)
     */
    function getAncestors(uint256 assetId)
        external
        view
        returns (uint256[] memory ancestorIds, uint8[] memory distances);
    
    /**
     * @notice 获取资产的所有后代
     * @param assetId 资产ID
     * @param maxDepth 最大查询深度(0=所有)
     * @return descendantIds 后代资产ID数组
     * @return depths 深度数组
     */
    function getDescendants(uint256 assetId, uint8 maxDepth)
        external
        view
        returns (uint256[] memory descendantIds, uint8[] memory depths);
    
    /**
     * @notice 获取衍生路径
     * @param fromAssetId 起始资产
     * @param toAssetId 目标资产
     * @return path 路径上的资产ID数组(包含起点和终点)
     * @return exists 路径是否存在
     */
    function getDerivationPath(uint256 fromAssetId, uint256 toAssetId)
        external
        view
        returns (uint256[] memory path, bool exists);
    
    /**
     * @notice 计算资产的衍生树统计
     * @param assetId 资产ID
     * @return directChildren 直接子资产数
     * @return totalDescendants 总后代数
     * @return maxDepthReached 达到的最大深度
     */
    function getDerivationStats(uint256 assetId)
        external
        view
        returns (
            uint32 directChildren,
            uint32 totalDescendants,
            uint8 maxDepthReached
        );
    
    //////////////////////////////////////////////////////////////
    // 权利继承计算
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 计算继承的权利配置
     * @param childAssetId 子资产ID
     * @return inheritedUse 继承的使用权
     * @return inheritedDer 继承的衍生权
     * @return inheritedExt 继承的扩展权
     * @return inheritedRev 继承的收益权
     * @dev 根据父资产权利和依赖关系计算子资产应继承的权利约束
     */
    function calculateInheritedRights(uint256 childAssetId)
        external
        view
        returns (
            UseRight memory inheritedUse,
            DerRight memory inheritedDer,
            ExtRight memory inheritedExt,
            RevRight memory inheritedRev
        );
    
    /**
     * @notice 计算多父资产的合并权利
     * @param parentIds 父资产ID数组
     * @param contributions 贡献比例数组
     * @return mergedUse 合并后的使用权
     * @return mergedDer 合并后的衍生权
     * @return mergedExt 合并后的扩展权
     * @return mergedRev 合并后的收益权
     * @dev 使用贡献比例加权合并多个父资产的权利约束(取最严格)
     */
    function mergeParentRights(
        uint256[] calldata parentIds,
        uint16[] calldata contributions
    )
        external
        view
        returns (
            UseRight memory mergedUse,
            DerRight memory mergedDer,
            ExtRight memory mergedExt,
            RevRight memory mergedRev
        );
    
    /**
     * @notice 计算上游分润链
     * @param assetId 资产ID
     * @param revenue 总收益
     * @return recipients 接收方地址数组
     * @return amounts 各接收方应得金额数组
     * @dev 递归计算所有祖先应得的分润
     */
    function calculateUpstreamSplits(uint256 assetId, uint256 revenue)
        external
        view
        returns (address[] memory recipients, uint256[] memory amounts);
    
    /**
     * @notice 验证衍生合规性
     * @param childAssetId 子资产ID
     * @return isCompliant 是否符合所有父资产的衍生要求
     * @return violations 违规详情数组
     */
    function verifyDerivationCompliance(uint256 childAssetId)
        external
        view
        returns (bool isCompliant, bytes32[] memory violations);
    
    //////////////////////////////////////////////////////////////
    // 上游权利追踪
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 追踪资产的所有上游权利
     * @param assetId 资产ID
     * @return upstreamAssetIds 上游资产ID数组
     * @return upstreamRights 对应的权利配置数组
     * @return transferChains 权利传递链数组
     */
    function traceUpstreamRights(uint256 assetId)
        external
        view
        returns (
            uint256[] memory upstreamAssetIds,
            RightsBundle[] memory upstreamRights,
            bytes32[] memory transferChains
        );
    
    /**
     * @notice 获取资产到特定上游的分润比例
     * @param assetId 资产ID
     * @param upstreamAssetId 上游资产ID
     * @return splitBps 分润比例(基点)
     * @return path 传递路径
     */
    function getUpstreamSplit(uint256 assetId, uint256 upstreamAssetId)
        external
        view
        returns (uint16 splitBps, uint256[] memory path);
    
    /**
     * @notice 检查是否存在循环依赖
     * @param assetId 待检查资产ID
     * @param proposedParentId 拟议的父资产ID
     * @return wouldCreateCycle 是否会创建循环
     * @return cyclePath 循环路径(如果存在)
     */
    function checkCircularDependency(
        uint256 assetId,
        uint256 proposedParentId
    )
        external
        view
        returns (bool wouldCreateCycle, uint256[] memory cyclePath);
    
    //////////////////////////////////////////////////////////////
    // 事件定义
    //////////////////////////////////////////////////////////////
    
    event DerivationRegistered(
        uint256 indexed childAssetId,
        uint256 indexed parentAssetId,
        DependencyType depType,
        uint16 contributionBps
    );
    
    event MultiParentDerivationRegistered(
        uint256 indexed childAssetId,
        uint256[] parentAssetIds,
        uint16[] contributions
    );
    
    event InheritanceCalculated(
        uint256 indexed childAssetId,
        bytes32 inheritedConfigHash
    );
    
    event UpstreamSplitCalculated(
        uint256 indexed assetId,
        uint256 revenue,
        uint256 recipientCount
    );
}
```

### 4.2 继承算法实现

```solidity
/**
 * @title RightsInheritance
 * @notice 权利继承系统实现
 */
contract RightsInheritance is IRightsInheritance {
    
    using RightsStorage for RightsStorage.WarmStorage;
    using RightsStorage for RightsStorage.ColdStorage;
    
    RightsStorage.WarmStorage private warmStorage;
    RightsStorage.ColdStorage private coldStorage;
    
    IRightsRegistry public rightsRegistry;
    ILicenseManager public licenseManager;
    
    uint8 constant MAX_DEPTH_LIMIT = 10;
    uint16 constant BASIS_POINTS = 10000;
    
    constructor(address _rightsRegistry, address _licenseManager) {
        rightsRegistry = IRightsRegistry(_rightsRegistry);
        licenseManager = ILicenseManager(_licenseManager);
    }
    
    function registerDerivation(
        uint256 childAssetId,
        uint256 parentAssetId,
        DependencyType depType,
        uint16 contributionBps
    ) external override {
        require(
            childAssetId != parentAssetId,
            "RightsInheritance: cannot derive from self"
        );
        
        // 检查循环依赖
        (bool wouldCycle, ) = checkCircularDependency(childAssetId, parentAssetId);
        require(!wouldCycle, "RightsInheritance: circular dependency detected");
        
        // 获取或创建依赖记录
        RightsDependency storage dep = warmStorage.dependencyGraph[childAssetId];
        
        if (dep.assetId == 0) {
            dep.assetId = childAssetId;
            dep.depth = 1;
        }
        
        dep.parentAssetId = parentAssetId;
        dep.depType = uint8(depType);
        dep.isDirect = true;
        dep.upstreamShareBps = contributionBps;
        dep.createdAt = uint64(block.timestamp);
        
        // 更新父资产的子资产列表
        RightsDependency storage parentDep = warmStorage.dependencyGraph[parentAssetId];
        if (parentDep.assetId == 0) {
            parentDep.assetId = parentAssetId;
        }
        parentDep.directChildren.push(childAssetId);
        parentDep.childrenCount++;
        
        // 递归更新祖先的后代列表
        _updateDescendants(parentAssetId, childAssetId);
        
        emit DerivationRegistered(childAssetId, parentAssetId, depType, contributionBps);
    }
    
    function _updateDescendants(uint256 ancestorId, uint256 newDescendantId) internal {
        RightsDependency storage ancestor = warmStorage.dependencyGraph[ancestorId];
        
        if (!ancestor.hasMultipleParents) {
            ancestor.allDescendants.push(newDescendantId);
            ancestor.totalDescendants++;
        }
        
        // 递归向上更新
        if (ancestor.parentAssetId != 0) {
            _updateDescendants(ancestor.parentAssetId, newDescendantId);
        }
    }
    
    function getAncestors(uint256 assetId)
        external
        view
        override
        returns (uint256[] memory ancestorIds, uint8[] memory distances)
    {
        RightsDependency storage dep = warmStorage.dependencyGraph[assetId];
        require(dep.assetId != 0, "RightsInheritance: asset not registered");
        
        uint256 currentId = dep.parentAssetId;
        uint8 distance = 1;
        
        // 统计祖先数量
        uint256 count = 0;
        while (currentId != 0 && distance <= MAX_DEPTH_LIMIT) {
            count++;
            RightsDependency storage current = warmStorage.dependencyGraph[currentId];
            currentId = current.parentAssetId;
            distance++;
        }
        
        ancestorIds = new uint256[](count);
        distances = new uint8[](count);
        
        // 填充数据
        currentId = dep.parentAssetId;
        distance = 1;
        uint256 index = 0;
        
        while (currentId != 0 && distance <= MAX_DEPTH_LIMIT) {
            ancestorIds[index] = currentId;
            distances[index] = distance;
            index++;
            
            RightsDependency storage current = warmStorage.dependencyGraph[currentId];
            currentId = current.parentAssetId;
            distance++;
        }
        
        return (ancestorIds, distances);
    }
    
    function calculateUpstreamSplits(uint256 assetId, uint256 revenue)
        external
        view
        override
        returns (address[] memory recipients, uint256[] memory amounts)
    {
        // 获取资产的收益权配置
        RightsBundle memory rights = rightsRegistry.getRights(assetId);
        
        // 收集所有上游资产的收益接收方
        uint256[] memory ancestorIds;
        (ancestorIds, ) = this.getAncestors(assetId);
        
        uint256 totalRecipients = 1 + ancestorIds.length; // 自己 + 所有祖先
        recipients = new address[](totalRecipients);
        amounts = new uint256[](totalRecipients);
        
        // 当前资产收益方
        uint256 index = 0;
        for (uint256 i = 0; i < rights.rev.recipients.length; i++) {
            recipients[index] = rights.rev.recipients[i];
            // 当前资产接收剩余收益
            amounts[index] = (revenue * (BASIS_POINTS - rights.der.upstreamShareBps)) / BASIS_POINTS;
            index++;
        }
        
        // 上游资产分润
        uint256 remainingRevenue = revenue;
        for (uint256 i = 0; i < ancestorIds.length; i++) {
            RightsBundle memory ancestorRights = rightsRegistry.getRights(ancestorIds[i]);
            
            uint256 splitAmount = (revenue * ancestorRights.der.upstreamShareBps) / BASIS_POINTS;
            remainingRevenue -= splitAmount;
            
            for (uint256 j = 0; j < ancestorRights.rev.recipients.length; j++) {
                recipients[index] = ancestorRights.rev.recipients[j];
                amounts[index] = (splitAmount * ancestorRights.rev.shareDistribution[j]) / BASIS_POINTS;
                index++;
            }
        }
        
        return (recipients, amounts);
    }
    
    function checkCircularDependency(uint256 assetId, uint256 proposedParentId)
        external
        view
        override
        returns (bool wouldCreateCycle, uint256[] memory cyclePath)
    {
        if (assetId == proposedParentId) {
            return (true, new uint256[](0));
        }
        
        // 从拟议父资产向上遍历，检查是否能到达当前资产
        uint256 currentId = proposedParentId;
        uint8 depth = 0;
        
        // 临时存储路径
        uint256[MAX_DEPTH_LIMIT] memory tempPath;
        uint256 pathLength = 0;
        
        while (currentId != 0 && depth < MAX_DEPTH_LIMIT) {
            if (currentId == assetId) {
                // 发现循环
                cyclePath = new uint256[](pathLength + 1);
                for (uint256 i = 0; i <= pathLength; i++) {
                    cyclePath[i] = tempPath[i];
                }
                return (true, cyclePath);
            }
            
            tempPath[pathLength] = currentId;
            pathLength++;
            
            RightsDependency storage current = warmStorage.dependencyGraph[currentId];
            currentId = current.parentAssetId;
            depth++;
        }
        
        return (false, new uint256[](0));
    }
    
    function verifyDerivationCompliance(uint256 childAssetId)
        external
        view
        override
        returns (bool isCompliant, bytes32[] memory violations)
    {
        RightsDependency storage childDep = warmStorage.dependencyGraph[childAssetId];
        RightsBundle memory childRights = rightsRegistry.getRights(childAssetId);
        
        if (childDep.parentAssetId == 0) {
            return (true, new bytes32[](0)); // 原创作品，无需检查
        }
        
        RightsBundle memory parentRights = rightsRegistry.getRights(childDep.parentAssetId);
        
        // 临时违规存储
        bytes32[10] memory tempViolations;
        uint256 violationCount = 0;
        
        // 检查衍生权是否允许
        if (!parentRights.der.allowed) {
            tempViolations[violationCount] = keccak256("DERIVATION_NOT_ALLOWED");
            violationCount++;
        }
        
        // 检查衍生深度
        if (childDep.depth > parentRights.der.maxDepth && parentRights.der.maxDepth > 0) {
            tempViolations[violationCount] = keccak256("DERIVATION_DEPTH_EXCEEDED");
            violationCount++;
        }
        
        // 检查上游分润比例
        if (childRights.der.upstreamShareBps < parentRights.der.upstreamShareBps) {
            tempViolations[violationCount] = keccak256("UPSTREAM_SHARE_TOO_LOW");
            violationCount++;
        }
        
        // 复制违规记录
        violations = new bytes32[](violationCount);
        for (uint256 i = 0; i < violationCount; i++) {
            violations[i] = tempViolations[i];
        }
        
        isCompliant = (violationCount == 0);
        return (isCompliant, violations);
    }
}
```

---

## 5. Conflict Detection Mechanism

### 5.1 冲突检测架构

```solidity
/**
 * @title IConflictDetector
 * @notice 权利冲突检测系统接口
 * @dev 自动检测和预防权利配置冲突
 */
interface IConflictDetector {
    
    //////////////////////////////////////////////////////////////
    // 冲突检测
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 预检查配置冲突
     * @param assetId 资产ID (0=新资产)
     * @param newRights 拟议的权利配置
     * @return hasConflict 是否存在冲突
     * @return conflicts 冲突详情数组
     * @dev 在设置权利配置前进行冲突预检查
     */
    function preCheckConflicts(
        uint256 assetId,
        RightsBundle calldata newRights
    )
        external
        view
        returns (bool hasConflict, ConflictPreview[] memory conflicts);
    
    /**
     * @notice 检测资产间的权利冲突
     * @param assetIdA 资产A ID
     * @param assetIdB 资产B ID
     * @return conflicts 发现的冲突数组
     */
    function detectConflictsBetween(uint256 assetIdA, uint256 assetIdB)
        external
        view
        returns (ConflictRecord[] memory conflicts);
    
    /**
     * @notice 批量检测资产列表中的冲突
     * @param assetIds 资产ID数组
     * @return conflictMatrix 冲突矩阵(上三角)
     * @return totalConflicts 总冲突数
     */
    function batchDetectConflicts(uint256[] calldata assetIds)
        external
        view
        returns (bool[][] memory conflictMatrix, uint256 totalConflicts);
    
    /**
     * @notice 扫描衍生链中的冲突
     * @param assetId 起始资产ID
     * @param maxDepth 扫描深度
     * @return chainConflicts 发现的冲突数组
     * @return blockingConflicts 阻塞性冲突数量
     */
    function scanDerivationChain(uint256 assetId, uint8 maxDepth)
        external
        view
        returns (
            ConflictRecord[] memory chainConflicts,
            uint256 blockingConflicts
        );
    
    /**
     * @notice 实时检测授权冲突
     * @param licenseRequest 授权请求详情
     * @return isAllowed 是否允许
     * @return blockingConflicts 阻塞性冲突
     */
    function checkLicenseConflict(LicenseRequest calldata licenseRequest)
        external
        view
        returns (bool isAllowed, ConflictPreview[] memory blockingConflicts);
    
    //////////////////////////////////////////////////////////////
    // 冲突解决
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 提交冲突解决提案
     * @param conflictId 冲突ID
     * @param resolutionType 解决方案类型
     * @param resolutionData 解决方案数据
     */
    function proposeResolution(
        uint256 conflictId,
        ResolutionType resolutionType,
        bytes calldata resolutionData
    ) external;
    
    /**
     * @notice 执行冲突解决
     * @param conflictId 冲突ID
     * @param resolutionId 解决方案ID
     */
    function executeResolution(uint256 conflictId, uint256 resolutionId) external;
    
    /**
     * @notice 自动解决可自动处理的冲突
     * @param conflictIds 冲突ID数组
     * @return resolvedCount 成功解决数
     */
    function autoResolveConflicts(uint256[] calldata conflictIds)
        external
        returns (uint256 resolvedCount);
    
    /**
     * @notice 获取冲突的建议解决方案
     * @param conflictId 冲突ID
     * @return suggestions 建议方案数组
     */
    function getResolutionSuggestions(uint256 conflictId)
        external
        view
        returns (ResolutionSuggestion[] memory suggestions);
    
    //////////////////////////////////////////////////////////////
    // 冲突预防
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 设置冲突预防规则
     * @param ruleType 规则类型
     * @param ruleData 规则数据
     */
    function setPreventionRule(PreventionRuleType ruleType, bytes calldata ruleData)
        external;
    
    /**
     * @notice 验证配置是否符合预防规则
     * @param rights 权利配置
     * @return isCompliant 是否符合
     * @return failedRules 未通过的规则
     */
    function validateAgainstRules(RightsBundle calldata rights)
        external
        view
        returns (bool isCompliant, PreventionRuleType[] memory failedRules);
    
    /**
     * @notice 生成权利配置的兼容性报告
     * @param assetId 资产ID
     * @return compatibility 与常见配置的兼容性评分(0-10000)
     * @return recommendations 优化建议
     */
    function generateCompatibilityReport(uint256 assetId)
        external
        view
        returns (uint16 compatibility, string[] memory recommendations);
    
    //////////////////////////////////////////////////////////////
    // 数据结构
    //////////////////////////////////////////////////////////////
    
    struct ConflictPreview {
        ConflictType conflictType;
        uint8 severity;
        bytes32 description;
        bytes32 suggestedFix;
        bool isAutoResolvable;
    }
    
    struct LicenseRequest {
        uint256 assetId;
        address requester;
        RightType requestedRight;
        uint8 requestedScope;
        uint64 requestedDuration;
    }
    
    struct ResolutionSuggestion {
        ResolutionType resolutionType;
        bytes32 description;
        uint16 confidence;  // 置信度(基点)
        bytes data;
    }
    
    enum ResolutionType {
        MODIFY_RIGHTS,      // 修改权利配置
        RESTRICT_SCOPE,     // 限制使用范围
        NEGOTIATE,          // 协商解决
        ESCALATE,           // 升级仲裁
        IGNORE,             // 忽略(低风险)
        AUTO_ADJUST         // 自动调整
    }
    
    enum PreventionRuleType {
        MIN_UPSTREAM_SHARE,     // 最小上游分润比例
        MAX_DERIVATIVE_DEPTH,   // 最大衍生深度限制
        EXCLUSIVE_COMPATIBILITY, // 排他性兼容检查
        CURRENCY_CONSISTENCY,    // 币种一致性
        PLATFORM_WHITELIST,     // 平台白名单
        MIN_COOLDOWN_PERIOD,    // 最小冷却期
        ATTRIBUTION_REQUIRED    // 强制署名要求
    }
    
    //////////////////////////////////////////////////////////////
    // 事件
    //////////////////////////////////////////////////////////////
    
    event ConflictDetected(
        uint256 indexed conflictId,
        uint256 indexed assetIdA,
        uint256 indexed assetIdB,
        ConflictType conflictType,
        uint8 severity
    );
    
    event ConflictResolved(
        uint256 indexed conflictId,
        ResolutionType resolutionType,
        address resolver
    );
    
    event PreventionRuleTriggered(
        uint256 indexed assetId,
        PreventionRuleType ruleType,
        bytes32 violation
    );
}
```

### 5.2 冲突检测算法实现

```solidity
/**
 * @title ConflictDetector
 * @notice 权利冲突检测系统实现
 */
contract ConflictDetector is IConflictDetector {
    
    using RightsStorage for RightsStorage.WarmStorage;
    
    IRightsRegistry public rightsRegistry;
    IRightsInheritance public rightsInheritance;
    
    // 冲突ID计数器
    uint256 private nextConflictId;
    
    // 预防规则存储
    mapping(PreventionRuleType => bytes) public preventionRules;
    mapping(uint256 => ConflictRecord) public conflicts;
    
    constructor(address _rightsRegistry, address _rightsInheritance) {
        rightsRegistry = IRightsRegistry(_rightsRegistry);
        rightsInheritance = IRightsInheritance(_rightsInheritance);
        nextConflictId = 1;
    }
    
    function preCheckConflicts(uint256 assetId, RightsBundle calldata newRights)
        external
        view
        override
        returns (bool hasConflict, ConflictPreview[] memory conflictPreviews)
    {
        ConflictPreview[20] memory tempConflicts;
        uint256 conflictCount = 0;
        
        // 检查1: 使用权与衍生权的范围重叠
        if (newRights.use.isActive && newRights.der.isActive) {
            if ((newRights.use.usageScope & uint8(UsageScope.DERIVATIVE)) != 0 && 
                !newRights.der.allowed) {
                tempConflicts[conflictCount] = ConflictPreview({
                    conflictType: ConflictType.USE_SCOPE_OVERLAP,
                    severity: 3,
                    description: keccak256("USE allows DERIVATIVE but DER right forbids it"),
                    suggestedFix: keccak256("Either disable DERIVATIVE in USE scope or enable DER right"),
                    isAutoResolvable: true
                });
                conflictCount++;
            }
        }
        
        // 检查2: 收益分润比例总和超过100%
        if (newRights.rev.isActive) {
            uint256 totalShares = 0;
            for (uint256 i = 0; i < newRights.rev.recipients.length; i++) {
                totalShares += uint16(uint256(newRights.rev.shareDistribution) >> (i * 16));
            }
            if (totalShares > 10000) {
                tempConflicts[conflictCount] = ConflictPreview({
                    conflictType: ConflictType.REV_SHARE_MISMATCH,
                    severity: 5,
                    description: keccak256("Revenue shares exceed 100%"),
                    suggestedFix: keccak256("Adjust share distribution to total 100%"),
                    isAutoResolvable: true
                });
                conflictCount++;
            }
        }
        
        // 检查3: 衍生链深度与上游分润的合理性
        if (newRights.der.isActive && newRights.der.maxDepth > 0) {
            // 如果深度很大但上游分润很低，可能导致激励不足
            if (newRights.der.maxDepth > 5 && newRights.der.upstreamShareBps < 500) {
                tempConflicts[conflictCount] = ConflictPreview({
                    conflictType: ConflictType.DER_CHAIN_DEPTH,
                    severity: 2,
                    description: keccak256("Low upstream share with deep derivation chain may disincentivize creators"),
                    suggestedFix: keccak256("Consider increasing upstream share or limiting depth"),
                    isAutoResolvable: false
                });
                conflictCount++;
            }
        }
        
        // 检查4: 扩展权的安全级别与接口类型的匹配
        if (newRights.ext.isActive) {
            if (newRights.ext.securityLevel == uint8(SecurityLevel.OPEN) &&
                (newRights.ext.interfaceType & uint8(InterfaceType.PLUGIN)) != 0) {
                tempConflicts[conflictCount] = ConflictPreview({
                    conflictType: ConflictType.EXT_SECURITY_LEVEL,
                    severity: 4,
                    description: keccak256("Plugin interface with OPEN security is risky"),
                    suggestedFix: keccak256("Increase security level for plugin interfaces"),
                    isAutoResolvable: true
                });
                conflictCount++;
            }
        }
        
        // 检查5: 结算周期与自动分配的矛盾
        if (newRights.rev.isActive && newRights.rev.autoDistribute) {
            if (newRights.rev.settlementTrigger == uint8(SettlementTrigger.MANUAL)) {
                tempConflicts[conflictCount] = ConflictPreview({
                    conflictType: ConflictType.REV_SETTLEMENT_CYCLE,
                    severity: 3,
                    description: keccak256("Auto-distribute with MANUAL settlement trigger is contradictory"),
                    suggestedFix: keccak256("Change to automatic settlement trigger"),
                    isAutoResolvable: true
                });
                conflictCount++;
            }
        }
        
        // 复制结果
        conflictPreviews = new ConflictPreview[](conflictCount);
        for (uint256 i = 0; i < conflictCount; i++) {
            conflictPreviews[i] = tempConflicts[i];
        }
        
        return (conflictCount > 0, conflictPreviews);
    }
    
    function detectConflictsBetween(uint256 assetIdA, uint256 assetIdB)
        external
        view
        override
        returns (ConflictRecord[] memory)
    {
        RightsBundle memory rightsA = rightsRegistry.getRights(assetIdA);
        RightsBundle memory rightsB = rightsRegistry.getRights(assetIdB);
        
        ConflictRecord[10] memory tempConflicts;
        uint256 conflictCount = 0;
        
        // 检查双向衍生冲突
        (bool aDerivesB, ) = rightsInheritance.getDerivationPath(assetIdA, assetIdB);
        (bool bDerivesA, ) = rightsInheritance.getDerivationPath(assetIdB, assetIdA);
        
        if (aDerivesB && bDerivesA) {
            uint256 conflictId = nextConflictId + conflictCount;
            tempConflicts[conflictCount] = ConflictRecord({
                conflictId: conflictId,
                assetIdA: assetIdA,
                assetIdB: assetIdB,
                conflictType: uint8(ConflictType.DER_RECIPROCAL),
                severity: 5,
                rightTypeInvolved: uint8(RightType.DER),
                isResolved: false,
                isBlocking: true,
                descriptionHash: keccak256("Circular derivation detected between assets"),
                suggestedFixHash: keccak256("Break derivation cycle by removing one direction"),
                detectedAt: uint64(block.timestamp),
                resolvedAt: 0,
                expiresAt: 0,
                detectedBy: address(this),
                resolutionType: 0,
                resolutionProof: bytes32(0),
                resolvedBy: address(0),
                relatedAssets: new uint256[](0),
                parentConflictId: 0
            });
            conflictCount++;
        }
        
        // 检查独占性冲突
        if (rightsA.use.isActive && rightsB.use.isActive) {
            // 如果A授予了B独占使用权，而B又试图授予其他人
            // 这需要在授权层面检查
        }
        
        // 复制结果
        ConflictRecord[] memory result = new ConflictRecord[](conflictCount);
        for (uint256 i = 0; i < conflictCount; i++) {
            result[i] = tempConflicts[i];
        }
        
        return result;
    }
    
    function checkLicenseConflict(LicenseRequest calldata request)
        external
        view
        override
        returns (bool isAllowed, ConflictPreview[] memory blockingConflicts)
    {
        RightsBundle memory rights = rightsRegistry.getRights(request.assetId);
        ConflictPreview[10] memory tempBlocks;
        uint256 blockCount = 0;
        
        // 检查请求的权利类型是否激活
        if (request.requestedRight == RightType.USE && !rights.use.isActive) {
            tempBlocks[blockCount++] = ConflictPreview({
                conflictType: ConflictType.EXCLUSIVE_INCOMPATIBLE,
                severity: 5,
                description: keccak256("Use right is not active for this asset"),
                suggestedFix: keccak256("Enable use right first"),
                isAutoResolvable: false
            });
        }
        
        // 检查使用范围
        if (request.requestedRight == RightType.USE) {
            if ((rights.use.usageScope & request.requestedScope) == 0) {
                tempBlocks[blockCount++] = ConflictPreview({
                    conflictType: ConflictType.USE_SCOPE_OVERLAP,
                    severity: 4,
                    description: keccak256("Requested scope not allowed by asset rights"),
                    suggestedFix: keccak256("Adjust request scope or modify asset rights"),
                    isAutoResolvable: false
                });
            }
        }
        
        // 检查衍生权限
        if (request.requestedRight == RightType.DER && !rights.der.allowed) {
            tempBlocks[blockCount++] = ConflictPreview({
                conflictType: ConflictType.EXCLUSIVE_INCOMPATIBLE,
                severity: 5,
                description: keccak256("Derivative right is not allowed for this asset"),
                suggestedFix: keccak256("Request derivative permission from asset owner"),
                isAutoResolvable: false
            });
        }
        
        // 复制结果
        blockingConflicts = new ConflictPreview[](blockCount);
        for (uint256 i = 0; i < blockCount; i++) {
            blockingConflicts[i] = tempBlocks[i];
        }
        
        isAllowed = (blockCount == 0);
        return (isAllowed, blockingConflicts);
    }
    
    function autoResolveConflicts(uint256[] calldata conflictIds)
        external
        override
        returns (uint256 resolvedCount)
    {
        resolvedCount = 0;
        
        for (uint256 i = 0; i < conflictIds.length; i++) {
            ConflictRecord storage conflict = conflicts[conflictIds[i]];
            
            if (conflict.isResolved) continue;
            if (conflict.conflictId == 0) continue;
            
            // 自动处理可自动解决的冲突
            if (conflict.conflictType == uint8(ConflictType.REV_SHARE_MISMATCH)) {
                // 收益分润错误可以通过调整配置自动解决
                // 需要调用RightsRegistry修改权利配置
                conflict.isResolved = true;
                conflict.resolvedAt = uint64(block.timestamp);
                conflict.resolutionType = uint8(ResolutionType.AUTO_ADJUST);
                conflict.resolvedBy = msg.sender;
                resolvedCount++;
                
                emit ConflictResolved(conflictIds[i], ResolutionType.AUTO_ADJUST, msg.sender);
            }
            
            if (conflict.conflictType == uint8(ConflictType.USE_SCOPE_OVERLAP) && 
                conflict.severity <= 2) {
                // 低严重性的使用范围重叠可以自动放宽
                conflict.isResolved = true;
                conflict.resolvedAt = uint64(block.timestamp);
                conflict.resolutionType = uint8(ResolutionType.AUTO_ADJUST);
                conflict.resolvedBy = msg.sender;
                resolvedCount++;
                
                emit ConflictResolved(conflictIds[i], ResolutionType.AUTO_ADJUST, msg.sender);
            }
        }
        
        return resolvedCount;
    }
}
```

---

## 6. Events and Indexing

### 6.1 事件系统设计

```solidity
/**
 * @title RightsEvents
 * @notice 权利系统事件定义
 * @dev 完整的事件系统支持链下索引和分析
 */
interface RightsEvents {
    
    //////////////////////////////////////////////////////////////
    // 权利配置事件
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 权利配置已创建
     */
    event RightsConfigured(
        uint256 indexed assetId,
        address indexed configurator,
        bytes32 indexed configHash,
        RightsBundle rights,
        uint256 version
    );
    
    /**
     * @notice 权利配置已更新
     */
    event RightsUpdated(
        uint256 indexed assetId,
        address indexed updater,
        bytes32 indexed oldConfigHash,
        bytes32 newConfigHash,
        uint256 newVersion,
        string[] changedFields
    );
    
    /**
     * @notice 权利配置已锁定
     */
    event RightsLocked(
        uint256 indexed assetId,
        address indexed locker,
        uint64 lockedUntil,
        bytes32 lockReason
    );
    
    /**
     * @notice 单个权利类型已修改
     */
    event RightModified(
        uint256 indexed assetId,
        RightType indexed rightType,
        bytes32 oldValueHash,
        bytes32 newValueHash,
        string fieldName
    );
    
    //////////////////////////////////////////////////////////////
    // 授权事件
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 授权已授予
     */
    event LicenseGranted(
        uint256 indexed licenseId,
        uint256 indexed assetId,
        address indexed grantor,
        address grantee,
        RightType rightType,
        LicenseType licenseType,
        uint64 validFrom,
        uint64 validUntil,
        uint88 usageLimit
    );
    
    /**
     * @notice 授权已激活
     */
    event LicenseActivated(
        uint256 indexed licenseId,
        uint64 activatedAt
    );
    
    /**
     * @notice 授权使用已记录
     */
    event LicenseUsage(
        uint256 indexed licenseId,
        uint256 indexed assetId,
        address indexed user,
        bytes4 operation,
        uint64 timestamp,
        uint88 remainingUsage
    );
    
    /**
     * @notice 授权已暂停
     */
    event LicenseSuspended(
        uint256 indexed licenseId,
        address indexed suspender,
        bytes32 reason,
        uint64 suspendedUntil
    );
    
    /**
     * @notice 授权已恢复
     */
    event LicenseResumed(
        uint256 indexed licenseId,
        address indexed resumer,
        uint64 resumedAt
    );
    
    /**
     * @notice 授权已撤销
     */
    event LicenseRevoked(
        uint256 indexed licenseId,
        address indexed revoker,
        uint8 reasonCode,
        bytes32 details,
        uint64 revokedAt
    );
    
    /**
     * @notice 授权已过期
     */
    event LicenseExpired(
        uint256 indexed licenseId,
        uint64 expiredAt,
        uint88 finalUsageCount
    );
    
    /**
     * @notice 授权已续期
     */
    event LicenseRenewed(
        uint256 indexed licenseId,
        address indexed renewer,
        uint64 oldExpiry,
        uint64 newExpiry,
        uint256 additionalPayment
    );
    
    /**
     * @notice 授权已转让
     */
    event LicenseTransferred(
        uint256 indexed licenseId,
        address indexed from,
        address indexed to,
        uint64 transferredAt
    );
    
    //////////////////////////////////////////////////////////////
    // 衍生与继承事件
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 衍生关系已注册
     */
    event DerivationRegistered(
        uint256 indexed childAssetId,
        uint256 indexed parentAssetId,
        DependencyType depType,
        uint16 contributionBps,
        uint8 depth,
        uint64 registeredAt
    );
    
    /**
     * @notice 多父衍生已注册
     */
    event MultiParentDerivation(
        uint256 indexed childAssetId,
        uint256[] parentAssetIds,
        uint16[] contributions,
        bytes32 combinedRightsHash
    );
    
    /**
     * @notice 权利已继承
     */
    event RightsInherited(
        uint256 indexed childAssetId,
        uint256 indexed parentAssetId,
        bytes32 inheritedConfigHash,
        bytes32 constraintsApplied
    );
    
    /**
     * @notice 上游分润已计算
     */
    event UpstreamSplitCalculated(
        uint256 indexed assetId,
        uint256 revenue,
        uint256 indexed upstreamAssetId,
        uint16 splitBps,
        uint256 calculatedAmount
    );
    
    /**
     * @notice 衍生链深度已更新
     */
    event DerivationDepthUpdated(
        uint256 indexed assetId,
        uint8 oldDepth,
        uint8 newDepth,
        uint256[] affectedDescendants
    );
    
    //////////////////////////////////////////////////////////////
    // 冲突事件
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 冲突已检测
     */
    event ConflictDetected(
        uint256 indexed conflictId,
        ConflictType indexed conflictType,
        uint8 severity,
        uint256 indexed assetIdA,
        uint256 assetIdB,
        bytes32 description,
        uint64 detectedAt
    );
    
    /**
     * @notice 冲突警告(非阻塞)
     */
    event ConflictWarning(
        uint256 indexed assetId,
        ConflictType conflictType,
        bytes32 warning,
        bytes32 suggestion
    );
    
    /**
     * @notice 冲突已解决
     */
    event ConflictResolved(
        uint256 indexed conflictId,
        ResolutionType resolutionType,
        address indexed resolver,
        bytes32 resolutionProof,
        uint64 resolvedAt
    );
    
    /**
     * @notice 冲突已升级
     */
    event ConflictEscalated(
        uint256 indexed conflictId,
        address indexed escalator,
        address arbitrator,
        bytes32 reason,
        uint64 escalatedAt
    );
    
    /**
     * @notice 预防规则已触发
     */
    event PreventionRuleTriggered(
        uint256 indexed assetId,
        PreventionRuleType indexed ruleType,
        bytes32 violation,
        bytes32 autoAction,
        uint64 triggeredAt
    );
    
    //////////////////////////////////////////////////////////////
    // 扩展与集成事件
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 扩展调用已执行
     */
    event ExtensionCalled(
        uint256 indexed assetId,
        address indexed caller,
        bytes4 indexed selector,
        uint64 timestamp,
        uint32 cpuUsed,
        uint32 memoryUsed,
        bool success
    );
    
    /**
     * @notice API限流已触发
     */
    event RateLimitTriggered(
        uint256 indexed assetId,
        address indexed caller,
        uint8 limitType,
        uint64 retryAfter,
        uint32 currentUsage,
        uint32 limit
    );
    
    /**
     * @notice 跨链权利已同步
     */
    event CrossChainRightsSync(
        uint256 indexed assetId,
        uint256 indexed targetChainId,
        bytes32 rightsHash,
        bytes32 syncProof,
        bool success
    );
}
```

### 6.2 索引策略

```solidity
/**
 * @title RightsIndexer
 * @notice 权利系统索引辅助合约
 * @dev 优化链下索引的查询效率
 */
contract RightsIndexer {
    
    // 资产ID -> 授权ID列表映射(用于快速查询)
    mapping(uint256 => uint256[]) public assetLicensesIndex;
    
    // 用户 -> 授权ID列表映射
    mapping(address => uint256[]) public userLicensesIndex;
    
    // 权利类型 -> 资产ID列表(用于按类型浏览)
    mapping(uint8 => uint256[]) public rightTypeAssets;
    
    // 定价模型 -> 资产ID列表
    mapping(uint8 => uint256[]) public pricingModelAssets;
    
    // 配置哈希 -> 使用该配置的资产列表
    mapping(bytes32 => uint256[]) public configAssetsIndex;
    
    // 衍生深度 -> 资产ID列表
    mapping(uint8 => uint256[]) public depthAssetsIndex;
    
    /**
     * @notice 更新资产索引
     */
    function indexAssetRights(uint256 assetId, RightsBundle calldata rights) external {
        // 更新权利类型索引
        if (rights.use.isActive) {
            _addToIndex(rightTypeAssets[uint8(RightType.USE)], assetId);
        }
        if (rights.der.isActive) {
            _addToIndex(rightTypeAssets[uint8(RightType.DER)], assetId);
        }
        if (rights.ext.isActive) {
            _addToIndex(rightTypeAssets[uint8(RightType.EXT)], assetId);
        }
        if (rights.rev.isActive) {
            _addToIndex(rightTypeAssets[uint8(RightType.REV)], assetId);
        }
        
        // 更新定价模型索引
        _addToIndex(pricingModelAssets[uint8(rights.use.pricingModel)], assetId);
        
        // 更新配置哈希索引
        _addToIndex(configAssetsIndex[rights.configHash], assetId);
    }
    
    /**
     * @notice 批量查询资产授权
     */
    function getAssetLicensesPaginated(
        uint256 assetId,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory licenseIds, uint256 total) {
        uint256[] storage allLicenses = assetLicensesIndex[assetId];
        total = allLicenses.length;
        
        if (offset >= total) {
            return (new uint256[](0), total);
        }
        
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        
        licenseIds = new uint256[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            licenseIds[i - offset] = allLicenses[i];
        }
        
        return (licenseIds, total);
    }
    
    /**
     * @notice 按定价模型筛选资产
     */
    function getAssetsByPricingModel(
        uint8 pricingModel,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory assetIds, uint256 total) {
        uint256[] storage allAssets = pricingModelAssets[pricingModel];
        total = allAssets.length;
        
        if (offset >= total) {
            return (new uint256[](0), total);
        }
        
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        
        assetIds = new uint256[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            assetIds[i - offset] = allAssets[i];
        }
        
        return (assetIds, total);
    }
    
    function _addToIndex(uint256[] storage index, uint256 value) internal {
        // 检查是否已存在
        for (uint256 i = 0; i < index.length; i++) {
            if (index[i] == value) return;
        }
        index.push(value);
    }
}
```

---

## 7. Security Considerations

### 7.1 安全架构

```solidity
/**
 * @title RightsSecurity
 * @notice 权利系统安全模块
 */
contract RightsSecurity is AccessControl, ReentrancyGuard, Pausable {
    
    bytes32 public constant RIGHTS_ADMIN_ROLE = keccak256("RIGHTS_ADMIN_ROLE");
    bytes32 public constant LICENSE_GRANTER_ROLE = keccak256("LICENSE_GRANTER_ROLE");
    bytes32 public constant CONFLICT_RESOLVER_ROLE = keccak256("CONFLICT_RESOLVER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // 安全参数
    uint256 public constant MAX_DAILY_LICENSES = 1000;
    uint256 public constant MAX_BULK_LICENSES = 100;
    uint256 public constant MIN_LICENSE_DURATION = 1 hours;
    uint256 public constant MAX_LICENSE_DURATION = 365 days * 10;
    
    // 使用限制
    mapping(address => uint256) public dailyLicenseGrants;
    mapping(address => uint256) public lastLicenseGrantDay;
    
    // 黑名单
    mapping(address => bool) public blacklistedGrantees;
    
    // 紧急暂停标记
    mapping(uint8 => bool) public pausedOperations;
    
    modifier withinDailyLimit() {
        uint256 today = block.timestamp / 1 days;
        if (today > lastLicenseGrantDay[msg.sender]) {
            dailyLicenseGrants[msg.sender] = 0;
            lastLicenseGrantDay[msg.sender] = today;
        }
        require(
            dailyLicenseGrants[msg.sender] < MAX_DAILY_LICENSES,
            "RightsSecurity: daily license limit exceeded"
        );
        _;
        dailyLicenseGrants[msg.sender]++;
    }
    
    modifier notBlacklisted(address account) {
        require(!blacklistedGrantees[account], "RightsSecurity: account blacklisted");
        _;
    }
    
    modifier whenOperationNotPaused(uint8 operation) {
        require(!pausedOperations[operation], "RightsSecurity: operation paused");
        _;
    }
    
    /**
     * @notice 验证权利配置的合理性
     */
    function validateRightsConfig(RightsBundle calldata rights)
        external
        pure
        returns (bool isValid, string[] memory errors)
    {
        string[10] memory tempErrors;
        uint256 errorCount = 0;
        
        // 验证收益分润总和
        if (rights.rev.isActive) {
            uint256 totalShares = 0;
            for (uint256 i = 0; i < 16; i++) {
                totalShares += uint16(uint256(rights.rev.shareDistribution) >> (i * 16));
            }
            if (totalShares > 10000) {
                tempErrors[errorCount++] = "Revenue shares exceed 100%";
            }
        }
        
        // 验证衍生深度合理性
        if (rights.der.isActive && rights.der.maxDepth > 20) {
            tempErrors[errorCount++] = "Derivative depth exceeds maximum allowed";
        }
        
        // 验证平台费率
        if (rights.use.platformFeeBps > 3000) { // 最高30%
            tempErrors[errorCount++] = "Platform fee exceeds 30%";
        }
        
        // 复制错误信息
        errors = new string[](errorCount);
        for (uint256 i = 0; i < errorCount; i++) {
            errors[i] = tempErrors[i];
        }
        
        return (errorCount == 0, errors);
    }
    
    /**
     * @notice 紧急暂停特定操作
     */
    function emergencyPause(uint8 operation) external onlyRole(EMERGENCY_ROLE) {
        pausedOperations[operation] = true;
        emit EmergencyPaused(operation, msg.sender);
    }
    
    /**
     * @notice 恢复暂停的操作
     */
    function emergencyUnpause(uint8 operation) external onlyRole(EMERGENCY_ROLE) {
        pausedOperations[operation] = false;
        emit EmergencyUnpaused(operation, msg.sender);
    }
    
    /**
     * @notice 将地址加入黑名单
     */
    function blacklistAddress(address account) external onlyRole(RIGHTS_ADMIN_ROLE) {
        blacklistedGrantees[account] = true;
        emit AddressBlacklisted(account, msg.sender);
    }
    
    /**
     * @notice 从黑名单移除
     */
    function unblacklistAddress(address account) external onlyRole(RIGHTS_ADMIN_ROLE) {
        blacklistedGrantees[account] = false;
        emit AddressUnblacklisted(account, msg.sender);
    }
    
    event EmergencyPaused(uint8 operation, address pauser);
    event EmergencyUnpaused(uint8 operation, address unpauser);
    event AddressBlacklisted(address indexed account, address indexed admin);
    event AddressUnblacklisted(address indexed account, address indexed admin);
}
```

### 7.2 安全最佳实践

```solidity
/**
 * @title SecurityBestPractices
 * @notice 权利系统安全最佳实践指南
 * @dev 以下是权利注册合约的关键安全考虑
 */
contract SecurityBestPractices {
    
    // ========== 1. 重入攻击防护 ==========
    
    /**
     * @dev 所有涉及外部调用的函数必须使用 ReentrancyGuard
     * 特别是：
     * - 授权退款
     * - 收益结算
     * - 权利转让
     */
    
    // ========== 2. 整数溢出防护 ==========
    
    /**
     * @dev 使用 Solidity 0.8+ 的内置溢出检查
     * 关键计算：
     * - 收益分润计算
     * - 使用次数统计
     * - 价格计算
     */
    
    // ========== 3. 访问控制 ==========
    
    /**
     * @dev 使用 OpenZeppelin AccessControl 进行细粒度权限管理
     * 关键角色：
     * - RIGHTS_ADMIN: 权利配置管理
     * - LICENSE_GRANTER: 授权发放
     * - CONFLICT_RESOLVER: 冲突解决
     * - EMERGENCY: 紧急操作
     */
    
    // ========== 4. 输入验证 ==========
    
    /**
     * @dev 严格验证所有外部输入
     */
    modifier validAssetId(uint256 assetId) {
        require(assetId > 0, "Invalid asset ID");
        _;
    }
    
    modifier validAddress(address account) {
        require(account != address(0), "Invalid address");
        _;
    }
    
    modifier validDuration(uint64 duration) {
        require(
            duration == 0 || (duration >= 1 hours && duration <= 3650 days),
            "Invalid duration"
        );
        _;
    }
    
    // ========== 5. 原子性操作 ==========
    
    /**
     * @dev 复杂操作必须保持原子性
     * - 使用检查-生效-交互模式
     * - 先更新状态，再进行外部调用
     */
    
    // ========== 6. Gas限制防护 ==========
    
    /**
     * @dev 防止Gas耗尽攻击
     */
    uint256 constant MAX_LOOP_ITERATIONS = 100;
    uint256 constant MAX_BATCH_SIZE = 50;
    
    modifier withinGasLimit() {
        require(gasleft() > 100000, "Insufficient gas");
        _;
    }
    
    // ========== 7. 时间操控防护 ==========
    
    /**
     * @dev 防范区块时间操控
     * - 不依赖精确时间进行关键决策
     * - 使用区块号作为备选
     */
    
    // ========== 8. 存储碰撞防护 ==========
    
    /**
     * @dev 使用确定性存储布局
     * - 避免动态数组作为 mapping 键
     * - 使用 struct 封装相关数据
     */
    
    // ========== 9. 前端运行防护 ==========
    
    /**
     * @dev 防范 MEV 和前端运行
     * - 对价格敏感操作使用提交-揭示机制
     * - 设置滑点保护
     */
    
    // ========== 10. 升级安全 ==========
    
    /**
     * @dev 使用代理模式进行合约升级
     * - UUPS 或 Transparent Proxy
     * - 保留存储布局兼容性
     */
}
```

---

## 8. Integration with EchoCore

### 8.1 集成架构

```solidity
/**
 * @title IRightsRegistry
 * @notice Rights Registry 主合约接口
 * @dev Layer 0 核心权利管理合约，与 EchoCore 深度集成
 */
interface IRightsRegistry {
    
    //////////////////////////////////////////////////////////////
    // 核心函数
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 为资产配置权利
     * @param assetId 资产ID
     * @param rights 四维权利配置
     * @dev 只能由资产所有者或授权代理人调用
     */
    function configureRights(
        uint256 assetId,
        RightsBundle calldata rights
    ) external;
    
    /**
     * @notice 批量配置多个资产的权利
     * @param assetIds 资产ID数组
     * @param rightsArray 权利配置数组
     */
    function batchConfigureRights(
        uint256[] calldata assetIds,
        RightsBundle[] calldata rightsArray
    ) external;
    
    /**
     * @notice 获取资产的权利配置
     * @param assetId 资产ID
     * @return rights 完整的权利配置
     */
    function getRights(uint256 assetId)
        external
        view
        returns (RightsBundle memory rights);
    
    /**
     * @notice 检查特定权利类型是否激活
     * @param assetId 资产ID
     * @param rightType 权利类型
     * @return isActive 是否激活
     */
    function isRightActive(uint256 assetId, RightType rightType)
        external
        view
        returns (bool isActive);
    
    /**
     * @notice 更新单个权利类型
     * @param assetId 资产ID
     * @param rightType 要更新的权利类型
     * @param newConfig 新配置(编码后)
     */
    function updateRight(
        uint256 assetId,
        RightType rightType,
        bytes calldata newConfig
    ) external;
    
    /**
     * @notice 锁定权利配置(防止修改)
     * @param assetId 资产ID
     * @param lockDuration 锁定持续时间(秒, 0=永久)
     */
    function lockRights(uint256 assetId, uint64 lockDuration) external;
    
    /**
     * @notice 解锁权利配置
     * @param assetId 资产ID
     */
    function unlockRights(uint256 assetId) external;
    
    //////////////////////////////////////////////////////////////
    // 查询函数
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 获取资产的权利历史
     * @param assetId 资产ID
     * @return configHashes 历史配置哈希数组
     * @return timestamps 更新时间数组
     */
    function getRightsHistory(uint256 assetId)
        external
        view
        returns (bytes32[] memory configHashes, uint64[] memory timestamps);
    
    /**
     * @notice 计算资产的权利摘要
     * @param assetId 资产ID
     * @return summary 权利摘要信息
     */
    function getRightsSummary(uint256 assetId)
        external
        view
        returns (RightsSummary memory summary);
    
    /**
     * @notice 批量查询多个资产的权利
     * @param assetIds 资产ID数组
     * @return rightsArray 权利配置数组
     */
    function batchGetRights(uint256[] calldata assetIds)
        external
        view
        returns (RightsBundle[] memory rightsArray);
    
    //////////////////////////////////////////////////////////////
    // 集成接口
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice EchoCore 回调：资产铸造时初始化权利
     * @param assetId 新铸造的资产ID
     * @param initialRights 初始权利配置
     * @dev 仅由 EchoCore 调用
     */
    function onAssetMinted(
        uint256 assetId,
        RightsBundle calldata initialRights
    ) external;
    
    /**
     * @notice EchoCore 回调：资产转移时更新权利
     * @param assetId 资产ID
     * @param previousOwner 原所有者
     * @param newOwner 新所有者
     * @dev 仅由 EchoCore 调用
     */
    function onAssetTransferred(
        uint256 assetId,
        address previousOwner,
        address newOwner
    ) external;
    
    /**
     * @notice EchoCore 回调：资产销毁时清理权利
     * @param assetId 资产ID
     * @dev 仅由 EchoCore 调用
     */
    function onAssetBurned(uint256 assetId) external;
    
    /**
     * @notice 验证权利配置(供外部合约调用)
     * @param assetId 资产ID
     * @param requiredRights 要求的权利配置
     * @return isSatisfied 是否满足要求
     */
    function verifyRightsRequirements(
        uint256 assetId,
        RightsRequirements calldata requiredRights
    ) external view returns (bool isSatisfied);
    
    //////////////////////////////////////////////////////////////
    // 数据结构
    //////////////////////////////////////////////////////////////
    
    struct RightsSummary {
        uint256 assetId;
        bool useActive;
        bool derActive;
        bool extActive;
        bool revActive;
        uint256 totalLicensesGranted;
        uint256 totalUsageCount;
        uint256 derivativeCount;
        uint256 totalRevenue;
        uint64 lastUpdated;
        bool isLocked;
    }
    
    struct RightsRequirements {
        bool requireUse;
        bool requireDer;
        bool requireExt;
        bool requireRev;
        uint256 minUpstreamShare;
        uint256 maxPrice;
        uint8 allowedScope;
    }
    
    //////////////////////////////////////////////////////////////
    // 事件
    //////////////////////////////////////////////////////////////
    
    event RightsConfigured(uint256 indexed assetId, bytes32 indexed configHash);
    event RightsUpdated(uint256 indexed assetId, bytes32 indexed oldHash, bytes32 indexed newHash);
    event RightsLocked(uint256 indexed assetId, uint64 lockedUntil);
    event RightsUnlocked(uint256 indexed assetId);
    event AssetRightsCleared(uint256 indexed assetId);
}
```

### 8.2 主合约实现

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title RightsRegistry
 * @notice ECHO Protocol Layer 0 - Rights Registry Contract
 * @dev 四维权利模型的核心实现，管理数字资产的完整权利生命周期
 */
contract RightsRegistry is 
    IRightsRegistry, 
    AccessControl, 
    ReentrancyGuard, 
    Pausable 
{
    
    //////////////////////////////////////////////////////////////
    // 状态变量
    //////////////////////////////////////////////////////////////
    
    IEchoCore public echoCore;
    ILicenseManager public licenseManager;
    IRightsInheritance public rightsInheritance;
    IConflictDetector public conflictDetector;
    
    bytes32 public constant RIGHTS_ADMIN = keccak256("RIGHTS_ADMIN");
    bytes32 public constant ECHO_CORE_ROLE = keccak256("ECHO_CORE_ROLE");
    
    // 资产ID -> 权利配置
    mapping(uint256 => RightsBundle) private _assetRights;
    
    // 资产ID -> 权利历史
    mapping(uint256 => RightsHistoryEntry[]) private _rightsHistory;
    
    // 配置哈希 -> 资产列表
    mapping(bytes32 => uint256[]) private _configAssets;
    
    // 资产ID -> 锁定信息
    mapping(uint256 => LockInfo) private _lockInfo;
    
    // 全局配置版本计数器
    uint256 private _globalConfigVersion;
    
    //////////////////////////////////////////////////////////////
    // 结构定义
    //////////////////////////////////////////////////////////////
    
    struct RightsHistoryEntry {
        bytes32 configHash;
        uint64 timestamp;
        address updatedBy;
        string reason;
    }
    
    struct LockInfo {
        bool isLocked;
        uint64 lockedUntil;
        address lockedBy;
        bytes32 lockReason;
    }
    
    //////////////////////////////////////////////////////////////
    // 修饰符
    //////////////////////////////////////////////////////////////
    
    modifier onlyAssetOwner(uint256 assetId) {
        require(
            echoCore.ownerOf(assetId) == msg.sender,
            "RightsRegistry: not asset owner"
        );
        _;
    }
    
    modifier onlyEchoCore() {
        require(
            hasRole(ECHO_CORE_ROLE, msg.sender),
            "RightsRegistry: only EchoCore can call"
        );
        _;
    }
    
    modifier whenNotLocked(uint256 assetId) {
        require(
            !_lockInfo[assetId].isLocked || 
            block.timestamp > _lockInfo[assetId].lockedUntil,
            "RightsRegistry: rights are locked"
        );
        _;
    }
    
    modifier validAsset(uint256 assetId) {
        require(
            echoCore.exists(assetId),
            "RightsRegistry: asset does not exist"
        );
        _;
    }
    
    //////////////////////////////////////////////////////////////
    // 构造函数
    //////////////////////////////////////////////////////////////
    
    constructor(
        address echoCoreAddress,
        address licenseManagerAddress,
        address rightsInheritanceAddress,
        address conflictDetectorAddress
    ) {
        echoCore = IEchoCore(echoCoreAddress);
        licenseManager = ILicenseManager(licenseManagerAddress);
        rightsInheritance = IRightsInheritance(rightsInheritanceAddress);
        conflictDetector = IConflictDetector(conflictDetectorAddress);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RIGHTS_ADMIN, msg.sender);
        _grantRole(ECHO_CORE_ROLE, echoCoreAddress);
        
        _globalConfigVersion = 1;
    }
    
    //////////////////////////////////////////////////////////////
    // 核心功能
    //////////////////////////////////////////////////////////////
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function configureRights(
        uint256 assetId,
        RightsBundle calldata rights
    ) 
        external 
        override
        onlyAssetOwner(assetId)
        whenNotLocked(assetId)
        whenNotPaused
    {
        _configureRightsInternal(assetId, rights, "manual update");
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function batchConfigureRights(
        uint256[] calldata assetIds,
        RightsBundle[] calldata rightsArray
    ) 
        external
        override
        whenNotPaused
    {
        require(
            assetIds.length == rightsArray.length,
            "RightsRegistry: array length mismatch"
        );
        require(
            assetIds.length <= 50,
            "RightsRegistry: batch size exceeds limit"
        );
        
        for (uint256 i = 0; i < assetIds.length; i++) {
            require(
                echoCore.ownerOf(assetIds[i]) == msg.sender,
                "RightsRegistry: not owner of all assets"
            );
            require(
                !_lockInfo[assetIds[i]].isLocked ||
                block.timestamp > _lockInfo[assetIds[i]].lockedUntil,
                "RightsRegistry: some assets are locked"
            );
        }
        
        for (uint256 i = 0; i < assetIds.length; i++) {
            _configureRightsInternal(assetIds[i], rightsArray[i], "batch update");
        }
    }
    
    /**
     * @dev 内部配置函数
     */
    function _configureRightsInternal(
        uint256 assetId,
        RightsBundle calldata rights,
        string memory reason
    ) internal {
        // 冲突预检查
        (bool hasConflict, IConflictDetector.ConflictPreview[] memory conflicts) = 
            conflictDetector.preCheckConflicts(assetId, rights);
        
        // 记录严重冲突但允许配置(发出警告)
        if (hasConflict) {
            for (uint256 i = 0; i < conflicts.length; i++) {
                if (conflicts[i].severity >= 4) {
                    emit HighSeverityConflictDetected(
                        assetId,
                        conflicts[i].conflictType,
                        conflicts[i].description
                    );
                }
            }
        }
        
        // 计算配置哈希
        bytes32 oldConfigHash = _assetRights[assetId].configHash;
        bytes32 newConfigHash = keccak256(abi.encode(rights));
        
        // 保存历史
        _rightsHistory[assetId].push(RightsHistoryEntry({
            configHash: oldConfigHash,
            timestamp: uint64(block.timestamp),
            updatedBy: msg.sender,
            reason: reason
        }));
        
        // 更新配置
        RightsBundle memory newRights = rights;
        newRights.configHash = newConfigHash;
        newRights.updatedAt = block.timestamp;
        newRights.configuredBy = msg.sender;
        newRights.version = _globalConfigVersion++;
        newRights.previousConfig = oldConfigHash;
        
        _assetRights[assetId] = newRights;
        
        // 更新索引
        _configAssets[newConfigHash].push(assetId);
        
        // 触发事件
        if (oldConfigHash == bytes32(0)) {
            emit RightsConfigured(assetId, newConfigHash);
        } else {
            emit RightsUpdated(assetId, oldConfigHash, newConfigHash);
        }
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function getRights(uint256 assetId)
        external
        view
        override
        validAsset(assetId)
        returns (RightsBundle memory)
    {
        return _assetRights[assetId];
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function isRightActive(uint256 assetId, RightType rightType)
        external
        view
        override
        validAsset(assetId)
        returns (bool)
    {
        RightsBundle memory rights = _assetRights[assetId];
        
        if (rightType == RightType.USE) return rights.use.isActive;
        if (rightType == RightType.DER) return rights.der.isActive;
        if (rightType == RightType.EXT) return rights.ext.isActive;
        if (rightType == RightType.REV) return rights.rev.isActive;
        
        return false;
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function updateRight(
        uint256 assetId,
        RightType rightType,
        bytes calldata newConfig
    ) 
        external
        override
        onlyAssetOwner(assetId)
        whenNotLocked(assetId)
        whenNotPaused
    {
        RightsBundle storage rights = _assetRights[assetId];
        
        if (rightType == RightType.USE) {
            rights.use = abi.decode(newConfig, (UseRight));
        } else if (rightType == RightType.DER) {
            rights.der = abi.decode(newConfig, (DerRight));
        } else if (rightType == RightType.EXT) {
            rights.ext = abi.decode(newConfig, (ExtRight));
        } else if (rightType == RightType.REV) {
            rights.rev = abi.decode(newConfig, (RevRight));
        }
        
        // 更新哈希和版本
        rights.configHash = keccak256(abi.encode(rights));
        rights.updatedAt = block.timestamp;
        rights.version = _globalConfigVersion++;
        
        emit RightUpdated(assetId, rightType, msg.sender);
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function lockRights(uint256 assetId, uint64 lockDuration)
        external
        override
        onlyAssetOwner(assetId)
    {
        uint64 lockedUntil = lockDuration == 0 ? type(uint64).max : uint64(block.timestamp) + lockDuration;
        
        _lockInfo[assetId] = LockInfo({
            isLocked: true,
            lockedUntil: lockedUntil,
            lockedBy: msg.sender,
            lockReason: keccak256("user locked")
        });
        
        _assetRights[assetId].isLocked = true;
        
        emit RightsLocked(assetId, lockedUntil);
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function unlockRights(uint256 assetId) external override {
        LockInfo storage lock = _lockInfo[assetId];
        
        require(lock.isLocked, "RightsRegistry: not locked");
        require(
            msg.sender == lock.lockedBy ||
            msg.sender == echoCore.ownerOf(assetId) ||
            hasRole(RIGHTS_ADMIN, msg.sender),
            "RightsRegistry: not authorized to unlock"
        );
        require(
            block.timestamp > lock.lockedUntil ||
            msg.sender == lock.lockedBy ||
            hasRole(RIGHTS_ADMIN, msg.sender),
            "RightsRegistry: lock period not expired"
        );
        
        lock.isLocked = false;
        _assetRights[assetId].isLocked = false;
        
        emit RightsUnlocked(assetId);
    }
    
    //////////////////////////////////////////////////////////////
    // EchoCore 集成回调
    //////////////////////////////////////////////////////////////
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function onAssetMinted(
        uint256 assetId,
        RightsBundle calldata initialRights
    ) 
        external
        override
        onlyEchoCore
    {
        RightsBundle memory rights = initialRights;
        rights.configHash = keccak256(abi.encode(initialRights));
        rights.createdAt = block.timestamp;
        rights.updatedAt = block.timestamp;
        rights.configuredBy = echoCore.ownerOf(assetId);
        rights.version = _globalConfigVersion++;
        
        _assetRights[assetId] = rights;
        
        emit RightsConfigured(assetId, rights.configHash);
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function onAssetTransferred(
        uint256 assetId,
        address previousOwner,
        address newOwner
    ) 
        external
        override
        onlyEchoCore
    {
        // 更新配置记录
        RightsBundle storage rights = _assetRights[assetId];
        rights.configuredBy = newOwner;
        rights.updatedAt = block.timestamp;
        
        // 发出权利转移通知(子合约处理具体的权利转移逻辑)
        emit RightsTransferred(assetId, previousOwner, newOwner);
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function onAssetBurned(uint256 assetId) external override onlyEchoCore {
        // 清理权利配置
        delete _assetRights[assetId];
        delete _lockInfo[assetId];
        
        // 保留历史记录供审计
        
        emit AssetRightsCleared(assetId);
    }
    
    //////////////////////////////////////////////////////////////
    // 查询函数
    //////////////////////////////////////////////////////////////
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function getRightsHistory(uint256 assetId)
        external
        view
        override
        returns (bytes32[] memory configHashes, uint64[] memory timestamps)
    {
        RightsHistoryEntry[] storage history = _rightsHistory[assetId];
        uint256 length = history.length;
        
        configHashes = new bytes32[](length);
        timestamps = new uint64[](length);
        
        for (uint256 i = 0; i < length; i++) {
            configHashes[i] = history[i].configHash;
            timestamps[i] = history[i].timestamp;
        }
        
        return (configHashes, timestamps);
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function getRightsSummary(uint256 assetId)
        external
        view
        override
        validAsset(assetId)
        returns (RightsSummary memory summary)
    {
        RightsBundle memory rights = _assetRights[assetId];
        LockInfo memory lock = _lockInfo[assetId];
        
        summary = RightsSummary({
            assetId: assetId,
            useActive: rights.use.isActive,
            derActive: rights.der.isActive,
            extActive: rights.ext.isActive,
            revActive: rights.rev.isActive,
            totalLicensesGranted: 0, // 需从 LicenseManager 查询
            totalUsageCount: rights.use.usedCount,
            derivativeCount: rights.der.derivativeCount,
            totalRevenue: rights.rev.totalRevenue,
            lastUpdated: uint64(rights.updatedAt),
            isLocked: lock.isLocked && block.timestamp <= lock.lockedUntil
        });
        
        return summary;
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function batchGetRights(uint256[] calldata assetIds)
        external
        view
        override
        returns (RightsBundle[] memory rightsArray)
    {
        rightsArray = new RightsBundle[](assetIds.length);
        
        for (uint256 i = 0; i < assetIds.length; i++) {
            if (echoCore.exists(assetIds[i])) {
                rightsArray[i] = _assetRights[assetIds[i]];
            }
        }
        
        return rightsArray;
    }
    
    /**
     * @inheritdoc IRightsRegistry
     */
    function verifyRightsRequirements(
        uint256 assetId,
        RightsRequirements calldata requiredRights
    ) 
        external
        view
        override
        returns (bool)
    {
        RightsBundle memory rights = _assetRights[assetId];
        
        if (requiredRights.requireUse && !rights.use.isActive) return false;
        if (requiredRights.requireDer && !rights.der.isActive) return false;
        if (requiredRights.requireExt && !rights.ext.isActive) return false;
        if (requiredRights.requireRev && !rights.rev.isActive) return false;
        
        if (rights.der.upstreamShareBps < requiredRights.minUpstreamShare) return false;
        if (rights.use.basePrice > requiredRights.maxPrice) return false;
        if ((rights.use.usageScope & requiredRights.allowedScope) == 0) return false;
        
        return true;
    }
    
    //////////////////////////////////////////////////////////////
    // 事件定义
    //////////////////////////////////////////////////////////////
    
    event RightsConfigured(uint256 indexed assetId, bytes32 indexed configHash);
    event RightsUpdated(uint256 indexed assetId, bytes32 indexed oldHash, bytes32 indexed newHash);
    event RightsLocked(uint256 indexed assetId, uint64 lockedUntil);
    event RightsUnlocked(uint256 indexed assetId);
    event AssetRightsCleared(uint256 indexed assetId);
    event RightsTransferred(uint256 indexed assetId, address indexed from, address indexed to);
    event RightUpdated(uint256 indexed assetId, RightType rightType, address indexed updater);
    event HighSeverityConflictDetected(
        uint256 indexed assetId,
        IConflictDetector.ConflictType conflictType,
        bytes32 description
    );
    
    //////////////////////////////////////////////////////////////
    // 管理函数
    //////////////////////////////////////////////////////////////
    
    /**
     * @notice 设置依赖合约地址
     */
    function setLicenseManager(address newLicenseManager)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        licenseManager = ILicenseManager(newLicenseManager);
    }
    
    /**
     * @notice 设置权利继承合约
     */
    function setRightsInheritance(address newRightsInheritance)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        rightsInheritance = IRightsInheritance(newRightsInheritance);
    }
    
    /**
     * @notice 设置冲突检测合约
     */
    function setConflictDetector(address newConflictDetector)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        conflictDetector = IConflictDetector(newConflictDetector);
    }
    
    /**
     * @notice 紧急暂停
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice 恢复
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
```

---

## 9. 合约部署与升级策略

### 9.1 部署架构

```solidity
/**
 * @title RightsRegistryFactory
 * @notice 权利注册合约工厂
 * @dev 管理合约部署和初始化
 */
contract RightsRegistryFactory {
    
    // 已部署的核心合约实例
    address public rightsRegistry;
    address public licenseManager;
    address public rightsInheritance;
    address public conflictDetector;
    address public rightsIndexer;
    address public rightsSecurity;
    
    // 代理合约地址
    address public rightsRegistryProxy;
    
    /**
     * @notice 部署完整的权利系统
     * @param echoCore EchoCore 合约地址
     */
    function deployRightsSystem(address echoCore) external returns (address) {
        // 1. 部署实现合约
        rightsRegistry = address(new RightsRegistry());
        licenseManager = address(new LicenseManager());
        rightsInheritance = address(new RightsInheritance());
        conflictDetector = address(new ConflictDetector());
        rightsIndexer = address(new RightsIndexer());
        rightsSecurity = address(new RightsSecurity());
        
        // 2. 部署代理合约
        bytes memory initData = abi.encodeWithSelector(
            RightsRegistry.initialize.selector,
            echoCore,
            licenseManager,
            rightsInheritance,
            conflictDetector
        );
        
        rightsRegistryProxy = address(new ERC1967Proxy(rightsRegistry, initData));
        
        // 3. 初始化其他合约
        LicenseManager(licenseManager).initialize(
            echoCore,
            rightsRegistryProxy
        );
        
        RightsInheritance(rightsInheritance).initialize(
            rightsRegistryProxy,
            licenseManager
        );
        
        ConflictDetector(conflictDetector).initialize(
            rightsRegistryProxy,
            rightsInheritance
        );
        
        // 4. 配置权限
        _configurePermissions();
        
        return rightsRegistryProxy;
    }
    
    /**
     * @notice 升级 RightsRegistry 实现
     */
    function upgradeRightsRegistry(address newImplementation)
        external
        onlyOwner
    {
        RightsRegistry(payable(rightsRegistryProxy)).upgradeTo(newImplementation);
    }
    
    function _configurePermissions() internal {
        // 配置合约间调用权限
        // 配置管理员角色
        // 配置暂停权限
    }
}
```

---

## 10. Gas 优化总结

### 10.1 优化策略

| 优化策略 | 实现方式 | Gas节省 |
|---------|---------|---------|
| 紧凑存储 | struct 字段按大小排序，使用位图 | 20-30% |
| 冷热分离 | 热数据连续存储，冷数据分散 | 15-25% |
| 批量操作 | 循环批量处理，减少重复检查 | 30-40% |
| 延迟计算 | 需要时才计算，缓存结果 | 10-20% |
| 事件日志 | 复杂数据通过事件存储，链上存哈希 | 25-35% |
| 默克尔树 | 多级分润使用默克尔树验证 | 40-50% |
| 压缩编码 | 配置数据 ABI 编码后存储 | 10-15% |

### 10.2 存储布局图

```
Slot 0-5:   热存储 - 核心权利配置 (RightsBundle)
Slot 6-10:  热存储 - 活跃授权列表
Slot 11-20: 温存储 - 依赖图边信息
Slot 21-30: 温存储 - 冲突记录
Slot 31+:   冷存储 - 历史记录、扩展配置
```

---

## 附录: 完整接口汇总

### A.1 对外接口

```solidity
// 权利配置
configureRights(uint256, RightsBundle)
batchConfigureRights(uint256[], RightsBundle[])
getRights(uint256) -> RightsBundle
updateRight(uint256, RightType, bytes)
lockRights(uint256, uint64)
unlockRights(uint256)

// 授权管理
grantUseLicense(uint256, address, UsageScope, uint64, uint88) -> uint256
grantDerLicense(uint256, address, uint8, uint16, uint8) -> uint256
grantExtLicense(uint256, address, uint8, SecurityLevel, RateLimitConfig) -> uint256
verifyLicense(uint256) -> bool
checkAndRecordUsage(uint256, address, uint8) -> (bool, uint256)
revokeLicense(uint256, uint8)

// 继承管理
registerDerivation(uint256, uint256, DependencyType, uint16)
calculateInheritedRights(uint256) -> (UseRight, DerRight, ExtRight, RevRight)
calculateUpstreamSplits(uint256, uint256) -> (address[], uint256[])

// 冲突检测
preCheckConflicts(uint256, RightsBundle) -> (bool, ConflictPreview[])
detectConflictsBetween(uint256, uint256) -> ConflictRecord[]
checkLicenseConflict(LicenseRequest) -> (bool, ConflictPreview[])
autoResolveConflicts(uint256[]) -> uint256
```

### A.2 事件列表

```solidity
RightsConfigured, RightsUpdated, RightsLocked, RightsUnlocked
LicenseGranted, LicenseRevoked, LicenseExpired, LicenseUsage
DerivationRegistered, RightsInherited, UpstreamSplitCalculated
ConflictDetected, ConflictResolved, ConflictWarning
```

---

**文档结束**

> **参考文档**:
> - ECHO-Five-Layers-Details.md
> - ECHO-Panorama-v2.md
> - ECHO-PRD-v1.0.md
> - OpenZeppelin Contracts
> - EIP-721, EIP-1155, EIP-1967
