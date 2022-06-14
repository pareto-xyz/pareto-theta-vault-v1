// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
     * Non-upgradeable storage
     * TODO: some of these should probably be made upgradeable!
     ***********************************************/
    
    address public paretoManager;

    // Owner manually sets strike price
    uint128 public manualStrike;

    // Round that owner manually sets strike price
    uint16 public manualStrikeRound;

    // Owner manually sets implied volatility
    uint128 public manualVolatility;

    // Round that owner manually sets volatility
    uint16 public manualVolatilityRound;

    // Owner manually sets fee rate
    uint128 public manualGamma;

    // Round that owner manually sets fee rate
    uint16 public manualGammaRound;

    /************************************************
     * Events
     ***********************************************/

    event OpenPositionEvent(
        bytes32 poolId,
        uint256 depositRisky,
        uint256 depositStable,
        uint256 returnLiquidity,
        address indexed keeper
    );

    event ClosePositionEvent(
        bytes32 poolId,
        uint256 burnLiquidity,
        uint256 withdrawRisky,
        uint256 withdrawStable,
        address indexed keeper
    );

    event DeployVaultEvent(
        bytes32 poolId,
        uint128 strikePrice,
        uint32 volatility,
        uint32 gamma,
        address indexed keeper
    );

    /************************************************
     * Constructor and Initialization
     ***********************************************/
    
    /**
     * @notice Initialization parameters for the vault
     * --
     * @param _owner is the owner of the vault with critical permissions
     * @param _feeRecipient is the address to recieve vault performance and management fees
     * @param _managementFeeRisky is the management fee pct for risky assets
     * @param _managementFeeStable is the management fee pct for stable assets
     * @param _tokenName is the name of the token
     * @param _tokenSymbol is the symbol of the token
     * @param _paretoManager is the address of the Pareto Manager contract
     */
    struct InitParams {
        address _owner;
        address _keeper;
        address _feeRecipient;
        uint256 _managementFeeRisky;
        uint256 _managementFeeStable;
        string _tokenName;
        string _tokenSymbol;
        address _paretoManager;
    }

    /**
     * @notice Initialize the contract with storage variables
     * --
     * @param _initParams is the struct with vault initialization params
     * @param _vaultParams with general data about the vault
     */
    function initialize(
        InitParams calldata _initParams,
        Vault.VaultParams calldata _vaultParams
    ) external initializer {
        baseInitialize(
            _initParams._owner,
            _initParams._keeper,
            _initParams._feeRecipient,
            _initParams._managementFeeRisky,
            _initParams._managementFeeStable,
            _initParams._tokenName,
            _initParams._tokenSymbol,
            _vaultParams
        );
        require(_initParams._paretoManager != address(0), "!_paretoManager");
        paretoManager = _initParams._paretoManager;
    }

    /************************************************
     * Setters
     ***********************************************/
    
    /**
     * @notice Sets the new Pareto manager contract
     * @param newManager is the address of the new Pareto manager contract
     */
    function setParetoManager(address newManager) external onlyOwner {
        require(newManager != address(0), "!newManager");
        paretoManager = newManager;
    }

    /************************************************
     * Vault operations
     ***********************************************/

    /**
     * @notice Requests a withdraw that is processed after the current round
     * --
     * @param shares is the number of shares to withdraw
     */
    function requestWithdraw(uint256 shares) external nonReentrant {
        _requestWithdraw(shares);
        // Update global variable caching shares queued for withdrawal
        vaultState.totalQueuedWithdrawShares = vaultState
            .totalQueuedWithdrawShares
            .add(shares);
    }

    /**
     * @notice Completes a requested withdraw from past round.
     */
    function completeWithdraw() external nonReentrant {
        (uint256 withdrawRisky, uint256 withdrawStable) = _completeWithdraw();
        // Update globals caching withdrawal amounts from last round
        vaultState.lastQueuedWithdrawRisky = vaultState
            .lastQueuedWithdrawRisky
            .sub(withdrawRisky);
        vaultState.lastQueuedWithdrawStable = vaultState
            .lastQueuedWithdrawStable
            .sub(withdrawStable);
    }

    /**
     * @notice Sets up the vault condition on the current vault
     */
    function deployVault() external onlyKeeper nonReentrant {
        bytes32 currPoolId = poolState.currPoolId;

        Vault.DeployParams memory deployParams = 
            Vault.DeployParams({
                currPoolId: currPoolId,
                manualStrike: manualStrike,
                manualStrikeRound: manualStrikeRound,
                manualVolatility: manualVolatility,
                manualVolatilityRound: manualVolatilityRound,
                manualGamma: manualGamma,
                manualGammaRound: manualGammaRound,
                paretoManager: paretoManager
            });

        (
            bytes32 nextPoolId,
            uint256 nextStrikePrice,
            uint32 nextVolatility,
            uint32 nextGamma
        ) = _prepareNextPool(deployParams, vaultParams);

        emit DeployVaultEvent(
            nextPoolId,
            nextStrikePrice,
            nextVolatility,
            nextGamma,
            msg.sender
        );

        // Update pool identifier in PoolState
        poolState.nextPoolId = nextPoolId;

        // Update timestamp for next pool in PoolState
        // TODO: add delay?
        uint256 nextPoolReadyAt = block.timestamp;
        VaultMath.assertUint32(nextPoolReadyAt);
        poolState.nextPoolReadyAt = uint32(nextPoolReadyAt);

        // Reset properties in VaultState
        vaultState.lockedRisky = 0;
        vaultState.lockedStable = 0;

        // Prevent bad things if we already called function
        if (currPoolId != "") {
            // Remove liquidity from Primitive pool for token assets
            (uint256 riskyAmount, uint256 stableAmount) = 
                _removeLiquidity(currPoolId, poolState.currLiquidity);

            emit ClosePositionEvent(
                currPoolId,
                riskyAmount,
                stableAmount,
                msg.sender
            );
        }

        // Reset properties in PoolState
        poolState.currPoolId = "";
        poolState.currLiquidity = 0;

        delete poolState.currPoolParams;
    }

    /**
     * @notice Roll's the vault's funds into the next vault
     */
    function rollover() external onlyKeeper nonReentrant {
        (
            bytes32 newPoolId,
            uint256 lockedRisky,
            uint256 lockedStable,
            uint256 queuedWithdrawRisky,
            uint256 queuedWithdrawStable
        ) = _prepareRollover();

        // Queued withdraws from current round are set to last round
        vaultState.lastQueuedWithdrawRisky = queuedWithdrawRisky;
        vaultState.lastQueuedWithdrawStable = queuedWithdrawStable;

        // Add queued withdraw shares for current round to cache and
        // reset current queue to zero
        uint256 totalQueuedWithdrawShares = vaultState
            .totalQueuedWithdrawShares
            .add(vaultState.currQueuedWithdrawShares);
        vaultState.totalQueuedWithdrawShares = totalQueuedWithdrawShares;
        vaultState.currQueuedWithdrawShares = 0;

        // Update locked balances
        VaultMath.assertUint104(lockedRisky);
        VaultMath.assertUint104(lockedStable);
        vaultState.lockedRisky = uint104(lockedRisky);
        vaultState.lockedStable = uint104(lockedStable);

        // Deposit locked liquidity into Primitive pools
        uint256 optionLiquidity = _depositLiquidity(
            newPoolId,
            lockedRisky,
            lockedStable
        );

        emit OpenPositionEvent(
            newPoolId,
            lockedRisky,
            lockedStable,
            optionLiquidity,
            msg.sender
        );

        // Save the liquidity into PoolState
        poolState.currLiquidity = optionLiquidity;
    }

    /************************************************
     * Owner operations
     ***********************************************/

    /**
     * @notice Optionality to manually set strike price
     * --
     * @param strikePrice is the strike price of the new pool (decimals = 8)
     */
    function setStrikePrice(uint128 strikePrice) external onlyOwner {
        require(strikePrice > 0, "!strikePrice");

        // Record into global variables
        manualStrike = strikePrice;
        manualStrikeRound = vaultState.round;
    }

    /**
     * @notice Optionality to manually set implied volatility
     * --
     * @param volatility is the sigma of the new pool (decimals = 8)
     */
    function setVolatility(uint128 volatility) external onlyOwner {
        require(volatility > 0, "!volatility");

        // Record into global variables
        manualVolatility = Volatility;
        manualVolatilityRound = vaultState.round;
    }

    /**
     * @notice Sets the new Pareto Manager contract
     * --
     * @param newParetoManager is the address of the new manager contract
     */
    function setParetoManager(address newParetoManager) external onlyOwner {
        require(newParetoManager != address(0), "!newParetoManager");
        paretoManager = newParetoManager;
    }
}
