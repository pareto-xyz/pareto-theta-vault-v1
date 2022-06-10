// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Vault} from "./Vault.sol";

library VaultMath {
    using SafeMath for uint256;

    /**
     * @notice Convert assets to shares.
     * --
     * @param risky is the amount of risky assets
     * @param stable is the amount of stable assets
     * @param riskyPrice is the price of one share in risky assets
     * @param stablePrice is the price of one share in stable assets
     * @param decimals is the decimals for vault shares
     * --
     * @return shares is the amount of shares
     */
    function assetsToShares(
        uint256 risky,
        uint256 stable,
        uint256 riskyPrice,
        uint256 stablePrice,
        uint256 decimals
    ) internal pure returns (uint256) {
        return
            Math.min(
                risky.mul(10**decimals).div(riskyPrice),
                stable.mul(10**decimals).div(stablePrice)
            );
    }

    /**
     * @notice Convert shares to risky assets
     * --
     * @param shares is the amount of shares
     * @param sharePrice is the price of one share in assets
     * @param decimals is the decimals for vault shares
     * --
     * @return risky is the amount of risky assets
     * @return stable is the amount of stable assets
     */
    function sharesToAssets(
        uint256 shares,
        uint256 riskyPrice,
        uint256 stablePrice,
        uint256 decimals
    ) internal pure returns (uint256, uint256) {
        uint256 risky = shares.mul(riskyPrice).div(10**decimals);
        uint256 stable = shares.mul(stablePrice).div(10**decimals);
        return (risky, stable);
    }

    /**
     * @notice Returns the shares unredeemed by the user
     * These shares must roll over to the next vault
     * --
     * @param depositReceipt is the user's deposit receipt
     * @param currentRound is the `round` stored on the vault
     * @param sharePrice is the price in asset per share
     * @param decimals is the number of decimals the asset/shares use
     * --
     * @return shares is the user's virtual balance of shares that are owed
     */
    function getSharesFromReceipt(
        Vault.DepositReceipt memory depositReceipt,
        uint256 currentRound,
        uint256 riskyPrice,
        uint256 stablePrice,
        uint256 decimals
    ) internal pure returns (uint256 shares) {
        if (depositReceipt.round > 0 && depositReceipt.round < currentRound) {
            // If receipt is from earlier round, compute shares value
            // At max only one of these as continuously updated
            uint256 currShares = assetsToShares(
                depositReceipt.risky,
                depositReceipt.stable,
                riskyPrice,
                stablePrice,
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
     * @param totalSupply is the total supply of the receipt tokens
     * @param totalRisky is the total supply of risky assets
     * @param totalStable is the total supply of stable assets
     * @param pendingRisky is the amount of risky asset set for minting
     * @param pendingStable is the amount of risky asset set for minting
     * @param decimals is the number of decimals the asset/shares use
     * --
     * @return riskyPrice is the price of shares in risky asset
     * @return stablePrice is the price of shares in stable asset
     */
    function getSharePrice(
        uint256 totalSupply,
        uint256 totalRisky,
        uint256 totalStable,
        uint256 pendingRisky,
        uint256 pendingStable,
        uint256 decimals
    ) internal pure returns (uint256, uint256) {
        uint256 oneShare = 10**decimals;
        // 10**decimals * (balance - pending) / supply
        uint256 riskyPrice = totalSupply > 0
            ? oneShare.mul(totalRisky.sub(pendingRisky)).div(totalSupply)
            : oneShare;
        uint256 stablePrice = totalSupply > 0
            ? oneShare.mul(totalStable.sub(pendingStable)).div(totalSupply)
            : oneShare;
        return (riskyPrice, stablePrice);
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
