// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

import {VaultMath} from "../libraries/VaultMath.sol";

/*
 * Dummy contract to test a subset of functions in VaultMath
 */
contract TestVaultMath {
    function assetToShares(
        uint256 assets,
        uint256 sharePrice,
        uint256 decimals
    ) external pure returns (uint256) {
        return VaultMath.assetToShares(assets, sharePrice, decimals);
    }

    function sharesToAsset(
        uint256 shares,
        uint256 sharePrice,
        uint256 decimals
    ) external pure returns (uint256) {
        return VaultMath.sharesToAsset(shares, sharePrice, decimals);
    }
}