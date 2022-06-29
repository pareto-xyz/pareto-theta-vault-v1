// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import {VaultMath} from "../libraries/VaultMath.sol";

/**
 * @notice Test contract to wrap around VaultMath.sol library
 */
contract TestVaultMath {
    function assetToShare(
        uint256 amount,
        uint256 sharePrice,
        uint8 decimals
    ) external pure returns (uint256) {
        return VaultMath.assetToShare(amount, sharePrice, decimals);
    }

    function shareToAsset(
        uint256 shares,
        uint256 sharePrice,
        uint8 decimals
    ) external pure returns (uint256) {
        return VaultMath.shareToAsset(shares, sharePrice, decimals);
    }
}