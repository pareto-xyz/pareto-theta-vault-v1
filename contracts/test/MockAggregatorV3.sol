// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

contract MockAggregatorV3 {
    /**
     * @notice Hardcoded answer to return
     */
    int256 public savedAnswer;
    uint80 public round = 1;

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function setLatestAnswer(int256 answer) public {
        savedAnswer = answer;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = round;
        answer = savedAnswer;
        // Spoof startedAt and updatedAt as current times
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        // Spoof as current round
        answeredInRound = round;
    }
}
