// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

/**
 * @title AgentJury
 * @notice Agent 陪审团：commit-reveal + VRF 抽选 + 3/5 多签
 * @dev 基于 X7 第三轮 checklist，两阶段开案 + 候选池 + caseId+msg.sender 绑 salt
 */
contract AgentJury is VRFConsumerBaseV2 {
    // ============ 状态变量 ============
    
    address public owner;
    address public daoTreasury;                     // DAO 国库地址（新增）
    
    // 候选池（新增：从候选池抽选，不是直接用 jurorList）
    address[] public juryCandidates;                // 陪审员候选池
    mapping(address => bool) public isCandidate;    // 是否在候选池
    
    uint256 public constant JURY_SIZE = 5;          // 陪审团规模
    uint256 public constant REQUIRED_SIGNATURES = 3; // 3/5 多签
    
    // VRF 配置
    address public vrfCoordinator;
    bytes32 public keyHash;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit = 200000;
    uint16 public requestConfirmations = 3;
    
    // 案件状态机（新增：两阶段开案）
    enum CaseState {
        PENDING_VRF,    // 等待 VRF 随机数
        COMMIT_OPEN,    // 可 commit
        REVEAL_OPEN,    // 可 reveal
        RESOLVED        // 已结案
    }
    
    struct Commit {
        bytes32 commitHash;    // keccak256(vote, salt, caseId, msg.sender)
        uint256 commitTime;
        bool revealed;
        uint256 salt;          // 存储 salt
    }
    
    struct Case {
        uint256 caseId;
        bytes32 evidenceHash;
        uint256 commitDeadline;
        uint256 revealDeadline;
        uint256 vrfRequestId;
        uint256 randomWord;
        CaseState state;                           // 案件状态（新增）
        mapping(address => Commit) commits;
        mapping(address => bool) hasRevealed;
        mapping(address => bool) eligibleJurors;   // 被选为本案陪审员（新增）
        address[] selectedJurors;                   // 选中的陪审员列表（新增）
        uint256 revealCount;
        uint256 yesVotes;
        uint256 noVotes;
        bool resolved;
        bool finalVerdict;
        mapping(address => uint256) stakes;        // 反证质押
        uint256 commitStake;
        mapping(address => uint256) jurorStakes;   // 各陪审员押金
    }
    
    mapping(uint256 => Case) public cases;
    uint256 public nextCaseId;
    mapping(uint256 => uint256) public requestIdToCase;
    
    // 押金配置
    uint256 public constant JURY_COMMIT_STAKE = 0.01 ether;
    
    // 未 reveal 记录（用于外部信誉系统）
    mapping(address => uint256) public unrevealedCount;
    
    // ============ 事件 ============
    
    event CaseOpened(uint256 indexed caseId, bytes32 evidenceHash);
    event JurorsSelected(uint256 indexed caseId, address[5] jurors, uint256 randomWord);  // 新增
    event CommitSubmitted(uint256 indexed caseId, address indexed juror, bytes32 commitHash);
    event RevealSubmitted(uint256 indexed caseId, address indexed juror, bool vote);
    event CaseResolved(uint256 indexed caseId, bool verdict, uint256 yesVotes, uint256 noVotes, string verdictType);  // 新增 verdictType
    event BondSlashed(uint256 indexed caseId, address indexed juror, uint256 amount);  // 改名（原 JurorPenalized）
    event DisproofStaked(uint256 indexed caseId, address indexed challenger, uint256 amount);
    event DisproofRewarded(uint256 indexed caseId, address indexed challenger, uint256 reward);
    event DisproofSlashed(uint256 indexed caseId, address indexed challenger, uint256 slashed);
    event CandidateAdded(address indexed juror);
    event CandidateRemoved(address indexed juror);
    
    // ============ 修饰器 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "AJ: not owner");
        _;
    }
    
    modifier onlyEligibleJuror(uint256 _caseId) {
        require(cases[_caseId].eligibleJurors[msg.sender], "AJ: not selected for this case");  // 新增
        _;
    }
    
    modifier onlyDuringCommit(uint256 _caseId) {
        require(cases[_caseId].state == CaseState.COMMIT_OPEN, "AJ: commit not open");  // 两阶段校验
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
        uint64 _subscriptionId,
        address _daoTreasury                    // 新增
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        owner = msg.sender;
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        daoTreasury = _daoTreasury;              // 初始化 DAO 国库
    }
    
    // ============ 候选池管理（新增）============
    
    function addCandidate(address _juror) external onlyOwner {
        require(!isCandidate[_juror], "AJ: already candidate");
        isCandidate[_juror] = true;
        juryCandidates.push(_juror);
        emit CandidateAdded(_juror);
    }
    
    function removeCandidate(address _juror) external onlyOwner {
        require(isCandidate[_juror], "AJ: not candidate");
        isCandidate[_juror] = false;
        for (uint i = 0; i < juryCandidates.length; i++) {
            if (juryCandidates[i] == _juror) {
                juryCandidates[i] = juryCandidates[juryCandidates.length - 1];
                juryCandidates.pop();
                break;
            }
        }
        emit CandidateRemoved(_juror);
    }
    
    // ============ 案件管理（两阶段开案）============
    
    function openCase(
        bytes32 _evidenceHash,
        uint256 _commitBlocks,
        uint256 _revealBlocks
    ) external onlyOwner returns (uint256 caseId) {
        caseId = nextCaseId++;
        Case storage c = cases[caseId];
        c.caseId = caseId;
        c.evidenceHash = _evidenceHash;
        c.commitDeadline = block.number + _commitBlocks;
        c.revealDeadline = c.commitDeadline + _revealBlocks;
        c.state = CaseState.PENDING_VRF;          // 阶段 A：等待 VRF
        
        // 请求 VRF 随机数
        c.vrfRequestId = requestRandomWords(caseId);
        
        emit CaseOpened(caseId, _evidenceHash);
        return caseId;
    }
    
    // ============ Commit-Reveal ============
    
    function juryCommit(
        uint256 _caseId,
        bytes32 _commitHash,  // keccak256(abi.encodePacked(vote, salt, caseId, msg.sender))
        uint256 _salt
    ) external payable onlyEligibleJuror(_caseId) onlyDuringCommit(_caseId) {
        Case storage c = cases[_caseId];
        require(c.commits[msg.sender].commitHash == bytes32(0), "AJ: already committed");
        require(msg.value == JURY_COMMIT_STAKE, "AJ: incorrect stake");
        
        // 弱 salt 防御（X7 checklist #1）
        require(_salt != 0, "AJ: salt cannot be zero");
        require(_salt > 1_000_000, "AJ: salt too weak");
        
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
        bool _vote,
        uint256 _salt
    ) external onlyEligibleJuror(_caseId) onlyDuringReveal(_caseId) {
        Case storage c = cases[_caseId];
        Commit storage commit = c.commits[msg.sender];
        
        require(commit.commitHash != bytes32(0), "AJ: no commit found");
        require(!commit.revealed, "AJ: already revealed");
        
        // commitHash 绑 caseId + msg.sender（X7 checklist #1）
        bytes32 expectedHash = keccak256(abi.encodePacked(_vote, _salt, _caseId, msg.sender));
        require(expectedHash == commit.commitHash, "AJ: reveal mismatch");
        require(_salt == commit.salt, "AJ: salt mismatch");
        
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
        
        // 提前满票可触发结案（但需等全部 reveal 或时间到）
        // 不自动结案，等 finalizeCase 外部调用
    }
    
    // 任何人可触发结案（X7 checklist #3）
    function finalizeCase(uint256 _caseId) external {
        Case storage c = cases[_caseId];
        require(c.state != CaseState.RESOLVED, "AJ: already resolved");
        require(
            c.revealCount == JURY_SIZE || block.number > c.revealDeadline,
            "AJ: not ready to finalize"
        );
        
        _resolveCase(_caseId);
    }
    
    function _resolveCase(uint256 _caseId) internal {
        Case storage c = cases[_caseId];
        require(c.state != CaseState.RESOLVED, "AJ: already resolved");
        
        c.state = CaseState.RESOLVED;
        c.resolved = true;
        
        // 先惩罚未 reveal 的陪审员（X7 checklist #2）
        _penalizeUnrevealed(_caseId);
        
        // 平票/不达 3 票直接 No（X7 checklist #3）
        if (c.yesVotes >= REQUIRED_SIGNATURES) {
            c.finalVerdict = true;
            emit CaseResolved(_caseId, true, c.yesVotes, c.noVotes, "Yes");
        } else {
            c.finalVerdict = false;
            emit CaseResolved(_caseId, false, c.yesVotes, c.noVotes, "No");
        }
    }
    
    // 未 reveal 惩罚（X7 checklist #2：50% 销毁 + 50% DAO 国库）
    function _penalizeUnrevealed(uint256 _caseId) internal {
        Case storage c = cases[_caseId];
        
        for (uint i = 0; i < c.selectedJurors.length; i++) {
            address juror = c.selectedJurors[i];
            Commit storage commit = c.commits[juror];
            
            if (commit.commitHash != bytes32(0) && !commit.revealed) {
                uint256 stake = c.jurorStakes[juror];
                if (stake > 0) {
                    c.jurorStakes[juror] = 0;
                    c.commitStake -= stake;
                    
                    // 50% 销毁（留在合约中）+ 50% 给 DAO 国库
                    uint256 treasuryAmount = stake / 2;
                    if (daoTreasury != address(0)) {
                        payable(daoTreasury).transfer(treasuryAmount);
                    }
                    
                    emit BondSlashed(_caseId, juror, stake);  // X7 checklist 事件名
                }
                unrevealedCount[juror]++;
            }
        }
    }
    
    // ============ 反证质押 ============
    
    function stakeDisproof(uint256 _caseId) external payable {
        require(msg.value == DISPROOF_STAKE, "AJ: incorrect stake");
        Case storage c = cases[_caseId];
        require(c.resolved, "AJ: case not resolved");
        require(c.stakes[msg.sender] == 0, "AJ: already staked");
        
        c.stakes[msg.sender] = msg.value;
        emit DisproofStaked(_caseId, msg.sender, msg.value);
    }
    
    function resolveDisproof(
        uint256 _caseId,
        address _challenger,
        bool _isValid
    ) external onlyOwner {
        Case storage c = cases[_caseId];
        uint256 stake = c.stakes[_challenger];
        require(stake > 0, "AJ: no stake found");
        
        if (_isValid) {
            uint256 reward = (stake * REWARD_RATE) / 10000;
            payable(_challenger).transfer(stake + reward);
            emit DisproofRewarded(_caseId, _challenger, reward);
        } else {
            uint256 slashAmount = (stake * SLASH_RATE) / 10000;
            uint256 reward = stake - slashAmount;
            payable(owner).transfer(reward);  // TODO: 改为被反证方地址
            emit DisproofSlashed(_caseId, _challenger, slashAmount);
        }
        
        delete c.stakes[_challenger];
    }
    
    // ============ VRF 回调（两阶段：抽选陪审员）============
    
    function requestRandomWords(uint256 _caseId) internal returns (uint256 requestId) {
        requestId = VRFCoordinatorV2Interface(vrfCoordinator).requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );
        requestIdToCase[requestId] = _caseId;
    }
    
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        uint256 caseId = requestIdToCase[_requestId];
        Case storage c = cases[caseId];
        require(c.state == CaseState.PENDING_VRF, "AJ: not pending VRF");
        
        c.randomWord = _randomWords[0];
        c.state = CaseState.COMMIT_OPEN;  // 阶段 B：commit 开放
        
        // 从候选池抽选 5 名陪审员（X7 checklist #4）
        _selectJurors(caseId, _randomWords[0]);
    }
    
    function _selectJurors(uint256 _caseId, uint256 _randomWord) internal {
        Case storage c = cases[_caseId];
        uint256 poolSize = juryCandidates.length;
        require(poolSize >= JURY_SIZE, "AJ: insufficient candidate pool");
        
        address[5] memory selected;
        bool[] memory used = new bool[](poolSize);
        
        for (uint i = 0; i < JURY_SIZE; i++) {
            uint256 idx = (_randomWord + i * 31) % poolSize;  // 31 是质数，打散分布
            while (used[idx]) {
                idx = (idx + 1) % poolSize;
            }
            used[idx] = true;
            selected[i] = juryCandidates[idx];
            c.eligibleJurors[juryCandidates[idx]] = true;
            c.selectedJurors.push(juryCandidates[idx]);
        }
        
        emit JurorsSelected(_caseId, selected, _randomWord);
    }
    
    // ============ 查询函数 ============
    
    function getCase(uint256 _caseId) external view returns (
        bytes32 evidenceHash,
        uint256 commitDeadline,
        uint256 revealDeadline,
        CaseState state,
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
            c.state,
            c.revealCount,
            c.yesVotes,
            c.noVotes,
            c.resolved,
            c.finalVerdict
        );
    }
    
    function getJuryCandidates() external view returns (address[] memory) {
        return juryCandidates;
    }
    
    function getSelectedJurors(uint256 _caseId) external view returns (address[] memory) {
        return cases[_caseId].selectedJurors;
    }
    
    receive() external payable {}
}
