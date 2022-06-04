// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// Standard imports from OpenZeppelin
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Helps prevent reentract calls to a function
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// Basic access control mechanism where there is an account (an owner) that an be
// granted exclusive access to specific functions
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// implementation of ERC20 token
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

// Relative imports 
import {Vault} from "../libraries/Vault.sol";
import {VaultLifecycle} from "../libraries/VaultLifecycle.sol";
import {VaultMath} from "../libraries/VaultMath.sol";
import {IWETH} from "../interfaces/IWETH.sol";

/**
 * Based on RibbonVault.sol
 * See https://docs.ribbon.finance/developers/ribbon-v2 
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
    // This is used to determine the numebr of shares to be returned to a user 
    // with their DepositReceipt.depositAmount
    mapping(uint256 => uint256) public roundSharePrice;

    // Pending user withdrawals
    maping(address Vault.Withdrawal) public withdrawals;

    // Vault's parameters
    Vault.VaultParams public vaultParams;

    // Vault's lifecycle state
    Vault.VaultState public vaultState;

    // Fee ecipient for the performance and management fees
    address public feeRecipient;

    // Role in charge of weekly vault operations including `rollToNextOption`
    // and `burnRemainingOTokens`. Cannot access critical vault changes. 
    address public keeper;

    // Performance fee charged on premiums earned in `rollToNextOption`.
    // Only charged when there is no loss.
    uint256 public performanceFee;

    // Management fee charged on entire assets under management (AUM) in 
    // `rollToNextOption`. Only charged when there is no loss.
    uint256 public managementFee;

    // Gap in memory to avoid storage collisions. Safety measure. 
    uint256[30] private ____gap;

    // *IMPORTANT* NO NEW STORAGE VARIABLES SHOULD BE ADDED HERE
    // This is to prevent storage collisions. All storage variables should be 
    // appended to `ParetoThetaVaultStorage` instead.

    /************************************************
     *  Immutables and Constants
     ***********************************************/

    // WETH9 token contract - 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    address public immutable WETH;

    // USDC token contract - 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address public immutable USDC;

    // length of options sale
    uint256 public constant PERIOD = 7 days;

    // Number of weeks per year = 52.142857 weeks * FEE_MULTIPLIER = 52142857
    // Dividing by weeks per year: num.mul(FEE_MULTIPLIER).div(WEEKS_PER_YEAR)
    uint256 private constant WEEKS_PER_YEAR = 52142857;

    /************************************************
     *  Events (store info in tx logs)
     ***********************************************/

    event DepositEvent(address indexed account, uint256 amount, uint256 round);

    event RedeemEvent(uint256 indexed account, uint256 share, uint256 round);

    event WithdrawRequestEvent(
        address indexed account, uint256 shares, uint256 round);

    event WithdrawEvent(address indexed account, uint256 amount, uint256 shares);

    event ManagementFeeEvent(uint256 managementFee, uint256 newManagementFee);

    event PerformanceFeeEvent(
        uint256 performanceFee, uint256 newPerformanceFee); 

    event WithdrawEvent(
        address indexed account, uint256 amount, uint256 shares);

    /************************************************
     *  Constructor and Initialization
     ***********************************************/
    
    /**
     * Initializes contract with immutable variables
     * -- 
     * @param _weth is the Wrapped Ether contract
     * @param _usdc is the USDC contract
     */
    constructor(
        address _weth,
        address _usdc
    ) {
        require(_weth != address(0), "Empty _weth");
        require(_usdc != address(0), "Empty _usdc");
        WETH = _weth;  // Set global variables
        USDC = _usdc;
    }

    /** 
     * Initializes the contract with storage variables
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

        // Setup code from inherited classes
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

        uint256 assetBalance = IERC20(vaultParams.asset).balanceOf(address(this));
        VaultMath.assertUint104(assetBalance);

        // Why is this set to assetBalance?
        vaultState.lastLockedAmount = uint104(assetBalance);

        // Initialize round to 1
        vaultState.round = 1;
    }

    /************************************************
     *  Permissions and Roles (Owner only)
     ***********************************************/

    /**
     * Throws if called by any account other than the keeper.
     */
    modifier onlyKeeper() {
        require(msg.sender == keeper, "Requires keeper");
        _;
    }

    /**
     * Sets the keeper. Only accessible by owner
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
        uint256 weekManagementFee = 
            newManagementFee.mul(Vault.FEE_MULTIPLIER).div(WEEKS_PER_YEAR);
        
        // Log event
        emit ManagementFeeEvent(managementFee, newManagementFee);

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

        emit PerformanceFeeEvent(performanceFee, newPerformanceFee);

        performanceFee = newPerformanceFee;
    }

    /************************************************
     *  Deposits and Withdrawals (User Facing)
     ***********************************************/

    /**
     * Deposits ETH into contract and mints vault shares. 
     * Does nothing if asset is not WETH.
     */
    function depositETH() external payable nonReentrant {
        require(vaultParams.asset == WETH, "Must be WETH");
        require(msg.value > 0, "Invalid value passed");

        _mintShares(msg.value, msg.sender);

        // Make the deposit
        IWETH(WETH).deposit{value: msg.value}();
    }

    /**
     * Deposits asset from msg.sender. Must be the asset 
     * specified in VaultParams
     * --
    * @param amount is the amount of `asset` to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid `amount` passed");

        _mintShares(amount, msg.sender);

        // Requires approve() call by msg.sender
        IERC20(vaultParams.asset).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
    }

    /**
     * Redeems shares owed to account 
     * This is useful for users (e.g. Protocols) who may wish to 
     * own the the shares rather than Pareto
     * --
     * @param numShares is the number of shares to redeem
     */
    function redeem(uint256 numShares) external nonReentrant {
        require(numShares > 0, "Invalid `numShares` passed");
        _redeemShares(numShares, false);
    }

    /**
     * Rdeems all shares owned to account
     * This is useful for users (e.g. Protocols) who may wish to 
     * own the the shares rather than Pareto
     */
    function redeemMax() external nonReentrant {
        _redeemShares(0, true);
    }

    /************************************************
     *  Deposits and Withdrawals (Internal Logic)
     ***********************************************/

    /**
     * Mints the vault shares to the creditor
     * --
     * @param amount is the amount of asset deposited
     * @param creditor is the address to receive the deposit
     */
    function _mintShares(uint256 amount, address creditor) private {
        uint256 currentRound = vaultState.round;
        uint256 balanceWithDeposit = totalBalance().add(amount);

        require(balanceWithDeposit <= vaultParams.maxSupply, "Exceeds cap");
        require(
            balanceWithDeposit >= vaultParams.minSupply,
            "Insufficient balance"
        );

        // Emit to log
        emit DepositEvent(creditor, amount, currentRound);

        Vault.DepositReceipt memory receipt = depositReceipts[creditor];

        // Check if there are pending deposits from previous rounds
        uint256 unredeemedShares = receipt.getSharesFromReceipt(
            currentRound,
            roundSharePrice[receipt.round],
            vaultParams.decimals
        );

        uint256 depositAmount = amount;

        // If another pending deposit exists for current round, add to it
        // This effectively rolls two deposits into one
        if (receipt.round == currentRound) {
            depositAmount = uint256(receipt.amount).add(amount);
        }

        VaultMath.assertUint104(depositAmount);

        depositReceipts[creditor] = Vault.DepositReceipt({
            round: uint16(currentRound),
            amount: uint104(depositAmount),
            // total number of pTHETA tokens owned by user 
            unredeemedShares: uint128(unredeemedShares);
        });

        // Ignore any receipt logic - focus only on `amount`
        uint256 newTotalPending = uint256(vaultState.totalPending).add(amount);
        VaultMath.assertUint128(newTotalPending);

        vaultState.totalPending = uint128(newTotalPending);
    }

    /**
     * Redeems shares owned to account by transfering pTHETA tokens from 
     * vault to user address. This is useful for protocols.
     * --
     * @param numShares is the number of shares to redeem, could be 0 when isMax=true
     * @param isMax is flag for when callers do a max redemption
     */
    function _redeemShares(uint256 numShares, bool isMax) internal {
        Vault.DepositReceipt memory receipt = depositReceipts[msg.sender];

        uint256 currentRound = vaultState.round;
        uint256 unredeemedShares = receipt.getSharesFromReceipt(
            currentRound,
            roundSharePrice[receipt.round],
            vaultParams.decimals
        );

        numShares = isMax ? unredeemedShares : numShares;

        if (numShares == 0) {
            return;  // nothing to do
        }
        requires(numShares <= unredeemedShares, "Exceeds available");

        if (receipt.round < currentRound) {
            depositReceipts[msg.sender].amount = 0;  // mark as redeemed
        }

        VaultMath.assertUint128(numShares);
        depositReceipts[msg.sender].unredeemedShares = uint128(
            unredeemedShares.sub(numShares)
        );

        // Log that shares have been redeemed
        emit Redeem(msg.sender, numShares, receipt.round);

        // user will own the shares
        _transfer(address(this), msg.sender, numShares);
    }

    /**
     * Initiates a withdraw that can be processed after round completes
     * A user is not allowed to withdraw within a round
     *
     * TODO: allow immediate withdraw?
     */
    function _requestWithdraw(uint256 numShares) internal {
        require(numShares > 0, "Invalid `numShares` passed");

        Vault.DepositReceipt memory receipt = depositReceipts[msg.sender];

        // Perform a max redeem before withdrawing
        // After this statement, all shares are in user wallet

        if (receipt.amount > 0 || receipt.unredeemedShares > 0) {
            _redeemShares(0, true);
        }

        uint256 currentRound = vaultState.round;
        Vault.Withdrawal storage withdrawal = withdrawals[msg.sender];

        emit WithdrawRequestEvent(msg.sender, numShares, currentRound);

        uint256 withdrawnShares;

        if (withdrawal.round == currentRound) {
            withdrawnShares = uint256(withdrawal.shares).add(numShares);
        } else {
            require(uint256(withdrawal.shares) == 0, "Found unprocessed withdraw");
            withdrawnShares = numShares;
            // Update round to be current round
            withdrawals[msg.sender].round = uint16(currentRound);
        }

        VaultMath.assertUint128(withdrawnShares);
        withdrawals[msg.sender].shares = uint128(withdrawnShares);

        // transfers shares back to contract (for burning)
        _transfer(msg.sender, address(this), numShares);
    }

    /** 
     * Complete a scheduled withdrawal from past round
     * --
     * @return withdrawAmount is the current withdrawal amount
     */
    function _completeWithdraw() internal returns (uint256) {
        Vault.Withdrawal storage withdrawal = withdrawals[msg.sender];

        uint256 withdrawShares = withdrawal.shares;
        uint256 withdrawRound = withdrawal.round;

        // Check that `_requestWithdraw` has been called
        require(withdrawShares > 0, "Withdrawal not requested");
        // Check that the withdraw request was made in a previous round
        require(withdrawRound < vaultState.round, "Round not complete");

        // Reset params back to 0 (leave round untouched for gas)
        withdrawal[msg.sender].shares = 0;

        uint256 withdrawAmount = VaultMath.sharesToAsset(
            withdrawShares,
            roundSharePrice[withdrawRound],
            vaultParams.decimals
        );

        // Log withdraw event
        emit Withdraw(msg.sender, withdrawAmount, withdrawShares);

        // Burn the shares
        _burn(address(this), withdrawShares);

        require(withdrawAmount > 0, "Invalid `withdrawAmount`");
        _transferAsset(msg.sender, withdrawAmount);

        return withdrawAmount;
    }

    /**
     * Transfer ETH or ERC20 token to recipient
     * -- 
     * @param recipient is the receiving address
     * @param amount is the transfer amount
     */
    function _transferAsset(address recipient, int256 amount) internal {
        if (vaultParams.asset == WETH) {
            // Custom logic for wrapped ETH
            IWETH(WETH).withdraw(amount);
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "Transfer failed");
        } else {
            IERC20(asset).safeTransfer(recipient, amount);
        }
    }

    /************************************************
     *  Vault Operations
     ***********************************************/
    
    /**
     * Hack to save gas by writing `1` into the round price map, which 
     * prevents cold writes. Ribbon documents gas savings from 20k-5k.
     * Requires you to specify number of rounds before hand.
     *
     * TODO This is to be called by the user? Who calls this?
     */
    function initRounds(uint256 numRounds) external nonReentrant {
        require(numRounds > 0, "!numRounds");
        uint256 _round = vaultState.round;
        for (uint256 i = 0; i < numRounds; i++) {
            uint256 index = _round + i;
            // AVOID OVERWRITING ACTUAL VALUES
            require(roundSharePrice[index] == 0, "Already initialized");
            roundSharePrice[index] = VaultMath.PLACEHOLDER_UINT;
        }
    }

    /************************************************
     *  Helper and Getter functions (frontend)
     ***********************************************/
    
    /**
     * Returns the asset balance held in the vault for one account
     * --
     * @param account is the address to lookup balance for
     * --
     * @return the amount of `asset` owned by the vault for the user
     */
    function getAccountBalance(address account) 
        external view returns (uint256)
    {
        uint256 _decimals = vaultParams.decimals;
        uint256 assetPerShare = VaultMath.sharePrice(
            totalSupply(),
            totalBalance(),
            vaultState.totalPending,
            _decimals
        );
        return VaultMath.sharesToAsset(
            getAccountShares(account), assetPerShare, _decimals);
    }

    /**
     * Returns the number of shares (including unredeemed shares) for 
     * one account
     * --
     * @param account is the address to lookup balance for
     * --
     * @return the share balance
     */
    function getAccountShares(address account) public view returns (uint256) {
        (uint256 heldByAccount, heldByVault) = getShareSplit(account);
        return heldByAccount.add(heldByVault);
    }

    /**
     * Returns the number of shares held by account versus held within vault
     * --
     * @param account is the account to lookup share balance for
     * --
     * @return heldByAccount is the shares held by account
     * @return heldByVault is the shares held on the vault (unredeemedShares)
     */
    function getShareSplit(address account)
        public view returns (uint256 heldByAccount, uint256 heldByVault)
    {
        Vault.DepositReceipt memory receipt = depositReceipts[account];

        if (receipt.round < VaultMath.PLACEHOLDER_UINT) {
            // Vault is empty - just return account shares
            return (balanceof(account), 0);
        }

        uint256 unredeemedShares = receipt.getSharesFromReceipt(
            vaultState.round,
            roundSharePrice[receipt.round],
            vaultParams.decimals
        );

        return(balanceOf(account), unredeemedShares);
    }

    /**
     * The share price in the asset
     */
    function getSharePrice() external view returns (uint256) {
        return VaultMath.getSharePrice(
            totalSupply(),
            totalBalance(),
            vaultState.totalPending,
            vaultParams.decimals
        );
    }

    /** 
     * Return vault's total balance, including amounts locked into 
     * third party protocols
     */
    function totalBalance() public view returns (uint256) {
        return uint256(vaultState.lockedAmount)
            .add(IERC20(vaultParams.asset).balanceOf(address(this)));
    }
}
