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
import {IPrimitiveManager} from "../interfaces/IPrimitiveManager.sol";
import {IPrimitiveFactory} from "@primitivefi/rmm-core/contracts/interfaces/IPrimitiveFactory.sol";
import {IManagerBase} from "@primitivefi/rmm-manager/contracts/interfaces/IManagerBase.sol";
import {IPrimitiveEngineView} from "@primitivefi/rmm-core/contracts/interfaces/engine/IPrimitiveEngineView.sol";
import {Vault} from "../libraries/Vault.sol";
import {VaultMath} from "../libraries/VaultMath.sol";
import {UniswapRouter} from "../libraries/UniswapRouter.sol";
import {console} from "hardhat/console.sol";

/**
 * @notice Based on Ribbon's implementation of Theta Vaults.
 * @dev Many of the functions are written to preserve the design of RibbonVault.sol.
 *      See https://docs.ribbon.finance/developers/ribbon-v2.
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
     * State Variables
     ***********************************************/

    /**
     * @notice A map from address to a Vault.DepositReceipt, which tracks the round,
     *         the amount of risky to deposit, and the amount of shares owned by the user
     */
    mapping(address => Vault.DepositReceipt) public depositReceipts;

    /**
     * @notice Maps user address to a price in risky decimals
     * @dev Since users may withdraw shares deposited from an arbitrarily early round,
     *      share prices in risky token across all rounds are saved.
     */
    mapping(uint256 => uint256) public roundSharePriceInRisky;

    /**
     * @notice Maps user address to a price in stable decimals
     */
    mapping(uint256 => uint256) public roundSharePriceInStable;

    /**
     * @notice Map from user address to a `Vault.PendingWithdraw` object, which stores the
     *         round of withdrawal and the amount of shares to withdraw
     */
    mapping(address => Vault.PendingWithdraw) public pendingWithdraw;

    /**
     * @notice Stores information on the risky and stable assets that enter and exit the
     *         vault's lifecycle
     * @dev Includes the amount of tokens locked in a RMM-01 pool, the amount of tokens
     *      pending from recent deposits, and the amount of tokens queued for withdrawal
     */
    Vault.VaultState public vaultState;

    /// @notice Tracks the state of RMM-01 pool, including pool identifiers and parameters
    Vault.PoolState public poolState;

    /**
     * @notice The keeper can manually specify strike price, volatility, gamma.
     * @dev The manageState saves these choices for use in `_prepareNextPool`
     */
    Vault.ManagerState public managerState;

    /// @notice Recipient of the fees charged each rollover
    address public override feeRecipient;

    /**
     * @notice Keeper who manually managers contract via deployment and rollover.
     * @dev No access to critical vault changes
     */
    address public override keeper;

    /// @notice Address of the `ParetoManager` contract to choose the next vault
    address public override vaultManager;

    /// @notice Stores information on the Primitive contracts
    Vault.PrimitiveParams public primitiveParams;

    /// @notice Stores the Uniswap router, including the contract address and pool fee
    Vault.UniswapParams public uniswapParams;

    /// @notice Stores the addresses and decimals for risky and stable tokens
    Vault.TokenParams public tokenParams;

    /**
     * @notice Fee to take yearly, set to 2 percent of owned asset value.
     *         Fees are transferred in fractions weekly, only taken if the vault makes profit.
     * @dev Specified in decimals of 6.
     */
    uint256 public managementFee;

    /**
     * @notice Fee to take weekly, set to 20 percent of vault profits.
     *         Only taken if the vault makes profit that week.
     * @dev Specified in decimals of 6.
     */
    uint256 public performanceFee;

    /************************************************
     * Immutables and Constants
     ***********************************************/

    /**
     * @notice Number of weeks per year = 52.142857 weeks * 10**FEE_DECIMALS = 52142857
     *         Dividing by weeks per year via num.mul(10**FEE_DECIMALS).div(WEEKS_PER_YEAR)
     */
    uint256 private constant WEEKS_PER_YEAR = 52142857;

    /**
     * @notice This constant specifies the minimum amount of liquidity that the Pareto RTV must hold.
     *         This amount is used to create Primitive RMM-01 pools.
     * @dev In extracting fees and withdrawal, the contract must maintain this minimum
     */
    uint256 public constant MIN_LIQUIDITY = 100000;

    /**
     * @notice Name of the Pareto token that acts as a receipt for users who deposit.
     * @dev Currently, this token is not transferred to users
     */
    string public constant TOKEN_NAME = "Pareto Theta Vault V1";

    /**
     * @notice Symbol of the Pareto token that acts as a receipt for users who deposit
     */
    string public constant TOKEN_SYMBOL = "PTHETA-V1";

    /************************************************
     * Events
     ***********************************************/

    /**
     * @notice Emitted when any user deposits risky asset into vault.
     *         Users cannot deposit stable assets
     * @param account Address of the depositor
     * @param riskyAmount Amount of risky token to be deposited
     * @param round Current round
     */
    event DepositEvent(
        address indexed account,
        uint256 riskyAmount,
        uint16 round
    );

    /**
     * @notice Emitted when user requests a withdrawal
     * @param account Address of the `msg.sender`
     * @param shares Number of shares to withdraw
     * @param round Current round
     */
    event WithdrawRequestEvent(
        address indexed account,
        uint256 shares,
        uint16 round
    );

    /**
     * @notice Emitted when user's requested withdrawal is complete
     * @param account Address of the `msg.sender`
     * @param shares Number of shares to withdraw from vault
     * @param riskyAmount Amount of risky tokens to transfer to user
     * @param stableAmount Amount of stable tokens to transfer to user
     */
    event WithdrawCompleteEvent(
        address indexed account,
        uint256 shares,
        uint256 riskyAmount,
        uint256 stableAmount
    );

    /**
     * @notice Emitted when fees are transferred to fee recipient
     * @param feeInRisky Vault fee in risky asset
     * @param feeInStable Vault fee in stable asset
     * @param round Current round
     * @param feeRecipient The address of the fee recipient
     */
    event VaultFeesCollectionEvent(
        uint256 feeInRisky,
        uint256 feeInStable,
        uint16 round,
        address indexed feeRecipient
    );

    /**
     * @notice Emitted when keeper deposits vault assets into RMM-01 pool during rollover
     * @param poolId Identifier for the pool
     * @param riskyAmount Amount of risky token deposited into RMM-01 pool
     * @param stableAmount Amount of stable token deposited into RMM-01 pool
     * @param returnLiquidity Amount of liquidity returned from RMM-01 pool in exchange for deposit
     * @param keeper Address of the keeper
     */
    event OpenPositionEvent(
        bytes32 poolId,
        uint256 riskyAmount,
        uint256 stableAmount,
        uint256 returnLiquidity,
        address indexed keeper
    );

    /**
     * @notice Emitted when keeper removes liquidity from the previous vault
     * @param poolId Identifier for the pool
     * @param burnLiquidity Amount of liquidity from RMM-01 to burn
     * @param riskyAmount Amount of risky assets withdrawn from pool
     * @param stableAmount Amount of stable assets withdrawn from pool
     * @param keeper Address of the keeper
     */
    event ClosePositionEvent(
        bytes32 poolId,
        uint256 burnLiquidity,
        uint256 riskyAmount,
        uint256 stableAmount,
        address indexed keeper
    );

    /**
     * @notice Emitted when keeper deploys a new vault
     * @param poolId Identifier for the pool
     * @param strikePrice Strike price in stable asset
     * @param volatility Implied volatility in decimals of four
     * @param gamma One minus fees in decimals of four
     * @param keeper Address of the keeper
     */
    event DeployVaultEvent(
        bytes32 poolId,
        uint128 strikePrice,
        uint32 volatility,
        uint32 gamma,
        address indexed keeper
    );

    /**
     * @notice Emitted in rollover when assets are rebalanced before being deposited in pool
     * @param initialRisky Initial amounts of risky token pre-rebalancing
     * @param initialStable Initial amounts of stable token pre-rebalancing
     * @param optimalRisky Optimal amounts of risky token post-rebalancing
     * @param optimalStable Optimal amounts of stable token post-rebalancing
     * @param keeper Address of the keeper
     */
    event RebalanceVaultEvent(
        uint256 initialRisky,
        uint256 initialStable,
        uint256 optimalRisky,
        uint256 optimalStable,
        address indexed keeper
    );

    /**
     * @notice Emitted when keeper manually sets next round's strike price in stable decimals
     * @param strikePrice Next strike price in terms of stable assets
     * @param round Current round
     */
    event StrikePriceSetEvent(uint128 strikePrice, uint16 round);

    /**
     * @notice Emitted when keeper manually sets next round's implied volatility
     * @param volatility Implied volatility in decimals of four
     * @param round Current round
     */
    event VolatilitySetEvent(uint32 volatility, uint16 round);

    /**
     * @notice Emitted when keeper manually sets next round's trading fee
     * @param gamma 1-fee in decimals of four
     * @param round Current round
     */
    event GammaSetEvent(uint32 gamma, uint16 round);

    /**
     * @notice Emitted when owner sets new yearly management fee in 6 decimals
     * @param managementFee Current management fee in decimals of 4
     * @param newManagementFee New management fee in decimals of 4
     */
    event ManagementFeeSetEvent(
        uint256 managementFee,
        uint256 newManagementFee
    );

    /**
     * @notice Emitted when owner sets new weekly performance fee in 6 decimals
     * @param performanceFee Current performance fee in decimals of 4
     * @param newPerformanceFee New performance fee in decimals of 4
     */
    event PerformanceFeeSetEvent(
        uint256 performanceFee,
        uint256 newPerformanceFee
    );

    /**
     * @notice Emitted when owner sets new keeper address
     * @param keeper Address of the keeper
     */
    event KeeperSetEvent(address indexed keeper);

    /**
     * @notice Emitted when owner sets new recipient address for fees
     * @param keeper Address of the keeper
     */
    event FeeRecipientSetEvent(address indexed keeper);

    /**
     * @notice Emitted when owner sets new vault manager contract
     * @param vaultManager Emitted when owner sets new vault manager contract
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
     * @param _primitiveFactory is the address for primitive factory
     * @param _uniswapRouter is the address for uniswap router
     * @param _risky is the address for the risky token
     * @param _stable is the address for the stable token
     * @param _managementFee is the management fee percent per year
     * @param _performanceFee is the management fee percent per round
     */
    constructor(
        address _keeper,
        address _feeRecipient,
        address _vaultManager,
        address _primitiveManager,
        address _primitiveEngine,
        address _primitiveFactory,
        address _uniswapRouter,
        address _risky,
        address _stable,
        uint256 _managementFee,
        uint256 _performanceFee
    ) ERC20(TOKEN_NAME, TOKEN_SYMBOL) {
        require(_keeper != address(0), "!_keeper");
        require(_feeRecipient != address(0), "!_feeRecipient");
        require(_feeRecipient != address(0), "!_feeRecipient");
        require(_vaultManager != address(0), "!_vaultManager");
        require(_primitiveManager != address(0), "!_primitiveManager");
        require(_primitiveEngine != address(0), "!_primitiveEngine");
        require(_primitiveFactory != address(0), "!_primitiveFactory");
        require(_uniswapRouter != address(0), "!_uniswapRouter");
        require(_risky != address(0), "!_risky");
        require(_stable != address(0), "!_stable");
        require(_managementFee > 0, "!_managementFee");
        require(_performanceFee > 0, "!_performanceFee");
        require(
            _managementFee < 100 * 10**Vault.FEE_DECIMALS,
            "_managementFee > 100"
        );
        require(
            _performanceFee < 100 * 10**Vault.FEE_DECIMALS,
            "_performanceFee > 100"
        );
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
        primitiveParams.manager = _primitiveManager;
        primitiveParams.engine = _primitiveEngine;
        primitiveParams.factory = _primitiveFactory;
        primitiveParams.decimals = 18;
        uniswapParams.router = _uniswapRouter;
        /// @dev we may not want this to be a constant
        uniswapParams.poolFee = 3000;
        tokenParams.risky = _risky;
        tokenParams.stable = _stable;
        tokenParams.riskyDecimals = IERC20(_risky).decimals();
        tokenParams.stableDecimals = IERC20(_stable).decimals();
        performanceFee = _performanceFee;
        // Compute management to charge per week by yearly amount
        /// @dev Dividing by 52142857 means we need to multiply 10**6
        managementFee = _managementFee.mul(10**Vault.FEE_DECIMALS).div(
            WEEKS_PER_YEAR
        );
        // Approval for manager to transfer tokens
        IERC20(_risky).safeIncreaseAllowance(
            _primitiveManager,
            type(uint256).max
        );
        IERC20(_stable).safeIncreaseAllowance(
            _primitiveManager,
            type(uint256).max
        );
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
     * @notice Seeds vault with minimum funding for RMM-01 pool deployment.
     *         Called only by owner
     * @dev Requires approval by owner to contract of at least MIN_LIQUIDITY.
     *      This is used to satisfy the minimum liquidity to start RMM-01 pools
     */
    function seedVault() external onlyOwner {
        IERC20(tokenParams.risky).safeTransferFrom(
            msg.sender,
            address(this),
            MIN_LIQUIDITY
        );
        IERC20(tokenParams.stable).safeTransferFrom(
            msg.sender,
            address(this),
            MIN_LIQUIDITY
        );

        // Update state so we don't count seed as profit
        // This has the effect that first round will not take any fees
        VaultMath.assertUint104(MIN_LIQUIDITY);
        vaultState.lastLockedRisky = uint104(MIN_LIQUIDITY);
        vaultState.lastLockedStable = uint104(MIN_LIQUIDITY);
    }

    /**
     * @notice Sets the address of the keeper
     * @dev Set only by the owner
     * @param newKeeper Address of the new keeper
     */
    function setKeeper(address newKeeper) external onlyOwner {
        require(newKeeper != address(0), "!keeper`");
        emit KeeperSetEvent(newKeeper);
        keeper = newKeeper;
    }

    /**
     * @notice Sets the address of the fee recipient
     * @dev Must be a number between 0 and 1 in decimals of 4.
     *      Set only by the owner
     * @param newFeeRecipient Address of the new fee recipient
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "!newFeeRecipient");
        require(newFeeRecipient != feeRecipient, "Old feeRecipient");
        emit FeeRecipientSetEvent(newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    /**
     * @notice Sets the new Vault Manager contract
     * @param newVaultManager Address of the new manager contract
     */
    function setVaultManager(address newVaultManager) external onlyOwner {
        require(newVaultManager != address(0), "!newVaultManager");
        emit VaultManagerSetEvent(newVaultManager);
        vaultManager = newVaultManager;
    }

    /**
     * @notice Sets the address for a ParetoManager contract
     * @dev Set only by the owner
     * @param newManagementFee Address of the new manager contract
     */
    function setManagementFee(uint256 newManagementFee) external onlyOwner {
        require(
            newManagementFee < 100 * 10**Vault.FEE_DECIMALS,
            "newManagementFee > 100"
        );

        // Divide annualized management fee by num weeks in a year
        uint256 weeklyFee = newManagementFee.mul(10**Vault.FEE_DECIMALS).div(
            WEEKS_PER_YEAR
        );

        emit ManagementFeeSetEvent(managementFee, newManagementFee);
        managementFee = weeklyFee;
    }

    /**
     * Sets the performance fee for the vault
     * @param newPerformanceFee The new performance fee
     */
    function setPerformanceFee(uint256 newPerformanceFee) external onlyOwner {
        require(
            newPerformanceFee < 100 * 10**Vault.FEE_DECIMALS,
            "newPerformanceFee > 100"
        );
        emit PerformanceFeeSetEvent(performanceFee, newPerformanceFee);
        performanceFee = newPerformanceFee;
    }

    /**
     * @notice Sets the fee to search for when routing a Uniswap trade
     * @dev Set only by the owner
     * @param newPoolFee Pool fee of the Uniswap AMM used to route swaps of risky and stable tokens
     */
    function setUniswapPoolFee(uint24 newPoolFee) external onlyKeeper {
        require(newPoolFee < 10**6, "newPoolFee > 100");
        uniswapParams.poolFee = newPoolFee;
    }

    /**
     * @notice Sets the strike price for the next vault
     * @dev Set only by the owner
     * @param strikePrice Strike price of the next RMM-01 pool
     */
    function setStrikePrice(uint128 strikePrice) external onlyKeeper {
        require(strikePrice > 0, "!strikePrice");
        emit StrikePriceSetEvent(strikePrice, vaultState.round);
        managerState.manualStrike = strikePrice;
        managerState.manualStrikeRound = vaultState.round;
    }

    /**
     * @notice Sets the implied volatility for the next vault
     * @dev Must be a number between 0 and 1 in decimals of 4.
     *      Set only by the owner
     * @param volatility Implied volatility of the next RMM-01 pool
     */
    function setVolatility(uint32 volatility) external onlyKeeper {
        require(volatility > 0, "!volatility");
        emit VolatilitySetEvent(volatility, vaultState.round);
        managerState.manualVolatility = volatility;
        managerState.manualVolatilityRound = vaultState.round;
    }

    /**
     * @notice Sets the gamma for the next vault
     * @dev Set only by the owner
     * @param gamma One minus fee for the next RMM-01 pool
     */
    function setGamma(uint32 gamma) external onlyKeeper {
        require(gamma > 0, "!gamma");
        emit GammaSetEvent(gamma, vaultState.round);
        managerState.manualGamma = gamma;
        managerState.manualGammaRound = vaultState.round;
    }

    /************************************************
     * User-facing Vault Operations
     ***********************************************/

    /**
     * @notice Save gas by writing default values into the `roundSharePriceInRisky/Stable`.
     *         Future writes will be no longer be cold writes
     * @dev Writing 1 makes subsequent writes warm, reducing the gas from 20k to 5k
     * @param numRounds Number of rounds to initialize in the map
     */
    function initRounds(uint256 numRounds) external nonReentrant {
        require(numRounds > 0, "!numRounds");
        uint256 _round = vaultState.round;
        for (uint256 i = 0; i < numRounds; i++) {
            uint256 index = _round + i;
            // Do not overwrite any existing values
            require(roundSharePriceInRisky[index] == 0, "Initialized");
            require(roundSharePriceInStable[index] == 0, "Initialized");
            roundSharePriceInRisky[index] = 1;
            roundSharePriceInStable[index] = 1;
        }
    }

    /**
     * @notice Deposits risky asset from `msg.sender` to the vault address.
     *         Updates the deposit receipt associated with `msg.sender` in rollover
     * @dev Emits `DepositEvent`
     * @param riskyAmount Amount of risky asset to deposit
     */
    function deposit(uint256 riskyAmount) external override nonReentrant {
        require(riskyAmount > 0, "!riskyAmount");

        emit DepositEvent(msg.sender, riskyAmount, vaultState.round);
        _processDeposit(riskyAmount, msg.sender);

        // Make transfers from tx caller to contract
        IERC20(tokenParams.risky).safeTransferFrom(
            msg.sender,
            address(this),
            riskyAmount
        );
    }

    /**
     * @notice User requests a withdrawal that can be completed after the current round.
     *         Cannot request more shares than than the user obtained through deposits.
     *         Multiple requests can be made for the same round
     * @dev Emits `WithdrawRequestEvent`
     * @param shares Number of shares to withdraw
     */
    function requestWithdraw(uint256 shares) external override nonReentrant {
        _requestWithdraw(shares);

        // Update global variable caching shares queued for withdrawal
        vaultState.currQueuedWithdrawShares = vaultState
            .currQueuedWithdrawShares
            .add(shares);
    }

    /**
     * @notice Users call this function to complete a requested withdraw from a past round.
     *         A withdrawal request must have been made via requestWithdraw.
     *         This function must be called after the round
     * @dev Emits `WithdrawCompleteEvent`.
     *      Burns receipts, and transfers tokens to `msg.sender`
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
     * @notice Deploys a new vault, which creates a new Primitive RMM-01 pool.
     *         Calls the `ParetoManager` to choose the parameters of the next vault
     * @dev Emits `DeployVaultEvent`.
     *      This is the first function to be called when starting a new vault round
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
            if (currPoolId != "") {
                vaultState.lastLockedRisky = vaultState.lockedRisky;
                vaultState.lastLockedStable = vaultState.lockedStable;
            }
        }

        // Reset properties in VaultState
        vaultState.lockedRisky = 0;
        vaultState.lockedStable = 0;

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

        // Reset properties in PoolState
        poolState.currPoolId = "";
        poolState.currLiquidity = 0;

        // Rollover will replace this with nextPoolParams
        delete poolState.currPoolParams;
    }

    /**
     * @notice Rolls the vault's funds into the next vault, pays royalties to the keeper,
     *         performs rebalancing, and deposits tokens into a new Primitive pool
     * @dev Pending assets get converted into locked assets.
     *      The round is complete after this call, at which the round is incremented
     */
    function rollover() external onlyKeeper nonReentrant {
        (
            bytes32 newPoolId,
            uint256 idealLockedRisky,
            uint256 idealLockedStable,
            uint256 queuedWithdrawRisky,
            uint256 queuedWithdrawStable
        ) = _prepareRollover();

        // Rebalance the locked assets
        (uint256 lockedRisky, uint256 lockedStable) = _rebalance(
            idealLockedRisky,
            idealLockedStable
        );

        emit RebalanceVaultEvent(
            idealLockedRisky,
            idealLockedStable,
            lockedRisky,
            lockedStable,
            keeper
        );

        delete idealLockedRisky;
        delete idealLockedStable;

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

        uint256 optionLiquidity = 0;

        if ((lockedRisky > MIN_LIQUIDITY) && (lockedStable > MIN_LIQUIDITY)) {
            // Deposit locked liquidity into Primitive pools
            optionLiquidity = _depositLiquidity(
                newPoolId,
                lockedRisky.sub(MIN_LIQUIDITY),
                lockedStable.sub(MIN_LIQUIDITY)
            );
        }

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
     * @notice Updates receipts. Users only deposit risky assets
     * @dev No minting nor token transfers are done within this function.
     *      Users can call `deposit` and hence `_processDeposit` multiple times
     * @param riskyAmount Amount of risky asset to be deposited
     * @param creditor Address to receive the deposit
     */
    function _processDeposit(uint256 riskyAmount, address creditor) internal {
        uint16 currRound = vaultState.round;

        // Find cached receipt for user if already deposited in a previous round
        Vault.DepositReceipt memory receipt = depositReceipts[creditor];

        // Compute the number of total shares from (1) user's owned shares from
        // depositing earlier and (2) new shares from depositing this round
        uint256 totalShares = receipt.getSharesFromReceipt(
            currRound,
            roundSharePriceInRisky[receipt.round], // round of deposit
            tokenParams.riskyDecimals
        );

        uint256 depositAmount = riskyAmount;

        // If another pending deposit exists for current round, add to it
        if (receipt.round == currRound) {
            depositAmount = uint256(receipt.riskyToDeposit).add(riskyAmount);
        }

        VaultMath.assertUint104(depositAmount);
        VaultMath.assertUint128(totalShares);

        /**
         * @dev New receipt has deposited amount from current round and owned shares from previous rounds.
         *      Critically, `riskyToDeposit` is not accounted for in `ownedShares`.
         *      This is the only place in the code where we update receipts
         */
        depositReceipts[creditor] = Vault.DepositReceipt({
            round: currRound,
            riskyToDeposit: uint104(depositAmount),
            ownedShares: uint128(totalShares)
        });

        /**
         * @dev Pending is the amount of asset waiting to be converted to shares.
         *      Use `riskyAmount` not `depositAmount` since a portion of `depositAmount` has
         *      already been accounted for in a previous call to `_processDeposit`
         */
        uint256 newPendingRisky = uint256(vaultState.pendingRisky).add(
            riskyAmount
        );
        VaultMath.assertUint128(newPendingRisky);
        vaultState.pendingRisky = uint128(newPendingRisky);
    }

    /**
     * @notice Initiates a withdraw to be processed after round completes.
     * @dev This function does not make the actual withdrawal.
     *      Must be called prior to `_completeWithdraw`
     * @param shares Amount of shares to withdraw
     */
    function _requestWithdraw(uint256 shares) internal {
        require(shares > 0, "!shares");
        uint256 accountShares = getAccountShares(msg.sender);
        // Cannot request to withdraw more than owned
        require(shares <= accountShares, "!shares");

        uint16 currRound = vaultState.round;

        // Stores the round and amount of shares to be withdrawn
        Vault.PendingWithdraw storage withdrawal = pendingWithdraw[msg.sender];

        emit WithdrawRequestEvent(msg.sender, shares, currRound);

        uint256 sharesToWithdraw;
        if (withdrawal.round == currRound) {
            // If the user has a pending withdrawal from same round, merge
            sharesToWithdraw = uint256(withdrawal.shares).add(shares);
            require(sharesToWithdraw <= accountShares, "!shares");
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
     * @notice Complete a scheduled withdrawal from past round.
     *         Users deposit risky assets only but can withdraw both risky and stable
     * @return withdrawRisky Withdrawn amount of risky asset
     * @return withdrawStable Withdrawn amount of stable asset
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
            tokenParams.riskyDecimals
        );
        uint256 stableWithdrawn = VaultMath.shareToAsset(
            sharesToWithdraw,
            roundSharePriceInStable[withdrawRound],
            tokenParams.stableDecimals
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
        IERC20(tokenParams.risky).safeTransfer(msg.sender, riskyWithdrawn);
        IERC20(tokenParams.stable).safeTransfer(msg.sender, stableWithdrawn);

        return (riskyWithdrawn, stableWithdrawn);
    }

    /************************************************
     * Vault Operations
     ***********************************************/

    /**
     * @notice Setup the next Primitive pool (i.e. the next option)
     * @dev Deploys a new pool but does not perform rollover
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
        uint32 nextMaturity = _getNextMaturity(currPoolId);

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

        uint256 tau = uint256(nextMaturity).sub(block.timestamp);

        // Fetch the oracle price - this will be used to RMM-01 initial price
        // as well as how much liquidity to swap
        uint256 spotAtCreation = manager.getRiskyToStablePrice();

        /// @dev: tau = maturity timestamp - current timestamp
        uint256 riskyPerLp = manager.getRiskyPerLp(
            spotAtCreation,
            nextStrikePrice,
            nextVolatility,
            tau,
            tokenParams.riskyDecimals,
            tokenParams.stableDecimals
        );

        VaultMath.assertUint128(spotAtCreation);

        // Define params of next pool
        Vault.PoolParams memory nextParams = Vault.PoolParams({
            spotAtCreation: uint128(spotAtCreation),
            strike: nextStrikePrice,
            sigma: nextVolatility,
            maturity: nextMaturity,
            gamma: nextGamma,
            riskyPerLp: riskyPerLp,
            stablePerLp: 0 /// @dev placeholder value
        });

        // Deploy the next Primitive pool; this does not perform rollover
        // The current pool is still the active one
        nextPoolId = _deployPool(nextParams);

        // After obtaining pool id, we back-derive LP price in stable
        uint256 stablePerLp = manager.getStablePerLp(
            IPrimitiveEngineView(primitiveParams.engine).invariantOf(
                nextPoolId
            ),
            riskyPerLp,
            nextStrikePrice,
            nextVolatility,
            tau,
            tokenParams.riskyDecimals,
            tokenParams.stableDecimals
        );
        nextParams.stablePerLp = stablePerLp;
        poolState.nextPoolParams = nextParams;

        return (nextPoolId, nextStrikePrice, nextVolatility, nextGamma);
    }

    /**
     * @notice Rolling to the next option: minting new shares and transferring vault fees
     * @dev Calls to Primitive are not made in this function but require its outputs.
     *      The round is officially updated at the end of this function
     * @return newPoolId Identifier of the next Primitive pool
     * @return lockedRisky Amount of risky asset locked for next round
     * @return lockedStable Amount of stable asset locked for next round
     * @return queuedWithdrawRisky New queued amount amount of risky asset to withdraw
     * @return queuedWithdrawStable New queued amount amount of stable asset to withdraw
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
            uint256 currRisky = IERC20(tokenParams.risky).balanceOf(
                address(this)
            );
            uint256 currStable = IERC20(tokenParams.stable).balanceOf(
                address(this)
            );

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
                    tokenParams.riskyDecimals
                );
                newSharePriceInStable = VaultMath.getSharePrice(
                    currSupply,
                    currStable.sub(vaultState.lastQueuedWithdrawStable),
                    0,
                    tokenParams.stableDecimals
                );

                // Update the amount of risky and stable asset to be withdrawn
                // based on new share price
                queuedWithdrawRisky = vaultState.lastQueuedWithdrawRisky.add(
                    VaultMath.shareToAsset(
                        vaultState.currQueuedWithdrawShares,
                        newSharePriceInRisky,
                        tokenParams.riskyDecimals
                    )
                );
                queuedWithdrawStable = vaultState.lastQueuedWithdrawStable.add(
                    VaultMath.shareToAsset(
                        vaultState.currQueuedWithdrawShares,
                        newSharePriceInStable,
                        tokenParams.stableDecimals
                    )
                );

                // Compute number of shares that can be minted from pending risky
                // This solely uses the amount of pending deposits from new users
                sharesToMint = VaultMath.assetToShare(
                    vaultState.pendingRisky,
                    newSharePriceInRisky,
                    tokenParams.riskyDecimals
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
        if (feeInRisky > MIN_LIQUIDITY) {
            IERC20(tokenParams.risky).safeTransfer(
                payable(feeRecipient),
                feeInRisky.sub(MIN_LIQUIDITY)
            );
        }
        if (feeInStable > MIN_LIQUIDITY) {
            IERC20(tokenParams.stable).safeTransfer(
                payable(feeRecipient),
                feeInStable.sub(MIN_LIQUIDITY)
            );
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
     * @notice Rebalance the tokens in accordance with the current market price
     * @dev Make swaps internally via `UniswapRouter` to achieve optimal risky and stable
     * @dev Not all of `initialRisky` and `initialStable` will be used.
     *      Likely one of the two assets will have a small remainder
     *      This function is called after `_prepareRollover` within `rollover`
     * @param initialRisky Amount of risky available to put into the pool
     * @param initialStable Amount of stable available to put into the pool
     * @return lockedRisky Amount of risky obtained from swap
     * @return lockedStable Amount of stable obtained from swap
     */
    function _rebalance(uint256 initialRisky, uint256 initialStable)
        internal
        returns (uint256 lockedRisky, uint256 lockedStable)
    {
        // Fetch parameters of pool, which are updated after `_prepareRollover`
        Vault.PoolParams memory poolParams = poolState.currPoolParams;

        // Compute best swap values from `initialRisky` and `initialStable`
        // TODO: replace `spotAtCreation` with current Uniswap price? Doing so
        //       may reduce any loss we must take in price drifts
        (uint256 optimalRisky, uint256 optimalStable) = _getBestSwap(
            initialRisky,
            initialStable,
            poolParams.spotAtCreation,
            poolParams.riskyPerLp,
            poolParams.stablePerLp
        );

        if (
            (initialRisky >= optimalRisky) && (initialStable >= optimalStable)
        ) {
            // Case 1: no swap needed - sufficient liquidity on both sides
            lockedRisky = optimalRisky;
            lockedStable = optimalStable;
        } else if (initialRisky > optimalRisky) {
            // Case 2: trade risky for stable
            uint256 deltaStable = _swapRiskyForStable(
                initialRisky.sub(optimalRisky),
                optimalStable.sub(initialStable)
            );
            lockedRisky = optimalRisky;
            lockedStable = initialStable.add(deltaStable);
        } else if (initialStable > optimalStable) {
            // Case 3: trade stable for risky
            uint256 deltaRisky = _swapStableForRisky(
                initialStable.sub(optimalStable),
                optimalRisky.sub(initialRisky)
            );
            lockedRisky = initialRisky.add(deltaRisky);
            lockedStable = optimalStable;
        }

        return (lockedRisky, lockedStable);
    }

    /**
     * @notice Compute optimal swap amounts to deposit into RMM-01 pool
     * @param riskyAmount Amount of risky token currently in portfolio
     * @param stableAmount Amount of stable token currently in portfolio
     * @param riskyToStablePrice Oracle price from risky to stable asset
     * @param riskyPerLp Black-Scholes value of an RMM-01 LP token in risky
     * @param stablePerLp Black-Scholes value of an RMM-01 LP token in stable
     * @return riskyBest Amount of risky to place into the RMM-01 pool
     * @return stableBest Amount of stable to place into the RMM-01 pool
     */
    function _getBestSwap(
        uint256 riskyAmount,
        uint256 stableAmount,
        uint256 riskyToStablePrice,
        uint256 riskyPerLp,
        uint256 stablePerLp
    ) internal view returns (uint256 riskyBest, uint256 stableBest) {
        uint256 value = riskyToStablePrice
            .mul(riskyAmount)
            .div(10**tokenParams.stableDecimals)
            .add(stableAmount);
        uint256 denom = riskyPerLp
            .mul(riskyToStablePrice)
            .div(10**tokenParams.stableDecimals)
            .add(stablePerLp);

        // decimals from mul and div cancel out
        riskyBest = riskyPerLp.mul(value).div(denom);
        // decimals from mul and div cancel out
        stableBest = stablePerLp.mul(value).div(denom);

        // Check that the allocation is feasible
        require(
            !((riskyBest > riskyAmount) && (stableBest > stableAmount)),
            "Unobtainable portfolio"
        );

        return (riskyBest, stableBest);
    }

    /**
     * @notice Check if the vault was successful in making money.
     *         Decides if the performance fee should be token through risky or stable token
     * @dev `preVaultRisky` includes pending deposits from last round and `postVaultRisky`
     *      does not include pending deposits from this round
     * @param inputs Contains the pre- and post- week vault statistics
     * @return success Decides if current value is higher than before the round began
     * @return riskyForPerformanceFee Decides if performance fee in in risky or stable asset
     * @return valueForPerformanceFee Amount to charge for a performance fee
     */
    function _checkVaultSuccess(Vault.VaultSuccessInput memory inputs)
        internal
        view
        returns (
            bool success,
            bool riskyForPerformanceFee,
            uint256 valueForPerformanceFee
        )
    {
        // risky was earned throughout vault
        bool moreRisky = inputs.postVaultRisky > inputs.preVaultRisky;
        // stable was earned throughout vault
        bool moreStable = inputs.postVaultStable > inputs.preVaultStable;

        if (!moreRisky && !moreStable) {
            /// @dev Clearly lost money
            return (false, false, 0);
        }

        uint8 oracleDecimals = IParetoManager(vaultManager).getOracleDecimals();
        uint256 oraclePrice;
        uint256 preVaultValue;
        uint256 postVaultValue;

        if (moreRisky) {
            /// @dev This covers two cases: either more risky and less stable, or
            ///      both more risky and more stable
            oraclePrice = IParetoManager(vaultManager).getStableToRiskyPrice();
            preVaultValue = inputs.preVaultRisky.add(
                inputs.preVaultStable.mul(oraclePrice).div(10**oracleDecimals)
            );
            postVaultValue = inputs.postVaultRisky.add(
                inputs.postVaultStable.mul(oraclePrice).div(10**oracleDecimals)
            );
        } else {
            /// @dev This covers the case with more stable but less risky
            require(moreStable, "!moreStable");
            oraclePrice = IParetoManager(vaultManager).getRiskyToStablePrice();
            preVaultValue = inputs.preVaultStable.add(
                inputs.preVaultRisky.mul(oraclePrice).div(10**oracleDecimals)
            );
            postVaultValue = inputs.postVaultStable.add(
                inputs.postVaultRisky.mul(oraclePrice).div(10**oracleDecimals)
            );
        }

        success = postVaultValue > preVaultValue;
        if (success) {
            valueForPerformanceFee = postVaultValue.sub(preVaultValue);
        }
        return (success, moreRisky, valueForPerformanceFee);
    }

    /**
     * @notice Calculates performance and management fee for this week's round
     * @param feeParams Parameters for fee computation. See `FeeCalculatorInput`
     * @return feeInRisky Fees awarded to fee recipient in risky token
     * @return feeInStable Fees awarded to fee recipient in stable token
     */
    function _getVaultFees(Vault.FeeCalculatorInput memory feeParams)
        internal
        view
        returns (uint256 feeInRisky, uint256 feeInStable)
    {
        // Locked amount should not include new pending amount as deposits should
        // not be counted towards profits
        uint256 currLockedRisky = feeParams.currRisky > feeParams.pendingRisky
            ? feeParams.currRisky.sub(feeParams.pendingRisky)
            : 0;
        // Users cannot deposit stable i.e. `currLockedStable = feeParams.currStable`
        uint256 _performanceFeeInRisky;
        uint256 _performanceFeeInStable;
        uint256 _managementFeeInRisky;
        uint256 _managementFeeInStable;

        // Take performance fee and management fee ONLY if the value of vault's
        // current assets (at current oracle price) is higher than the value of
        // vault before the round (at the same oracle price)
        (
            bool vaultSuccess,
            bool riskyForPerformanceFee,
            uint256 valueForPerformanceFee
        ) = _checkVaultSuccess(
                Vault.VaultSuccessInput({
                    preVaultRisky: feeParams.lastLockedRisky,
                    preVaultStable: feeParams.lastLockedStable,
                    postVaultRisky: currLockedRisky,
                    postVaultStable: feeParams.currStable
                })
            );

        if (vaultSuccess) {
            if (riskyForPerformanceFee) {
                _performanceFeeInRisky = feeParams.performanceFeePercent > 0
                    ? valueForPerformanceFee
                        .mul(feeParams.performanceFeePercent)
                        .div(100 * 10**Vault.FEE_DECIMALS)
                    : 0;
            } else {
                _performanceFeeInStable = feeParams.performanceFeePercent > 0
                    ? valueForPerformanceFee
                        .mul(feeParams.performanceFeePercent)
                        .div(100 * 10**Vault.FEE_DECIMALS)
                    : 0;
            }

            // Management fee is take on the entire locked amount; this removes the
            // amount scheduled to be
            _managementFeeInRisky = feeParams.managementFeePercent > 0
                ? currLockedRisky.mul(feeParams.managementFeePercent).div(
                    100 * 10**Vault.FEE_DECIMALS
                )
                : 0;
            _managementFeeInStable = feeParams.managementFeePercent > 0
                ? feeParams.currStable.mul(feeParams.managementFeePercent).div(
                    100 * 10**Vault.FEE_DECIMALS
                )
                : 0;

            // Total fee is just the sum of the two
            feeInRisky = _performanceFeeInRisky.add(_managementFeeInRisky);
            feeInStable = _performanceFeeInStable.add(_managementFeeInStable);
        }

        return (feeInRisky, feeInStable);
    }

    /************************************************
     * Uniswap Bindings
     ***********************************************/

    /**
     * @notice Use `UniswapRouter` to swap risky for stable tokens
     * @param riskyToSwap Amount of risky token to trade
     * @param stableMinExpected Minimum amount of stable token expected from trade
     * @return stableFromSwap Amount of stable token obtained
     */
    function _swapRiskyForStable(uint256 riskyToSwap, uint256 stableMinExpected)
        internal
        returns (uint256 stableFromSwap)
    {
        stableFromSwap = UniswapRouter.swap(
            address(this),
            tokenParams.risky,
            tokenParams.stable,
            uniswapParams.poolFee,
            riskyToSwap,
            stableMinExpected,
            uniswapParams.router
        );
    }

    /**
     * @notice Use `UniswapRouter` to swap risky for stable tokens
     * @param stableToSwap Amount of risky token traded
     * @param riskyMinExpected Minimum amount of risky token expected from trade
     * @return riskyFromSwap Amount of stable token obtained
     */
    function _swapStableForRisky(uint256 stableToSwap, uint256 riskyMinExpected)
        internal
        returns (uint256 riskyFromSwap)
    {
        riskyFromSwap = UniswapRouter.swap(
            address(this),
            tokenParams.stable,
            tokenParams.risky,
            uniswapParams.poolFee,
            stableToSwap,
            riskyMinExpected,
            uniswapParams.router
        );
    }

    /************************************************
     * Primitive Bindings
     ***********************************************/

    /**
     * @notice Fetch the maturity timestamp of the current Primitive pool
     * @param poolId Identifier of the current pool
     * @return maturity Expiry date of the current pool
     */
    function _getPoolMaturity(bytes32 poolId) internal view returns (uint32) {
        (, , uint32 maturity, , ) = IPrimitiveEngineView(primitiveParams.engine)
            .calibrations(poolId);
        return maturity;
    }

    /**
     * @notice Creates a new Primitive pool using OptionParams
     * @param poolParams Black-Scholes parameters for the pool
     * @return poolId Identifier of the created pool
     */
    function _deployPool(Vault.PoolParams memory poolParams)
        internal
        returns (bytes32)
    {
        uint256 factor = IPrimitiveFactory(primitiveParams.factory)
            .MIN_LIQUIDITY_FACTOR();
        uint256 lowestDecimals = tokenParams.riskyDecimals >
            tokenParams.stableDecimals
            ? tokenParams.stableDecimals
            : tokenParams.riskyDecimals;
        uint256 minLiquidity = 10**(lowestDecimals / factor + 1);
        (bytes32 poolId, , ) = IPrimitiveManager(primitiveParams.manager)
            .create(
                tokenParams.risky,
                tokenParams.stable,
                poolParams.strike,
                poolParams.sigma,
                poolParams.maturity,
                poolParams.gamma,
                poolParams.riskyPerLp,
                minLiquidity
            );
        return poolId;
    }

    /**
     * @notice Deposits a pair of assets in a Primitive pool.
     *         Stores the liquidity tokens in this contract
     * @param poolId Identifier of the pool to deposit in
     * @param riskyAmount Amount of risky assets to deposit
     * @param stableAmount Amount of stable assets to deposit
     * @return liquidity Amount of LP tokens returned from deposit
     */
    function _depositLiquidity(
        bytes32 poolId,
        uint256 riskyAmount,
        uint256 stableAmount
    ) internal returns (uint256) {
        uint256 liquidity = IPrimitiveManager(primitiveParams.manager).allocate(
            address(this),
            poolId,
            tokenParams.risky,
            tokenParams.stable,
            riskyAmount,
            stableAmount,
            false,
            0
        );
        return liquidity;
    }

    /**
     * @notice Removes a pair of assets from a Primitive pool.
     *         Takes liquidity tokens from this contract
     * @param poolId Identifier of the pool to deposit in
     * @param liquidity Amount of LP tokens returned from deposit
     * @return riskyAmount Amount of risky assets to deposit
     * @return stableAmount Amount of stable assets to deposit
     */
    function _removeLiquidity(bytes32 poolId, uint256 liquidity)
        internal
        returns (uint256, uint256)
    {
        if (liquidity == 0) {
            return (0, 0);
        }
        // Moves into margin account in Primitive
        (uint256 riskyAmount, uint256 stableAmount) = IPrimitiveManager(
            primitiveParams.manager
        ).remove(primitiveParams.engine, poolId, liquidity, 0, 0);

        // Moves from margin into this contract
        IPrimitiveManager(primitiveParams.manager).withdraw(
            address(this),
            primitiveParams.engine,
            riskyAmount,
            stableAmount
        );
        return (riskyAmount, stableAmount);
    }

    /************************************************
     * Getter functions (frontend)
     ***********************************************/

    /**
     * @notice Returns the balance held in the vault for one account in risky and stable tokens
     * @param account Address to lookup balance for
     * @return riskyAmount Risky asset owned by the vault for the user
     * @return stableAmount Stable asset owned by the vault for the user
     */
    function getAccountBalance(address account)
        external
        view
        override
        returns (uint256 riskyAmount, uint256 stableAmount)
    {
        uint256 supply = totalSupply();
        if (supply == 0) {
            // no supply tokens
            return (0, 0);
        }
        uint256 sharePriceInRisky = VaultMath.getSharePrice(
            supply,
            totalRisky(),
            vaultState.pendingRisky,
            tokenParams.riskyDecimals
        );
        uint256 sharePriceInStable = VaultMath.getSharePrice(
            supply,
            totalStable(),
            0,
            tokenParams.stableDecimals
        );
        riskyAmount = VaultMath.shareToAsset(
            getAccountShares(account),
            sharePriceInRisky,
            tokenParams.riskyDecimals
        );
        stableAmount = VaultMath.shareToAsset(
            getAccountShares(account),
            sharePriceInStable,
            tokenParams.stableDecimals
        );
        return (riskyAmount, stableAmount);
    }

    /**
     * @notice Returns the number of shares owned by one account
     * @param account Address to lookup balance for
     * @return shares Balance for the account in share decimals
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
            tokenParams.riskyDecimals
        );
        return shares;
    }

    /**
     * @notice Returns vault's balance of risky assets, including amounts locked in pools
     * @return riskyAmount Amount of risky asset used or owned by the contract
     */
    function totalRisky() public view returns (uint256) {
        return
            uint256(vaultState.lockedRisky).add(
                IERC20(tokenParams.risky).balanceOf(address(this))
            );
    }

    /**
     * @notice Returns vault's balance of stable assets, including amounts locked in pools
     * @return stableAmount Amount of stable asset used or owned by the contract
     */
    function totalStable() public view returns (uint256) {
        return
            uint256(vaultState.lockedStable).add(
                IERC20(tokenParams.stable).balanceOf(address(this))
            );
    }

    /// @notice Risky token of the risky / stable pair
    function risky() external view override returns (address) {
        return tokenParams.risky;
    }

    /// @notice Stable token of the risky / stable pair
    function stable() external view override returns (address) {
        return tokenParams.stable;
    }

    /************************************************
     * Utility functions
     ***********************************************/

    /**
     * @notice Gets the next expiry timestamp
     * @param poolId Identifier of the current Primitive pool
     * @return nextMaturity Maturity of the next pool
     */
    function _getNextMaturity(bytes32 poolId) internal view returns (uint32) {
        if (poolId == "") {
            // uninitialized state
            return _getNextFriday(block.timestamp);
        }
        uint32 currMaturity = _getPoolMaturity(poolId);

        // If its past one week since last option
        if (block.timestamp > currMaturity + 7 days) {
            return _getNextFriday(block.timestamp);
        }
        return _getNextFriday(currMaturity);
    }

    /**
     * @notice Gets the next options expiry timestamp
     * @param timestamp Expiry timestamp of the current option
     * @dev Examples:
     * _getNextFriday(week 1 thursday) -> week 1 friday
     * _getNextFriday(week 1 friday) -> week 2 friday
     * _getNextFriday(week 1 saturday) -> week 2 friday
     */
    function _getNextFriday(uint256 timestamp) internal pure returns (uint32) {
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
