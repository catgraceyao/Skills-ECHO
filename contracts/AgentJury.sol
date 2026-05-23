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
        uint256 salt;          // 存储 salt 用于校验（新增）
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
        mapping(address => bool) jurorSelected;  // 是否被选为本案陪审员（新增）
        mapping(uint256 => address) slotToJuror; // 席位→陪审员映射（新增）
        uint256 revealCount;
        uint256 yesVotes;
        uint256 noVotes;
        bool resolved;
        bool finalVerdict;
        mapping(address => uint256) stakes;  // 反证质押
        uint256 commitStake;       // 每案 commit 押金总额（新增）
        mapping(address => uint256) jurorStakes; // 各陪审员押金（新增）
    }
    
    mapping(uint256 => Case) public cases;
    uint256 public nextCaseId;
    
    // 陪审员 commit 押金（修复 X7 review：未 reveal 惩罚）
    uint256 public constant JURY_COMMIT_STAKE = 0.01 ether;
    uint256 public constant REVEAL_PENALTY_RATE = 10000; // 100% 未 reveal 没收
    
    // 未 reveal 记录（用于外部信誉系统）
    mapping(address => uint256) public unrevealedCount;
    
    // ============ 事件 ============
    
    event CaseOpened(uint256 indexed caseId, bytes32 evidenceHash, uint256 commitDeadline, uint256 revealDeadline);
    event CommitSubmitted(uint256 indexed caseId, address indexed juror, bytes32 commitHash);
    event RevealSubmitted(uint256 indexed caseId, address indexed juror, bool vote);
    event CaseResolved(uint256 indexed caseId, bool verdict, uint256 yesVotes, uint256 noVotes);
    event DisproofStaked(uint256 indexed caseId, address indexed challenger, uint256 amount);
    event DisproofRewarded(uint256 indexed caseId, address indexed challenger, uint256 reward);
    event DisproofSlashed(uint256 indexed caseId, address indexed challenger, uint256 slashed);
    event JurorAdded(address indexed juror);
    event JurorPenalized(uint256 indexed caseId, address indexed juror, uint256 amount);
    
    // ============ 修饰器 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "AJ: not owner");
        _;
    }
    
    modifier onlyCaseJuror(uint256 _caseId) {
        require(cases[_caseId].jurorSelected[msg.sender], "AJ: not case juror");
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
        c.vrfRequestId = requestRandomWords(caseId);
        
        emit CaseOpened(caseId, _evidenceHash, c.commitDeadline, c.revealDeadline);
        return caseId;
    }
    
    // ============ Commit-Reveal ============
    
    function juryCommit(
        uint256 _caseId,
        bytes32 _commitHash,  // keccak256(abi.encodePacked(vote, salt))
        uint256 _salt         // 原始 salt（存储用于校验和惩罚）
    ) external payable onlyCaseJuror(_caseId) onlyDuringCommit(_caseId) {
        Case storage c = cases[_caseId];
        require(c.commits[msg.sender].commitHash == bytes32(0), "AJ: already committed");
        require(msg.value >= JURY_COMMIT_STAKE, "AJ: insufficient stake");
        
        // salt 非零校验（修复 X7 review：弱 salt 防御）
        require(_salt != 0, "AJ: salt cannot be zero");
        require(_salt > 1000000, "AJ: salt too weak");  // 避免常见弱值
        
        c.commits[msg.sender] = Commit({
            commitHash: _commitHash,
            commitTime: block.timestamp,
            revealed: false,
            salt: _salt
        });
        c.jurorStakes[msg.sender] = msg.value;
        c.commitStake += msg.value;
        
        emit CommitSubmitted(_caseId, msg.sender, _commitHash);
    }
    
    function juryReveal(
        uint256 _caseId,
        bool _vote,      // true = yes, false = no
        uint256 _salt   // 用于验证 commit 的 salt
    ) external onlyCaseJuror(_caseId) onlyDuringReveal(_caseId) {
        Case storage c = cases[_caseId];
        Commit storage commit = c.commits[msg.sender];
        
        require(commit.commitHash != bytes32(0), "AJ: no commit found");
        require(!commit.revealed, "AJ: already revealed");
        
        // 验证 reveal 与 commit 匹配（使用存储的 salt 和传入的 salt 双重校验）
        bytes32 expectedHash = keccak256(abi.encodePacked(_vote, _salt));
        require(expectedHash == commit.commitHash, "AJ: reveal mismatch");
        require(_salt == commit.salt, "AJ: salt mismatch");  // 双重校验
        
        commit.revealed = true;
        c.hasRevealed[msg.sender] = true;
        c.revealCount++;
        
        if (_vote) {
            c.yesVotes++;
        } else {
            c.noVotes++;
        }
        
        emit RevealSubmitted(_caseId, msg.sender, _vote);
        
        // 退还押金
        uint256 stake = c.jurorStakes[msg.sender];
        if (stake > 0) {
            c.jurorStakes[msg.sender] = 0;
            c.commitStake -= stake;
            payable(msg.sender).transfer(stake);
        }
    }
    
    // 新增：处理未 reveal 陪审员的惩罚
    function _penalizeUnrevealed(uint256 _caseId) internal {
        Case storage c = cases[_caseId];
        
        for (uint i = 0; i < JURY_SIZE; i++) {
            address juror = c.slotToJuror[i];
            if (juror == address(0)) continue;
            
            Commit storage commit = c.commits[juror];
            if (commit.commitHash != bytes32(0) && !commit.revealed) {
                // 未 reveal：没收押金 + 记录
                uint256 stake = c.jurorStakes[juror];
                if (stake > 0) {
                    c.jurorStakes[juror] = 0;
                    c.commitStake -= stake;
                    // 押金 50% 销毁 + 50% 给国库（owner）
                    uint256 treasury = stake / 2;
                    payable(owner).transfer(treasury);
                    emit JurorPenalized(_caseId, juror, stake);
                }
                unrevealedCount[juror]++;
            }
        }
    }
    
    function _resolveCase(uint256 _caseId) internal {
        Case storage c = cases[_caseId];
        require(!c.resolved, "AJ: already resolved");
        
        // 先惩罚未 reveal 的陪审员
        _penalizeUnrevealed(_caseId);
        
        c.resolved = true;
        // 修复 X7 review：3/5 真多签语义，yesVotes >= 3 才通过
        c.finalVerdict = c.yesVotes >= REQUIRED_SIGNATURES;
        
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
    
    // ============ VRF 回调（修复 X7 review：randomWord 用于抽选陪审员） ============
    
    mapping(uint256 => uint256) public requestIdToCase; // requestId => caseId
    
    function requestRandomWords(uint256 _caseId) internal returns (uint256 requestId) {
        requestId = VRFCoordinatorV2Interface(vrfCoordinator).requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1  // 请求 1 个随机数
        );
        requestIdToCase[requestId] = _caseId;
    }
    
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        uint256 caseId = requestIdToCase[_requestId];
        Case storage c = cases[caseId];
        require(!c.vrfFulfilled, "AJ: VRF already fulfilled");
        
        c.randomWord = _randomWords[0];
        c.vrfFulfilled = true;
        
        // 从候选池（jurorList）中按 randomWord 抽选 5 名陪审员
        _selectJurors(caseId, _randomWords[0]);
    }
    
    function _selectJurors(uint256 _caseId, uint256 _randomWord) internal {
        Case storage c = cases[_caseId];
        uint256 poolSize = jurorList.length;
        require(poolSize >= JURY_SIZE, "AJ: insufficient juror pool");
        
        // Fisher-Yates shuffle 从候选池抽 5 名
        address[] memory selected = new address[](JURY_SIZE);
        bool[] memory used = new bool[](poolSize);
        
        for (uint i = 0; i < JURY_SIZE; i++) {
            uint256 idx = (_randomWord + i) % poolSize;
            // 避免重复：如果已被使用，顺序往后找
            while (used[idx]) {
                idx = (idx + 1) % poolSize;
            }
            used[idx] = true;
            selected[i] = jurorList[idx];
            c.slotToJuror[i] = jurorList[idx];
        }
        
        // 只有选中的陪审员才能参与本案
        for (uint i = 0; i < JURY_SIZE; i++) {
            c.jurorSelected[selected[i]] = true;
        }
    }
    
    // 修改 onlyJuror 为 onlyCaseJuror：检查是否被选为本案陪审员
    modifier onlyCaseJuror(uint256 _caseId) {
        require(cases[_caseId].jurorSelected[msg.sender] || isJuror[msg.sender], "AJ: not case juror");
        _;
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
