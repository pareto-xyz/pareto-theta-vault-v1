// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

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

    /**
     * @param decimals is the decimals for vault shares
     * @param strike is the strike price of the pool
     * @param sigma is the implied volatility of the pool
     * @param maturity is the timestamp when the option pool expires
     * @param gamma is the gamma of the pool (1 - fee)
     */
    struct OptionState {
        uint8 decimals;
        uint128 strike;
        uint32 sigma;
        uint32 maturity;
        uint32 gamma;
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
     * @param queuedWithdrawShares is the total amount of queued withdrawal
     *  shares from previous rounds (doesn't include the current round)
     * @param unusedRisky is the amount of risky asset leftover after
     *  minting shares
     * @param unusedStable is the amount of stable asset leftover
     *  after minting shares
     */
    struct VaultState {
        uint16 round;
        uint104 lockedRisky;
        uint104 lockedStable;
        uint128 pendingRisky;
        uint128 pendingStable;
        uint128 queuedWithdrawShares;
        uint128 unusedRisky;
        uint128 unusedStable;
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
