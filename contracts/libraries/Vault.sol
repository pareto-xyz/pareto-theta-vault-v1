// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

/**
 * @notice Collection of constants and structs describing a theta vault.
 * @dev Used thoroughly in `ParetoVault` and `ParetoManager`
 */
library Vault {
    /// @notice Fees are 6-decimal places. For example: 20 * 10**6 = 20%
    uint256 internal constant FEE_DECIMALS = 6;

    /**
     * @notice State of the current and next RMM-01 pool 
     * @param nextPoolId Primitive pool that the vault is depositing into next cycle
     * @param currPoolId Primitive pool that the vault is currently depositing into
     * @param currLiquidity Amount of liquidity deposited into the current pool
     * @param currPoolParams Black scholes parameters for the current pool
     * @param nextPoolParams Black scholes parameters for the next pool
     * @param nextPoolReadyAt The timestamp when the `nextPoolId` can be used by the vault
     */
    struct PoolState {
        bytes32 nextPoolId;
        bytes32 currPoolId;
        uint256 currLiquidity;
        PoolParams currPoolParams;
        PoolParams nextPoolParams;
        uint32 nextPoolReadyAt;
    }

    /**
     * @notice Parameters for tokens used in the vault
     * @param risky Address of the risky asset
     * @param stable Address of the stable asset
     * @param riskyDecimals Decimals for the risky asset
     * @param stableDecimals Decimals for the stable asset
     */
    struct TokenParams {
        address risky;
        address stable;
        uint8 riskyDecimals;
        uint8 stableDecimals;
    }

    /**
     * @notice Parameters of the RMM-01 pool
     * @param spotAtCreation Spot price at the time the pool was created
     *                       Used to compute `riskyPerLp` (and thus `stablePerLp`)
     * @param strike Strike price of the pool
     * @param sigma Implied volatility of the pool
     * @param maturity Timestamp when the option pool expires
     * @param gamma Gamma of the pool (1 - fee)
     * @param riskyPerLp Risky reserve per liquidity with risky decimals
     * @param stablePerLp Stable reserve per liq. with stable decimals
     * @dev The variable `RiskyPerLp` (R1) is computed as `R1 = 1 - N(d1)`.
     *      Also, `d1 = (ln(S/K)+(r*sigma^2/2))/sigma*sqrt(tau)`
     */
    struct PoolParams {
        uint128 spotAtCreation;
        uint128 strike;
        uint32 sigma;
        uint32 maturity;
        uint32 gamma;
        uint256 riskyPerLp;
        uint256 stablePerLp;
    }

    /**
     * @notice State used to override manager parameters for the next pool
     * @param manualStrike Manually specified strike price
     * @param manualStrikeRound Round of a manual strike
     * @param manualVolatility Manually specified IV
     * @param manualVolatilityRound Round of a manual IV
     * @param manualGamma Manually specified fee rate
     * @param manualGammaRound Round of a manual fee rate
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
     * @notice State of the vault, containing locked and pending assets 
     *         along with assets queued for withdrawal
     * @param round Current round number
     * @param lockedRisky Amount of risky asset locked away in a covered call short position
     * @param lockedStable Amount of stable asset locked away in a covered call short position
     * @param lastLockedRisky Amount of risky asset locked from last round.
     *                        Used to compute performance fee
     * @param lastLockedStable Amount of stable asset locked from last round.
                               Used to compute performance fee
     * @param pendingRisky Amount of risky asset to be used to mint receipt tokens
     * @param lastQueuedWithdrawRisky Amount of risky asset received from withdrawal last round 
     * @param lastQueuedWithdrawStable Amount of stable asset received from withdrawal last round
     * @param currQueuedWithdrawShares Amount of shares locked for withdrawal this round
     * @param totalQueuedWithdrawShares Amount of shares locked for withdrawal over all users
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
     * @notice Receipt given to users after a deposit
     * @param round Round number with a maximum of 65535 rounds.
     *              Assuming round is 1 week, max is 1256 yrs
     * @param riskyToDeposit Amount of the risky asset to be converted into shares at rollover
     * @param ownedShares Amount of shares owned by user from depositing in past rounds
     */
    struct DepositReceipt {
        uint16 round;
        uint104 riskyToDeposit;
        uint128 ownedShares;
    }

    /**
     * @notice Structure that keeps track of when to and how much shares to withdraw
     * @param round Round number with a maximum of 65535 rounds
     * @param shares Number of withdrawn shares
     */
    struct PendingWithdraw {
        uint16 round;
        uint128 shares;
    }

    /**
     * @notice Input structure to compute fees
     * @param currRisky Balance of risky assets in vault
     * @param currStable Balance of stable assets in vault
     * @param lastLockedRisky Amount of risky assets locked from last round
     * @param lastLockedStable Amount of stable assets locked from last round
     * @param pendingRisky Pending deposit amount of risky asset
     * @param managementFeePercent Fee percent on the AUM in both assets
     * @param performanceFeePercent Fee percent on the premium in both assets
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
     * @notice Input structure to the `_checkVaultSuccess` function
     * @param preVaultRisky Amount of risky token the vault owns at the start of the round
     * @param preVaultStable Amount of stable token the vault owns at the start of the round
     * @param postVaultRisky Amount of risky token the vault owns at the end of the round
     * @param postVaultStable Amount of stable token the vault owns at the end of the round
     */
    struct VaultSuccessInput {
        uint256 preVaultRisky;
        uint256 preVaultStable;
        uint256 postVaultRisky;
        uint256 postVaultStable;
    }

    /**
     * @notice Parameters for the Uniswap swap AMM
     * @param router Address for the Uniswap router contract
     * @param poolFee Fee for the uniswap pool to search for when making a swap
     */
    struct UniswapParams {
        address router;
        uint24 poolFee;
    }

    /**
     * @notice Parameters for the Primitive contracts
     * @param manager Address for the Primitive manager contract
     * @param engine Address for the Primitive engine contract
     * @param factory Address for the Primitive factory contract
     * @param decimals Decimals for Primitive liquidity
     */
    struct PrimitiveParams {
        address manager;
        address engine;
        address factory;
        uint8 decimals;
    }
}
