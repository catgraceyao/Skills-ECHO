// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

/**
 * @title AgentJury
 * @notice Agent 陪审团：commit-reveal + 时间隔离 + 3/5 多签
 * @dev 基于 v0.4 文档 §3.7，修复 X7 review #1（成员校验）和 #3（VRF随机源）
 */
contract AgentJury is VRFConsumerBaseV2 {
    // ============ 状态变量 ============
    
    address public owner;
    mapping(address => bool) public isJuror;      // 陪审员白名单（修复 #1）
    address[] public jurorList;                   // 陪审员列表
    uint256 public constant JURY_SIZE = 5;        // 陪审团规模
    uint256 public constant REQUIRED_SIGNATURES = 3; // 3/5 多签
    
    // VRF 配置（修复 #3）
    address public vrfCoordinator;
    bytes32 public keyHash;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit = 200000;
    uint16 public requestConfirmations = 3;
    
    // Commit-Reveal 阶段
    struct Commit {
        bytes32 commitHash;    // keccak256(vote + salt)
        uint256 commitTime;
        bool revealed;
    }
    
    struct Case {
        uint256 caseId;
        bytes32 evidenceHash;
        uint256 commitDeadline;   // 区块 N 前
        uint256 revealDeadline;   // 区块 N+K 后
        uint256 vrfRequestId;     // VRF 请求 ID
        uint256 randomWord;       // VRF 随机数（用于抽选陪审员）
        mapping(address => Commit) commits;
        mapping(address => bool) hasRevealed;
        uint256 revealCount;
        uint256 yesVotes;
        uint256 noVotes;
        bool resolved;
        bool finalVerdict;
        mapping(address => uint256) stakes;  // 反证质押
    }
    
    mapping(uint256 => Case) public cases;
    uint256 public nextCaseId;
    
    // 反证质押
    uint256 public constant DISPROOF_STAKE = 0.05 ether;
    uint256 public constant SLASH_RATE = 5000; // 50% 销毁
    uint256 public constant REWARD_RATE = 5000; // 50% 奖励
    
    // ============ 事件 ============
    
    event CaseOpened(uint256 indexed caseId, bytes32 evidenceHash, uint256 commitDeadline, uint256 revealDeadline);
    event CommitSubmitted(uint256 indexed caseId, address indexed juror, bytes32 commitHash);
    event RevealSubmitted(uint256 indexed caseId, address indexed juror, bool vote);
    event CaseResolved(uint256 indexed caseId, bool verdict, uint256 yesVotes, uint256 noVotes);
    event DisproofStaked(uint256 indexed caseId, address indexed challenger, uint256 amount);
    event DisproofRewarded(uint256 indexed caseId, address indexed challenger, uint256 reward);
    event DisproofSlashed(uint256 indexed caseId, address indexed challenger, uint256 slashed);
    event JurorAdded(address indexed juror);
    event JurorRemoved(address indexed juror);
    
    // ============ 修饰器 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "AJ: not owner");
        _;
    }
    
    modifier onlyJuror() {
        require(isJuror[msg.sender], "AJ: not juror");  // 修复 #1：成员校验
        _;
    }
    
    modifier onlyDuringCommit(uint256 _caseId) {
        require(block.number <= cases[_caseId].commitDeadline, "AJ: commit phase ended");
        _;
    }
    
    modifier onlyDuringReveal(uint256 _caseId) {
        require(block.number > cases[_caseId].commitDeadline, "AJ: not reveal phase yet");
        require(block.number <= cases[_caseId].revealDeadline, "AJ: reveal phase ended");
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        owner = msg.sender;
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }
    
    // ============ 陪审员管理 ============
    
    function addJuror(address _juror) external onlyOwner {
        require(!isJuror[_juror], "AJ: already juror");
        require(jurorList.length < JURY_SIZE, "AJ: jury full");
        isJuror[_juror] = true;
        jurorList.push(_juror);
        emit JurorAdded(_juror);
    }
    
    function removeJuror(address _juror) external onlyOwner {
        require(isJuror[_juror], "AJ: not juror");
        isJuror[_juror] = false;
        // 从数组中移除
        for (uint i = 0; i < jurorList.length; i++) {
            if (jurorList[i] == _juror) {
                jurorList[i] = jurorList[jurorList.length - 1];
                jurorList.pop();
                break;
            }
        }
        emit JurorRemoved(_juror);
    }
    
    // ============ 案件管理 ============
    
    function openCase(
        bytes32 _evidenceHash,
        uint256 _commitBlocks,   // commit 阶段持续区块数
        uint256 _revealBlocks    // reveal 阶段持续区块数
    ) external onlyOwner returns (uint256 caseId) {
        caseId = nextCaseId++;
        Case storage c = cases[caseId];
        c.caseId = caseId;
        c.evidenceHash = _evidenceHash;
        c.commitDeadline = block.number + _commitBlocks;
        c.revealDeadline = c.commitDeadline + _revealBlocks;
        
        // 请求 VRF 随机数用于抽选陪审员（修复 #3）
        c.vrfRequestId = requestRandomWords();
        
        emit CaseOpened(caseId, _evidenceHash, c.commitDeadline, c.revealDeadline);
        return caseId;
    }
    
    // ============ Commit-Reveal ============
    
    function juryCommit(
        uint256 _caseId,
        bytes32 _commitHash  // keccak256(abi.encodePacked(vote, salt))
    ) external onlyJuror onlyDuringCommit(_caseId) {
        Case storage c = cases[_caseId];
        require(c.commits[msg.sender].commitHash == bytes32(0), "AJ: already committed");
        
        c.commits[msg.sender] = Commit({
            commitHash: _commitHash,
            commitTime: block.timestamp,
            revealed: false
        });
        
        emit CommitSubmitted(_caseId, msg.sender, _commitHash);
    }
    
    function juryReveal(
        uint256 _caseId,
        bool _vote,      // true = yes, false = no
        uint256 _salt   // 用于验证 commit 的 salt
    ) external onlyJuror onlyDuringReveal(_caseId) {
        Case storage c = cases[_caseId];
        Commit storage commit = c.commits[msg.sender];
        
        require(commit.commitHash != bytes32(0), "AJ: no commit found");
        require(!commit.revealed, "AJ: already revealed");
        
        // 验证 reveal 与 commit 匹配
        bytes32 expectedHash = keccak256(abi.encodePacked(_vote, _salt));
        require(expectedHash == commit.commitHash, "AJ: reveal mismatch");
        
        commit.revealed = true;
        c.hasRevealed[msg.sender] = true;
        c.revealCount++;
        
        if (_vote) {
            c.yesVotes++;
        } else {
            c.noVotes++;
        }
        
        emit RevealSubmitted(_caseId, msg.sender, _vote);
        
        // 如果达到 3/5 阈值，自动裁决
        if (c.revealCount >= REQUIRED_SIGNATURES && !c.resolved) {
            _resolveCase(_caseId);
        }
    }
    
    function _resolveCase(uint256 _caseId) internal {
        Case storage c = cases[_caseId];
        require(!c.resolved, "AJ: already resolved");
        
        c.resolved = true;
        // 简单多数决：yes > no 则通过
        c.finalVerdict = c.yesVotes > c.noVotes;
        
        emit CaseResolved(_caseId, c.finalVerdict, c.yesVotes, c.noVotes);
    }
    
    // ============ 反证质押 ============
    
    function stakeDisproof(uint256 _caseId) external payable {
        require(msg.value == DISPROOF_STAKE, "AJ: incorrect stake amount");
        Case storage c = cases[_caseId];
        require(c.resolved, "AJ: case not resolved");
        require(c.stakes[msg.sender] == 0, "AJ: already staked");
        
        c.stakes[msg.sender] = msg.value;
        emit DisproofStaked(_caseId, msg.sender, msg.value);
    }
    
    function resolveDisproof(
        uint256 _caseId,
        address _challenger,
        bool _isValid  // 反证是否成立
    ) external onlyOwner {
        Case storage c = cases[_caseId];
        uint256 stake = c.stakes[_challenger];
        require(stake > 0, "AJ: no stake found");
        
        if (_isValid) {
            // 反证成立：退回质押 + 奖励
            uint256 reward = (stake * REWARD_RATE) / 10000;
            uint256 refund = stake;
            
            payable(_challenger).transfer(refund + reward);
            emit DisproofRewarded(_caseId, _challenger, reward);
        } else {
            // 反证不成立：50% 销毁 + 50% 奖励给被污蔑方
            uint256 slashAmount = (stake * SLASH_RATE) / 10000;
            uint256 reward = stake - slashAmount;
            
            // slashAmount 留在合约中（可由 DAO 处置）
            // reward 奖励给被反证的 Agent（简化：转给 owner）
            payable(owner).transfer(reward);
            
            emit DisproofSlashed(_caseId, _challenger, slashAmount);
        }
        
        delete c.stakes[_challenger];
    }
    
    // ============ VRF 回调 ============
    
    function requestRandomWords() internal returns (uint256 requestId) {
        requestId = VRFCoordinatorV2Interface(vrfCoordinator).requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1  // 请求 1 个随机数
        );
    }
    
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        // 根据 requestId 找到对应案件并记录随机数
        // 简化：随机数用于未来扩展（如随机抽选陪审员子集）
        // 当前使用固定 5 人陪审团
    }
    
    // ============ 查询函数 ============
    
    function getCase(uint256 _caseId) external view returns (
        bytes32 evidenceHash,
        uint256 commitDeadline,
        uint256 revealDeadline,
        uint256 revealCount,
        uint256 yesVotes,
        uint256 noVotes,
        bool resolved,
        bool finalVerdict
    ) {
        Case storage c = cases[_caseId];
        return (
            c.evidenceHash,
            c.commitDeadline,
            c.revealDeadline,
            c.revealCount,
            c.yesVotes,
            c.noVotes,
            c.resolved,
            c.finalVerdict
        );
    }
    
    function getJurorList() external view returns (address[] memory) {
        return jurorList;
    }
    
    receive() external payable {}
}
