// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.6;

interface IParetoManager {
    function getNextStrikePrice() external view returns (uint128);

    function getNextVolatility() external view returns (uint32);

    function getNextGamma() external view returns (uint32);
}
