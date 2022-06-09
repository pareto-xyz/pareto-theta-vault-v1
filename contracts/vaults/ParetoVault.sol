// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

// Standard imports from OpenZeppelin
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Helps prevent reentract calls to a function
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// Basic access control mechanism where there is an account (an owner) that an be
// granted exclusive access to specific functions
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// implementation of ERC20 token
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

// Relative imports
import {Vault} from "../libraries/Vault.sol";
import {VaultLifecycle} from "../libraries/VaultLifecycle.sol";
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
     *  Non-upgradeable storage
     ***********************************************/

    // User's pending deposit for the round
    mapping(address => Vault.DepositReceipt) public depositReceipts;

    // When round closes, the share price of an pTHETA token is stored
    // This is used to determine the number of shares to be returned to a user
    // with their DepositReceipt.{risky,stable}Amount
    mapping(uint256 => Vault.SharePrice) public roundSharePrice;

    // Pending user withdrawals
    mapping(address => Vault.Withdrawal) public withdrawals;

    // Vault's parameters
    Vault.VaultParams public vaultParams;

    // Vault's lifecycle state
    Vault.VaultState public vaultState;

    // State of the option in the Vault
    Vault.OptionState public optionState;

    // Recipient of performance and management fees
    address public feeRecipient;

    // Role in charge of weekly vault operations 
    // No access to critical vault changes
    address public keeper;

    /// Performance fee charged on premiums earned.
    //  Only charged when there is no loss.
    uint256 public performanceFee;

    /// Management fee charged on entire AUM.
    // Only charged when there is no loss.
    uint256 public managementFee;

    // Gap is left to avoid storage collisions
    uint256[30] private ____gap;

    /************************************************
     *  Immutables and Constants
     ***********************************************/
    
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

    event ManagementFeeSetEvent(uint256 managementFee, uint256 newManagementFee);

    event PerformanceFeeSetEvent(uint256 performanceFee, uint256 newPerformanceFee);

    event WithdrawEvent(
        address indexed account, 
        uint256 risky, 
        uint256 stable,
        uint256 shares
    );

    event VaultFeesCollectionEvent(
        uint256 performanceFee,
        uint256 vaultFee,
        uint256 round,
        address indexed feeRecipient
    );

    /************************************************
     *  Constructor and Initialization
     ***********************************************/

    /**
     * @notice Initializes the contract with storage variables
     * --
     * @param _owner is the Owner address
     * @param _keeper is the Keeper address
     * @param _feeRecipient is the address that receives fees
     * @param _managementFee is the management fee percent
     * @param _performanceFee is the management fee percent
     * @param _tokenName is the name of the asset
     * @param _tokenSymbol is the symbol of the asset
     * @param _vaultParams is the parameters of the vault
     */
    function baseInitialize(
        address _owner,
        address _keeper,
        address _feeRecipient,
        uint256 _managementFee,
        uint256 _performanceFee,
        string memory _tokenName,
        string memory _tokenSymbol,
        Vault.VaultParams calldata _vaultParams
    ) internal initializer {
        // Check that input parameters are valid
        VaultLifecycle.verifyInitializerParams(
            _owner,
            _keeper,
            _feeRecipient,
            _performanceFee,
            _managementFee,
            _tokenName,
            _tokenSymbol,
            _vaultParams
        );

        // Init calls are required for upgradeable contracts
        __ReentrancyGuard_init();
        __ERC20_init(_tokenName, _tokenSymbol);
        __Ownable_init();
        transferOwnership(_owner);

        // Set global variables
        keeper = _keeper;
        feeRecipient = _feeRecipient;
        performanceFee = _performanceFee;
        managementFee = _managementFee
            .mul(Vault.FEE_MULTIPLIER)
            .div(WEEKS_PER_YEAR);
        vaultParams = _vaultParams;

        // Initialize VaultState
        uint256 riskyBalance = IERC20(vaultParams.risky).balanceOf(address(this));
        uint256 stableBalance = IERC20(vaultParams.stable).balanceOf(address(this))
        VaultMath.assertUint104(riskyBalance);
        VaultMath.assertUint104(stableBalance);
        vaultState.lastLockedRisky = uint104(riskyBalance);
        vaultState.lastLockedStable = uint104(stableBalance);
        vaultState.round = 1;
    }

    /************************************************
     *  Permissions and Roles (Owner only)
     ***********************************************/

    /**
     * @notice Throws if called by any account other than the keeper.
     */
    modifier onlyKeeper() {
        require(msg.sender == keeper, "Requires keeper");
        _;
    }

    /**
     * @notice Sets the keeper. Only accessible by owner
     * --
     * @param newKeeper is the address of the new keeper
     */
    function setKeeper(address newKeeper) external onlyOwner {
        require(newKeeper != address(0), "Missing `newKeeper`");
        keeper = newKeeper;
    }

    /**
     * Sets the fee recipient. Only accessible by owner
     * --
     * @param newFeeRecipient is the address of the new fee recipient
     *  This must be different than the current `feeRecipient`
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "Missing `newFeeRecipient`");
        require(newFeeRecipient != feeRecipient, "Must be new `feeRecipient`");
        feeRecipient = newFeeRecipient;
    }

    /**
     * Sets the management fee for the vault
     * --
     * @param newManagementFee is the management fee (6 decimals)
     *  For example, 2 * 10**6 = 2%
     */
    function setManagementFee(uint256 newManagementFee) external onlyOwner {
        require(
            newManagementFee < 100 * Vault.FEE_MULTIPLIER,
            "Invalid management fee"
        );

        // Divide annualized management fee by num weeks in a year
        uint256 weekManagementFee = newManagementFee
            .mul(Vault.FEE_MULTIPLIER)
            .div(WEEKS_PER_YEAR);

        // Log event
        emit ManagementFeeSetEvent(managementFee, newManagementFee);

        // Note we use the weekly fee
        managementFee = weekManagementFee;
    }

    /**
     * Sets the performance fee for the vault
     * --
     * @param newPerformanceFee is the performance fee (6 decimals)
     *  For example, 20 * 10**6 = 20%
     */
    function setPerformanceFee(uint256 newPerformanceFee) external onlyOwner {
        require(
            newPerformanceFee < 100 * Vault.FEE_MULTIPLIER,
            "Invalid performance fee"
        );

        emit PerformanceFeeSetEvent(performanceFee, newPerformanceFee);

        performanceFee = newPerformanceFee;
    }

    /************************************************
     *  Deposits and Withdrawals
     ***********************************************/

    /**
     * @notice Deposits risky asset from msg.sender. 
     * --
     * @param risky is the amount of risky asset to deposit
     * @param stable is the amount of stable asset to deposit
     *  in stable 
     */
    function deposit(uint256 risky, uint256 stable) 
        external 
        nonReentrant 
    {
        require(risky > 0, "Invalid amount of risky tokens");
        require(stable > 0, "Invalid amount of stable tokens");

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
        uint256 currentRound = vaultState.round;

        // Emit to log
        emit DepositEvent(creditor, risky, stable, currentRound);

        // Find cached receipt for user & retrieve shares
        Vault.DepositReceipt memory receipt = depositReceipts[creditor];
        uint256 shares = receipt.getSharesFromReceipt(
            currentRound,
            roundSharePrice[receipt.round],
            vaultParams.decimals
        );

        uint256 depositRisky = risky;
        uint256 depositStable = stable;

        // If another pending deposit exists for current round, add to it
        // This effectively rolls two deposits into one
        if (receipt.round == currentRound) {
            depositRisky = uint256(receipt.risky).add(risky);
            depositStable = uint256(receipt.stable).add(stable);
        }

        // Sanity check type-casting prior to doing so
        VaultMath.assertUint104(depositRisky);
        VaultMath.assertUint104(depositStable);

        // Update the receipt
        depositReceipts[creditor] = Vault.DepositReceipt({
            round: uint16(currentRound),
            risky: uint104(depositRisky),
            stable: uint104(depositStable),
            shares: uint128(shares)
        });

        // Pending = money waiting to be converted to shares
        uint256 newPendingRisky = uint256(vaultState.pendingRisky).add(risky);
        VaultMath.assertUint128(newPendingRisky);
        vaultState.pendingRisky = uint128(newPendingRisky);

        uint256 newPendingStable = uint256(vaultState.PendingStable).add(stable);
        VaultMath.assertUint128(newPendingStable);
        vaultState.PendingStable = uint128(newPendingStable);
    }

    /**
     * @notice Initiates a withdraw to be processed after round completes
     * @notice This function does not make the actual withdrawl
     * --
     * @param shares is the amount of shares to withdraw
     */
    function _requestWithdraw(uint256 shares) internal {
        require(shares > 0, "Invalid shares passed");

        // Fetch caller's receipt
        Vault.DepositReceipt memory receipt = depositReceipts[msg.sender];

        uint256 currentRound = vaultState.round;
        Vault.Withdrawal storage withdrawal = withdrawals[msg.sender];

        emit WithdrawRequestEvent(msg.sender, shares, currentRound);

        uint256 withdrawnShares;

        if (withdrawal.round == currentRound) {
            // If the user requested a withdrawal recently, merge
            withdrawnShares = uint256(withdrawal.shares).add(shares);
        } else {
            // If we find a withdrawal request from an old round, something
            // bad has happened 
            require(uint256(withdrawal.shares) == 0, "Abandoned withdraw");
            withdrawnShares = shares;
            // Update cached withdrawal request
            withdrawals[msg.sender].round = uint16(currentRound);
        }
        VaultMath.assertUint128(withdrawnShares);  // check typecasting
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
        require(withdrawShares > 0, "Withdrawal not requested");
        // Check that the withdraw request was made in a previous round
        require(withdrawRound < vaultState.round, "Round not complete");

        // Reset params back to 0
        withdrawals[msg.sender].shares = 0;

        (uint256 withdrawRisky, uint256 withdrawStable) = VaultMath.sharesToAsset(
            withdrawShares,
            roundSharePrice[withdrawRound],
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

        require(withdrawRisky > 0, 
            "Invalid amount of risky asset to withdraw");
        require(withdrawStable > 0,
            "Invalid amount of stable asset to withdraw");

        // Transfer tokens from contract to user
        IERC20(vaultParams.risky).safeTransfer(msg.sender, withdrawRisky);
        IERC20(vaultParams.stable).safeTransfer(msg.sender, withdrawStable);

        return (withdrawRisky, withdrawStable);
    }

    /************************************************
     *  Vault Operations
     ***********************************************/

    /**
     * @notice Pipeline for rolling to the next option, such as calling
     *  minting new shares and getting vault fees
     * --
     * @param lastWithdrawRisky is the amount of risky assets withdrawn last
     * @param lastWithdrawStable is the amount of risky assets withdrawn last
     *  This is needed to compute vault fees
     * @param queuedWithdrawShares is the queued withdraw shares for current
     *  round
     * --
     * @return newOption is the new option's address
     * @return lockedBalance is amount 
     * @return queuedWithdrawAmount is the new queued withdraw amount for this
     *  round
     */
    function _rollToNextOption(
        uint256 lastWithdrawAmount,
        uint256 queuedWithdrawShares
    )
        internal
        returns (
            address newOption,
            uint256 lockedBalance,
            uint256 queuedWithdrawAmount
        )
    {
        require(
            block.timestamp >= optionState.nextOptionReadyAt,
            "Too early to roll over"
        );

        newOption = optionState.nextOption;
        require(newOption != address(0), "Invalid next option");

        address recipient = feeRecipient;
        uint256 mintShares;
        uint256 performanceFeeInAsset;
        uint256 totalVaultFee;

        // Begin new scope
        {
            uint256 newSharePrice;

            // Punt to VaultLifecycle to do a lot of the heavy lifting
            (
                lockedBalance,
                queuedWithdrawAmount,
                newSharePrice,
                mintShares,
                performanceFeeInAsset,
                totalVaultFee
            ) = VaultLifecycle.rollover(
                vaultState,
                // Direct usage avoids saving variable
                VaultLifecycle.RolloverParams(
                    vaultParams.decimals,
                    IERC20(vaultParams.asset).balanceOf(address(this)),
                    totalSupply(),
                    lastQueuedWithdrawAmount,
                    performanceFee,
                    managementFee,
                    queuedWithdrawShares
                )
            );

            // Overwrite current option with new option
            optionState.currentOption = newOption;

            // Reset new option to be empty
            optionState.nextOption = address(0);

            uint256 currentRound = vaultState.round;
            roundSharePrice[currentRound] = newSharePrice;

            // Log that vault fees are being collected
            emit VaultFeesCollectionEvent(
                performanceFeeInAsset,
                totalVaultFee,
                currentRound,
                recipient
            );

            // Reset pending to zero
            vaultState.pendingRisky = 0;
            vaultState.pendingStable = 0;
            vaultState.round = uint16(currentRound + 1);
        }

        _mint(address(this), mintShares);

        if (totalVaultFee > 0) {
            _transferAsset(payable(recipient), totalVaultFee);
        }

        return (newOption, lockedBalance, queuedWithdrawAmount);
    }

    /************************************************
     *  Helper and Getter functions (frontend)
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
        Vault.SharePrice memory sharePrice = VaultMath.getSharePrice(
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
                sharePrice,
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
        return receipt.getSharesFromReceipt(
            vaultState.round,
            roundSharePrice[receipt.round],
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
}
