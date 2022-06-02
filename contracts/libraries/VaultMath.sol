// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

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
     * Helper function to assert number is uint104
     */
    function assertUint104(uint256 num) internal pure {
        require(num <= type(uint104).max, "Overflow uint104");
    }

    /**
     * Helper function to assert number is uint128
     */
    function assertUint256(uint256 num) internal pure {
        require(num <= type(uint128).max, "Overflow uint128");
    }
}