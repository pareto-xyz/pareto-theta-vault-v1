// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Vault} from "./Vault.sol";
import {console} from "hardhat/console.sol";

library VaultMath {
    using SafeMath for uint256;

    /**
     * @notice Convert assets to shares via exchange rate
     * @param amount Amount of assets
     * @param sharePrice Price of one share in assets
     * @param decimals Decimals for asset
     * @return shares Amount of shares
     */
    function assetToShare(
        uint256 amount,
        uint256 sharePrice,
        uint8 decimals
    ) internal pure returns (uint256) {
        return amount.mul(10**decimals).div(sharePrice);
    }

    /**
     * @notice Convert shares to risky assets via exchange rate
     * @param shares Amount of shares
     * @param sharePrice Price of one share in risky assets
     * @param decimals Decimals for risky asset
     * @return amount Amount of risky assets
     */
    function shareToAsset(
        uint256 shares,
        uint256 sharePrice,
        uint8 decimals
    ) internal pure returns (uint256) {
        return shares.mul(sharePrice).div(10**decimals);
    }

    /**
     * @notice Returns the shares owned by the user using a receipt
     * @param depositReceipt User's deposit receipt
     * @param currRound Current round
     * @param sharePrice Price of one share in assets
     * @param decimals Decimals for asset
     * @return shares User's virtual balance of shares that are owed
     */
    function getSharesFromReceipt(
        Vault.DepositReceipt memory depositReceipt,
        uint16 currRound,
        uint256 sharePrice,
        uint8 decimals
    ) internal pure returns (uint256 shares) {
        if (depositReceipt.round > 0 && depositReceipt.round < currRound) {
            // If receipt is from earlier round, we need to add together shares
            // accumulated in the receipt and shares from current round
            // Shares stored in the receipt are updated over rounds
            uint256 newShares = assetToShare(
                depositReceipt.riskyToDeposit,
                sharePrice,
                decimals
            );
            // Added with shares from current round
            return uint256(depositReceipt.ownedShares).add(newShares);
        } else {
            // If receipt is from current round, shares from the current round
            // have already been added into the `ownedShares` attribute
            return depositReceipt.ownedShares;
        }
    }

    /**
     * @notice Returns the price of a single share in risky and stable asset
     * @param totalSupply Total supply of Pareto tokens
     * @param totalBalance Total supply of assets
     * @param pendingAmount Amount of asset set for minting
     * @param decimals Decimals for asset
     * @return price Price of shares in asset
     */
    function getSharePrice(
        uint256 totalSupply,
        uint256 totalBalance,
        uint256 pendingAmount,
        uint8 decimals
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
     * @notice Helper function to check number is uint32
     * @param num Unsigned integer with 256 bits
     */
    function assertUint32(uint256 num) internal pure {
        require(num <= type(uint32).max, "Overflow uint32");
    }

    /**
     * @notice Helper function to check number is uint104
     * @param num Unsigned integer with 256 bits
     */
    function assertUint104(uint256 num) internal pure {
        require(num <= type(uint104).max, "Overflow uint104");
    }

    /**
     * @notice Helper function to check number is uint128
     * @param num Unsigned integer with 256 bits
     */
    function assertUint128(uint256 num) internal pure {
        require(num <= type(uint128).max, "Overflow uint128");
    }
}
