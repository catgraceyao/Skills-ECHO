// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LicenseNFT
 * @notice ECHO 许可 NFT：使用权 + 扩展权 + 衍生权 + 收益权
 * @dev 基于 v0.4 文档 §2.x
 */
contract LicenseNFT is ERC721, ERC721Enumerable, Ownable {
    
    // ============ 枚举 ============
    
    enum LicenseType {
        Usage,      // 使用权
        Extension,  // 扩展权
        Derivative, // 衍生权
        Revenue     // 收益权
    }
    
    enum LicenseStatus {
        Active,     // 生效中
        Expired,    // 已过期
        Sunset,     // 日落冻结
        Refunded    // 已退款
    }
    
    // ============ 数据结构 ============
    
    struct License {
        uint256 id;
        uint256 versionId;       // 关联版本
        LicenseType licenseType; // 许可类型
        LicenseStatus status;    // 状态
        uint256 issueTime;       // 发行时间
        uint256 expiryTime;      // 过期时间
        uint256 price;           // 购买价格
        address creator;         // 创作者
        bytes32 termsHash;       // 条款哈希
    }
    
    struct SunsetRecord {
        uint256 versionId;
        uint256 freezeTime;      // 冻结时间
        bool newLicensesFrozen;  // 新许可是否冻结
        bool configChangesFrozen;// 配置变更是否冻结
    }
    
    // ============ 状态变量 ============
    
    mapping(uint256 => License) public licenses;
    mapping(uint256 => SunsetRecord) public sunsets;
    mapping(uint256 => bool) public versionExists;
    
    uint256 public nextLicenseId;
    address public creatorConfig;
    address public exitGasPool;
    
    // ============ 事件 ============
    
    event LicenseIssued(
        uint256 indexed id,
        uint256 indexed versionId,
        address indexed holder,
        LicenseType licenseType,
        uint256 expiryTime
    );
    event LicenseTransferred(
        uint256 indexed id,
        address indexed from,
        address indexed to
    );
    event LicenseSunset(uint256 indexed versionId, uint256 freezeTime);
    event LicenseRefunded(uint256 indexed id, uint256 refundAmount);
    event VersionRegistered(uint256 indexed versionId);
    
    // ============ 构造函数 ============
    
    constructor() ERC721("ECHO License", "ECHOL") Ownable(msg.sender) {}
    
    function setCreatorConfig(address _config) external onlyOwner {
        creatorConfig = _config;
    }
    
    function setExitGasPool(address _pool) external onlyOwner {
        exitGasPool = _pool;
    }
    
    // ============ 版本注册 ============
    
    function registerVersion(uint256 _versionId) external onlyOwner {
        require(!versionExists[_versionId], "LNFT: version already registered");
        versionExists[_versionId] = true;
        emit VersionRegistered(_versionId);
    }
    
    // ============ 发行许可 ============
    
    function issueLicense(
        address _to,
        uint256 _versionId,
        LicenseType _type,
        uint256 _duration,
        uint256 _price,
        address _creator,
        bytes32 _termsHash
    ) external onlyOwner returns (uint256 id) {
        require(versionExists[_versionId], "LNFT: version not registered");
        
        // 检查 sunset 状态
        SunsetRecord storage sunset = sunsets[_versionId];
        if (sunset.newLicensesFrozen) {
            require(block.timestamp < sunset.freezeTime, "LNFT: new licenses frozen");
        }
        
        id = nextLicenseId++;
        uint256 expiry = block.timestamp + _duration;
        
        licenses[id] = License({
            id: id,
            versionId: _versionId,
            licenseType: _type,
            status: LicenseStatus.Active,
            issueTime: block.timestamp,
            expiryTime: expiry,
            price: _price,
            creator: _creator,
            termsHash: _termsHash
        });
        
        _safeMint(_to, id);
        
        emit LicenseIssued(id, _versionId, _to, _type, expiry);
        return id;
    }
    
    // ============ 转让许可 ============
    
    function transferLicense(address _from, address _to, uint256 _tokenId) external {
        // OpenZeppelin 5.x: _isAuthorized 需 3 个参数 (owner, spender, tokenId)
        require(_isAuthorized(ownerOf(_tokenId), msg.sender, _tokenId), "LNFT: not authorized");
        require(licenses[_tokenId].status == LicenseStatus.Active, "LNFT: not active");
        require(block.timestamp <= licenses[_tokenId].expiryTime, "LNFT: expired");
        
        _transfer(_from, _to, _tokenId);
        
        emit LicenseTransferred(_tokenId, _from, _to);
    }
    
    // ============ Sunset 机制 ============
    
    function sunsetVersion(
        uint256 _versionId,
        bool _freezeNew,
        bool _freezeConfig
    ) external onlyOwner {
        sunsets[_versionId] = SunsetRecord({
            versionId: _versionId,
            freezeTime: block.timestamp,
            newLicensesFrozen: _freezeNew,
            configChangesFrozen: _freezeConfig
        });
        
        emit LicenseSunset(_versionId, block.timestamp);
    }
    
    // ============ 退款（触发退出 gas 退还） ============
    
    function refundLicense(uint256 _tokenId) external {
        License storage lic = licenses[_tokenId];
        require(lic.status == LicenseStatus.Active, "LNFT: not active");
        require(block.timestamp <= lic.expiryTime, "LNFT: already expired");
        
        address holder = ownerOf(_tokenId);
        require(msg.sender == holder, "LNFT: not holder");
        
        lic.status = LicenseStatus.Refunded;
        
        // 计算退款（按剩余时间比例）
        uint256 elapsed = block.timestamp - lic.issueTime;
        uint256 total = lic.expiryTime - lic.issueTime;
        uint256 refund = (lic.price * (total - elapsed)) / total;
        
        // 退还 ETH
        (bool success, ) = payable(holder).call{value: refund}("");
        require(success, "LNFT: refund failed");
        
        // 触发 gas 退还
        if (exitGasPool != address(0)) {
            uint256 gasStart = gasleft();
            // 调用 exitGasPool.refundExitGas() 的 gas 消耗
            // 简化：实际 gas 消耗由 ExitGasPool 计算
        }
        
        emit LicenseRefunded(_tokenId, refund);
    }
    
    // ============ 批量发行（gas 优化） ============
    
    function batchIssueLicenses(
        address[] calldata _tos,
        uint256[] calldata _versionIds,
        LicenseType[] calldata _types,
        uint256[] calldata _durations,
        uint256[] calldata _prices,
        address[] calldata _creators,
        bytes32[] calldata _termsHashes
    ) external onlyOwner {
        require(
            _tos.length == _versionIds.length &&
            _versionIds.length == _types.length &&
            _types.length == _durations.length &&
            _durations.length == _prices.length &&
            _prices.length == _creators.length &&
            _creators.length == _termsHashes.length,
            "LNFT: array length mismatch"
        );
        
        for (uint i = 0; i < _tos.length; i++) {
            this.issueLicense(
                _tos[i],
                _versionIds[i],
                _types[i],
                _durations[i],
                _prices[i],
                _creators[i],
                _termsHashes[i]
            );
        }
    }
    
    // ============ 查询 ============
    
    function getLicense(uint256 _tokenId) external view returns (License memory) {
        return licenses[_tokenId];
    }
    
    function isLicenseValid(uint256 _tokenId) external view returns (bool) {
        License storage lic = licenses[_tokenId];
        return lic.status == LicenseStatus.Active && block.timestamp <= lic.expiryTime;
    }
    
    function getLicensesByHolder(address _holder) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(_holder);
        uint256[] memory result = new uint256[](balance);
        for (uint i = 0; i < balance; i++) {
            result[i] = tokenOfOwnerByIndex(_holder, i);
        }
        return result;
    }
    
    function getSunsetStatus(uint256 _versionId) external view returns (
        bool isFrozen,
        bool newLicensesFrozen,
        bool configChangesFrozen
    ) {
        SunsetRecord storage s = sunsets[_versionId];
        return (
            s.freezeTime > 0,
            s.newLicensesFrozen,
            s.configChangesFrozen
        );
    }
    
    // ============ 重载 ============
    
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }
    
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    receive() external payable {}
}