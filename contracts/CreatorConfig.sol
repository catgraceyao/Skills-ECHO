// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CreatorConfig
 * @notice 创作者配置：版本 DAG + TOPUP 定价锚定 + 链下存储
 * @dev 基于 v0.4 文档 §1.x
 */
contract CreatorConfig {
    
    // ============ 枚举 ============
    
    enum MigrationMode {
        None,       // 无迁移
        Sunset,     // 日落
        TOPUP,      // 补差价
        Fork        // 分叉
    }
    
    enum PriceDirection {
        Increase,   // 涨价
        Decrease,   // 降价
        Same        // 不变
    }
    
    // ============ 数据结构 ============
    
    struct Version {
        uint256 id;
        uint256 parentId;         // 父版本 ID（0 = 创世）
        bytes32 configHash;       // 配置哈希
        bytes32 contractHash;     // 合约字节码哈希
        uint256 publishTime;
        uint256 childCount;
        MigrationMode migrationMode;
        bool exists;
    }
    
    struct TOPUPricing {
        uint256 oldPrice;
        uint256 newPrice;
        uint256 announceTime;     // 公示开始时间
        uint256 twapPrice;        // 时间加权平均价格
        uint256 challengeDeadline;  // 社区质疑截止
        bool challenged;            // 是否被质疑
        PriceDirection direction;   // 价格方向
    }
    
    struct ChainStorage {
        string ipfsHash;          // IPFS 内容哈希
        bytes32 merkleRoot;       // Merkle root
        uint256 pinCount;         // Pinning 节点数
        uint256 lastVerified;     // 上次验证时间
    }
    
    // ============ 常量 ============
    
    uint256 public constant ANNOUNCE_PERIOD = 3 days;       // TOPUP 公示期
    uint256 public constant TWAP_WINDOW = 7 days;         // TWAP 窗口
    uint256 public constant CHALLENGE_WINDOW = 2 days;      // 社区质疑窗口
    uint256 public constant MAX_CONFIG_SIZE = 10240;        // 10KB 配置上限
    
    // ============ 状态变量 ============
    
    mapping(uint256 => Version) public versions;
    mapping(uint256 => TOPUPricing) public topuPricings;
    mapping(uint256 => ChainStorage) public chainStorages;
    mapping(bytes32 => uint256) public configKeys;        // key => value
    
    uint256 public nextVersionId;
    address public owner;
    address public licenseContract;
    
    // ============ 事件 ============
    
    event VersionPublished(
        uint256 indexed id,
        uint256 indexed parentId,
        bytes32 configHash,
        MigrationMode mode
    );
    event TOPUAnnounced(
        uint256 indexed versionId,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 twap
    );
    event TOPUChallenged(uint256 indexed versionId, address challenger);
    event ChainStorageUpdated(uint256 indexed versionId, string ipfsHash, bytes32 merkleRoot);
    event ConfigSet(bytes32 indexed key, uint256 value);
    
    // ============ 修饰器 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "CC: not owner");
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor() {
        owner = msg.sender;
        nextVersionId = 1;  // 版本 ID 从 1 开始
    }
    
    function setLicenseContract(address _license) external onlyOwner {
        licenseContract = _license;
    }
    
    // ============ 版本发布 ============
    
    function publishVersion(
        uint256 _parentVersionId,
        bytes32 _configHash,
        bytes32 _contractHash,
        MigrationMode _migrationMode
    ) external onlyOwner returns (uint256 versionId) {
        // 父版本验证
        if (_parentVersionId != 0) {
            require(versions[_parentVersionId].exists, "CC: parent not found");
        }
        
        versionId = nextVersionId++;
        versions[versionId] = Version({
            id: versionId,
            parentId: _parentVersionId,
            configHash: _configHash,
            contractHash: _contractHash,
            publishTime: block.timestamp,
            childCount: 0,
            migrationMode: _migrationMode,
            exists: true
        });
        
        // 更新父版本子计数
        if (_parentVersionId != 0) {
            versions[_parentVersionId].childCount++;
        }
        
        emit VersionPublished(versionId, _parentVersionId, _configHash, _migrationMode);
        return versionId;
    }
    
    // ============ 版本 DAG 查询 ============
    
    function getVersionLineage(uint256 _versionId) external view returns (uint256[] memory) {
        require(versions[_versionId].exists, "CC: version not found");
        
        // 计算路径长度
        uint256 length = 0;
        uint256 current = _versionId;
        while (current != 0) {
            length++;
            current = versions[current].parentId;
        }
        
        // 填充路径
        uint256[] memory path = new uint256[](length);
        current = _versionId;
        uint256 index = length;
        while (current != 0) {
            index--;
            path[index] = current;
            current = versions[current].parentId;
        }
        
        return path;
    }
    
    function getVersion(uint256 _versionId) external view returns (
        uint256 id,
        uint256 parentId,
        bytes32 configHash,
        bytes32 contractHash,
        uint256 publishTime,
        uint256 childCount,
        MigrationMode migrationMode
    ) {
        Version storage v = versions[_versionId];
        require(v.exists, "CC: version not found");
        return (
            v.id,
            v.parentId,
            v.configHash,
            v.contractHash,
            v.publishTime,
            v.childCount,
            v.migrationMode
        );
    }
    
    // ============ TOPUP 定价锚定 ============
    
    function announceTOPUP(
        uint256 _versionId,
        uint256 _oldPrice,
        uint256 _newPrice
    ) external onlyOwner {
        require(versions[_versionId].exists, "CC: version not found");
        
        // 计算 TWAP（简化：实际应接入预言机）
        uint256 twap = (_oldPrice + _newPrice) / 2;  // 简化 TWAP
        
        PriceDirection dir;
        if (_newPrice > _oldPrice) {
            dir = PriceDirection.Increase;
        } else if (_newPrice < _oldPrice) {
            dir = PriceDirection.Decrease;
        } else {
            dir = PriceDirection.Same;
        }
        
        topuPricings[_versionId] = TOPUPricing({
            oldPrice: _oldPrice,
            newPrice: _newPrice,
            announceTime: block.timestamp,
            twapPrice: twap,
            challengeDeadline: block.timestamp + CHALLENGE_WINDOW,
            challenged: false,
            direction: dir
        });
        
        emit TOPUAnnounced(_versionId, _oldPrice, _newPrice, twap);
    }
    
    function challengeTOPUP(uint256 _versionId) external {
        TOPUPricing storage t = topuPricings[_versionId];
        require(t.announceTime > 0, "CC: TOPUP not announced");
        require(block.timestamp <= t.challengeDeadline, "CC: challenge window closed");
        require(!t.challenged, "CC: already challenged");
        
        t.challenged = true;
        emit TOPUChallenged(_versionId, msg.sender);
        
        // 被质疑后进入 DAO 投票（简化）
        // 实际应调用 GovernanceDAO.propose()
    }
    
    function getTOPUPStatus(uint256 _versionId) external view returns (
        uint256 oldPrice,
        uint256 newPrice,
        uint256 twap,
        bool canExecute,
        bool challenged,
        PriceDirection direction
    ) {
        TOPUPricing storage t = topuPricings[_versionId];
        bool expired = block.timestamp > t.announceTime + ANNOUNCE_PERIOD;
        return (
            t.oldPrice,
            t.newPrice,
            t.twapPrice,
            expired && !t.challenged,
            t.challenged,
            t.direction
        );
    }
    
    // ============ 负价差策略 ============
    
    function executeNegativeSpread(uint256 _versionId) external onlyOwner {
        TOPUPricing storage t = topuPricings[_versionId];
        require(t.direction == PriceDirection.Decrease, "CC: not negative spread");
        require(block.timestamp > t.announceTime + ANNOUNCE_PERIOD, "CC: announce period not ended");
        require(!t.challenged, "CC: challenged");
        
        // 降价时：旧许可持有者免费迁移，享受更低价格
        // 创作者收入损失由协议补贴（简化）
        
        // 触发 LicenseNFT 的批量价格调整
        // 简化：实际应调用 licenseContract
    }
    
    // ============ 链下存储 ============
    
    function updateChainStorage(
        uint256 _versionId,
        string calldata _ipfsHash,
        bytes32 _merkleRoot
    ) external onlyOwner {
        chainStorages[_versionId] = ChainStorage({
            ipfsHash: _ipfsHash,
            merkleRoot: _merkleRoot,
            pinCount: 3,  // 默认 3 个 pinning 节点
            lastVerified: block.timestamp
        });
        
        emit ChainStorageUpdated(_versionId, _ipfsHash, _merkleRoot);
    }
    
    function verifyChainStorage(uint256 _versionId) external view returns (bool) {
        ChainStorage storage s = chainStorages[_versionId];
        if (s.pinCount < 3) return false;
        if (bytes(s.ipfsHash).length == 0) return false;
        if (s.merkleRoot == bytes32(0)) return false;
        return true;
    }
    
    // ============ 配置管理 ============
    
    function setConfig(bytes32 _key, uint256 _value) external onlyOwner {
        configKeys[_key] = _value;
        emit ConfigSet(_key, _value);
    }
    
    function getConfig(bytes32 _key) external view returns (uint256) {
        return configKeys[_key];
    }
    
    // ============ 批量操作 ============
    
    function batchPublishVersions(
        uint256[] calldata _parentIds,
        bytes32[] calldata _configHashes,
        bytes32[] calldata _contractHashes,
        MigrationMode[] calldata _modes
    ) external onlyOwner {
        require(
            _parentIds.length == _configHashes.length &&
            _configHashes.length == _contractHashes.length &&
            _contractHashes.length == _modes.length,
            "CC: array length mismatch"
        );
        
        for (uint i = 0; i < _parentIds.length; i++) {
            this.publishVersion(_parentIds[i], _configHashes[i], _contractHashes[i], _modes[i]);
        }
    }
    
    receive() external payable {}
}
