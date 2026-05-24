// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title GovernanceDAO
 * @notice 治理DAO：投票权重解耦、activityBoost衰减、MIN_MEMBERS=11
 * @dev 基于 v0.4 文档 §5.x
 * 修复：投票权重与势位引擎解耦、activityBoost衰减、公式完全公开
 */
contract GovernanceDAO {
    using Math for uint256;

    // ============ 常量 ============
    
    uint256 public daoMinMembers = 3;                   // 初始最小成员数 3，owner可调
    uint256 public constant DAO_MAX_MEMBERS = 21;          // 最大成员数
    uint256 public constant VOTE_DURATION = 7 days;        // 投票期
    uint256 public constant EXECUTE_DELAY = 12 hours;      // 执行延迟（6h→12h）
    uint256 public constant ACTIVITY_DECAY = 1000;         // 每次投票后衰减10%
    uint256 public constant MAX_ACTIVITY_BOOST = 2000;     // 最大activityBoost 20%
    uint256 public constant MIN_ACTIVITY_BOOST = 100;      // 最小activityBoost 1%
    
    // ============ 数据结构 ============
    
    struct Member {
        uint256 reputation;        // 信誉分（独立计算，不与势位引擎耦合）
        uint256 baseWeight;        // 基础权重
        uint256 activityBoost;     // 活跃度加成（可衰减）
        uint256 lastVoteTime;      // 上次投票时间
        bool active;               // 是否活跃
    }
    
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        bytes callData;
        address target;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
    }
    
    // ============ 状态变量 ============
    
    mapping(address => Member) public members;
    address[] public memberList;
    
    mapping(uint256 => Proposal) public proposals;
    uint256 public nextProposalId;
    
    address public owner;
    address public emergencyContract;
    address public potentialEngine;
    
    // ============ 事件 ============
    
    event MemberAdded(address indexed member, uint256 reputation);
    event MemberRemoved(address indexed member);
    event ProposalCreated(uint256 indexed id, address indexed proposer, string description);
    event VoteCast(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);
    event ProposalCancelled(uint256 indexed id);
    event ActivityBoostUpdated(address indexed member, uint256 newBoost);
    
    // ============ 修饰器 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "DAO: not owner");
        _;
    }
    
    modifier onlyMember() {
        require(members[msg.sender].active, "DAO: not member");
        _;
    }
    
    modifier onlyEmergency() {
        require(msg.sender == emergencyContract, "DAO: not emergency");
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor() {
        owner = msg.sender;
    }
    
    function setDaoMinMembers(uint256 _newMin) external onlyOwner {
        require(_newMin >= 3 && _newMin <= DAO_MAX_MEMBERS, "DAO: invalid min members");
        daoMinMembers = _newMin;
    }
    
    function setEmergencyContract(address _emergency) external onlyOwner {
        emergencyContract = _emergency;
    }
    
    function setPotentialEngine(address _pe) external onlyOwner {
        potentialEngine = _pe;
    }
    
    // ============ 成员管理 ============
    
    function addMember(address _member, uint256 _reputation, uint256 _baseWeight) external onlyOwner {
        require(!members[_member].active, "DAO: already member");
        require(memberList.length < DAO_MAX_MEMBERS, "DAO: max members reached");
        require(_reputation <= 10000, "DAO: invalid reputation");
        
        members[_member] = Member({
            reputation: _reputation,
            baseWeight: _baseWeight,
            activityBoost: MAX_ACTIVITY_BOOST,
            lastVoteTime: 0,
            active: true
        });
        memberList.push(_member);
        
        emit MemberAdded(_member, _reputation);
    }
    
    function removeMember(address _member) external onlyOwner {
        require(members[_member].active, "DAO: not member");
        members[_member].active = false;
        
        for (uint i = 0; i < memberList.length; i++) {
            if (memberList[i] == _member) {
                memberList[i] = memberList[memberList.length - 1];
                memberList.pop();
                break;
            }
        }
        
        emit MemberRemoved(_member);
    }
    
    // ============ 投票权重计算（完全公开公式） ============
    
    function calculateWeight(address _member) public view returns (uint256) {
        Member storage m = members[_member];
        if (!m.active) return 0;
        
        // 权重 = 基础权重 * (1 + 信誉加成 + 活跃度加成)
        // 信誉加成 = reputation / 10000（最高100%）
        // 活跃度加成 = activityBoost / 10000（可衰减，最高20%）
        // 公式完全公开，与势位引擎解耦
        
        uint256 reputationBonus = m.reputation;  // 0-10000
        uint256 activityBonus = m.activityBoost; // 0-2000
        
        uint256 totalBonus = reputationBonus + activityBonus;
        uint256 weight = (m.baseWeight * (10000 + totalBonus)) / 10000;
        
        return weight;
    }
    
    // ============ activityBoost衰减 ============
    
    function _decayActivityBoost(address _member) internal {
        Member storage m = members[_member];
        if (!m.active) return;
        
        // 每次投票后衰减10%
        uint256 newBoost = (m.activityBoost * (10000 - ACTIVITY_DECAY)) / 10000;
        if (newBoost < MIN_ACTIVITY_BOOST) {
            newBoost = MIN_ACTIVITY_BOOST;
        }
        m.activityBoost = newBoost;
        
        emit ActivityBoostUpdated(_member, newBoost);
    }
    
    // ============ 提案 ============
    
    function propose(
        string calldata _description,
        address _target,
        bytes calldata _callData
    ) external onlyMember returns (uint256 id) {
        require(memberList.length >= daoMinMembers, "DAO: insufficient members");
        
        id = nextProposalId++;
        Proposal storage p = proposals[id];
        p.id = id;
        p.proposer = msg.sender;
        p.description = _description;
        p.target = _target;
        p.callData = _callData;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + VOTE_DURATION;
        
        emit ProposalCreated(id, msg.sender, _description);
        return id;
    }
    
    // ============ 投票 ============
    
    function vote(uint256 _proposalId, bool _support) external onlyMember {
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp <= p.endTime, "DAO: voting ended");
        require(!p.hasVoted[msg.sender], "DAO: already voted");
        require(!p.executed, "DAO: already executed");
        require(!p.cancelled, "DAO: cancelled");
        
        uint256 weight = calculateWeight(msg.sender);
        require(weight > 0, "DAO: zero weight");
        
        p.hasVoted[msg.sender] = true;
        
        if (_support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }
        
        // 衰减 activityBoost
        _decayActivityBoost(msg.sender);
        members[msg.sender].lastVoteTime = block.timestamp;
        
        emit VoteCast(_proposalId, msg.sender, _support, weight);
    }
    
    // ============ 执行 ============
    
    function execute(uint256 _proposalId) external onlyMember {
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp > p.endTime + EXECUTE_DELAY, "DAO: execute delay not met");
        require(!p.executed, "DAO: already executed");
        require(!p.cancelled, "DAO: cancelled");
        require(p.forVotes > p.againstVotes, "DAO: not passed");
        
        p.executed = true;
        
        // 执行调用
        (bool success, ) = p.target.call(p.callData);
        require(success, "DAO: execution failed");
        
        emit ProposalExecuted(_proposalId);
    }
    
    // ============ 紧急取消（仅紧急干预合约） ============
    
    function emergencyCancel(uint256 _proposalId) external onlyEmergency {
        Proposal storage p = proposals[_proposalId];
        require(!p.executed, "DAO: already executed");
        p.cancelled = true;
        emit ProposalCancelled(_proposalId);
    }
    
    // ============ 查询 ============
    
    function getMemberInfo(address _member) external view returns (
        uint256 reputation,
        uint256 baseWeight,
        uint256 activityBoost,
        uint256 lastVoteTime,
        bool active
    ) {
        Member storage m = members[_member];
        return (m.reputation, m.baseWeight, m.activityBoost, m.lastVoteTime, m.active);
    }
    
    function getProposal(uint256 _id) external view returns (
        uint256 id,
        address proposer,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        bool cancelled
    ) {
        Proposal storage p = proposals[_id];
        return (
            p.id,
            p.proposer,
            p.description,
            p.forVotes,
            p.againstVotes,
            p.startTime,
            p.endTime,
            p.executed,
            p.cancelled
        );
    }
    
    function getMemberCount() external view returns (uint256) {
        return memberList.length;
    }
    
    function hasVoted(uint256 _proposalId, address _member) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_member];
    }
}
