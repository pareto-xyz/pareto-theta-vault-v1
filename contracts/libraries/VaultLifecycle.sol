// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

// Standard imports from OpenZeppelin
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Relative imports
import {Vault} from "./Vault.sol";
import {VaultMath} from "./VaultMath.sol";

library VaultLifecycle {
    using SafeMath for uint256;

    /**
     * @notice Parameters for rollover
     * --
     * @param decimals is the decimals of the asset
     * @param totalRisky is the vault's total balance of risky
     * @param totalStable is the vault's total balance of stable
     * @param shareSupply is the vaults total balance of the receipt
     * @param performanceFee is the perf fee percent to charge on premiums
     * @param managementFee is the management fee percent to charge on the AUM
     * @param queuedWithdrawShares is amount of queued withdrawals from the
     *  current round
     */
    struct RolloverParams {
        uint256 decimals;
        uint256 totalRisky;
        uint256 totalStable;
        uint256 shareSupply;
        uint256 lastQueuedWithdrawRisky;
        uint256 lastQueuedWithdrawStable;
        uint256 managementFeeRisky;
        uint256 managementFeeStable;
        uint256 queuedWithdrawShares;
    }

    /**
     * @notice Calculate the shares to mint, new price per share, and amount of
     * funds to re-allocate as collateral for the new round
     * @notice totalVaultFee is only > 0 if the difference between last
     * week's and this week's vault > 0
     * --
     * @param vaultState is the storage variable
     * @param params is the rollover parameters passed to compute the next
     *  state
     * @return queuedWithdrawRisky is the amount of risky funds set aside
     *  for withdrawal
     * @return queuedWithdrawStable is the amount of stable funds set aside
     *  for withdrawal
     * @return newRiskyPrice is the risky price per share of the new round
     * @return newStablePrice is the stable price per share of the new round
     * @return mintShares is the amount of shares to mint from deposits
     * @return unusedRisky is the amount of risky asset that was not used
     *  in minting shares
     * @return unusedStable is the amount of stable asset that was not used
     *  in minting shares
     * @return vaultFeeRisky is the total fee on risky charged by vault
     * @return vaultFeeStable is the total fee on stable charged by vault
     */
    function rollover(
        Vault.VaultState storage vaultState,
        RolloverParams calldata params
    )
        external
        view
        returns (
            uint256 queuedWithdrawRisky,
            uint256 queuedWithdrawStable,
            uint256 newRiskyPrice,
            uint256 newStablePrice,
            uint256 mintShares,
            uint256 unusedRisky,
            uint256 unusedStable,
            uint256 vaultFeeRisky,
            uint256 vaultFeeStable
        )
    {
        uint256 currentRisky = params.totalRisky;
        uint256 currentStable = params.totalStable;
        uint256 riskyForVaultFees = currentRisky.sub(
            params.lastQueuedWithdrawRisky
        );
        uint256 stableForVaultFees = currentStable.sub(
            params.lastQueuedWithdrawStable
        );
        uint256 pendingRisky = vaultState.pendingRisky;
        uint256 pendingStable = vaultState.pendingStable;

        (vaultFeeRisky, vaultFeeStable) = VaultLifecycle.getVaultFees(
            riskyForVaultFees,
            stableForVaultFees,
            pendingRisky,
            pendingStable,
            params.managementFeeRisky,
            params.managementFeeStable
        );

        // Remove fee from assets
        currentRisky = currentRisky.sub(vaultFeeRisky);
        currentStable = currentStable.sub(vaultFeeStable);

        // Total amount of queued shares to withdraw from previous rounds
        uint256 lastQueuedWithdrawShares = vaultState.queuedWithdrawShares;

        {
            (newRiskyPrice, newStablePrice) = VaultMath.getSharePrice(
                params.shareSupply.sub(lastQueuedWithdrawShares),
                currentRisky.sub(params.lastQueuedWithdrawRisky),
                currentStable.sub(params.lastQueuedWithdrawStable),
                pendingRisky,
                pendingStable,
                params.decimals
            );
            Vault.SharePrice memory newSharePrice = Vault.SharePrice({
                riskyPrice: newRiskyPrice,
                stablePrice: newStablePrice
            });
            (uint256 newRisky, uint256 newStable) = VaultMath.sharesToAssets(
                params.queuedWithdrawShares,
                newSharePrice,
                params.decimals
            );
            queuedWithdrawRisky = params.lastQueuedWithdrawRisky.add(newRisky);
            queuedWithdrawStable = params.lastQueuedWithdrawStable.add(
                newStable
            );

            // Compute number of shares that can be minded using the
            // liquidity pending
            mintShares = VaultMath.assetsToShares(
                pendingRisky,
                pendingStable,
                newSharePrice,
                params.decimals
            );

            // Compute liquidity remaining as some rounding is required
            // to convert assets to shares
            (uint256 reconRisky, uint256 reconStable) = VaultMath
                .sharesToAssets(mintShares, newSharePrice, params.decimals);
            unusedRisky = pendingRisky.sub(reconRisky);
            unusedStable = pendingStable.sub(reconStable);
        }

        return (
            queuedWithdrawRisky,
            queuedWithdrawStable,
            newRiskyPrice,
            newStablePrice,
            mintShares,
            unusedRisky,
            unusedStable,
            vaultFeeRisky,
            vaultFeeStable
        );
    }

    /**
     * @notice Calculates performance and management fee for this week's round
     * --
     * @param currentRisky is the balance of risky assets in vault
     * @param currentStable is the balance of stable assets in vault
     * @param pendingRisky is the pending deposit amount of risky asset
     * @param pendingStable is the pending deposit amount of stable asset
     * @param managementFeeRisky is the fee percent on the risky asset
     * @param managementFeeStable is the fee percent on the stable asset
     * --
     * @return vaultFeeRisky is the fees awarded to owner in risky
     * @return vaultFeeStable is the fees awarded to owner in stable
     */
    function getVaultFees(
        uint256 currentRisky,
        uint256 currentStable,
        uint256 pendingRisky,
        uint256 pendingStable,
        uint256 managementFeeRisky,
        uint256 managementFeeStable
    ) internal pure returns (uint256, uint256) {
        uint256 riskyMinusPending = currentRisky > pendingRisky
            ? currentRisky.sub(pendingRisky)
            : 0;
        uint256 stableMinusPending = currentStable > pendingStable
            ? currentStable.sub(pendingStable)
            : 0;

        uint256 _vaultFeeRisky;
        uint256 _vaultFeeStable;

        // TODO: For future versions, we should consider a price oracle to
        // compute performance w/ conditional fees
        _vaultFeeRisky = managementFeeRisky > 0
            ? riskyMinusPending.mul(managementFeeRisky).div(
                100 * Vault.FEE_MULTIPLIER
            )
            : 0;
        _vaultFeeStable = managementFeeStable > 0
            ? stableMinusPending.mul(managementFeeStable).div(
                100 * Vault.FEE_MULTIPLIER
            )
            : 0;
        return (_vaultFeeRisky, _vaultFeeStable);
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
     * @param managementFeeRisky is the management fee percent for risky
     * @param managementFeeStable is the management fee percent for stable
     * @param tokenName is the name of the token
     * @param tokenSymbol is the symbol of the token
     * @param _vaultParams is the struct with vault general data
     */
    function verifyInitializerParams(
        address owner,
        address keeper,
        address feeRecipient,
        uint256 managementFeeRisky,
        uint256 managementFeeStable,
        string calldata tokenName,
        string calldata tokenSymbol,
        Vault.VaultParams calldata _vaultParams
    ) external pure {
        require(owner != address(0), "Empty owner address");
        require(keeper != address(0), "Empty keeper address");
        require(feeRecipient != address(0), "Empty feeRecipient address");
        require(
            managementFeeRisky < 100 * Vault.FEE_MULTIPLIER,
            "managementFeeRisky >= 100%"
        );
        require(
            managementFeeStable < 100 * Vault.FEE_MULTIPLIER,
            "managementFeeStable >= 100%"
        );
        require(bytes(tokenName).length > 0, "Empty tokenName");
        require(bytes(tokenSymbol).length > 0, "Empty tokenSymbol");
    }
}
