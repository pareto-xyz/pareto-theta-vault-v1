// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

interface IParetoManager {
    /**
     * @notice Query oracle for price of stable to risky asset
     */
    function getStableToRiskyPrice() external view returns (uint256);

    /**
     * @notice Query oracle for price of risky to stable asset
     */
    function getRiskyToStablePrice() external view returns (uint256);

    /**
     * @notice Query oracle for price of both stable to risky asset
     *  and the risky to stable asset
     */
    function getPrice()
        external
        view
        returns (uint256 stableToRiskyPrice, uint256 riskyToStablePrice);

    /**
     * @notice Query oracle for its decimals
     */
    function getOracleDecimals() external view returns (uint8);

    /**
     * @notice Compute next strike price using fixed multiplier
     */
    function getNextStrikePrice() external view returns (uint128);

    /**
     * @notice Compute next volatility using a constant for now
     */
    function getNextVolatility() external pure returns (uint32);

    /**
     * @notice Compute next fee for pool
     */
    function getNextGamma() external pure returns (uint32);

    /**
     * @notice Compute riskyForLp for RMM-01 pool creation
     * @return Risky reserve per liquidity with risky decimals
     */
    function getRiskyPerLp(
        uint256 spot,
        uint128 strike,
        uint32 sigma,
        uint256 tau,
        uint8 riskyDecimals,
        uint8 stableDecimals
    ) external view returns (uint256);

    /**
     * @notice Compute stableForLp for RMM-01 pool creation
     * @return Stable reserve per liquidity with stable decimals
     */
    function getStablePerLp(
        int128 invariantX64,
        uint256 riskyPerLp,
        uint128 strike,
        uint32 sigma,
        uint256 tau,
        uint8 riskyDecimals,
        uint8 stableDecimals
    ) external pure returns (uint256);

    /**
     * @notice Risky token of the risky / stable pair
     */
    function risky() external view returns (address);

    /**
     * @notice Stable token of the risky / stable pair
     */
    function stable() external view returns (address);

    /**
     * @notice Multiplier for strike price (2 decimal places)
     */
    function strikeMultiplier() external view returns (uint256);
}
