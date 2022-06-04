// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// Standard imports from OpenZeppelin
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Relative imports
import {Vault} from "./Vault.sol";

library VaultLifecycle {
    using SafeMath for uint256

    /**
     * Calculate the shares to mint, new price per share, and amount of 
     * funds to re-allocate as collateral for the new round
     */
    function rollover() {}

    /**
     * Opens a short position
     * Sells a covered call through a replicating market maker
     * --
     * @param assetAmount is the amount of asset to deposit
     * @param numeraireAmount is the amount of numeraire to deposit
     -- 
     * @return the LP token mint amount
     */
    function createShort(
        uint256 assetAmount,
        uint256 numeraireAmount,
    ) external returns (uint256) {
    }

    /**
     * Closes a short position
     * Burns LP token through a replicating market maker
     */
    function settleShort() external returns (uint256) {
    }

    /** 
     * Calculates performance and management fee for this week's round
     * --
     * @param currentBalance is the balance of funds in vault
     * @param lastLockedAmount is the amount of funds locked from previous round
     * @param pendingAmount is the pending deposit amount
     * @param performanceFeePercent is the performance fee percent
     * @param managementFeePercent is the management fee percent
     * --
     * @return performanceFeeInAsset is the performance fee
     * @return managementFeeInAsset is the management fee
     * @return vaultFee is the total fees (performance + management)
     */
    function getVaultFees(
        uint256 currentBalance,
        uint256 lastLockedAmount,
        uint256 pendingAmount,
        uint256 performanceFeePercent,
        uint256 managementFeePercent
    )
        internal 
        pure
        returns (
            uint256 performanceFeeInAsset,
            uint256 managementFeeInAsset,
            uint256 vaultFee
        )
    {
        // In the first rount, currentBalance = 0 and pendingAmount > 0
        // In this case, do not charge anything
        uint256 balanceMinusPending = 
            currentBalance > pendingAmount
                ? currentBalance.sub(pendingAmount)
                : 0;

        // Placeholder variables to return (default to 0)
        uint256 _performanceFeeInAsset;
        uint256 _managementFeeInAsset;
        uint256 _vaultFee;

        // Compute difference between last week's and this week's vault 
        // deposits (taking pending deposits and withdrawals into account)
        // If this difference is positive, fee > 0. If it is negative, 
        // that means the vault took a loss (option expired ITM)
        if (balanceMinusPending > lastLockedAmount) {
            _performanceFeeInAsset = performanceFeePercent > 0
                ? balanceMinusPending
                    .sub(lastLockedAmount)
                    .mul(performanceFeePercent)
                    .div(100 * Vault.FEE_MULTIPLIER)
                : 0;
            _managementFeeInAsset = managementFeePercent > 0
                ? balanceMinusPending
                    .mul(managementFeePercent)
                    .div(100 * Vault.FEE_MULTIPLIER)
                : 0;
            _vaultFee = _performanceFeeInAsset.add(_managementFeeInAsset);
        }

        return (_performanceFeeInAsset, _managementFeeInAsset, _vaultFee);
    }

    /************************************************
     *  Primitive Bindings
     ***********************************************/

    /**
     * Retrieve Primitives LP token
     * --
     * --
     @return lpToken is a address of an LP token
     */
    function getLPToken(
    ) internal returns (address) {
    }

    /** 
     * Deposits liquidity in exchange for a Primitive LP token. 
     * --
     * @param assetAmount is the amount of asset to deposit
     * @param numeraireAmount is the amount of numeraire to deposit
     */
    function deployLPToken(
        uint256 assetAmount,
        uint256 numeraireAmount,
    ) internal returns (uint256) {
    }

    /**
     * Burns an LP token in exchange for an amount of risky asset and 
     * numeraire.
     */
    function burnLPToken() internal returns (uint256, uint256)
    {
    }

    /**
     * Verify that the LP token has the correct parameters to prevent 
     * vulnerability to primitive contract changes
     * --
     * @param tokenAddress is the address of the Primitive LP token
     * @param vaultParams is the struct with info about the vault
     * @param USDC is the address of the usdc
     * @param delay is the delay between `commitAndClose` and `rollToNextOption`
     */
    function verifyLPToken(
        address tokenAddress,
        Vault.VaultParams storage vaultParams,
        address USDC,
        uint256 delay
    ) private view {
    }

    /************************************************
     *  Utilities
     ***********************************************/

    /**
     * Verify the params passed to ParetoVault.baseInitialize
     * --
     * @param owner is the owner of the vault with critical permissions
     * @param keeper is the keeper of the vault 
     * @param feeRecipient is the address to recieve vault performance and management fees
     * @param performanceFee is the perfomance fee percent
     * @param tokenName is the name of the token
     * @param tokenSymbol is the symbol of the token
     * @param _vaultParams is the struct with vault general data
     */
    function verifyInitializerParams(
        address owner,
        address keeper,
        address feeRecipient,
        uint256 performanceFee,
        uint256 managementFee,
        string calldata tokenName,
        string calldata tokenSymbol,
        Vault.VaultParams calldata _vaultParams
    ) external pure {
        require(owner != address(0), "Empty owner address");
        require(keeper != address(0), "Empty keeper address");
        require(feeRecipient != address(0), "Empty feeRecipient address");
        require(performanceFee < 100 * Vault.FEE_MULTIPLIER, "performanceFee >= 100%");
        require(managementFee < 100 * Vault.FEE_MULTIPLIER, "managementFee >= 100%");
        require(bytes(tokenName).length > 0, "Empty tokenName");
        require(bytes(tokenSymbol).length > 0, "Empty tokenSymbol");
        verifyVaultParams(_vaultParams);
    }

    /**
     * Helper function to verify vault params
     */
    function verifyVaultParams(Vault.VaultParams calldata _vaultParams) 
        external pure 
    {
        require(_vaultParams.minSupply > 0, "Empty minSupply");
        require(_vaultParams.maxSupply > 0, "Empty maxSupply");
    }

    /** 
     * Gets the next option expiry timestamp
     */
    function getNextExpiry(address currentOption) 
        internal view returns (uint256)
    {
    }

    /**
     * Get date of next friday
     * --
     * @param timestamp is the expiry timestamp of the current option
     * Reference: https://codereview.stackexchange.com/a/33532
     * --
     * @example getNextFriday(week 1 thursday) -> week 1 friday
     * @example getNextFriday(week 1 friday) -> week 2 friday
     * @example getNextFriday(week 1 saturday) -> week 2 friday
     */
    function getNextFriday(uint256 timestamp) internal pure returns (uint256) {
        // dayOfWeek = 0 (sunday) - 6 (saturday)
        uint256 dayOfWeek = ((timestamp / 1 days) + 4) % 7;
        uint256 nextFriday = timestamp + ((7 + 5 - dayOfWeek) % 7) * 1 days;
        uint256 friday8am = nextFriday - (nextFriday % (24 hours)) + (8 hours);

        // if the input `timestamp` is day=Friday, hour>8am, increment to next Friday
        if (timestamp >= friday8am) {
            friday8am += 7 days;
        }
        return friday8am;
    }
}