// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Vault} from "../libraries/Vault.sol";
import {VaultLifecycle} from "../libraries/VaultLifecycle.sol";
import {VaultMath} from "../libraries/VaultMath.sol";
import {ParetoVault} from "./ParetoVault.sol";

/**
 * TODO: Add upgradeable storage for this to inherit from.
 */
contract ParetoThetaVault is ParetoVault {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using VaultMath for Vault.DepositReceipt;

    /************************************************
     *  VAULT OPERATIONS
     ***********************************************/

    /**
     * @notice Requests a withdraw that is processed after the current round
     * --
     * @param shares is the number of shares to withdraw
     */
    function requestWithdraw(uint256 shares) external nonReentrant {
        _requestWithdraw(shares);
        // Update global variable caching shares queued for withdrawal
        queuedWithdrawShares = queuedWithdrawShares.add(shares);
    }

    /**
     * @notice Completes a requested withdraw from past round.
     */
    function completeWithdraw() external nonReentrant {
        (uint256 withdrawRisky, uint256 withdrawStable) = _completeWithdraw();
        // Update globals caching withdrawal amounts from last round
        lastQueuedWithdrawRisky = uint128(
            uint256(lastQueuedWithdrawRisky).sub(withdrawRisky)
        );
        lastQueuedWithdrawStable = uint128(
            uint256(lastQueuedWithdrawStable).sub(withdrawStable)
        );
    }

    /**
     * @notice Roll's the vault's funds into the next vault
     */
    function rollToNextOption() external onlyKeeper nonReentrant {
        _rollToNextOption(
            lastQueuedWithdrawRisky,
            lastQueuedWithdrawStable,
            queuedWithdrawShares
        )
    }
}