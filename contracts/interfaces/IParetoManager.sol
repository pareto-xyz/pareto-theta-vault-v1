// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

interface IParetoManager {
    /**
     * @notice Price of one unit of stable token in risky using risky decimals
     * @dev Wrapper function around `_getOraclePrice`
     * @return price Amount of risky tokens for one unit of stable token
     */
    function getStableToRiskyPrice() external view returns (uint256);

    /**
     * @notice Price of one unit of risky token in stable using stable decimals
     * @dev Wrapper function around `_getOraclePrice`
     * @return price Amount of stable tokens for one unit of risky token
     */
    function getRiskyToStablePrice() external view returns (uint256);

    /**
     * @notice Return both stable-to-risky and risky-to-stable prices
     * @return stableToRiskyPrice Amount of risky tokens for one unit of stable token
     * @return riskyToStablePrice Amount of stable tokens for one unit of risky token
     */
    function getPrice()
        external
        view
        returns (uint256 stableToRiskyPrice, uint256 riskyToStablePrice);

    /**
     * @notice Return decimals used by the Chainlink Oracle
     * @return decimals Oracle uses a precision of 10**decimals
     */
    function getOracleDecimals() external view returns (uint8);

    /**
     * @notice Computes the strike price for the next pool by a multiple of the current price.
     *         Requires an oracle for spot price
     * @dev Uses the same decimals as the stable token
     * @return strikePrice Relative price of risky in stable
     */
    function getNextStrikePrice() external view returns (uint128);

    /**
     * @notice Computes the volatility for the next pool
     * @dev Currently hardcoded to 80%.
     *      Optimal choice is to match realized volatility in market
     * @return sigma Estimate of implied volatility
     */
    function getNextVolatility() external pure returns (uint32);

    /**
     * @notice Computes the gamma (or 1 - fee) for the next pool
     * @dev Currently hardcoded to 0.95.
     *      Choosing gamma effects the quality of replication
     * @return gamma Gamma for the next pool
     */
    function getNextGamma() external pure returns (uint32);

    /**
     * @notice Computes the riskyForLp using oracle as spot price
     * @param spot Spot price in stable
     * @param strike Strike price in stable
     * @param sigma Implied volatility
     * @param tau Time to maturity in seconds.
     *            The conversion to years will happen within `MoreReplicationMath`
     * @param riskyDecimals Decimals for the risky asset
     * @param stableDecimals Decimals for the stable asset
     * @return riskyForLp R1 variable (in risky decimals)
     * @dev See page 14 of https://primitive.xyz/whitepaper-rmm-01.pdf.
     *      We cap the value within the range [0.1, 0.9]
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
     * @notice Computes the exchange rate between stable asset and RMM-01 LP token.
     *         Assumes that `riskyPerLp` has been precomputed
     * @param invariantX64 Invariant for the pool
     * @param riskyPerLp Amount of risky token to trade for 1 LP token
     * @param strike Strike price in stable
     * @param sigma Implied volatility
     * @param tau Time to maturity in seconds
     * @param riskyDecimals Decimals for the risky asset
     * @param stableDecimals Decimals for the stable asset
     * @return stableForLp Amount of stable token to trade for 1 LP token
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

    /// @notice Address for the risky asset
    function risky() external view returns (address);

    /// @notice Address for the stable asset
    function stable() external view returns (address);

    /// @notice Multiplier for strike selection as a percentage
    function strikeMultiplier() external view returns (uint256);
}
