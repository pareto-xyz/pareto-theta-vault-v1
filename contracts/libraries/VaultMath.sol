// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Vault} from "./Vault.sol";

library VaultMath {
    using SafeMath for uint256;

    // minimum amount of assets per share- prevents cold writes
    uint256 internal constant PLACEHOLDER_UINT = 1;

    /**
     * Convert assets to shares
     * --
     * @param assets is the amount of assets
     * @param assetPerShare is the price of one share in assets
     * @param decimals is the decimals for vault shares
     * --
     * @return shares is the amount of shares
     */
    function assetToShares(
        uint256 assets,
        uint256 assetPerShare,
        uint256 decimals
    ) internal pure returns (uint256) {
        require(assetPerShare > PLACEHOLDER_UINT, "Invalid assetPerShare");
        return assets.mul(10**decimals).div(assetPerShare);
    }

    /**
     * Convert shares to assets
     * --
     * @param shares is the amount of shares
     * @param assetPerShare is the price of one share in assets
     * @param decimals is the decimals for vault shares
     * --
     * @return assets is the amount of shares
     */
    function sharesToAsset(
        uint256 shares,
        uint256 assetPerShare,
        uint256 decimals
    ) internal pure returns (uint256) {
        require(assetPerShare > PLACEHOLDER_UINT, "Invalid assetPerShare");
        return shares.mul(assetPerShare).div(10**decimals);
    }

    /**
     * Returns the shares unredeemed by the user
     * These shares must roll over to the next vault
     * --
     * @param depositReceipt is the user's deposit receipt
     * @param currentRound is the `round` stored on the vault
     * @param assetPerShare is the price in asset per share
     * @param decimals is the number of decimals the asset/shares use
     * --
     * @return unredeemedShares is the user's virtual balance of shares that are owed
     */
    function getSharesFromReceipt(
        Vault.DepositReceipt memory depositReceipt,
        uint256 currentRound,
        uint256 assetPerShare,
        uint256 decimals
    ) internal pure returns (uint256 unredeemedShares) {
        if (depositReceipt.round > 0 && depositReceipt.round < currentRound) {
            // If receipt is from earlier round, compute shares value
            // This will be done using price from earlier round (not current price)
            uint256 currentShares = assetToShares(
                depositReceipt.amount,
                assetPerShare,
                decimals
            );
            // added with shares from current round
            return uint256(depositReceipt.unredeemedShares).add(currentShares);
        } else {
            // If receipt is from current round, return attribute
            return depositReceipt.unredeemedShares;
        }
    }

    /**
     * Returns the price of a single share in asset
     * --
     * @param totalSupply is the total supply of asset
     * @param totalBalance is the total supply of pTHETA
     * @param pendingAmount is the amount of asset promised for minting
     * @param decimals is the number of decimals the asset/shares use
     * --
     * @return the price of shares
     */
    function getSharePrice(
        uint256 totalSupply,
        uint256 totalBalance,
        uint256 pendingAmount,
        uint256 decimals
    ) internal pure returns (uint256) {
        uint256 oneShare = 10**decimals; // TODO: ???
        // 10**decimals * (balance - pending) / supply
        return
            totalSupply > 0
                ? oneShare.mul(totalBalance.sub(pendingAmount)).div(totalSupply)
                : oneShare;
    }

    /**
     * Helper function to assert number is uint104
     */
    function assertUint104(uint256 num) internal pure {
        require(num <= type(uint104).max, "Overflow uint104");
    }

    /**
     * Helper function to assert number is uint128
     */
    function assertUint128(uint256 num) internal pure {
        require(num <= type(uint128).max, "Overflow uint128");
    }
}
