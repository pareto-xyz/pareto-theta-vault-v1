// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {IERC20} from "../interfaces/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "../libraries/SafeERC20.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IParetoManager} from "../interfaces/IParetoManager.sol";
import {IParetoVault} from "../interfaces/IParetoVault.sol";
import {IPrimitiveManager} from "@primitivefi/rmm-manager/contracts/interfaces/IPrimitiveManager.sol";
import {IManagerBase} from "@primitivefi/rmm-manager/contracts/interfaces/IManagerBase.sol";
import {IPrimitiveEngineView} from "@primitivefi/rmm-core/contracts/interfaces/engine/IPrimitiveEngineView.sol";
import {EngineAddress} from "@primitivefi/rmm-manager/contracts/libraries/EngineAddress.sol";
import {Vault} from "../libraries/Vault.sol";
import {VaultMath} from "../libraries/VaultMath.sol";

/**
 * @notice Based on RibbonVault.sol
 *  See https://docs.ribbon.finance/developers/ribbon-v2
 */
contract ParetoVault is
    IParetoVault,
    ReentrancyGuard,
    Ownable,
    ERC20,
    ERC1155Holder
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using VaultMath for Vault.DepositReceipt;

    /************************************************
     * Non-upgradeable storage
     ***********************************************/

    // User's pending deposit for the round
    mapping(address => Vault.DepositReceipt) public depositReceipts;

    // When round closes, the share price of a receipt token is stored
    // We must store the price for all rounds since users can deposit at any
    // round and withdrawal at any later round
    mapping(uint256 => uint256) public roundSharePriceInRisky;
    mapping(uint256 => uint256) public roundSharePriceInStable;

    // Map from user address to pending withdraw info
    mapping(address => Vault.PendingWithdraw) public pendingWithdraw;

    // Vault state containing round and asset amounts
    Vault.VaultState public vaultState;

    // State of current and next option in the vault
    Vault.PoolState public poolState;

    // State of the vault manager (manual overrides)
    Vault.ManagerState public managerState;

    // Recipient of performance and management fees
    address public override feeRecipient;

    // Role in charge of weekly vault operations
    // No access to critical vault changes
    address public override keeper;

    // Address for the vault manager contract
    address public override vaultManager;

    // Address for the Primitive manager contract
    address public immutable primitiveManager;

    // Address for the Primitive engine contract
    address public immutable primitiveEngine;

    // Address for the risky asset
    address public override risky;

    // Address for the stable asset
    address public override stable;

    // Management fee charged on entire AUM
    uint256 public managementFee;

    // Performance fee charged on premiums earned
    uint256 public performanceFee;

    /************************************************
     * Immutables and Constants
     ***********************************************/

    /**
     * @notice Number of weeks per year = 52.142857 weeks * FEE_MULTIPLIER = 52142857
     *  Dividing by weeks per year via num.mul(FEE_MULTIPLIER).div(WEEKS_PER_YEAR)
     */
    uint256 private constant WEEKS_PER_YEAR = 52142857;

    /************************************************
     * Events
     ***********************************************/

    /**
     * @notice Emitted when user deposits risky asset into vault
     */
    event DepositEvent(
        address indexed account,
        uint256 riskyAmount,
        uint16 round
    );

    /**
     * @notice Emitted when user requests a withdrawal
     */
    event WithdrawRequestEvent(
        address indexed account,
        uint256 shares,
        uint16 round
    );

    /**
     * @notice Emitted when user's queued withdrawal is complete
     */
    event WithdrawCompleteEvent(
        address indexed account,
        uint256 shares,
        uint256 riskyAmount,
        uint256 stableAmount
    );

    /**
     * @notice Emitted when fees are transfered to feeRecipient
     */
    event VaultFeesCollectionEvent(
        uint256 feeInRisky,
        uint256 feeInStable,
        uint16 round,
        address indexed feeRecipient
    );

    /**
     * @notice Emitted when keeper deposits vault assets into RMM-01 pool
     */
    event OpenPositionEvent(
        bytes32 poolId,
        uint256 riskyAmount,
        uint256 stableAmount,
        uint256 returnLiquidity,
        address indexed keeper
    );

    /**
     * @notice Emitted when keeper burns RMM-01 LP tokens for assets
     */
    event ClosePositionEvent(
        bytes32 poolId,
        uint256 burnLiquidity,
        uint256 riskyAmount,
        uint256 stableAmount,
        address indexed keeper
    );

    /**
     * @notice Emitted when keeper creates a new RMM-01 pool
     */
    event DeployVaultEvent(
        bytes32 poolId,
        uint128 strikePrice,
        uint32 volatility,
        uint32 gamma,
        address indexed keeper
    );

    /**
     * @notice Emitted when vault swaps assets to deposit in RMM-01.
     */
    event SwapAssetsEvent(
        uint256 riskyPreswap,
        uint256 stablePreswap,
        uint256 riskyPostswap,
        uint256 stablePostswap,
        address indexed keeper
    );

    /**
     * @notice Emitted when keeper manually sets next round's strike price
     */
    event StrikePriceSetEvent(uint128 strikePrice, uint16 round);

    /**
     * @notice Emitted when keeper manually sets next round's implied volality
     */
    event VolatilitySetEvent(uint32 volatility, uint16 round);

    /**
     * @notice Emitted when keeper manually sets next round's trading fee
     */
    event GammaSetEvent(uint32 gamma, uint16 round);

    /**
     * @notice Emitted when owner sets new management fee
     */
    event ManagementFeeSetEvent(
        uint256 managementFee,
        uint256 newManagementFee
    );

    /**
     * @notice Emitted when owner sets new performance fee
     */
    event PerformanceFeeSetEvent(
        uint256 performanceFee,
        uint256 newPerformanceFee
    );

    /**
     * @notice Emitted when owner sets new keeper address
     */
    event KeeperSetEvent(address indexed keeper);

    /**
     * @notice Emitted when owner sets new recipient address for fees
     */
    event FeeRecipientSetEvent(address indexed keeper);

    /**
     * @notice Emitted when owner sets new vault manager contract
     */
    event VaultManagerSetEvent(address indexed vaultManager);

    /************************************************
     * Constructor and Initialization
     ***********************************************/

    /**
     * @notice Initializes the contract
     * @param _keeper is the Keeper address
     * @param _feeRecipient is the address that receives fees
     * @param _vaultManager is the address for pareto manager
     * @param _primitiveManager is the address for primitive manager
     * @param _primitiveEngine is the address for primitive engine
     * @param _risky is the address for the risky token
     * @param _stable is the address for the stable token
     * @param _managementFee is the management fee percent per year
     * @param _performanceFee is the management fee percent per round
     * @param _tokenName is the name of the asset
     * @param _tokenSymbol is the symbol of the asset
     */
    constructor(
        address _keeper,
        address _feeRecipient,
        address _vaultManager,
        address _primitiveManager,
        address _primitiveEngine,
        address _risky,
        address _stable,
        uint256 _managementFee,
        uint256 _performanceFee,
        string memory _tokenName,
        string memory _tokenSymbol
    ) ERC20(_tokenName, _tokenSymbol) {
        require(_keeper != address(0), "!_keeper");
        require(_primitiveManager != address(0), "!_primitiveManager");
        require(_primitiveEngine != address(0), "!_primitiveEngine");
        require(_risky != address(0), "!_risky");
        require(_stable != address(0), "!_stable");
        require(_managementFee > 0, "!_stable");
        require(_performanceFee > 0, "!_stable");
        require(
            IParetoManager(_vaultManager).risky() == _risky,
            "Risky asset does not match"
        );
        require(
            IParetoManager(_vaultManager).stable() == _stable,
            "Stable asset does not match"
        );

        keeper = _keeper;
        feeRecipient = _feeRecipient;
        vaultManager = _vaultManager;
        primitiveManager = _primitiveManager;
        primitiveEngine = _primitiveEngine;
        risky = _risky;
        stable = _stable;
        performanceFee = _performanceFee;
        // Compute management to charge per week by yearly amount
        managementFee = _managementFee.mul(Vault.FEE_MULTIPLIER).div(
            WEEKS_PER_YEAR
        );
        // Account for pre-existing funds
        uint256 riskyBalance = IERC20(risky).balanceOf(address(this));
        uint256 stableBalance = IERC20(stable).balanceOf(address(this));
        VaultMath.assertUint104(riskyBalance);
        VaultMath.assertUint104(stableBalance);
        vaultState.lastLockedRisky = uint104(riskyBalance);
        vaultState.lastLockedStable = uint104(stableBalance);
        // Initialize round
        vaultState.round = 1;
    }

    /************************************************
     *  Permissions and Roles (Owner only)
     ***********************************************/

    /**
     * @notice Throws if called by any account other than the keeper
     */
    modifier onlyKeeper() {
        require(msg.sender == keeper, "!keeper");
        _;
    }

    /**
     * @notice Sets the keeper
     * @param newKeeper is the address of the new keeper
     */
    function setKeeper(address newKeeper) external onlyOwner {
        require(newKeeper != address(0), "!keeper`");
        emit KeeperSetEvent(newKeeper);
        keeper = newKeeper;
    }

    /**
     * Sets the fee recipient
     * @param newFeeRecipient is the address of the new fee recipient
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "!newFeeRecipient");
        require(newFeeRecipient != feeRecipient, "Old feeRecipient");
        emit FeeRecipientSetEvent(newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    /**
     * Sets the management fee for the vault
     * @param newManagementFee is the management fee
     */
    function setManagementFee(uint256 newManagementFee) external onlyOwner {
        require(
            newManagementFee < 100 * Vault.FEE_MULTIPLIER,
            "newManagementFee > 100"
        );

        // Divide annualized management fee by num weeks in a year
        uint256 weeklyFee = newManagementFee.mul(Vault.FEE_MULTIPLIER).div(
            WEEKS_PER_YEAR
        );

        emit ManagementFeeSetEvent(managementFee, newManagementFee);
        managementFee = weeklyFee;
    }

    /**
     * Sets the performance fee for the vault
     * @param newPerformanceFee is the performance fee
     */
    function setPerformanceFee(uint256 newPerformanceFee) external onlyOwner {
        require(
            newPerformanceFee < 100 * Vault.FEE_MULTIPLIER,
            "newPerformanceFee > 100"
        );
        emit PerformanceFeeSetEvent(performanceFee, newPerformanceFee);
        performanceFee = newPerformanceFee;
    }

    /**
     * @notice Optionality to manually set strike price
     * @param strikePrice is the strike price of the new pool
     */
    function setStrikePrice(uint128 strikePrice) external onlyKeeper {
        require(strikePrice > 0, "!strikePrice");
        emit StrikePriceSetEvent(strikePrice, vaultState.round);
        managerState.manualStrike = strikePrice;
        managerState.manualStrikeRound = vaultState.round;
    }

    /**
     * @notice Optionality to manually set implied volatility
     * @param volatility is the sigma of the new pool
     */
    function setVolatility(uint32 volatility) external onlyKeeper {
        require(volatility > 0, "!volatility");
        emit VolatilitySetEvent(volatility, vaultState.round);
        managerState.manualVolatility = volatility;
        managerState.manualVolatilityRound = vaultState.round;
    }

    /**
     * @notice Optionality to manually set gamma
     * @param gamma is 1-fee of the new pool. Important for replication
     */
    function setGamma(uint32 gamma) external onlyKeeper {
        require(gamma > 0, "!gamma");
        emit GammaSetEvent(gamma, vaultState.round);
        managerState.manualGamma = gamma;
        managerState.manualGammaRound = vaultState.round;
    }

    /**
     * @notice Sets the new Vault Manager contract
     * @param newVaultManager is the address of the new manager contract
     */
    function setVaultManager(address newVaultManager) external onlyOwner {
        require(newVaultManager != address(0), "!newVaultManager");
        emit VaultManagerSetEvent(newVaultManager);
        vaultManager = newVaultManager;
    }

    /************************************************
     * User-facing Vault Operations
     ***********************************************/

    /**
     * @notice Deposits risky asset from msg.sender.
     * @param riskyAmount is the amount of risky asset to deposit
     */
    function deposit(uint256 riskyAmount) external override nonReentrant {
        require(riskyAmount > 0, "!riskyAmount");

        emit DepositEvent(msg.sender, riskyAmount, vaultState.round);
        _processDeposit(riskyAmount, msg.sender);

        // Make transfers from tx caller to contract
        IERC20(risky).safeTransferFrom(msg.sender, address(this), riskyAmount);
    }

    /**
     * @notice Requests a withdraw that is processed after the current round
     * @param shares is the number of shares to withdraw
     */
    function requestWithdraw(uint256 shares) external override nonReentrant {
        _requestWithdraw(shares);

        // Update global variable caching shares queued for withdrawal
        vaultState.currQueuedWithdrawShares = vaultState
            .currQueuedWithdrawShares
            .add(shares);
    }

    /**
     * @notice Completes a requested withdraw from past round.
     */
    function completeWithdraw() external override nonReentrant {
        (uint256 riskyWithdrawn, uint256 stableWithdrawn) = _completeWithdraw();

        // Update globals caching withdrawal amounts from last round
        vaultState.lastQueuedWithdrawRisky = vaultState
            .lastQueuedWithdrawRisky
            .sub(riskyWithdrawn);
        vaultState.lastQueuedWithdrawStable = vaultState
            .lastQueuedWithdrawStable
            .sub(stableWithdrawn);
    }

    /**
     * @notice Sets up the vault condition on the current vault
     */
    function deployVault() external onlyKeeper nonReentrant {
        bytes32 currPoolId = poolState.currPoolId;

        (
            bytes32 nextPoolId,
            uint128 nextStrikePrice,
            uint32 nextVolatility,
            uint32 nextGamma
        ) = _prepareNextPool(currPoolId);

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

        {
            // Save last round's locked assets
            uint104 lockedRisky = vaultState.lockedRisky;
            uint104 lockedStable = vaultState.lockedStable;
            if (currPoolId != "") {
                vaultState.lastLockedRisky = lockedRisky;
                vaultState.lastLockedStable = lockedStable;
            }
        }

        // Reset properties in VaultState
        vaultState.lockedRisky = 0;
        vaultState.lockedStable = 0;

        // Prevent bad things if we already called function
        if (currPoolId != "") {
            // Remove liquidity from Primitive pool for token assets
            (uint256 riskyAmount, uint256 stableAmount) = _removeLiquidity(
                currPoolId,
                poolState.currLiquidity
            );

            emit ClosePositionEvent(
                currPoolId,
                poolState.currLiquidity,
                riskyAmount,
                stableAmount,
                msg.sender
            );
        }

        // Reset properties in PoolState
        poolState.currPoolId = "";
        poolState.currLiquidity = 0;

        // Rollover will replace this with nextPoolParams
        delete poolState.currPoolParams;
    }

    /**
     * @notice Rolls the vault's funds into the next vault
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
     * Deposits and Withdrawal Utilities
     ***********************************************/

    /**
     * @notice Updates receipts and internal variables
     *  Minting will be done in the next rollover
     *  Users only deposit risky assets. Swaps to stable assets is internal
     * @param riskyAmount is the amount of risky asset to be deposited
     * @param creditor is the address to receive the deposit
     */
    function _processDeposit(uint256 riskyAmount, address creditor) private {
        uint16 currRound = vaultState.round;

        // Find cached receipt for user if already deposited in a previous round
        Vault.DepositReceipt memory receipt = depositReceipts[creditor];

        // Compute owed shares from previous rounds
        uint256 shares = receipt.getSharesFromReceipt(
            currRound,
            roundSharePriceInRisky[receipt.round], // round of deposit
            IERC20(risky).decimals()
        );

        uint256 depositAmount = riskyAmount;
        // If another pending deposit exists for current round, add to it
        if (receipt.round == currRound) {
            depositAmount = uint256(receipt.riskyAmount).add(riskyAmount);
        }

        VaultMath.assertUint104(depositAmount);
        VaultMath.assertUint128(shares);

        // New receipt has total deposited amount from current round and
        // the number of owned shares from previous rounds
        depositReceipts[creditor] = Vault.DepositReceipt({
            round: currRound,
            riskyAmount: uint104(depositAmount),
            shares: uint128(shares)
        });

        // Pending = money waiting to be converted to shares. Use riskyAmount
        // not depositAmount as a portion has already been accounted for
        // This must be in risky asset. Users cannot deposit stable
        uint256 newPendingRisky = uint256(vaultState.pendingRisky).add(
            riskyAmount
        );
        VaultMath.assertUint128(newPendingRisky);
        vaultState.pendingRisky = uint128(newPendingRisky);
    }

    /**
     * @notice Initiates a withdraw to be processed after round completes
     *  This function does not make the actual withdrawal but must be called
     *  prior to _completeWithdraw
     * @param shares is the amount of shares to withdraw
     */
    function _requestWithdraw(uint256 shares) internal {
        require(shares > 0, "!shares");
        uint16 currRound = vaultState.round;

        // Stores the round and amount of shares to be withdrawn
        Vault.PendingWithdraw storage withdrawal = pendingWithdraw[msg.sender];

        emit WithdrawRequestEvent(msg.sender, shares, currRound);

        uint256 sharesToWithdraw;

        if (withdrawal.round == currRound) {
            // If the user has a pending withdrawal from same round, merge
            sharesToWithdraw = uint256(withdrawal.shares).add(shares);
        } else {
            // If we find unfilled withdrawal request from old round, error
            require(uint256(withdrawal.shares) == 0, "Abandoned withdraw");
            sharesToWithdraw = shares;
            pendingWithdraw[msg.sender].round = uint16(currRound);
        }
        VaultMath.assertUint128(sharesToWithdraw);
        // pendingWithdraw is up-to-date
        pendingWithdraw[msg.sender].shares = uint128(sharesToWithdraw);
    }

    /**
     * @notice Complete a scheduled withdrawal from past round
     *  Users deposit risky assets only but can withdraw both risky and stable
     * @return withdrawRisky is the withdrawn amount of risky asset
     * @return withdrawStable is the withdrawn amount of stable asset
     */
    function _completeWithdraw() internal returns (uint256, uint256) {
        // withdrawal is guaranteed to be up-to-date b/c of _requestWithdraw
        Vault.PendingWithdraw storage withdrawal = pendingWithdraw[msg.sender];

        uint256 sharesToWithdraw = withdrawal.shares;
        uint256 withdrawRound = withdrawal.round;

        // Check that a request to withdrawal has been made
        require(sharesToWithdraw > 0, "!sharesToWithdraw");
        // Check that the withdraw request was made in a previous round
        require(withdrawRound < vaultState.round, "Too early to withdraw");

        // Reset params back to 0 to prevent over-withdrawal
        // TODO: check for re-entrancy?
        pendingWithdraw[msg.sender].shares = 0;

        // Remove portion from queued withdraws
        vaultState.totalQueuedWithdrawShares = uint128(
            uint256(vaultState.totalQueuedWithdrawShares).sub(sharesToWithdraw)
        );

        // A single share is traded for both risky and stable assets
        // based on share price at the withdraw round
        uint256 riskyWithdrawn = VaultMath.shareToAsset(
            sharesToWithdraw,
            roundSharePriceInRisky[withdrawRound],
            IERC20(risky).decimals()
        );
        uint256 stableWithdrawn = VaultMath.shareToAsset(
            sharesToWithdraw,
            roundSharePriceInStable[withdrawRound],
            IERC20(stable).decimals()
        );

        require(riskyWithdrawn > 0, "!riskyWithdrawn");
        require(stableWithdrawn > 0, "!stableWithdrawn");

        emit WithdrawCompleteEvent(
            msg.sender,
            sharesToWithdraw,
            riskyWithdrawn,
            stableWithdrawn
        );

        // Burn the Pareto ERC20 tokens
        _burn(address(this), sharesToWithdraw);

        // Transfer tokens from contract to user
        IERC20(risky).safeTransfer(msg.sender, riskyWithdrawn);
        IERC20(stable).safeTransfer(msg.sender, stableWithdrawn);

        return (riskyWithdrawn, stableWithdrawn);
    }

    /************************************************
     * Vault Operations
     ***********************************************/

    /**
     * @notice Setup the next Primitive pool (i.e. the next option)
     *  Updates all internal state variables; deploys a new pool but
     *  does not perform rollover
     * @param currPoolId is the id of the current Primitive pool
     */
    function _prepareNextPool(bytes32 currPoolId)
        internal
        returns (
            bytes32 nextPoolId,
            uint128 nextStrikePrice,
            uint32 nextVolatility,
            uint32 nextGamma
        )
    {
        // Compute the maturity date for the next pool
        uint32 nextMaturity = getNextMaturity(currPoolId);

        // Manager contains logic to get params of the next pool
        IParetoManager manager = IParetoManager(vaultManager);

        // Check if we manually set strike price, otherwise call manager
        nextStrikePrice = managerState.manualStrikeRound == vaultState.round
            ? managerState.manualStrike
            : manager.getNextStrikePrice();
        require(nextStrikePrice > 0, "!nextStrikePrice");

        // Check if we manually set volatility, otherwise call manager
        nextVolatility = managerState.manualVolatilityRound == vaultState.round
            ? managerState.manualVolatility
            : manager.getNextVolatility();
        require(nextVolatility > 0, "!nextVolatility");

        // Check if we manually set gamma, otherwise call manager
        nextGamma = managerState.manualGammaRound == vaultState.round
            ? managerState.manualGamma
            : manager.getNextGamma();
        require(nextGamma > 0, "!nextGamma");

        // Define params of next pool
        Vault.PoolParams memory nextParams = Vault.PoolParams({
            strike: nextStrikePrice,
            sigma: nextVolatility,
            maturity: nextMaturity,
            gamma: nextGamma,
            riskyPerLP: poolState.currPoolParams.riskyPerLP,
            delLiquidity: poolState.currPoolParams.delLiquidity
        });

        // Deploy the next Primitive pool; this does not perform rollover
        // The current pool is still the active one
        nextPoolId = _deployPool(nextParams);
        poolState.nextPoolParams = nextParams;

        return (nextPoolId, nextStrikePrice, nextVolatility, nextGamma);
    }

    /**
     * @notice Logistic operations for rolling to the next option, such as
     *  minting new shares and transferring vault fees. The actual calls to
     *  Primitive are not made in this function but require the outputs of this
     * @return newPoolId is the bytes32 id of the next Primitive pool
     * @return lockedRisky is the amount of risky asset locked for next round
     * @return lockedStable is the amount of stable asset locked for next round
     * @return queuedWithdrawRisky is the new queued withdraw amount of risky
     *  asset for this round
     * @return queuedWithdrawStable is the new queued withdraw amount of stable
     *  asset for this round
     */
    function _prepareRollover()
        internal
        returns (
            bytes32 newPoolId,
            uint256 lockedRisky,
            uint256 lockedStable,
            uint256 queuedWithdrawRisky,
            uint256 queuedWithdrawStable
        )
    {
        require(
            block.timestamp >= poolState.nextPoolReadyAt,
            "Too early to rollover"
        );
        newPoolId = poolState.nextPoolId;
        require(newPoolId != "", "!newPoolId");

        // Use deposited tokens (from last week) to mint new shares
        uint256 sharesToMint;
        // Amount of fees to transfer to recipient (in two tokens)
        uint256 feeInRisky;
        uint256 feeInStable;
        {
            uint256 newSharePriceInRisky;
            uint256 newSharePriceInStable;

            // Get the amount of assets owned by current token
            uint256 currRisky = IERC20(risky).balanceOf(address(this));
            uint256 currStable = IERC20(stable).balanceOf(address(this));

            // Compute supply of Pareto tokens minus what is queued for withdrawal
            uint256 currSupply = totalSupply().sub(
                vaultState.totalQueuedWithdrawShares
            );

            {
                // Compute vault fees in two assets
                (feeInRisky, feeInStable) = _getVaultFees(
                    Vault.FeeCalculatorInput({
                        currRisky: currRisky.sub(
                            vaultState.lastQueuedWithdrawRisky
                        ),
                        currStable: currStable.sub(
                            vaultState.lastQueuedWithdrawStable
                        ),
                        lastLockedRisky: vaultState.lastLockedRisky,
                        lastLockedStable: vaultState.lastLockedStable,
                        pendingRisky: vaultState.pendingRisky,
                        managementFeePercent: managementFee,
                        performanceFeePercent: performanceFee
                    })
                );
            }

            // Remove fee from assets
            currRisky = currRisky.sub(feeInRisky);
            currStable = currStable.sub(feeInStable);

            {
                // Compute new share price after rollover
                newSharePriceInRisky = VaultMath.getSharePrice(
                    currSupply,
                    currRisky.sub(vaultState.lastQueuedWithdrawRisky),
                    vaultState.pendingRisky,
                    IERC20(risky).decimals()
                );
                newSharePriceInStable = VaultMath.getSharePrice(
                    currSupply,
                    currStable.sub(vaultState.lastQueuedWithdrawStable),
                    0,
                    IERC20(stable).decimals()
                );

                // Update the amount of risky and stable asset to be withdrawn
                // based on new share price
                queuedWithdrawRisky = vaultState.lastQueuedWithdrawRisky.add(
                    VaultMath.shareToAsset(
                        vaultState.currQueuedWithdrawShares,
                        newSharePriceInRisky,
                        IERC20(risky).decimals()
                    )
                );
                queuedWithdrawStable = vaultState.lastQueuedWithdrawStable.add(
                    VaultMath.shareToAsset(
                        vaultState.currQueuedWithdrawShares,
                        newSharePriceInStable,
                        IERC20(stable).decimals()
                    )
                );

                // Compute number of shares that can be minted from pending risky
                // This solely uses the amount of pending deposits from new users
                sharesToMint = VaultMath.assetToShare(
                    vaultState.pendingRisky,
                    newSharePriceInRisky,
                    IERC20(risky).decimals()
                );
            }

            // Locked asset is the amount that we can deposit into RMM-01 pool
            // Remove assets queued for withdraw
            lockedRisky = currRisky.sub(queuedWithdrawRisky);
            lockedStable = currStable.sub(queuedWithdrawStable);

            // Update properties of poolState
            poolState.currPoolId = newPoolId;
            poolState.nextPoolId = "";

            poolState.currPoolParams = poolState.nextPoolParams;
            delete poolState.nextPoolParams;

            // Record the new share price
            roundSharePriceInRisky[vaultState.round] = newSharePriceInRisky;
            roundSharePriceInStable[vaultState.round] = newSharePriceInStable;

            emit VaultFeesCollectionEvent(
                feeInRisky,
                feeInStable,
                vaultState.round,
                feeRecipient
            );

            // All the pending risky will be used so reset to zereo
            vaultState.pendingRisky = 0;

            // Update the vault round
            vaultState.round = uint16(vaultState.round + 1);
        }

        // Mint new shares for next round
        _mint(address(this), sharesToMint);

        // Make transfers for fee
        if (feeInRisky > 0) {
            IERC20(risky).safeTransfer(payable(feeRecipient), feeInRisky);
        }
        if (feeInStable > 0) {
            IERC20(stable).safeTransfer(payable(feeRecipient), feeInStable);
        }

        return (
            newPoolId,
            lockedRisky,
            lockedStable,
            queuedWithdrawRisky,
            queuedWithdrawStable
        );
    }

    /**
     * Check if the vault was successful in making money. This converts stable
     * to risky to compute value, using an oracle price
     * @param preVaultRisky is the amount of risky before the vault
     * @param preVaultStable is the amount of stable before the vault
     * @param postVaultRisky is the amount of risky after the vault
     * @param postVaultStable is the amount of stable after the vault
     * @return success is true if current value is higher than before the vault
     *  at the same oracle price; otherwise false
     */
    function _checkVaultSuccess(
        uint256 preVaultRisky,
        uint256 preVaultStable,
        uint256 postVaultRisky,
        uint256 postVaultStable
    ) internal view returns (bool success) {
        uint8 oracleDecimals = IParetoManager(vaultManager).getOracleDecimals();
        uint256 stableToRiskyPrice = IParetoManager(vaultManager)
            .getStableToRiskyPrice();
        uint256 preVaultValue = preVaultRisky.add(
            preVaultStable.mul(stableToRiskyPrice).div(10**oracleDecimals)
        );
        uint256 postVaultValue = postVaultRisky.add(
            postVaultStable.mul(stableToRiskyPrice).div(10**oracleDecimals)
        );
        success = postVaultValue >= preVaultValue;
        return success;
    }

    /**
     * @notice Calculates performance and management fee for this week's round
     * @param feeParams is the parameters for fee computation
     * @return feeInRisky is the fees awarded to owner in risky
     * @return feeInStable is the fees awarded to owner in stable
     * --
     * TODO: check if vault made money
     */
    function _getVaultFees(Vault.FeeCalculatorInput memory feeParams)
        internal
        view
        returns (uint256 feeInRisky, uint256 feeInStable)
    {
        // Locked amount should not include pending amount
        uint256 currLockedRisky = feeParams.currRisky > feeParams.pendingRisky
            ? feeParams.currRisky.sub(feeParams.pendingRisky)
            : 0;
        // Users cannot deposit stable tokens
        uint256 _performanceFeeInRisky;
        uint256 _performanceFeeInStable;
        uint256 _managementFeeInRisky;
        uint256 _managementFeeInStable;

        // Take performance fee and management fee ONLY if the value of vault's
        // current assets (at current oracle price) is higher than the value of
        // vault before the round (at the same oracle price).
        bool vaultSuccess = _checkVaultSuccess(
            feeParams.lastLockedRisky,
            feeParams.lastLockedStable,
            currLockedRisky,
            feeParams.currStable
        );
        if (vaultSuccess) {
            _performanceFeeInRisky = feeParams.performanceFeePercent > 0
                ? currLockedRisky
                    .sub(feeParams.lastLockedRisky)
                    .mul(feeParams.performanceFeePercent)
                    .div(100 * Vault.FEE_MULTIPLIER)
                : 0;
            _performanceFeeInStable = feeParams.performanceFeePercent > 0
                ? feeParams
                    .currStable
                    .sub(feeParams.lastLockedStable)
                    .mul(feeParams.performanceFeePercent)
                    .div(100 * Vault.FEE_MULTIPLIER)
                : 0;
            _managementFeeInRisky = feeParams.managementFeePercent > 0
                ? currLockedRisky.mul(feeParams.managementFeePercent).div(
                    100 * Vault.FEE_MULTIPLIER
                )
                : 0;
            _managementFeeInStable = feeParams.managementFeePercent > 0
                ? feeParams.currStable.mul(feeParams.managementFeePercent).div(
                    100 * Vault.FEE_MULTIPLIER
                )
                : 0;
            feeInRisky = _performanceFeeInRisky.add(_managementFeeInRisky);
            feeInStable = _performanceFeeInStable.add(_managementFeeInStable);
        }
        return (feeInRisky, feeInStable);
    }

    /************************************************
     * Primitive Bindings
     ***********************************************/

    /**
     * @notice Fetch the maturity timestamp of the current Primitive pool
     * @param poolId is the identifier of the current pool
     * @return maturity is the expiry date of the current pool
     */
    function _getPoolMaturity(bytes32 poolId) internal view returns (uint32) {
        (, , uint32 maturity, , ) = IPrimitiveEngineView(primitiveEngine)
            .calibrations(poolId);
        return maturity;
    }

    /**
     * @notice Creates a new Primitive pool using OptionParams
     * @param poolParams are the Black-Scholes parameters for the pool
     * @return poolId is the pool identifier of the created pool
     */
    function _deployPool(Vault.PoolParams memory poolParams)
        internal
        returns (bytes32)
    {
        (bytes32 poolId, , ) = IPrimitiveManager(primitiveManager).create(
            risky,
            stable,
            poolParams.strike,
            poolParams.sigma,
            poolParams.maturity,
            poolParams.gamma,
            poolParams.riskyPerLP,
            poolParams.delLiquidity
        );
        return poolId;
    }

    /**
     * @notice Deposits a pair of assets in a Primitive pool
     *  Stores the liquidity tokens in this contract
     * @param poolId is the identifier of the pool to deposit in
     * @param riskyAmount is the amount of risky assets to deposit
     * @param stableAmount is the amount of stable assets to deposit
     * @return liquidity is the amount of LP tokens returned from deposit
     */
    function _depositLiquidity(
        bytes32 poolId,
        uint256 riskyAmount,
        uint256 stableAmount
    ) internal returns (uint256) {
        uint256 liquidity = IPrimitiveManager(primitiveManager).allocate(
            address(this),
            poolId,
            risky,
            stable,
            riskyAmount,
            stableAmount,
            false,
            0
        );
        return liquidity;
    }

    /**
     * @notice Removes a pair of assets from a Primitive pool
     * @notice Takes liquidity tokens from this contract
     * @param poolId is the identifier of the pool to deposit in
     * @param liquidity is the amount of LP tokens returned from deposit
     * @return riskyAmount is the amount of risky assets to deposit
     * @return stableAmount is the amount of stable assets to deposit
     */
    function _removeLiquidity(bytes32 poolId, uint256 liquidity)
        internal
        returns (uint256, uint256)
    {
        if (liquidity == 0) return (0, 0);

        (uint256 riskyAmount, uint256 stableAmount) = IPrimitiveManager(
            primitiveManager
        ).remove(primitiveEngine, poolId, liquidity, 0, 0);

        return (riskyAmount, stableAmount);
    }

    /************************************************
     * Getter functions (frontend)
     ***********************************************/

    /**
     * @notice Returns the asset balance held in the vault for one account
     * @param account is the address to lookup balance for
     * @return riskyAmount is the risky asset owned by the vault for the user
     * @return stableAmount is the stable asset owned by the vault for the user
     */
    function getAccountBalance(address account)
        external
        view
        override
        returns (uint256 riskyAmount, uint256 stableAmount)
    {
        uint256 sharePriceInRisky = VaultMath.getSharePrice(
            totalSupply(),
            totalRisky(),
            vaultState.pendingRisky,
            IERC20(risky).decimals()
        );
        uint256 sharePriceInStable = VaultMath.getSharePrice(
            totalSupply(),
            totalStable(),
            0,
            IERC20(stable).decimals()
        );
        riskyAmount = VaultMath.shareToAsset(
            getAccountShares(account),
            sharePriceInRisky,
            IERC20(risky).decimals()
        );
        stableAmount = VaultMath.shareToAsset(
            getAccountShares(account),
            sharePriceInStable,
            IERC20(stable).decimals()
        );
        return (riskyAmount, stableAmount);
    }

    /**
     * @notice Returns the number of shares (+unredeemed shares) for one account
     * @param account is the address to lookup balance for
     * @return shares is the share balance for the account
     */
    function getAccountShares(address account)
        public
        view
        returns (uint256 shares)
    {
        Vault.DepositReceipt memory receipt = depositReceipts[account];
        shares = receipt.getSharesFromReceipt(
            vaultState.round,
            roundSharePriceInRisky[receipt.round],
            IERC20(risky).decimals()
        );
        return shares;
    }

    /**
     * @notice Return vault's total balance of risky assets, including
     *  amounts locked into Primitive
     */
    function totalRisky() public view returns (uint256) {
        return
            uint256(vaultState.lockedRisky).add(
                IERC20(risky).balanceOf(address(this))
            );
    }

    /**
     * @notice Return vault's total balance of stable assets, including
     *  amounts locked into Primitive
     */
    function totalStable() public view returns (uint256) {
        return
            uint256(vaultState.lockedStable).add(
                IERC20(stable).balanceOf(address(this))
            );
    }

    /************************************************
     * Utility functions
     ***********************************************/

    /**
     * @notice Gets the next expiry timestamp
     * @param poolId is the identifier of the current Primitive pool
     * @return nextMaturity is the maturity of the next pool
     */
    function getNextMaturity(bytes32 poolId) internal view returns (uint32) {
        if (poolId == "") {
            // uninitialized state
            return getNextFriday(block.timestamp);
        }
        uint32 currMaturity = _getPoolMaturity(poolId);

        // If its past one week since last option
        if (block.timestamp > currMaturity + 7 days) {
            return getNextFriday(block.timestamp);
        }
        return getNextFriday(currMaturity);
    }

    /**
     * @notice Gets the next options expiry timestamp
     * @param timestamp is the expiry timestamp of the current option
     * Examples:
     * getNextFriday(week 1 thursday) -> week 1 friday
     * getNextFriday(week 1 friday) -> week 2 friday
     * getNextFriday(week 1 saturday) -> week 2 friday
     */
    function getNextFriday(uint256 timestamp) internal pure returns (uint32) {
        // dayOfWeek = 0 (sunday) - 6 (saturday)
        uint256 dayOfWeek = ((timestamp / 1 days) + 4) % 7;
        uint256 nextFriday = timestamp + ((7 + 5 - dayOfWeek) % 7) * 1 days;
        uint256 friday8am = nextFriday - (nextFriday % (24 hours)) + (8 hours);

        // If the passed timestamp is day=Friday hour>8am, we simply
        // increment it by a week to next Friday
        if (timestamp >= friday8am) {
            friday8am += 7 days;
        }
        VaultMath.assertUint32(friday8am);
        return uint32(friday8am);
    }
}
