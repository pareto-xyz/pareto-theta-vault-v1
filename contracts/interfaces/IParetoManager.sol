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
     * @notice Computes the strike price for the next pool by back-deriving strike
     *         from a known delta, implied volatility, and spot price
     * @dev Uses the same decimals as the stable token
     * @param spot Spot price for risky in terms of stable asset
     * @param delta Black Scholes delta
     * @param sigma Implied volatility
     * @param tau Time to maturity in seconds.
     *            The conversion to years will happen within `MoreReplicationMath`
     * @param stableDecimals Decimals for the stable asset
     * @return strikePrice Relative price of risky in stable
     */
    function getNextStrikePrice(
        uint256 spot,
        uint32 delta,
        uint32 sigma,
        uint256 tau,
        uint8 stableDecimals
    ) external pure returns (uint128);

    /**
     * @notice Computes the volatility for the next pool
     * @dev Currently hardcoded to 80%.
     *      Optimal choice is to match realized volatility in market
     * @return sigma Estimate of implied volatility
     */
    function getNextSigma() external pure returns (uint32);

    /**
     * @notice Computes the gamma (or 1 - fee) for the next pool
     * @dev Uses a pre-trained linear regression model to map (S/K, sigma) 
     *      to prediction of optimal fee. Returns gamma as 1 - that fee
     * @param spot Spot price for risky in terms of stable asset
     * @param strike Strike price for risky in terms of stable asset
     * @param sigma Implied volatility
     * @param stableDecimals Decimals for the stable asset
     * @return gamma Gamma for the next pool
     */
    function getNextGamma(
      uint256 spot,
      uint128 strike,
      uint32 sigma,
      uint8 stableDecimals
    ) external pure returns (uint32 gamma);

    /**
     * @notice Computes the Black Scholes delta value
     * @dev Currently hardcoded to 20%. A higher value is more risky
     * @return delta Delta for the Black-Scholes model
     */
    function getNextDelta() external pure returns (uint32);

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
}
