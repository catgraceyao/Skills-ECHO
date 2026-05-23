// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AgentReputation
 * @notice 信誉分双轨计算：硬准确率 70% + 软共识率 30%
 * @dev 基于 v0.4 文档 §4.5 信誉分双轨
 */
library AgentReputation {
    using Math for uint256;

    struct Reputation {
        uint256 hardAccuracy;      // 硬准确率：链上事实一致性（0-10000，basis points）
        uint256 softConsensus;     // 软共识率：市场/Agent共识一致性（0-10000）
        uint256 observationEnd;      // 观察期结束时间戳
        uint256 consecutiveCorrect;// 连续独行正确次数
        uint256 totalCases;        // 参与总案例数
        uint256 correctCases;      // 正确案例数
    }

    uint256 constant OBSERVATION_PERIOD = 30 days;
    uint256 constant HARD_WEIGHT = 7000;  // 70%
    uint256 constant SOFT_WEIGHT = 3000;  // 30%
    uint256 constant HIGH_INDEPENDENCE_THRESHOLD = 3; // 连续3次独行正确→高独立判断力

    /**
     * @notice 计算综合信誉分
     * @param rep Reputation 结构体
     * @return score 综合信誉分（0-10000）
     */
    function calculateScore(Reputation storage rep) internal view returns (uint256 score) {
        require(block.timestamp >= rep.observationEnd, "AR: observation period not ended");
        
        if (rep.totalCases == 0) return 0;
        
        // 硬准确率 = correctCases / totalCases
        uint256 hard = (rep.correctCases * 10000) / rep.totalCases;
        
        // 综合分 = 硬准确率 * 70% + 软共识率 * 30%
        score = (hard * HARD_WEIGHT + rep.softConsensus * SOFT_WEIGHT) / 10000;
        
        // 高独立判断力权重动态提升：连续3次独行正确额外+10%
        if (rep.consecutiveCorrect >= HIGH_INDEPENDENCE_THRESHOLD) {
            score = Math.min(score + 1000, 10000); // +10%，上限100%
        }
        
        return score;
    }

    /**
     * @notice 记录案例结果
     * @param rep Reputation 结构体
     * @param isCorrect 是否正确
     * @param isSoloCorrect 是否独行正确（其他Agent都错，只有你对）
     */
    function recordCase(Reputation storage rep, bool isCorrect, bool isSoloCorrect) internal {
        if (block.timestamp < rep.observationEnd) {
            // 观察期内只统计，不计入最终分
            return;
        }
        
        rep.totalCases++;
        if (isCorrect) {
            rep.correctCases++;
            if (isSoloCorrect) {
                rep.consecutiveCorrect++;
            } else {
                rep.consecutiveCorrect = 0;
            }
        } else {
            rep.consecutiveCorrect = 0;
        }
    }

    /**
     * @notice 初始化观察期
     */
    function startObservation(Reputation storage rep) internal {
        rep.observationEnd = block.timestamp + OBSERVATION_PERIOD;
    }
}
