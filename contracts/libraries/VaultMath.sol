// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.6;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Vault} from "./Vault.sol";

library VaultMath {
    using SafeMath for uint256;

    /**
     * @notice Convert assets to shares.
     * @param amount is the amount of assets
     * @param sharePrice is the price of one share in assets
     * @param decimals is the decimals for asset
     * @return shares is the amount of shares
     */
    function assetToShare(
        uint256 amount,
        uint256 sharePrice,
        uint256 decimals
    ) internal pure returns (uint256) {
        return amount.mul(10**decimals).div(sharePrice);
    }

    /**
     * @notice Convert shares to risky assets
     * @param shares is the amount of shares
     * @param sharePrice is the price of one share in risky assets
     * @param decimals is the decimals for risky asset
     * @return amount is the amount of risky assets
     */
    function shareToAsset(
        uint256 shares,
        uint256 sharePrice,
        uint256 decimals
    ) internal pure returns (uint256) {
        return shares.mul(sharePrice).div(10**decimals);
    }

    /**
     * @notice Returns the shares unredeemed by the user
     * These shares must roll over to the next vault
     * @param depositReceipt is the user's deposit receipt
     * @param currRound is the `round` stored on the vault
     * @param sharePrice is the price of one share in assets
     * @param decimals is the decimals for asset
     * @return shares is the user's virtual balance of shares that are owed
     */
    function getSharesFromReceipt(
        Vault.DepositReceipt memory depositReceipt,
        uint16 currRound,
        uint256 sharePrice,
        uint256 decimals
    ) internal pure returns (uint256 shares) {
        if (depositReceipt.round > 0 && depositReceipt.round < currRound) {
            // If receipt is from earlier round, compute shares value
            // At max only one of these as continuously updated
            uint256 currShares = assetToShare(
                depositReceipt.riskyAmount,
                sharePrice,
                decimals
            );
            // added with shares from current round
            return uint256(depositReceipt.shares).add(currShares);
        } else {
            // If receipt is from current round, return directly
            return depositReceipt.shares;
        }
    }

    /**
     * @notice Returns the price of a single share in risky and stable asset
     * --
     * @param totalSupply is the total supply of Pareto tokens
     * @param totalBalance is the total supply of assets
     * @param pendingAmount is the amount of asset set for minting
     * @param decimals is the decimals for asset
     * --
     * @return price is the price of shares in asset
     */
    function getSharePrice(
        uint256 totalSupply,
        uint256 totalBalance,
        uint256 pendingAmount,
        uint256 decimals
    ) internal pure returns (uint256) {
        uint256 singleShare = 10**decimals;
        return
            totalSupply > 0
                ? singleShare.mul(totalBalance.sub(pendingAmount)).div(
                    totalSupply
                )
                : singleShare;
    }

    /**
     * Helper function to assert number is uint32
     */
    function assertUint32(uint256 num) internal pure {
        require(num <= type(uint32).max, "Overflow uint32");
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
