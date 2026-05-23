// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ExitGasPool
 * @notice 退出权 gas 兜底资金池：创作者强制存 0.1 ETH
 * @dev 基于 v0.4 文档 §3.8，修复：回灌路径
 */
contract ExitGasPool {
    
    // ============ 常量 ============
    
    uint256 public constant MIN_CREATOR_DEPOSIT = 0.1 ether;  // 创作者强制存入
    uint256 public constant PROTOCOL_TOPUP_RATE = 200;         // 协议收入 2% 注入池子
    uint256 public constant MAX_GAS_REFUND = 0.05 ether;       // 单次退出 gas 上限
    
    // ============ 数据结构 ============
    
    struct CreatorPool {
        uint256 balance;           // 创作者存入的 ETH
        uint256 totalRefunded;     // 累计退还
        bool active;               // 是否激活
    }
    
    // ============ 状态变量 ============
    
    mapping(address => CreatorPool) public creatorPools;   // 创作者地址 => 池子
    uint256 public protocolPool;                             // 协议兜底池
    address public owner;
    address public licenseContract;
    address public daoContract;
    
    uint256 public totalRefunded;     // 累计退还总量
    uint256 public totalDeposited;   // 累计存入总量
    
    // ============ 事件 ============
    
    event CreatorDeposit(address indexed creator, uint256 amount);
    event ProtocolTopup(uint256 amount);
    event GasRefunded(address indexed user, address indexed creator, uint256 amount);
    event PoolReplenished(address indexed creator, uint256 amount);
    
    // ============ 修饰器 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "EGP: not owner");
        _;
    }
    
    modifier onlyLicense() {
        require(msg.sender == licenseContract, "EGP: not license contract");
        _;
    }
    
    modifier onlyDAO() {
        require(msg.sender == daoContract, "EGP: not DAO");
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor() {
        owner = msg.sender;
    }
    
    function setLicenseContract(address _license) external onlyOwner {
        licenseContract = _license;
    }
    
    function setDAOContract(address _dao) external onlyOwner {
        daoContract = _dao;
    }
    
    // ============ 创作者存入 ============
    
    function creatorDeposit() external payable {
        require(msg.value >= MIN_CREATOR_DEPOSIT, "EGP: minimum deposit 0.1 ETH");
        
        CreatorPool storage pool = creatorPools[msg.sender];
        pool.balance += msg.value;
        pool.active = true;
        totalDeposited += msg.value;
        
        emit CreatorDeposit(msg.sender, msg.value);
    }
    
    // ============ 协议注入（收入 2%） ============
    
    function protocolTopup() external payable onlyOwner {
        protocolPool += msg.value;
        emit ProtocolTopup(msg.value);
    }
    
    // ============ 自动回灌（当创作者池子 < 0.05 ETH） ============
    
    function replenishPool(address _creator) external onlyDAO {
        CreatorPool storage pool = creatorPools[_creator];
        require(pool.active, "EGP: pool not active");
        
        if (pool.balance < MIN_CREATOR_DEPOSIT / 2) {
            // 从协议池回灌到创作者池
            uint256 needed = MIN_CREATOR_DEPOSIT - pool.balance;
            uint256 actual = needed > protocolPool ? protocolPool : needed;
            
            if (actual > 0) {
                protocolPool -= actual;
                pool.balance += actual;
                emit PoolReplenished(_creator, actual);
            }
        }
    }
    
    // ============ 退还退出 gas ============
    
    function refundExitGas(
        address _user,
        address _creator,
        uint256 _gasUsed
    ) external onlyLicense returns (uint256 refunded) {
        CreatorPool storage pool = creatorPools[_creator];
        require(pool.active, "EGP: creator pool not active");
        
        // 计算退还金额（按实际 gas 消耗，上限 0.05 ETH）
        uint256 gasCost = _gasUsed * tx.gasprice;
        refunded = gasCost > MAX_GAS_REFUND ? MAX_GAS_REFUND : gasCost;
        
        // 优先从创作者池扣
        if (pool.balance >= refunded) {
            pool.balance -= refunded;
        } else {
            // 创作者池不足，从协议池兜底
            uint256 fromPool = refunded - pool.balance;
            require(protocolPool >= fromPool, "EGP: insufficient protocol pool");
            
            protocolPool -= fromPool;
            pool.balance = 0;
        }
        
        pool.totalRefunded += refunded;
        totalRefunded += refunded;
        
        // 转账给用户
        (bool success, ) = payable(_user).call{value: refunded}("");
        require(success, "EGP: refund transfer failed");
        
        emit GasRefunded(_user, _creator, refunded);
        
        // 触发自动回灌检查
        if (pool.balance < MIN_CREATOR_DEPOSIT / 2) {
            // 异步触发（实际应通过 keeper 或 DAO）
            // 简化：这里不做自动回灌，留待 DAO 处理
        }
        
        return refunded;
    }
    
    // ============ 批量退还（gas 优化） ============
    
    function batchRefundExitGas(
        address[] calldata _users,
        address[] calldata _creators,
        uint256[] calldata _gasUsed
    ) external onlyLicense {
        require(
            _users.length == _creators.length && _creators.length == _gasUsed.length,
            "EGP: array length mismatch"
        );
        
        for (uint i = 0; i < _users.length; i++) {
            this.refundExitGas(_users[i], _creators[i], _gasUsed[i]);
        }
    }
    
    // ============ 查询 ============
    
    function getPoolInfo(address _creator) external view returns (
        uint256 balance,
        uint256 totalRefunded,
        bool active,
        bool needsReplenish
    ) {
        CreatorPool storage pool = creatorPools[_creator];
        return (
            pool.balance,
            pool.totalRefunded,
            pool.active,
            pool.balance < MIN_CREATOR_DEPOSIT / 2
        );
    }
    
    function getProtocolPool() external view returns (uint256) {
        return protocolPool;
    }
    
    function getStats() external view returns (
        uint256 totalDeposited_,
        uint256 totalRefunded_,
        uint256 protocolPool_
    ) {
        return (totalDeposited, totalRefunded, protocolPool);
    }
    
    // ============ 紧急提现（仅DAO） ============
    
    function emergencyWithdraw(uint256 _amount) external onlyDAO {
        require(_amount <= address(this).balance, "EGP: insufficient balance");
        payable(daoContract).transfer(_amount);
    }
    
    receive() external payable {}
}
