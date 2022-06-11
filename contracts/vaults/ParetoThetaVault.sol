// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Vault} from "../libraries/Vault.sol";
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
        vaultState.totalQueuedWithdrawShares = 
            vaultState.totalQueuedWithdrawShares.add(shares);
    }

    /**
     * @notice Completes a requested withdraw from past round.
     */
    function completeWithdraw() external nonReentrant {
        (uint256 withdrawRisky, uint256 withdrawStable) = _completeWithdraw();
        // Update globals caching withdrawal amounts from last round
        vaultState.lastQueuedWithdrawRisky = 
            vaultState.lastQueuedWithdrawRisky.sub(withdrawRisky);
        vaultState.lastQueuedWithdrawStable = 
            vaultState.lastQueuedWithdrawStable.sub(withdrawStable);
    }

    /**
     * @notice Roll's the vault's funds into the next vault
     */
    function rollToNextOption() external onlyKeeper nonReentrant {
        (
            uint256 lockedRisky,
            uint256 lockedStable,
            uint256 queuedWithdrawRisky,
            uint256 queuedWithdrawStable
        ) = 
            _rollToNextOption();
        
        // Queued withdraws from current round are set to last round
        vaultState.lastQueuedWithdrawRisky = queuedWithdrawRisky;
        vaultState.lastQueuedWithdrawStable = queuedWithdrawStable;

        // Add queued withdraw shares for current round to cache and 
        // reset current queue to zero
        uint256 totalQueuedWithdrawShares = 
            vaultState.totalQueuedWithdrawShares.add(
                vaultState.currQueuedWithdrawShares
            );
        vaultState.totalQueuedWithdrawShares = totalQueuedWithdrawShares;
        vaultState.currQueuedWithdrawShares = 0;

        // Update locked balances
        VaultMath.assertUint104(lockedRisky);
        VaultMath.assertUint104(lockedStable);
        vaultState.lockedRisky = uint104(lockedRisky);
        vaultState.lockedStable = uint104(lockedStable);

        // TODO do actual option creation
    }
}