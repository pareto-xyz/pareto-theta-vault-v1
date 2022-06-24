// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

interface IParetoManager {
    /**
     * @notice Query oracle for price of risky to stable asset
     */
    function getOraclePrice() external view returns (uint256);

    /**
     * @notice Compute next strike price using fixed multiplier
     */
    function getNextStrikePrice() external view returns (uint256);

    /**
     * @notice Compute next volatility using a constant for now
     */
    function getNextVolatility() external view returns (uint256);

    /**
     * @notice Compute next fee for pool
     */
    function getNextGamma() external view returns (uint256);

    /**
     * @notice Risky token of the risky / stable pair
     * @return Address of the risky token contract
     */
    function risky() external view returns (address);

    /**
     * @notice Stable token of the risky / stable pair
     * @return Address of the stable token contract
     */
    function stable() external view returns (address);
}
