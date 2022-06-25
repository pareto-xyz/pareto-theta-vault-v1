// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

/**
 * @notice Collection of constants and structs describing a theta vault
 */
library Vault {
    // Fees are 6-decimal places. For example: 20 * 10**6 = 20%
    uint256 internal constant FEE_MULTIPLIER = 10**6;

    struct PoolState {
        // Primitive pool that the vault is depositing into next cycle
        bytes32 nextPoolId;
        // Primitive pool that the vault is currently depositing into
        bytes32 currPoolId;
        // Amount of liquidity deposited into the current pool
        uint256 currLiquidity;
        // Black scholes parameters for the current pool
        PoolParams currPoolParams;
        // Black scholes parameters for the next pool
        PoolParams nextPoolParams;
        // The timestamp when the `nextPoolId` can be used by the vault
        uint32 nextPoolReadyAt;
    }

    /**
     * @param strike is the strike price of the pool
     * @param sigma is the implied volatility of the pool
     * @param maturity is the timestamp when the option pool expires
     * @param gamma is the gamma of the pool (1 - fee)
     * @param riskyPerLp is the risky reserve per liq. with risky decimals,
     *  = 1 - N(d1), d1 = (ln(S/K)+(r*sigma^2/2))/sigma*sqrt(tau)
     * @param delLiquidity is the amount of liquidity to allocate to the curve
     * wei value with 18 decimals of precision
     */
    struct PoolParams {
        uint128 strike;
        uint32 sigma;
        uint32 maturity;
        uint32 gamma;
        uint256 riskyPerLp;
        uint256 delLiquidity;
    }

    /**
     * @param manualStrike is a manually specified strike price
     * @param manualStrikeRound is the round of a manual strike
     * @param manualVolatility is a manually specified IV
     * @param manualVolatilityRound is the round of a manual IV
     * @param manualGamma is a manually specified fee rate
     * @param manualGammaRound is the round of a manual fee rate
     */
    struct ManagerState {
        uint128 manualStrike;
        uint16 manualStrikeRound;
        uint32 manualVolatility;
        uint16 manualVolatilityRound;
        uint32 manualGamma;
        uint16 manualGammaRound;
    }

    /**
     * @param round is the current round number
     * @param lockedRisky is the amount of risky asset locked away in
     *  a covered call short position
     * @param lockedStable is the amount of stable asset locked away in
     *  a covered call short position
     * @param lastLockedRisky is the amount of risky asset locked from last
     *  round; used to compute performance fee
     * @param lastLockedStable is the amount of stable asset locked from last
     *  round; used to compute performance fee
     * @param pendingRisky is the amount of risky asset to be used to mint
     *  receipt tokens
     * @param lastQueuedWithdrawRisky is the qmount of risky asset locked for
     *  withdrawal last vault
     * @param lastQueuedWithdrawStable is the amount of stable asset locked for
     *  withdrawal last vault
     * @param currQueuedWithdrawShares is the amount of shares locked for
     *  withdrawal currently
     * @param totalQueuedWithdrawShares is the amount of shares locked for
     *  withdrawal in all previous rounds (not including current)
     */
    struct VaultState {
        uint16 round;
        uint104 lockedRisky;
        uint104 lockedStable;
        uint104 lastLockedRisky;
        uint104 lastLockedStable;
        uint128 pendingRisky;
        uint256 lastQueuedWithdrawRisky;
        uint256 lastQueuedWithdrawStable;
        uint256 currQueuedWithdrawShares;
        uint256 totalQueuedWithdrawShares;
    }

    /**
     * @param round is the round number with a maximum of 65535 rounds
     *  Assuming round is 1 week, max is 1256 yrs
     * @param riskyAmount is the deposit amount of the risky asset
     * @param shares is the amount of shares owned by user
     */
    struct DepositReceipt {
        uint16 round;
        uint104 riskyAmount;
        uint128 shares;
    }

    /**
     * @param round is the round number with a maximum of 65535 rounds
     * @param shares is the number of withdrawn shares
     */
    struct PendingWithdraw {
        uint16 round;
        uint128 shares;
    }

    /**
     * @param currRisky is the balance of risky assets in vault
     * @param currStable is the balance of stable assets in vault
     * @param lastLockedRisky is the amount of risky assets locked from last round
     * @param lastLockedStable is the amount of stable assets locked from last round
     * @param pendingRisky is the pending deposit amount of risky asset
     * @param managementFeePercent is the fee percent on the AUM in both assets
     * @param performanceFeePercent is the fee percent on the premium in both assets
     */
    struct FeeCalculatorInput {
        uint256 currRisky;
        uint256 currStable;
        uint256 lastLockedRisky;
        uint256 lastLockedStable;
        uint256 pendingRisky;
        uint256 managementFeePercent;
        uint256 performanceFeePercent;
    }

    /**
     * @param router is the address for the Uniswap router contract
     * @param poolFee for swaps in uniswap pool to search for
     */
    struct UniswapParams {
        address router;
        uint24 poolFee;
    }

    /**
     * @param manager is the address for the Primitive manager contract
     * @param engine is the address for the Primitive engine contract
     */
    struct PrimitiveParams {
        address manager;
        address engine;
    }
}
