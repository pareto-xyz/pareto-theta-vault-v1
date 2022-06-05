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
     * @param asset is the asset used in Theta Vault
     * @param minSupply is the minimum supply of vault shares issued
     *  For ETH, it is 10**10
     * @param maxSupply is the maximum supply of vault shares issued
     *  Consider removing this later
     */
    struct VaultParams {
        uint8 decimals;
        address asset;
        uint56 minSupply;
        uint104 maxSupply;
    }

    /**
     * @param nextOption is the address of the option the vault is shorting
     *  in the next cycle
     * @param currentOption is the address of the current option
     * @param nextOptionReadyAt is the timestamp when the `nextOption` can be
     *  used by the vault
     */
    struct OptionState {
        address nextOption;
        address currentOption;
        uint32 nextOptionReadyAt;
    }

    /**
     * @param round is the current round number
     * @param lockedAmount is the amount locked away for selling options
     * @param lastLockedAmount is the amount locked for selling options in
     *  in the previous round
     *  Used for calculating performance fee deduction
     * @param totalPending is the amount of asset to be used to mint
     *  pTHETA tokens
     * @param queuedWithdrawShares is the total amount of queued withdrawal
     *  shares from previous rounds (doesn't include the current round)
     */
    struct VaultState {
        uint16 round;
        uint104 lockedAmount;
        uint104 lastLockedAmount;
        uint128 totalPending;
        uint128 queuedWithdrawShares;
    }

    /**
     * @param round is the round number with a maximum of 65535 rounds
     *  Assuming round is 1 week, max is 1256 yrs
     * @param amount is the deposit amount with a max of 20 trillion ETH
     * @param unredeemedShares is the amount of unredeemed shares
     */
    struct DepositReceipt {
        uint16 round;
        uint104 amount;
        uint128 unredeemedShares;
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
