// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.6;

/**
 * @notice Collection of constants and structs describing a theta vault
 */
library Vault {
    // Fees are 6-decimal places. For example: 20 * 10**6 = 20%
    uint256 internal constant FEE_MULTIPLIER = 10**6;

    /**
     * @param decimals is the decimals for vault shares
     * @param risky is the risky asset used in Theta Vault
     * @param stable is the stable asset used in Theta Vault
     */
    struct VaultParams {
        uint8 decimals;
        address risky;
        address stable;
    }

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
     * @param currPoolId is the identifier of the pool
     * @param manualStrike is a manually specified strike price
     * @param manualStrikeRound is the round of a manual strike
     * @param manualVolatility is a manually specified IV
     * @param manualVolatilityRound is the round of a manual IV
     * @param manualGamma is a manually specified fee rate
     * @param manualGammaRound is the round of a manual fee rate
     * @param paretoManager is the address of a manager contract
     */
    struct DeployParams {
        bytes32 currPoolId;
        uint128 manualStrike;
        uint16 manualStrikeRound;
        uint32 manualVolatility;
        uint16 manualVolatilityRound;
        uint32 manualGamma;
        uint16 manualGammaRound;
        address paretoManager;
    }

    /**
     * @param round is the current round number
     * @param lockedRisky is the amount of risky asset locked away in
     *  a covered call short position
     * @param lockedStable is the amount of stable asset locked away in
     *  a covered call short position
     * @param pendingRisky is the amount of risky asset to be used to mint
     *  receipt tokens
     * @param pendingStable is the amount of stable asset to be used to
     *  mint receipt tokens
     * @param unusedRisky is the amount of risky asset leftover after
     *  minting shares
     * @param unusedStable is the amount of stable asset leftover
     *  after minting shares
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
        uint128 pendingRisky;
        uint128 pendingStable;
        uint128 unusedRisky;
        uint128 unusedStable;
        uint256 lastQueuedWithdrawRisky;
        uint256 lastQueuedWithdrawStable;
        uint256 currQueuedWithdrawShares;
        uint256 totalQueuedWithdrawShares;
    }

    /**
     * @param round is the round number with a maximum of 65535 rounds
     *  Assuming round is 1 week, max is 1256 yrs
     * @param risky is the deposit amount of the risky asset
     * @param stable is the deposit amount of the stable asset
     * @param shares is the awarded amount of shares
     */
    struct DepositReceipt {
        uint16 round;
        uint104 risky;
        uint104 stable;
        uint128 shares;
    }

    /**
     * @param round is the round number with a maximum of 65535 rounds
     * @param shares is the number of withdrawn shares (pTHETA tokens)
     */
    struct Withdrawal {
        uint16 round;
        uint128 shares;
    }
}
