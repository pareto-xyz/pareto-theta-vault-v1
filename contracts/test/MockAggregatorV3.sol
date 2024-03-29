// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MockAggregatorV3 {
    using SafeMath for uint256;

    /**
     * @notice Hardcoded answer to return
     */
    uint256 public savedAnswer;
    uint80 public round = 1;
    uint8 public decimals = 18;

    function setLatestAnswer(uint256 answer) public {
        savedAnswer = answer;
    }

    /**
     * @notice Set the new value for decimals
     * @dev This is purely for testing
     */
    function setDecimals(uint8 _decimals) public {
        savedAnswer = savedAnswer.div(10**decimals).mul(10**_decimals);
        decimals = _decimals;
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
        answer = int256(savedAnswer);
        // Spoof startedAt and updatedAt as current times
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        // Spoof as current round
        answeredInRound = round;
    }
}
