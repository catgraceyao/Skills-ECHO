# ECHO 智能合约伪代码

## Solidity 合约设计文档

> 版本: v1.0  
> 基于 ECHO 势架构协议

---

## 目录

1. [合约架构总览](#一合约架构总览)
2. [势枢合约 ShiShu](#二势枢合约-shishusol)
3. [势场合约 ShiChang](#三势场合约-shichangsol)
4. [势位合约 ShiWei](#四势位合约-shiweisol)
5. [资产注册合约 AssetRegistry](#五资产注册合约-assetregistrysol)
6. [权利管理合约 RightsManager](#六权利管理合约-rightsmanagersol)
7. [收益分配合约 RevenueDistributor](#七收益分配合约-revenuedistributorsol)
8. [血缘追踪合约 LineageTracker](#八血缘追踪合约-lineagetrackersol)
9. [Agent调度合约 AgentScheduler](#九agent调度合约-agentschedulersol)

---

## 一、合约架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│                      ECHO 合约架构                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │
│   │  AssetRegistry│   │ RightsManager │   │LineageTracker│       │
│   │   资产注册    │    │   权利管理    │    │   血缘追踪    │       │
│   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘       │
│          │                   │                   │              │
│   ┌──────▼───────────────────▼───────────────────▼──────┐      │
│   │              RevenueDistributor                     │      │
│   │                  收益分配                           │      │
│   └────────────────────────┬───────────────────────────┘      │
│                            │                                   │
│   ┌────────────────────────▼───────────────────────────┐      │
│   │                    ShiShu                          │      │
│   │                  势枢核心                          │      │
│   │   ┌──────────┐   ┌──────────┐   ┌──────────┐      │      │
│   │   │   时间    │   │   空间    │   │   关系    │      │      │
│   │   └──────────┘   └──────────┘   └──────────┘      │      │
│   └────────────────────────┬───────────────────────────┘      │
│                            │                                   │
│   ┌────────────────────────▼───────────────────────────┐      │
│   │                   ShiChang                         │      │
│   │                  64卦聚类                          │      │
│   └────────────────────────┬───────────────────────────┘      │
│                            │                                   │
│   ┌────────────────────────▼───────────────────────────┐      │
│   │                   ShiWei                           │      │
│   │                  六爻坐标                          │      │
│   └────────────────────────────────────────────────────┘      │
│                                                                 │
│   ┌────────────────────────────────────────────────────┐      │
│   │                AgentScheduler                      │      │
│   │                  Agent调度                         │      │
│   └────────────────────────────────────────────────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 合约交互关系

```
用户铸造资产:
User → AssetRegistry.mint() 
       → RightsManager.validatePowers()
       → ShiShu.initializeDimensions()
       → ShiChang.generateGua()
       → ShiWei.calculateInitialPosition()

用户使用资产:
User → RightsManager.checkPermission()
       → RevenueDistributor.processPayment()
       → LineageTracker.recordUsage()
       → ShiWei.updatePosition()
       → AgentScheduler.triggerAgent()
```

---

## 二、势枢合约 ShiShu.sol

### 合约概述

**职责**: 管理资产的三维编织系统（时间/空间/关系）

### 数据结构

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ShiShu {
    
    // ============ 结构体定义 ============
    
    /// @notice 时间维度
    struct TimeDimension {
        uint256 created;           // 创建时间戳
        uint256 age;              // 生命周期（天）
        uint256 lastActive;       // 最后活跃时间
        uint256 activeRhythm;     // 活跃节奏（每天交互次数）
        uint256 seasonality;      // 季节系数（0-100）
    }
    
    /// @notice 空间维度
    struct SpaceDimension {
        string[] platforms;        // 所在平台列表
        string[] geography;        // 地理覆盖区域
        string[] channels;         // 传播渠道
        uint256 globalReach;       // 全球覆盖指数（0-100）
    }
    
    /// @notice 关系维度
    struct RelationDimension {
        bytes32[] upstream;        // 上游引用（被引用）
        bytes32[] downstream;      // 下游衍生（引用本资产）
        bytes32[] peers;           // 同类作品
        address[] collectors;      // 收藏者地址
        uint256 networkDensity;    // 网络密度（0-100）
    }
    
    /// @notice 三维坐标
    struct ShiShuCoordinate {
        TimeDimension time;
        SpaceDimension space;
        RelationDimension relation;
        uint256 lastUpdated;       // 最后更新时间
    }
    
    // ============ 状态变量 ============
    
    /// @notice 资产ID到三维坐标的映射
    mapping(bytes32 => ShiShuCoordinate) public coordinates;
    
    /// @notice 授权合约列表
    mapping(address => bool) public authorizedContracts;
    
    /// @notice 合约所有者
    address public owner;
    
    // ============ 事件定义 ============
    
    event CoordinateInitialized(
        bytes32 indexed assetId,
        uint256 timestamp
    );
    
    event TimeDimensionUpdated(
        bytes32 indexed assetId,
        uint256 age,
        uint256 rhythm
    );
    
    event SpaceDimensionUpdated(
        bytes32 indexed assetId,
        string[] platforms,
        uint256 globalReach
    );
    
    event RelationDimensionUpdated(
        bytes32 indexed assetId,
        uint256 upstreamCount,
        uint256 downstreamCount
    );
    
    // ============ 修饰器 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized");
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor() {
        owner = msg.sender;
    }
    
    // ============ 核心函数 ============
    
    /// @notice 初始化资产的三维坐标
    /// @param assetId 资产唯一标识
    function initializeCoordinate(bytes32 assetId) external onlyAuthorized {
        require(coordinates[assetId].lastUpdated == 0, "Already initialized");
        
        ShiShuCoordinate storage coord = coordinates[assetId];
        
        // 初始化时间维度
        coord.time.created = block.timestamp;
        coord.time.age = 0;
        coord.time.lastActive = block.timestamp;
        coord.time.activeRhythm = 0;
        coord.time.seasonality = calculateSeasonality();
        
        // 初始化空间维度
        coord.space.platforms.push("ECHO");
        coord.space.globalReach = 0;
        
        // 初始化关系维度
        coord.relation.networkDensity = 0;
        
        coord.lastUpdated = block.timestamp;
        
        emit CoordinateInitialized(assetId, block.timestamp);
    }
    
    /// @notice 更新时间维度
    /// @param assetId 资产ID
    function updateTimeDimension(bytes32 assetId) external onlyAuthorized {
        ShiShuCoordinate storage coord = coordinates[assetId];
        require(coord.lastUpdated > 0, "Coordinate not initialized");
        
        TimeDimension storage time = coord.time;
        
        // 计算生命周期
        time.age = (block.timestamp - time.created) / 1 days;
        
        // 更新活跃节奏
        uint256 timeSinceLastActive = block.timestamp - time.lastActive;
        if (timeSinceLastActive < 1 days) {
            time.activeRhythm++;
        } else {
            time.activeRhythm = time.activeRhythm > 0 ? time.activeRhythm - 1 : 0;
        }
        
        time.lastActive = block.timestamp;
        time.seasonality = calculateSeasonality();
        
        coord.lastUpdated = block.timestamp;
        
        emit TimeDimensionUpdated(assetId, time.age, time.activeRhythm);
    }
    
    /// @notice 更新空间维度
    /// @param assetId 资产ID
    /// @param platform 新增平台
    /// @param region 新增地理区域
    function updateSpaceDimension(
        bytes32 assetId,
        string calldata platform,
        string calldata region
    ) external onlyAuthorized {
        ShiShuCoordinate storage coord = coordinates[assetId];
        
        // 添加新平台（如果不存在）
        bool platformExists = false;
        for (uint i = 0; i < coord.space.platforms.length; i++) {
            if (keccak256(bytes(coord.space.platforms[i])) == keccak256(bytes(platform))) {
                platformExists = true;
                break;
            }
        }
        if (!platformExists) {
            coord.space.platforms.push(platform);
        }
        
        // 添加新地理区域
        bool regionExists = false;
        for (uint i = 0; i < coord.space.geography.length; i++) {
            if (keccak256(bytes(coord.space.geography[i])) == keccak256(bytes(region))) {
                regionExists = true;
                break;
            }
        }
        if (!regionExists) {
            coord.space.geography.push(region);
        }
        
        // 计算全球覆盖指数
        coord.space.globalReach = calculateGlobalReach(coord.space.geography.length);
        
        coord.lastUpdated = block.timestamp;
        
        emit SpaceDimensionUpdated(assetId, coord.space.platforms, coord.space.globalReach);
    }
    
    /// @notice 添加关系连接
    /// @param fromAsset 源资产（引用者）
    /// @param toAsset 目标资产（被引用者）
    function addRelation(
        bytes32 fromAsset,
        bytes32 toAsset
    ) external onlyAuthorized {
        require(fromAsset != toAsset, "Cannot relate to self");
        
        ShiShuCoordinate storage fromCoord = coordinates[fromAsset];
        ShiShuCoordinate storage toCoord = coordinates[toAsset];
        
        // 添加下游关系（from引用了to）
        fromCoord.relation.upstream.push(toAsset);
        
        // 添加上游关系（to被from引用）
        toCoord.relation.downstream.push(fromAsset);
        
        // 更新网络密度
        fromCoord.relation.networkDensity = calculateNetworkDensity(fromCoord.relation);
        toCoord.relation.networkDensity = calculateNetworkDensity(toCoord.relation);
        
        fromCoord.lastUpdated = block.timestamp;
        toCoord.lastUpdated = block.timestamp;
        
        emit RelationDimensionUpdated(
            fromAsset,
            fromCoord.relation.upstream.length,
            fromCoord.relation.downstream.length
        );
    }
    
    /// @notice 获取完整三维坐标
    function getCoordinate(bytes32 assetId) external view returns (ShiShuCoordinate memory) {
        return coordinates[assetId];
    }
    
    /// @notice 计算季节系数
    function calculateSeasonality() internal view returns (uint256) {
        // 基于当前月份计算（简化实现）
        uint256 month = (block.timestamp / 30 days) % 12;
        // 春季(3-5月)和秋季(9-11月)为旺季
        if ((month >= 2 && month <= 4) || (month >= 8 && month <= 10)) {
            return 80;
        }
        return 50;
    }
    
    /// @notice 计算全球覆盖指数
    function calculateGlobalReach(uint256 regionCount) internal pure returns (uint256) {
        // 简化的线性计算
        return regionCount * 10 > 100 ? 100 : regionCount * 10;
    }
    
    /// @notice 计算网络密度
    function calculateNetworkDensity(
        RelationDimension storage relation
    ) internal view returns (uint256) {
        uint256 total = relation.upstream.length + relation.downstream.length;
        // 简化的密度计算
        return total > 10 ? 100 : total * 10;
    }
    
    // ============ 管理函数 ============
    
    function authorizeContract(address contractAddress) external onlyOwner {
        authorizedContracts[contractAddress] = true;
    }
    
    function revokeContract(address contractAddress) external onlyOwner {
        authorizedContracts[contractAddress] = false;
    }
}
```

---

## 三、势场合约 ShiChang.sol

### 合约概述

**职责**: 64卦聚类系统，管理四权力到卦象的映射

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ShiChang {
    
    // ============ 结构体定义 ============
    
    /// @notice 八卦定义
    struct BaGua {
        string symbol;      // 卦符（如 ☰）
        string name;        // 卦名（如 乾）
        string element;     // 五行属性
        uint8 value;        // 数值（1-8）
    }
    
    /// @notice 64卦定义
    struct LiuShiSiGua {
        string symbol;      // 卦象符号
        string name;        // 卦名
        string shangGua;    // 上卦名称
        string xiaGua;      // 下卦名称
        string meaning;     // 卦辞含义
        string advice;      // 行动建议
    }
    
    /// @notice 四权力配置
    struct PowerConfig {
        uint8 usePower;      // 用权 1-8
        uint8 spreadPower;   // 扩权 1-8
        uint8 derivePower;   // 衍权 1-8
        uint8 profitPower;   // 益权 1-8
    }
    
    // ============ 状态变量 ============
    
    /// @notice 八卦映射（1-8）
    mapping(uint8 => BaGua) public baGuaMap;
    
    /// @notice 64卦映射（通过组合索引）
    mapping(uint8 => mapping(uint8 => LiuShiSiGua)) public guaXiangMap;
    
    /// @notice 资产当前卦象
    mapping(bytes32 => LiuShiSiGua) public assetGuaXiang;
    
    /// @notice 资产四权力配置
    mapping(bytes32 => PowerConfig) public assetPowers;
    
    address public owner;
    mapping(address => bool) public authorizedContracts;
    
    // ============ 事件定义 ============
    
    event GuaXiangGenerated(
        bytes32 indexed assetId,
        string guaName,
        string symbol
    );
    
    event PowersConfigured(
        bytes32 indexed assetId,
        uint8 usePower,
        uint8 spreadPower,
        uint8 derivePower,
        uint8 profitPower
    );
    
    // ============ 构造函数 ============
    
    constructor() {
        owner = msg.sender;
        initializeBaGua();
        initializeLiuShiSiGua();
    }
    
    // ============ 初始化函数 ============
    
    /// @notice 初始化八卦
    function initializeBaGua() internal {
        baGuaMap[1] = BaGua("☷", "坤", "地", 1);
        baGuaMap[2] = BaGua("☶", "艮", "山", 2);
        baGuaMap[3] = BaGua("☵", "坎", "水", 3);
        baGuaMap[4] = BaGua("☴", "巽", "风", 4);
        baGuaMap[5] = BaGua("☳", "震", "雷", 5);
        baGuaMap[6] = BaGua("☲", "离", "火", 6);
        baGuaMap[7] = BaGua("☱", "兑", "泽", 7);
        baGuaMap[8] = BaGua("☰", "乾", "天", 8);
    }
    
    /// @notice 初始化64卦（简化示例，实际应包含全部64卦）
    function initializeLiuShiSiGua() internal {
        // 乾卦（上乾下乾）
        guaXiangMap[8][8] = LiuShiSiGua(
            "䷀",
            "乾",
            "乾",
            "乾",
            "天行健，君子以自强不息",
            "盛势之时，宜进不宜退"
        );
        
        // 坤卦（上坤下坤）
        guaXiangMap[1][1] = LiuShiSiGua(
            "䷁",
            "坤",
            "坤",
            "坤",
            "地势坤，君子以厚德载物",
            "内守待时，蓄势待发"
        );
        
        // 泰卦（上坤下乾）- 完全开放
        guaXiangMap[1][8] = LiuShiSiGua(
            "䷊",
            "泰",
            "坤",
            "乾",
            "天地交泰，小往大来",
            "天地交合，宜广结善缘"
        );
        
        // 否卦（上乾下坤）- 封闭
        guaXiangMap[8][1] = LiuShiSiGua(
            "䷋",
            "否",
            "乾",
            "坤",
            "天地不交，闭塞不通",
            "宜守不宜攻，内修外治"
        );
        
        // 可以继续添加其他60卦...
    }
    
    // ============ 核心函数 ============
    
    /// @notice 配置资产四权力并生成卦象
    function configurePowers(
        bytes32 assetId,
        uint8 usePower,
        uint8 spreadPower,
        uint8 derivePower,
        uint8 profitPower
    ) external onlyAuthorized {
        require(usePower >= 1 && usePower <= 8, "Invalid use power");
        require(spreadPower >= 1 && spreadPower <= 8, "Invalid spread power");
        require(derivePower >= 1 && derivePower <= 8, "Invalid derive power");
        require(profitPower >= 1 && profitPower <= 8, "Invalid profit power");
        
        // 存储四权力配置
        assetPowers[assetId] = PowerConfig(
            usePower,
            spreadPower,
            derivePower,
            profitPower
        );
        
        // 生成卦象（基于用权和扩权）
        LiuShiSiGua memory gua = generateGuaXiang(usePower, spreadPower);
        assetGuaXiang[assetId] = gua;
        
        emit PowersConfigured(assetId, usePower, spreadPower, derivePower, profitPower);
        emit GuaXiangGenerated(assetId, gua.name, gua.symbol);
    }
    
    /// @notice 生成卦象
    function generateGuaXiang(
        uint8 usePower,
        uint8 spreadPower
    ) internal view returns (LiuShiSiGua memory) {
        // 默认返回否卦（如果不存在特定组合）
        LiuShiSiGua memory defaultGua = guaXiangMap[8][1];
        
        LiuShiSiGua memory gua = guaXiangMap[usePower][spreadPower];
        
        // 如果该组合未定义，返回默认值
        if (bytes(gua.name).length == 0) {
            return defaultGua;
        }
        
        return gua;
    }
    
    /// @notice 获取资产卦象
    function getGuaXiang(bytes32 assetId) external view returns (LiuShiSiGua memory) {
        return assetGuaXiang[assetId];
    }
    
    /// @notice 获取四权力配置
    function getPowerConfig(bytes32 assetId) external view returns (PowerConfig memory) {
        return assetPowers[assetId];
    }
    
    /// @notice 解析卦象建议
    function parseGuaAdvice(bytes32 assetId) external view returns (string memory) {
        LiuShiSiGua memory gua = assetGuaXiang[assetId];
        return gua.advice;
    }
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }
    
    function authorizeContract(address contractAddress) external {
        require(msg.sender == owner, "Only owner");
        authorizedContracts[contractAddress] = true;
    }
}
```

---

## 四、势位合约 ShiWei.sol

### 合约概述

**职责**: 六爻坐标系统，计算气数和变爻预警

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ShiShu.sol";

contract ShiWei {
    
    // ============ 结构体定义 ============
    
    /// @notice 六爻坐标
    struct LiuYao {
        uint8 shangLiu;     // 上六 - 时位
        uint8 jiuWu;        // 九五 - 空位
        uint8 liuSi;        // 六四 - 人位
        uint8 jiuSan;       // 九三 - 势位
        uint8 liuEr;        // 六二 - 变位
        uint8 chuJiu;       // 初九 - 根位
    }
    
    /// @notice 势位数据
    struct ShiWeiData {
        LiuYao liuYao;              // 六爻坐标
        uint256 qiShu;              // 气数（放大1000倍存储，如0.72存为720）
        uint256 lastCalculated;     // 最后计算时间
        uint8[] dongYaoHistory;     // 变爻历史
    }
    
    /// @notice 变爻预警
    struct BianYaoWarning {
        uint8 yaoPosition;          // 爻位（1-6）
        uint256 currentValue;       // 当前值
        uint256 threshold;          // 临界值
        uint256 estimatedTime;      // 预计变爻时间
        string severity;            // 严重程度：low/medium/high/critical
    }
    
    // ============ 状态变量 ============
    
    /// @notice 资产势位数据
    mapping(bytes32 => ShiWeiData) public shiWeiData;
    
    /// @notice 爻位权重
    uint8[6] public yaoWeights = [15, 20, 20, 20, 15, 10]; // 上六到初九
    
    /// @notice 临界值配置
    uint256 public constant THRESHOLD_HIGH = 850;
    uint256 public constant THRESHOLD_MEDIUM = 650;
    uint256 public constant THRESHOLD_LOW = 400;
    
    ShiShu public shiShu;
    address public owner;
    
    // ============ 事件定义 ============
    
    event ShiWeiCalculated(
        bytes32 indexed assetId,
        uint256 qiShu,
        string qiLevel
    );
    
    event BianYaoWarningGenerated(
        bytes32 indexed assetId,
        uint8 yaoPosition,
        string severity
    );
    
    event DongYaoOccurred(
        bytes32 indexed assetId,
        uint8 yaoPosition,
        uint256 timestamp
    );
    
    // ============ 构造函数 ============
    
    constructor(address _shiShu) {
        owner = msg.sender;
        shiShu = ShiShu(_shiShu);
    }
    
    // ============ 核心函数 ============
    
    /// @notice 计算资产势位
    function calculateShiWei(bytes32 assetId) external {
        // 获取三维坐标
        ShiShu.ShiShuCoordinate memory coord = shiShu.getCoordinate(assetId);
        
        // 计算六爻值
        LiuYao memory liuYao = LiuYao({
            shangLiu: calculateShangLiu(coord.time),
            jiuWu: calculateJiuWu(coord.space),
            liuSi: calculateLiuSi(coord.relation),
            jiuSan: calculateJiuSan(coord),
            liuEr: calculateLiuEr(coord.relation),
            chuJiu: calculateChuJiu(coord.time)
        });
        
        // 计算气数
        uint256 qiShu = calculateQiShu(liuYao);
        
        // 检测变爻
        checkBianYao(assetId, liuYao);
        
        // 存储数据
        ShiWeiData storage data = shiWeiData[assetId];
        data.liuYao = liuYao;
        data.qiShu = qiShu;
        data.lastCalculated = block.timestamp;
        
        emit ShiWeiCalculated(assetId, qiShu, parseQiLevel(qiShu));
    }
    
    /// @notice 计算上六（时位）
    function calculateShangLiu(
        ShiShu.TimeDimension memory time
    ) internal pure returns (uint8) {
        // 基于生命周期和活跃节奏
        uint256 score = (time.age > 365 ? 100 : time.age * 100 / 365);
        score = score + (time.activeRhythm > 10 ? 100 : time.activeRhythm * 10);
        return uint8(score > 200 ? 200 : score) / 2;
    }
    
    /// @notice 计算九五（空位）
    function calculateJiuWu(
        ShiShu.SpaceDimension memory space
    ) internal pure returns (uint8) {
        return uint8(space.globalReach);
    }
    
    /// @notice 计算六四（人位）
    function calculateLiuSi(
        ShiShu.RelationDimension memory relation
    ) internal pure returns (uint8) {
        return uint8(relation.networkDensity);
    }
    
    /// @notice 计算九三（势位）
    function calculateJiuSan(
        ShiShu.ShiShuCoordinate memory coord
    ) internal pure returns (uint8) {
        // 综合质量评分
        uint256 score = (coord.time.seasonality + 
                        coord.space.globalReach + 
                        coord.relation.networkDensity) / 3;
        return uint8(score);
    }
    
    /// @notice 计算六二（变位）
    function calculateLiuEr(
        ShiShu.RelationDimension memory relation
    ) internal pure returns (uint8) {
        // 基于衍生数量
        uint256 deriveCount = relation.downstream.length;
        return uint8(deriveCount > 10 ? 100 : deriveCount * 10);
    }
    
    /// @notice 计算初九（根位）
    function calculateChuJiu(
        ShiShu.TimeDimension memory time
    ) internal pure returns (uint8) {
        // 基于历史积淀
        uint256 score = time.age > 365 ? 100 : time.age * 100 / 365;
        return uint8(score);
    }
    
    /// @notice 计算气数
    function calculateQiShu(LiuYao memory liuYao) internal view returns (uint256) {
        uint256 weightedSum = 0;
        uint256 maxWeight = 0;
        
        uint8[6] memory yaoValues = [
            liuYao.shangLiu,
            liuYao.jiuWu,
            liuYao.liuSi,
            liuYao.jiuSan,
            liuYao.liuEr,
            liuYao.chuJiu
        ];
        
        for (uint i = 0; i < 6; i++) {
            weightedSum += uint256(yaoValues[i]) * yaoWeights[i];
            maxWeight += 100 * yaoWeights[i];
        }
        
        // 返回放大1000倍的值（0-1000）
        return (weightedSum * 1000) / maxWeight;
    }
    
    /// @notice 检查变爻
    function checkBianYao(bytes32 assetId, LiuYao memory liuYao) internal {
        uint8[6] memory yaoValues = [
            liuYao.shangLiu,
            liuYao.jiuWu,
            liuYao.liuSi,
            liuYao.jiuSan,
            liuYao.liuEr,
            liuYao.chuJiu
        ];
        
        for (uint i = 0; i < 6; i++) {
            string memory severity = "";
            
            if (yaoValues[i] >= 90) {
                severity = "critical";
            } else if (yaoValues[i] >= 80) {
                severity = "high";
            } else if (yaoValues[i] >= 70) {
                severity = "medium";
            } else if (yaoValues[i] <= 20) {
                severity = "low";
            }
            
            if (bytes(severity).length > 0) {
                emit BianYaoWarningGenerated(assetId, uint8(i + 1), severity);
            }
        }
    }
    
    /// @notice 解析气数等级
    function parseQiLevel(uint256 qiShu) internal pure returns (string memory) {
        if (qiShu >= 850) return "凛冽";
        if (qiShu >= 650) return "蓬勃";
        if (qiShu >= 400) return "温润";
        if (qiShu >= 200) return "沉寂";
        return "虚无";
    }
    
    /// @notice 获取势位数据
    function getShiWei(bytes32 assetId) external view returns (ShiWeiData memory) {
        return shiWeiData[assetId];
    }
    
    /// @notice 获取气数
    function getQiShu(bytes32 assetId) external view returns (uint256) {
        return shiWeiData[assetId].qiShu;
    }
}
```

---

## 五、资产注册合约 AssetRegistry.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract AssetRegistry is ERC721, ERC721Enumerable {
    
    // ============ 结构体定义 ============
    
    enum AssetType { SOUND, CANVAS, TEXT }
    enum AssetStatus { DRAFT, PUBLISHED, FROZEN, ARCHIVED }
    
    struct AssetMetadata {
        string title;
        string description;
        string[] tags;
        AssetType assetType;
        AssetStatus status;
        string contentURI;      // IPFS/Arweave hash
        string thumbnailURI;    // 缩略图
        uint256 createdAt;
        uint256 updatedAt;
    }
    
    // ============ 状态变量 ============
    
    /// @notice 资产元数据
    mapping(uint256 => AssetMetadata) public assets;
    
    /// @notice 资产ID到创建者
    mapping(uint256 => address) public creators;
    
    /// @notice 创建者的资产列表
    mapping(address => uint256[]) public creatorAssets;
    
    /// @notice 授权合约
    mapping(address => bool) public authorizedContracts;
    
    uint256 public tokenCounter;
    address public owner;
    
    // ============ 事件定义 ============
    
    event AssetMinted(
        uint256 indexed tokenId,
        address indexed creator,
        AssetType assetType,
        string title
    );
    
    event AssetUpdated(
        uint256 indexed tokenId,
        string title,
        AssetStatus status
    );
    
    // ============ 构造函数 ============
    
    constructor() ERC721("ECHO Asset", "ECHO") {
        owner = msg.sender;
        tokenCounter = 0;
    }
    
    // ============ 核心函数 ============
    
    /// @notice 铸造新资产
    function mint(
        string calldata title,
        string calldata description,
        string[] calldata tags,
        AssetType assetType,
        string calldata contentURI,
        string calldata thumbnailURI
    ) external returns (uint256) {
        tokenCounter++;
        uint256 tokenId = tokenCounter;
        
        // 铸造NFT
        _safeMint(msg.sender, tokenId);
        
        // 存储元数据
        assets[tokenId] = AssetMetadata({
            title: title,
            description: description,
            tags: tags,
            assetType: assetType,
            status: AssetStatus.DRAFT,
            contentURI: contentURI,
            thumbnailURI: thumbnailURI,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });
        
        creators[tokenId] = msg.sender;
        creatorAssets[msg.sender].push(tokenId);
        
        emit AssetMinted(tokenId, msg.sender, assetType, title);
        
        return tokenId;
    }
    
    /// @notice 更新资产状态
    function updateStatus(uint256 tokenId, AssetStatus newStatus) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner");
        assets[tokenId].status = newStatus;
        assets[tokenId].updatedAt = block.timestamp;
        
        emit AssetUpdated(tokenId, assets[tokenId].title, newStatus);
    }
    
    /// @notice 获取资产元数据
    function getAsset(uint256 tokenId) external view returns (AssetMetadata memory) {
        return assets[tokenId];
    }
    
    /// @notice 获取创建者的所有资产
    function getCreatorAssets(address creator) external view returns (uint256[] memory) {
        return creatorAssets[creator];
    }
    
    /// @notice 将tokenId转换为bytes32
    function getAssetHash(uint256 tokenId) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(tokenId));
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## 六、权利管理合约 RightsManager.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract RightsManager {
    
    // ============ 结构体定义 ============
    
    struct PowerConfig {
        uint8 usePower;      // 1-8
        uint8 spreadPower;   // 1-8
        uint8 derivePower;   // 1-8
        uint8 profitPower;   // 1-8
    }
    
    struct PermissionResult {
        bool allowed;
        string reason;
        uint256 fee;
    }
    
    // ============ 状态变量 ============
    
    mapping(bytes32 => PowerConfig) public assetPowers;
    mapping(address => bool) public authorizedContracts;
    address public owner;
    
    // ============ 构造函数 ============
    
    constructor() {
        owner = msg.sender;
    }
    
    // ============ 核心函数 ============
    
    /// @notice 设置资产四权力
    function setPowers(
        bytes32 assetId,
        uint8 usePower,
        uint8 spreadPower,
        uint8 derivePower,
        uint8 profitPower
    ) external onlyAuthorized {
        assetPowers[assetId] = PowerConfig(
            usePower,
            spreadPower,
            derivePower,
            profitPower
        );
    }
    
    /// @notice 检查使用权
    function checkUsePermission(
        bytes32 assetId,
        uint8 requestedLevel
    ) external view returns (PermissionResult memory) {
        PowerConfig memory powers = assetPowers[assetId];
        
        if (requestedLevel <= powers.usePower) {
            return PermissionResult(true, "", calculateUseFee(powers.profitPower));
        }
        
        return PermissionResult(false, "Insufficient use rights", 0);
    }
    
    /// @notice 检查扩散权
    function checkSpreadPermission(
        bytes32 assetId,
        string calldata platform
    ) external view returns (PermissionResult memory) {
        PowerConfig memory powers = assetPowers[assetId];
        
        // 简化的平台级别映射
        uint8 platformLevel = getPlatformLevel(platform);
        
        if (platformLevel <= powers.spreadPower) {
            return PermissionResult(true, "", 0);
        }
        
        return PermissionResult(false, "Platform not authorized", 0);
    }
    
    /// @notice 检查衍生权
    function checkDerivePermission(
        bytes32 assetId,
        uint8 deriveType
    ) external view returns (PermissionResult memory) {
        PowerConfig memory powers = assetPowers[assetId];
        
        if (deriveType <= powers.derivePower) {
            return PermissionResult(true, "", calculateDeriveFee(powers.profitPower));
        }
        
        return PermissionResult(false, "Derivation not allowed", 0);
    }
    
    /// @notice 获取收益分成比例
    function getRevenueShare(bytes32 assetId) external view returns (uint256 creatorShare, uint256 userShare) {
        PowerConfig memory powers = assetPowers[assetId];
        
        // 根据益权档位返回分成比例
        uint8[8] memory shares = [0, 95, 90, 80, 60, 50, 30, 20];
        creatorShare = shares[powers.profitPower - 1];
        userShare = 100 - creatorShare;
    }
    
    /// @notice 计算使用费
    function calculateUseFee(uint8 profitPower) internal pure returns (uint256) {
        // 益权越高，使用费越低（更开放）
        uint256[8] memory fees = [0, 1000, 800, 600, 400, 200, 100, 0];
        return fees[profitPower - 1];
    }
    
    /// @notice 计算衍生费
    function calculateDeriveFee(uint8 profitPower) internal pure returns (uint256) {
        uint256[8] memory fees = [0, 2000, 1500, 1000, 600, 300, 150, 0];
        return fees[profitPower - 1];
    }
    
    /// @notice 获取平台级别（简化实现）
    function getPlatformLevel(string calldata platform) internal pure returns (uint8) {
        if (keccak256(bytes(platform)) == keccak256(bytes("personal"))) return 1;
        if (keccak256(bytes(platform)) == keccak256(bytes("friend"))) return 2;
        if (keccak256(bytes(platform)) == keccak256(bytes("community"))) return 3;
        if (keccak256(bytes(platform)) == keccak256(bytes("platform"))) return 4;
        if (keccak256(bytes(platform)) == keccak256(bytes("public"))) return 5;
        if (keccak256(bytes(platform)) == keccak256(bytes("crosschain"))) return 6;
        if (keccak256(bytes(platform)) == keccak256(bytes("metaverse"))) return 7;
        if (keccak256(bytes(platform)) == keccak256(bytes("permanent"))) return 8;
        return 5; // default
    }
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }
    
    function authorizeContract(address contractAddress) external {
        require(msg.sender == owner);
        authorizedContracts[contractAddress] = true;
    }
}
```

---

## 七、收益分配合约 RevenueDistributor.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./RightsManager.sol";
import "./LineageTracker.sol";

contract RevenueDistributor {
    
    // ============ 结构体定义 ============
    
    struct Payment {
        bytes32 assetId;
        address payer;
        uint256 amount;
        uint256 platformFee;
        uint256 creatorShare;
        uint256 lineageShare;
        uint256 timestamp;
    }
    
    // ============ 状态变量 ============
    
    RightsManager public rightsManager;
    LineageTracker public lineageTracker;
    
    mapping(bytes32 => Payment[]) public paymentHistory;
    mapping(address => uint256) public pendingWithdrawals;
    
    uint256 public platformFeeRate = 5; // 5%
    address public platformWallet;
    address public owner;
    
    // ============ 事件定义 ============
    
    event PaymentProcessed(
        bytes32 indexed assetId,
        address indexed payer,
        uint256 amount,
        uint256 creatorShare
    );
    
    event RevenueDistributed(
        bytes32 indexed assetId,
        address creator,
        uint256 amount
    );
    
    event LineageRevenue(
        bytes32 indexed fromAsset,
        bytes32 indexed toAsset,
        uint256 amount
    );
    
    // ============ 构造函数 ============
    
    constructor(address _rightsManager, address _lineageTracker) {
        owner = msg.sender;
        platformWallet = msg.sender;
        rightsManager = RightsManager(_rightsManager);
        lineageTracker = LineageTracker(_lineageTracker);
    }
    
    // ============ 核心函数 ============
    
    /// @notice 处理支付并分配收益
    function processPayment(bytes32 assetId) external payable {
        require(msg.value > 0, "Payment required");
        
        uint256 totalAmount = msg.value;
        
        // 平台费用
        uint256 platformFee = (totalAmount * platformFeeRate) / 100;
        pendingWithdrawals[platformWallet] += platformFee;
        
        // 获取收益分成比例
        (uint256 creatorShare, ) = rightsManager.getRevenueShare(assetId);
        
        // 创作者收益
        uint256 creatorAmount = ((totalAmount - platformFee) * creatorShare) / 100;
        address creator = getAssetCreator(assetId);
        pendingWithdrawals[creator] += creatorAmount;
        
        // 血缘回流
        uint256 lineageAmount = totalAmount - platformFee - creatorAmount;
        distributeToLineage(assetId, lineageAmount);
        
        // 记录支付
        paymentHistory[assetId].push(Payment({
            assetId: assetId,
            payer: msg.sender,
            amount: totalAmount,
            platformFee: platformFee,
            creatorShare: creatorAmount,
            lineageShare: lineageAmount,
            timestamp: block.timestamp
        }));
        
        emit PaymentProcessed(assetId, msg.sender, totalAmount, creatorAmount);
    }
    
    /// @notice 分配血缘收益
    function distributeToLineage(bytes32 assetId, uint256 amount) internal {
        // 获取上游资产（被引用的资产）
        bytes32[] memory upstream = lineageTracker.getUpstreamAssets(assetId);
        
        if (upstream.length == 0) return;
        
        // 简化：平均分配给所有上游资产
        uint256 sharePerAsset = amount / upstream.length;
        
        for (uint i = 0; i < upstream.length; i++) {
            address upstreamCreator = getAssetCreator(upstream[i]);
            pendingWithdrawals[upstreamCreator] += sharePerAsset;
            
            emit LineageRevenue(assetId, upstream[i], sharePerAsset);
        }
    }
    
    /// @notice 提现待提取金额
    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawal");
        
        pendingWithdrawals[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    /// @notice 获取待提取金额
    function getPendingWithdrawal(address user) external view returns (uint256) {
        return pendingWithdrawals[user];
    }
    
    /// @notice 获取资产支付历史
    function getPaymentHistory(bytes32 assetId) external view returns (Payment[] memory) {
        return paymentHistory[assetId];
    }
    
    /// @notice 获取资产创建者（简化实现）
    function getAssetCreator(bytes32 assetId) internal view returns (address) {
        // 实际实现中应从AssetRegistry获取
        return address(uint160(uint256(assetId)));
    }
    
    receive() external payable {}
}
```

---

## 八、血缘追踪合约 LineageTracker.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract LineageTracker {
    
    // ============ 结构体定义 ============
    
    struct LineageNode {
        bytes32 assetId;
        bytes32[] parents;      // 上游（引用的资产）
        bytes32[] children;     // 下游（引用的本资产）
        uint256 createdAt;
    }
    
    struct Relation {
        bytes32 fromAsset;
        bytes32 toAsset;
        string relationType;    // "quote", "derive", "remix", etc.
        uint256 timestamp;
    }
    
    // ============ 状态变量 ============
    
    mapping(bytes32 => LineageNode) public nodes;
    mapping(bytes32 => Relation[]) public relations;
    mapping(address => bool) public authorizedContracts;
    
    address public owner;
    
    // ============ 事件定义 ============
    
    event RelationCreated(
        bytes32 indexed fromAsset,
        bytes32 indexed toAsset,
        string relationType
    );
    
    event LineageNodeCreated(bytes32 indexed assetId);
    
    // ============ 构造函数 ============
    
    constructor() {
        owner = msg.sender;
    }
    
    // ============ 核心函数 ============
    
    /// @notice 创建血缘节点
    function createNode(bytes32 assetId) external onlyAuthorized {
        require(nodes[assetId].createdAt == 0, "Node already exists");
        
        nodes[assetId] = LineageNode({
            assetId: assetId,
            parents: new bytes32[](0),
            children: new bytes32[](0),
            createdAt: block.timestamp
        });
        
        emit LineageNodeCreated(assetId);
    }
    
    /// @notice 创建引用关系
    function createRelation(
        bytes32 fromAsset,
        bytes32 toAsset,
        string calldata relationType
    ) external onlyAuthorized {
        require(fromAsset != toAsset, "Self reference not allowed");
        require(nodes[fromAsset].createdAt > 0, "From node not found");
        require(nodes[toAsset].createdAt > 0, "To node not found");
        
        // 检测循环引用
        require(!detectCycle(fromAsset, toAsset), "Cycle detected");
        
        // 添加关系
        nodes[fromAsset].parents.push(toAsset);
        nodes[toAsset].children.push(fromAsset);
        
        relations[fromAsset].push(Relation({
            fromAsset: fromAsset,
            toAsset: toAsset,
            relationType: relationType,
            timestamp: block.timestamp
        }));
        
        emit RelationCreated(fromAsset, toAsset, relationType);
    }
    
    /// @notice 检测循环引用
    function detectCycle(bytes32 fromAsset, bytes32 toAsset) internal view returns (bool) {
        // 简化的循环检测：检查toAsset是否已经在fromAsset的下游
        bytes32[] memory toChildren = nodes[toAsset].children;
        for (uint i = 0; i < toChildren.length; i++) {
            if (toChildren[i] == fromAsset) {
                return true;
            }
        }
        return false;
    }
    
    /// @notice 获取上游资产
    function getUpstreamAssets(bytes32 assetId) external view returns (bytes32[] memory) {
        return nodes[assetId].parents;
    }
    
    /// @notice 获取下游资产
    function getDownstreamAssets(bytes32 assetId) external view returns (bytes32[] memory) {
        return nodes[assetId].children;
    }
    
    /// @notice 获取血缘路径
    function getLineagePath(
        bytes32 fromAsset,
        bytes32 toAsset
    ) external view returns (bytes32[] memory) {
        // 简化的路径查找
        // 实际实现应使用图遍历算法
        bytes32[] memory path = new bytes32[](2);
        path[0] = fromAsset;
        path[1] = toAsset;
        return path;
    }
    
    /// @notice 获取节点的完整血缘信息
    function getNode(bytes32 assetId) external view returns (LineageNode memory) {
        return nodes[assetId];
    }
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }
    
    function authorizeContract(address contractAddress) external {
        require(msg.sender == owner);
        authorizedContracts[contractAddress] = true;
    }
}
```

---

## 九、Agent调度合约 AgentScheduler.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract AgentScheduler {
    
    // ============ 结构体定义 ============
    
    enum AgentType {
        FIELD_MAPPER,       // 势场测绘
        POSITION_NAVIGATOR, // 势位导航
        GENE_ADVISOR,       // 基因顾问
        DERIVATIVE_ASSISTANT, // 衍生助手
        VALUE_TRACKER       // 价值追踪
    }
    
    struct AgentTask {
        AgentType agentType;
        bytes32 assetId;
        bytes inputData;
        uint256 scheduledTime;
        bool executed;
        bytes outputData;
    }
    
    struct AgentConfig {
        string name;
        string description;
        address executor;       // Agent执行者地址
        uint256 fee;           // 执行费用
        bool active;
    }
    
    // ============ 状态变量 ============
    
    mapping(AgentType => AgentConfig) public agentConfigs;
    mapping(uint256 => AgentTask) public tasks;
    mapping(bytes32 => uint256[]) public assetTasks;
    
    uint256 public taskCounter;
    address public owner;
    
    // ============ 事件定义 ============
    
    event TaskScheduled(
        uint256 indexed taskId,
        AgentType agentType,
        bytes32 indexed assetId,
        uint256 scheduledTime
    );
    
    event TaskExecuted(
        uint256 indexed taskId,
        address executor,
        bytes outputData
    );
    
    event AgentRegistered(
        AgentType agentType,
        string name,
        address executor
    );
    
    // ============ 构造函数 ============
    
    constructor() {
        owner = msg.sender;
        taskCounter = 0;
        initializeAgents();
    }
    
    // ============ 初始化函数 ============
    
    function initializeAgents() internal {
        agentConfigs[AgentType.FIELD_MAPPER] = AgentConfig(
            "势场测绘员",
            "分析内容在三大模块中的分布与影响力",
            address(0),
            0.01 ether,
            true
        );
        
        agentConfigs[AgentType.POSITION_NAVIGATOR] = AgentConfig(
            "势位导航员",
            "为创作者提供最优发布策略建议",
            address(0),
            0.01 ether,
            true
        );
        
        agentConfigs[AgentType.GENE_ADVISOR] = AgentConfig(
            "创作基因顾问",
            "分析内容的原创性与独特价值",
            address(0),
            0.005 ether,
            true
        );
        
        agentConfigs[AgentType.DERIVATIVE_ASSISTANT] = AgentConfig(
            "衍生创作助手",
            "帮助用户基于现有资产进行衍生创作",
            address(0),
            0.008 ether,
            true
        );
        
        agentConfigs[AgentType.VALUE_TRACKER] = AgentConfig(
            "价值回流追踪器",
            "可视化血缘图谱，追踪收益流动",
            address(0),
            0.015 ether,
            true
        );
    }
    
    // ============ 核心函数 ============
    
    /// @notice 调度Agent任务
    function scheduleTask(
        AgentType agentType,
        bytes32 assetId,
        bytes calldata inputData,
        uint256 delay
    ) external payable returns (uint256) {
        AgentConfig memory config = agentConfigs[agentType];
        require(config.active, "Agent not active");
        require(msg.value >= config.fee, "Insufficient fee");
        
        taskCounter++;
        uint256 taskId = taskCounter;
        
        tasks[taskId] = AgentTask({
            agentType: agentType,
            assetId: assetId,
            inputData: inputData,
            scheduledTime: block.timestamp + delay,
            executed: false,
            outputData: ""
        });
        
        assetTasks[assetId].push(taskId);
        
        emit TaskScheduled(taskId, agentType, assetId, block.timestamp + delay);
        
        return taskId;
    }
    
    /// @notice 执行Agent任务
    function executeTask(uint256 taskId) external {
        AgentTask storage task = tasks[taskId];
        require(!task.executed, "Task already executed");
        require(block.timestamp >= task.scheduledTime, "Task not ready");
        
        AgentConfig memory config = agentConfigs[task.agentType];
        require(msg.sender == config.executor || config.executor == address(0), "Not authorized");
        
        // 执行Agent逻辑（简化）
        bytes memory output = executeAgentLogic(task.agentType, task.inputData);
        
        task.outputData = output;
        task.executed = true;
        
        // 支付执行者
        if (config.fee > 0) {
            payable(msg.sender).transfer(config.fee);
        }
        
        emit TaskExecuted(taskId, msg.sender, output);
    }
    
    /// @notice 执行Agent逻辑（内部函数）
    function executeAgentLogic(
        AgentType agentType,
        bytes memory input
    ) internal pure returns (bytes memory) {
        // 简化的Agent逻辑
        // 实际实现中应调用链下Agent服务
        if (agentType == AgentType.FIELD_MAPPER) {
            return abi.encode("Field mapping completed");
        } else if (agentType == AgentType.POSITION_NAVIGATOR) {
            return abi.encode("Navigation advice generated");
        } else if (agentType == AgentType.GENE_ADVISOR) {
            return abi.encode("Originality score: 85");
        } else if (agentType == AgentType.DERIVATIVE_ASSISTANT) {
            return abi.encode("Derivative template created");
        } else if (agentType == AgentType.VALUE_TRACKER) {
            return abi.encode("Lineage graph updated");
        }
        return "";
    }
    
    /// @notice 注册Agent
    function registerAgent(
        AgentType agentType,
        address executor,
        uint256 fee
    ) external {
        require(msg.sender == owner);
        agentConfigs[agentType].executor = executor;
        agentConfigs[agentType].fee = fee;
        
        emit AgentRegistered(agentConfigs[agentType].name, agentConfigs[agentType].name, executor);
    }
    
    /// @notice 获取资产的任务列表
    function getAssetTasks(bytes32 assetId) external view returns (uint256[] memory) {
        return assetTasks[assetId];
    }
    
    /// @notice 获取任务详情
    function getTask(uint256 taskId) external view returns (AgentTask memory) {
        return tasks[taskId];
    }
}
```

---

## 十、合约部署架构

### 部署顺序

```
1. 部署 ShiShu
2. 部署 ShiChang
3. 部署 ShiWei (传入 ShiShu 地址)
4. 部署 AssetRegistry
5. 部署 RightsManager
6. 部署 LineageTracker
7. 部署 RevenueDistributor (传入 RightsManager 和 LineageTracker 地址)
8. 部署 AgentScheduler

9. 配置授权：
   - ShiShu.authorize(AssetRegistry)
   - ShiShu.authorize(RevenueDistributor)
   - ShiChang.authorize(AssetRegistry)
   - RightsManager.authorize(AssetRegistry)
   - RightsManager.authorize(RevenueDistributor)
   - LineageTracker.authorize(AssetRegistry)
```

---

*智能合约是ECHO协议的链上实现，确保四权力、势位、血缘等核心概念的可信执行。* 🔗
