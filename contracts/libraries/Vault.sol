// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

/**
 * Collection of constants and structs describing a theta vault
 */
library Vault {
    // Fees are 6-decimal places. For example: 20 * 10**6 = 20%
    uint256 internal constant FEE_MULTIPLIER = 10**6;

    /**
     * @param decimals is the decimals for vault shares
     * @param underlying is the underlying asset of options sold by vault
     */
    struct VaultParams {
        uint8 decimals;
        address underlying;
    }

    /**
     * @param round is the current round number
     * @param lockedAmount is the amount locked away for selling options
     * @param lastLockedAmount is the amount locked for selling options in
     *  in the previous round
     *  Used for calculating performance fee deduction
     * @param totalPending is the amount of asset to be used to mint 
     *  pTHETA tokens
     */
    struct VaultState {
        uint16 round;
        uint104 lockedAmount;
        uint104 lastLockedAmount;
        uint128 totalPending;
    }

    /**
     * @param round is the round number with a maximum of 65535 rounds
     *  Assuming round is 1 week, max is 1256 yrs
     * @param amount is the deposit amount with a max of 20 trillion ETH
     */
    struct DepositReceipt {
        uint16 round;
        uint104 amount;
        uint128 totalPending;
    }

    /**
     * @param round is the round number with a maximum of 65535 rounds
     * @param shares is the number of withdrawn shares
     */
    struct Withdrawal {
        uint16 round;
        uint128 shares;
    }
}