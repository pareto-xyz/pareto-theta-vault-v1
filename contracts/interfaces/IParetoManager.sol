// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.6;

interface IParetoManager {
    function getOraclePrice(
        address risky, 
        address stable
    ) external pure returns (uint256);

    function getNextStrikePrice() external pure returns (uint128);

    function getNextVolatility() external pure returns (uint32);

    function getNextGamma() external pure returns (uint32);
}
