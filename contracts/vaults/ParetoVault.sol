// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.6;

// Standard imports from OpenZeppelin
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Helps prevent reentract calls to a function
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// Basic access control mechanism where there is an account (an owner) that an be
// granted exclusive access to specific functions
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// Implementation of ERC20 token
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// Strike selection
import {IParetoManager} from "../interfaces/IParetoManager.sol";
// Manage Primitive pools
import {IPrimitiveManager} from "@primitivefi/rmm-manager/contracts/interfaces/IPrimitiveManager.sol";
import {IManagerBase} from "@primitivefi/rmm-manager/contracts/interfaces/IManagerBase.sol";
import {IPrimitiveEngineView} from "@primitivefi/rmm-core/contracts/interfaces/engine/IPrimitiveEngineView.sol";
import {EngineAddress} from "@primitivefi/rmm-manager/contracts/libraries/EngineAddress.sol";
// Relative imports
import {Vault} from "../libraries/Vault.sol";
import {VaultMath} from "../libraries/VaultMath.sol";

/**
 * @notice Based on RibbonVault.sol
 * See https://docs.ribbon.finance/developers/ribbon-v2
 * @notice This is a token! You might see it tagged as pTHETA.
 * Special functions include `_mint` and `_burn` to increase
 * and decrease the supply.
 * @notice We expect to inherit from this class.
 */
contract ParetoVault is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    ERC20Upgradeable
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using VaultMath for Vault.DepositReceipt;

    /************************************************
     * Non-upgradeable storage
     * TODO: some of these should probably be made upgradeable!
     ***********************************************/

    // @notice User's pending deposit for the round
    mapping(address => Vault.DepositReceipt) public depositReceipts;

    // @notice When round closes, the share price of a receipt token is stored
    // This is used to determine the number of shares to be returned to a user
    mapping(uint256 => uint256) public roundSharePriceRisky;
    mapping(uint256 => uint256) public roundSharePriceStable;

    // @notice Pending user withdrawals
    mapping(address => Vault.Withdrawal) public withdrawals;

    // @notice Vault's parameters
    Vault.VaultParams public vaultParams;

    // @notice Vault's lifecycle state
    Vault.VaultState public vaultState;

    // @notice State of the option in the Vault
    Vault.PoolState public poolState;

    // Recipient of performance and management fees
    address public feeRecipient;

    // Role in charge of weekly vault operations
    // No access to critical vault changes
    address public keeper;

    /// Management fee charged on entire AUM.
    uint256 public managementFeeRisky;
    uint256 public managementFeeStable;

    // Gap is left to avoid storage collisions
    uint256[30] private ____gap;

    /************************************************
     * Immutables and Constants
     ***********************************************/

    // PRIMITIVE_MANAGER is Primitive's contract for creating, allocating
    // liquidity to, and withdrawing liquidity from pools
    // https://github.com/primitivefinance/rmm-manager/blob/main/contracts/PrimitiveManager.sol
    address public immutable PRIMITIVE_MANAGER;

    // Number of weeks per year = 52.142857 weeks * FEE_MULTIPLIER = 52142857
    // Dividing by weeks per year requires doing num.mul(FEE_MULTIPLIER).div(WEEKS_PER_YEAR)
    uint256 private constant WEEKS_PER_YEAR = 52142857;

    /************************************************
     * Events
     ***********************************************/

    event DepositEvent(
        address indexed account,
        uint256 risky,
        uint256 stable,
        uint256 round
    );

    event WithdrawRequestEvent(
        address indexed account,
        uint256 shares,
        uint256 round
    );

    event ManagementFeeSetEvent(
        uint256 managementFeeRisky,
        uint256 managementFeeStable,
        uint256 newManagementFeeRisky,
        uint256 newManagementFeeStable
    );

    event WithdrawEvent(
        address indexed account,
        uint256 risky,
        uint256 stable,
        uint256 shares
    );

    event VaultFeesCollectionEvent(
        uint256 vaultFeeRisky,
        uint256 vaultFeeStable,
        uint256 round,
        address indexed feeRecipient
    );

    /************************************************
     * Constructor and Initialization
     ***********************************************/

    /**
     * @notice Initializes the contract with immutable variables
     * --
     * @param _primitiveManager is the contract address for primitive manager
     */
    constructor(address _primitiveManager) {
        require(_primitiveManager != address(0), "!_primitiveManager");
        PRIMITIVE_MANAGER = _primitiveManager;
    }

    /**
     * @notice Initializes the contract with storage variables
     * --
     * @param _owner is the Owner address
     * @param _keeper is the Keeper address
     * @param _feeRecipient is the address that receives fees
     * @param _managementFeeRisky is the management fee percent for risky
     * @param _managementFeeStable is the management fee percent for stable
     * @param _tokenName is the name of the asset
     * @param _tokenSymbol is the symbol of the asset
     * @param _vaultParams is the parameters of the vault
     */
    function baseInitialize(
        address _owner,
        address _keeper,
        address _feeRecipient,
        uint256 _managementFeeRisky,
        uint256 _managementFeeStable,
        string memory _tokenName,
        string memory _tokenSymbol,
        Vault.VaultParams calldata _vaultParams
    ) internal initializer {
        // Init calls are required for upgradeable contracts
        __ReentrancyGuard_init();
        __ERC20_init(_tokenName, _tokenSymbol);
        __Ownable_init();
        transferOwnership(_owner);

        // Set global variables
        keeper = _keeper;
        feeRecipient = _feeRecipient;
        managementFeeRisky = _managementFeeRisky.mul(Vault.FEE_MULTIPLIER).div(
            WEEKS_PER_YEAR
        );
        managementFeeStable = _managementFeeStable
            .mul(Vault.FEE_MULTIPLIER)
            .div(WEEKS_PER_YEAR);
        vaultParams = _vaultParams;
        vaultState.round = 1;
    }

    /************************************************
     *  Permissions and Roles (Owner only)
     ***********************************************/

    /**
     * @notice Throws if called by any account other than the keeper.
     */
    modifier onlyKeeper() {
        require(msg.sender == keeper, "!keeper");
        _;
    }

    /**
     * @notice Sets the keeper. Only accessible by owner
     * --
     * @param newKeeper is the address of the new keeper
     */
    function setKeeper(address newKeeper) external onlyOwner {
        require(newKeeper != address(0), "!keeper`");
        keeper = newKeeper;
    }

    /**
     * Sets the fee recipient. Only accessible by owner
     * --
     * @param newFeeRecipient is the address of the new fee recipient
     *  This must be different than the current `feeRecipient`
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "!newFeeRecipient");
        require(newFeeRecipient != feeRecipient, "Old feeRecipient");
        feeRecipient = newFeeRecipient;
    }

    /**
     * Sets the management fee for the vault
     * --
     * @param newManagementFeeRisky is the management fee in risky asset
     * @param newManagementFeeStable is the management fee in stable asset
     */
    function setManagementFee(
        uint256 newManagementFeeRisky,
        uint256 newManagementFeeStable
    ) external onlyOwner {
        require(
            newManagementFeeRisky < 100 * Vault.FEE_MULTIPLIER,
            "newManagementFeeRisky > 100"
        );
        require(
            newManagementFeeStable < 100 * Vault.FEE_MULTIPLIER,
            "newManagementFeeStable > 100"
        );

        // Divide annualized management fee by num weeks in a year
        uint256 weekFeeRisky = newManagementFeeRisky
            .mul(Vault.FEE_MULTIPLIER)
            .div(WEEKS_PER_YEAR);

        uint256 weekFeeStable = newManagementFeeStable
            .mul(Vault.FEE_MULTIPLIER)
            .div(WEEKS_PER_YEAR);

        // Log event
        emit ManagementFeeSetEvent(
            managementFeeRisky,
            managementFeeStable,
            newManagementFeeRisky,
            newManagementFeeStable
        );

        managementFeeRisky = weekFeeRisky;
        managementFeeStable = weekFeeStable;
    }

    /************************************************
     * Deposits and Withdrawals
     ***********************************************/

    /**
     * @notice Deposits risky asset from msg.sender.
     * --
     * @param risky is the amount of risky asset to deposit
     * @param stable is the amount of stable asset to deposit
     *  in stable
     */
    function deposit(uint256 risky, uint256 stable) external nonReentrant {
        require(risky > 0, "!risky");
        require(stable > 0, "!stable");

        _processDeposit(risky, stable, msg.sender);

        // Make transfers from tx caller to contract
        IERC20(vaultParams.risky).safeTransferFrom(
            msg.sender,
            address(this),
            risky
        );
        IERC20(vaultParams.stable).safeTransferFrom(
            msg.sender,
            address(this),
            stable
        );
    }

    /**
     * @notice Updates receipts and internal variables
     * @notice Minting will be done in the next rollover
     * --
     * @param risky is the amount of risky asset to be deposited
     * @param stable is the amount of stable asset to be deposited
     * @param creditor is the address to receive the deposit
     */
    function _processDeposit(
        uint256 risky,
        uint256 stable,
        address creditor
    ) private {
        uint256 currRound = vaultState.round;

        // Emit to log
        emit DepositEvent(creditor, risky, stable, currRound);

        // Find cached receipt for user & retrieve shares
        Vault.DepositReceipt memory receipt = depositReceipts[creditor];
        uint256 shares = receipt.getSharesFromReceipt(
            currRound,
            roundSharePriceRisky[receipt.round],
            roundSharePriceStable[receipt.round],
            vaultParams.decimals
        );

        uint256 depositRisky = risky;
        uint256 depositStable = stable;

        // If another pending deposit exists for current round, add to it
        // This effectively rolls two deposits into one
        if (receipt.round == currRound) {
            depositRisky = uint256(receipt.risky).add(risky);
            depositStable = uint256(receipt.stable).add(stable);
        }

        // Sanity check type-casting prior to doing so
        VaultMath.assertUint104(depositRisky);
        VaultMath.assertUint104(depositStable);

        // Update the receipt
        depositReceipts[creditor] = Vault.DepositReceipt({
            round: uint16(currRound),
            risky: uint104(depositRisky),
            stable: uint104(depositStable),
            shares: uint128(shares)
        });

        // Pending = money waiting to be converted to shares
        uint256 newPendingRisky = uint256(vaultState.pendingRisky).add(risky);
        VaultMath.assertUint128(newPendingRisky);
        vaultState.pendingRisky = uint128(newPendingRisky);

        uint256 newPendingStable = uint256(vaultState.pendingStable).add(
            stable
        );
        VaultMath.assertUint128(newPendingStable);
        vaultState.pendingStable = uint128(newPendingStable);
    }

    /**
     * @notice Initiates a withdraw to be processed after round completes
     * @notice This function does not make the actual withdrawl
     * --
     * @param shares is the amount of shares to withdraw
     */
    function _requestWithdraw(uint256 shares) internal {
        require(shares > 0, "!shares");

        uint256 currRound = vaultState.round;
        Vault.Withdrawal storage withdrawal = withdrawals[msg.sender];

        emit WithdrawRequestEvent(msg.sender, shares, currRound);

        uint256 withdrawnShares;

        if (withdrawal.round == currRound) {
            // If the user requested a withdrawal recently, merge
            withdrawnShares = uint256(withdrawal.shares).add(shares);
        } else {
            // If we find a withdrawal request from an old round, something
            // bad has happened
            require(uint256(withdrawal.shares) == 0, "Abandoned withdraw");
            withdrawnShares = shares;
            // Update cached withdrawal request
            withdrawals[msg.sender].round = uint16(currRound);
        }
        VaultMath.assertUint128(withdrawnShares); // check typecasting
        withdrawals[msg.sender].shares = uint128(withdrawnShares);
    }

    /**
     * @notice Complete a scheduled withdrawal from past round
     * --
     * @return withdrawRisky is the withdrawn amount of risky asset
     * @return withdrawStable is the withdrawn amount of stable asset
     */
    function _completeWithdraw() internal returns (uint256, uint256) {
        Vault.Withdrawal storage withdrawal = withdrawals[msg.sender];

        uint256 withdrawShares = withdrawal.shares;
        uint256 withdrawRound = withdrawal.round;

        // Check that a request to withdrawal has been made
        require(withdrawShares > 0, "!withdrawShares");
        // Check that the withdraw request was made in a previous round
        require(withdrawRound < vaultState.round, "Round incomplete");

        // Reset params back to 0
        withdrawals[msg.sender].shares = 0;

        // Remove portion from queued withdraws
        vaultState.totalQueuedWithdrawShares = uint128(
            uint256(vaultState.totalQueuedWithdrawShares).sub(withdrawShares)
        );

        (uint256 withdrawRisky, uint256 withdrawStable) = VaultMath
            .sharesToAssets(
                withdrawShares,
                roundSharePriceRisky[withdrawRound],
                roundSharePriceStable[withdrawRound],
                vaultParams.decimals
            );

        // Log withdraw event
        emit WithdrawEvent(
            msg.sender,
            withdrawRisky,
            withdrawStable,
            withdrawShares
        );

        // Burn the shares
        _burn(address(this), withdrawShares);

        require(withdrawRisky > 0, "!withdrawRisky");
        require(withdrawStable > 0, "!withdrawStable");

        // Transfer tokens from contract to user
        IERC20(vaultParams.risky).safeTransfer(msg.sender, withdrawRisky);
        IERC20(vaultParams.stable).safeTransfer(msg.sender, withdrawStable);

        return (withdrawRisky, withdrawStable);
    }

    /************************************************
     * Vault Operations
     ***********************************************/

    /**
     * @notice Setup the next Primitive pool (i.e. the next option)
     * @notice Replaces the `commitAndClose` function in Ribbon.
     * --
     * @param deployParams is the struct with details on previous pool and
     *  settings for new pool
     */
    function _prepareNextPool(Vault.DeployParams memory deployParams)
        internal
        returns (
            bytes32 nextPoolId,
            uint128 nextStrikePrice,
            uint32 nextVolatility,
            uint32 nextGamma
        )
    {
        // Compute the maturity date for the next pool
        uint32 nextMaturity = getNextMaturity(deployParams.currPoolId);

        // Manager is responsible for setting up the next pool
        IParetoManager manager = IParetoManager(deployParams.paretoManager);

        // Check if we manually set strike price, overwise call manager
        nextStrikePrice = deployParams.manualStrikeRound == vaultState.round
            ? deployParams.manualStrike
            : manager.getNextStrikePrice();

        require(nextStrikePrice != 0, "!nextStrikePrice");

        // Check if we manually set volatility, overwise call manager
        nextVolatility = deployParams.manualVolatilityRound == vaultState.round
            ? deployParams.manualVolatility
            : manager.getNextVolatility();

        require(nextVolatility != 0, "!nextVolatility");

        // Check if we manually set gamma, overwise call manager
        nextGamma = deployParams.manualGammaRound == vaultState.round
            ? deployParams.manualGamma
            : manager.getNextGamma();

        require(nextGamma != 0, "!nextGamma");

        // Fetch parameters of current pool
        Vault.PoolParams memory currParams = poolState.currPoolParams;

        Vault.PoolParams memory nextParams = Vault.PoolParams({
            strike: nextStrikePrice,
            sigma: nextVolatility,
            maturity: nextMaturity,
            gamma: nextGamma,
            riskyPerLp: currParams.riskyPerLp,
            delLiquidity: currParams.delLiquidity
        });

        // Deploy the Primitive pool
        nextPoolId = _deployPool(nextParams);

        // Save params
        poolState.nextPoolParams = nextParams;

        return (nextPoolId, nextStrikePrice, nextVolatility, nextGamma);
    }

    /**
     * @notice Logistic operations for rolling to the next option, such as
     *  minting new shares and transferring vault fees. The actual calls to
     *  Primitive are not made in this function but require the outputs
     * --
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
        require(block.timestamp >= poolState.nextPoolReadyAt, "Too early");

        newPoolId = poolState.nextPoolId;
        require(newPoolId != "", "!newPoolId");

        uint256 mintShares;
        uint256 vaultFeeRisky;
        uint256 vaultFeeStable;

        {
            uint256 unusedRisky;
            uint256 unusedStable;
            uint256 newRiskyPrice;
            uint256 newStablePrice;

            uint256 currentRisky = IERC20(vaultParams.risky).balanceOf(
                address(this)
            );
            uint256 currentStable = IERC20(vaultParams.stable).balanceOf(
                address(this)
            );

            // Compute vault fees (consider moving this to a library)
            (vaultFeeRisky, vaultFeeStable) = _getVaultFees(
                currentRisky.sub(vaultState.lastQueuedWithdrawRisky),
                currentStable.sub(vaultState.lastQueuedWithdrawStable),
                vaultState.pendingRisky,
                vaultState.pendingStable,
                managementFeeRisky,
                managementFeeStable
            );

            // Remove fee from assets
            currentRisky = currentRisky.sub(vaultFeeRisky);
            currentStable = currentStable.sub(vaultFeeStable);

            {
                // Compute new share price after rollover
                (newRiskyPrice, newStablePrice) = VaultMath.getSharePrice(
                    totalSupply().sub(vaultState.totalQueuedWithdrawShares),
                    currentRisky.sub(vaultState.lastQueuedWithdrawRisky),
                    currentStable.sub(vaultState.lastQueuedWithdrawStable),
                    vaultState.pendingRisky,
                    vaultState.pendingStable,
                    vaultParams.decimals
                );
                (uint256 newRisky, uint256 newStable) = VaultMath
                    .sharesToAssets(
                        vaultState.currQueuedWithdrawShares,
                        newRiskyPrice,
                        newStablePrice,
                        vaultParams.decimals
                    );
                queuedWithdrawRisky = vaultState.lastQueuedWithdrawRisky.add(
                    newRisky
                );
                queuedWithdrawStable = vaultState.lastQueuedWithdrawStable.add(
                    newStable
                );

                // Compute number of shares that can be minded using the
                // liquidity pending
                mintShares = VaultMath.assetsToShares(
                    vaultState.pendingRisky,
                    vaultState.pendingStable,
                    newRiskyPrice,
                    newStablePrice,
                    vaultParams.decimals
                );
            }

            {
                // Compute liquidity remaining as some rounding is required
                // to convert assets to shares
                (uint256 reconRisky, uint256 reconStable) = VaultMath
                    .sharesToAssets(
                        mintShares,
                        newRiskyPrice,
                        newStablePrice,
                        vaultParams.decimals
                    );
                unusedRisky = uint256(vaultState.pendingRisky).sub(reconRisky);
                unusedStable = uint256(vaultState.pendingRisky).sub(
                    reconStable
                );
                require(
                    unusedRisky == 0 || unusedStable == 0,
                    "One must be zero"
                );

                lockedRisky = currentRisky.sub(queuedWithdrawRisky);
                lockedStable = currentStable.sub(queuedWithdrawStable);
            }

            // Record any liquidity not being used
            VaultMath.assertUint128(unusedRisky);
            VaultMath.assertUint128(unusedStable);
            vaultState.unusedRisky = uint128(unusedRisky);
            vaultState.unusedStable = uint128(unusedStable);

            // Update properties of poolState
            poolState.currPoolId = newPoolId;
            poolState.nextPoolId = "";

            poolState.currPoolParams = poolState.nextPoolParams;
            delete poolState.nextPoolParams;

            // record the share price
            roundSharePriceRisky[vaultState.round] = newRiskyPrice;
            roundSharePriceStable[vaultState.round] = newStablePrice;

            // Log that vault fees are being collected
            emit VaultFeesCollectionEvent(
                vaultFeeRisky,
                vaultFeeStable,
                vaultState.round,
                feeRecipient
            );

            // Reset pending to zero
            vaultState.pendingRisky = 0;
            vaultState.pendingStable = 0;

            vaultState.round = uint16(vaultState.round + 1);
        }

        // Mint new shares for next round
        _mint(address(this), mintShares);

        // Make transfers for fee
        if (vaultFeeRisky > 0) {
            IERC20(vaultParams.risky).safeTransfer(
                payable(feeRecipient),
                vaultFeeRisky
            );
        }
        if (vaultFeeStable > 0) {
            IERC20(vaultParams.stable).safeTransfer(
                payable(feeRecipient),
                vaultFeeStable
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
     * @notice Calculates performance and management fee for this week's round
     * --
     * @param currentRisky is the balance of risky assets in vault
     * @param currentStable is the balance of stable assets in vault
     * @param pendingRisky is the pending deposit amount of risky asset
     * @param pendingStable is the pending deposit amount of stable asset
     * @param _managementFeeRisky is the fee percent on the risky asset
     * @param _managementFeeStable is the fee percent on the stable asset
     * --
     * @return vaultFeeRisky is the fees awarded to owner in risky
     * @return vaultFeeStable is the fees awarded to owner in stable
     */
    function _getVaultFees(
        uint256 currentRisky,
        uint256 currentStable,
        uint256 pendingRisky,
        uint256 pendingStable,
        uint256 _managementFeeRisky,
        uint256 _managementFeeStable
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
        _vaultFeeRisky = _managementFeeRisky > 0
            ? riskyMinusPending.mul(_managementFeeRisky).div(
                100 * Vault.FEE_MULTIPLIER
            )
            : 0;
        _vaultFeeStable = _managementFeeStable > 0
            ? stableMinusPending.mul(_managementFeeStable).div(
                100 * Vault.FEE_MULTIPLIER
            )
            : 0;
        return (_vaultFeeRisky, _vaultFeeStable);
    }

    /************************************************
     * Primitive Bindings
     ***********************************************/

    /**
     * @notice Get the underlying Primitive engine of the Manager
     * --
     * @return engine is the address of the engine contract
     */
    function _getPrimitiveEngine() internal view returns (address) {
        address engine = EngineAddress.computeAddress(
            IManagerBase(PRIMITIVE_MANAGER).factory(),
            vaultParams.risky,
            vaultParams.stable
        );
        return engine;
    }

    /**
     * @notice Fetch the maturity timestamp of the current Primitive pool
     * --
     * @param poolId is the identifier of the current pool
     * --
     * @return maturity is the expiry date of the current pool
     */
    function _getPoolMaturity(bytes32 poolId) internal view returns (uint32) {
        address engine = _getPrimitiveEngine();
        (, , uint32 maturity, , ) = IPrimitiveEngineView(engine).calibrations(
            poolId
        );
        return maturity;
    }

    /**
     * @notice Creates a new Primitive pool using OptionParams
     * --
     * @param poolParams are the Black-Scholes parameters for the pool
     * --
     * @return poolId is the pool identifier of the created pool
     */
    function _deployPool(Vault.PoolParams memory poolParams)
        internal
        returns (bytes32)
    {
        (bytes32 poolId, , ) = IPrimitiveManager(PRIMITIVE_MANAGER).create(
            vaultParams.risky,
            vaultParams.stable,
            poolParams.strike,
            poolParams.sigma,
            poolParams.maturity,
            poolParams.gamma,
            poolParams.riskyPerLp,
            poolParams.delLiquidity
        );
        return poolId;
    }

    /**
     * @notice Deposits a pair of assets in a Primitive pool
     * @notice Stores the liquidity tokens in this contract
     * @notice TODO: do we need minimums?
     * --
     * @param poolId is the identifier of the pool to deposit in
     * @param riskyAmount is the amount of risky assets to deposit
     * @param stableAmount is the amount of stable assets to deposit
     * --
     * @return liquidity is the amount of LP tokens returned from deposit
     */
    function _depositLiquidity(
        bytes32 poolId,
        uint256 riskyAmount,
        uint256 stableAmount
    ) internal returns (uint256) {
        uint256 liquidity = IPrimitiveManager(PRIMITIVE_MANAGER).allocate(
            address(this),
            poolId,
            vaultParams.risky, // address of risky address
            vaultParams.stable, // address of stable address
            riskyAmount,
            stableAmount,
            true,
            0
        );
        return liquidity;
    }

    /**
     * @notice Removes a pair of assets from a Primitive pool
     * @notice Takes liquidity tokens from this contract
     * @notice TODO: do we need minimums?
     * --
     * @param poolId is the identifier of the pool to deposit in
     * @param liquidity is the amount of LP tokens returned from deposit
     * --
     * @return riskyAmount is the amount of risky assets to deposit
     * @return stableAmount is the amount of stable assets to deposit
     */
    function _removeLiquidity(bytes32 poolId, uint256 liquidity)
        internal
        returns (uint256, uint256)
    {
        if (liquidity == 0) return (0, 0);

        address engine = _getPrimitiveEngine(); // fetch engine
        (uint256 riskyAmount, uint256 stableAmount) = IPrimitiveManager(
            PRIMITIVE_MANAGER
        ).remove(engine, poolId, liquidity, 0, 0);

        return (riskyAmount, stableAmount);
    }

    /************************************************
     * Getter functions (frontend)
     ***********************************************/

    /**
     * @notice Returns the asset balance held in the vault for one account
     * --
     * @param account is the address to lookup balance for
     * --
     * @return the amount of `asset` owned by the vault for the user
     */
    function getAccountBalance(address account)
        external
        view
        returns (uint256, uint256)
    {
        uint256 _decimals = vaultParams.decimals;
        (uint256 riskyPrice, uint256 stablePrice) = VaultMath.getSharePrice(
            totalSupply(),
            totalRisky(),
            totalStable(),
            vaultState.pendingRisky,
            vaultState.pendingStable,
            _decimals
        );
        return
            VaultMath.sharesToAssets(
                getAccountShares(account),
                riskyPrice,
                stablePrice,
                _decimals
            );
    }

    /**
     * @notice Returns the number of shares (including unredeemed shares) for
     * one account
     * --
     * @param account is the address to lookup balance for
     * --
     * @return the share balance
     */
    function getAccountShares(address account) public view returns (uint256) {
        Vault.DepositReceipt memory receipt = depositReceipts[account];
        return
            receipt.getSharesFromReceipt(
                vaultState.round,
                roundSharePriceRisky[receipt.round],
                roundSharePriceStable[receipt.round],
                vaultParams.decimals
            );
    }

    /**
     * @notice Return vault's total balance of risky assets, including
     *  amounts locked into Primitive
     */
    function totalRisky() public view returns (uint256) {
        return
            uint256(vaultState.lockedRisky).add(
                IERC20(vaultParams.risky).balanceOf(address(this))
            );
    }

    /**
     * @notice Return vault's total balance of stable assets, including
     *  amounts locked into Primitive
     */
    function totalStable() public view returns (uint256) {
        return
            uint256(vaultState.lockedStable).add(
                IERC20(vaultParams.stable).balanceOf(address(this))
            );
    }

    /************************************************
     * Utility functions
     ***********************************************/

    /**
     * @notice Gets the next expiry timestamp
     * --
     * @param poolId is the identifier of the current Primitive pool
     * --
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
     * --
     * @param timestamp is the expiry timestamp of the current option
     * --
     * Reference: https://codereview.stackexchange.com/a/33532
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
