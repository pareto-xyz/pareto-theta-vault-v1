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
     ***********************************************/

    // User's pending deposit for the round
    mapping(address => Vault.DepositReceipt) public depositReceipts;

    // When round closes, the pricePerShare value of an pTHETA token is stored
    // This is used to determine the numebr of shares to be returned to a user 
    // with their DepositReceipt.depositAmount
    mapping(uint256 => uint256) public roundPricePerShare;

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
     * Immutables and Constants
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
     * Events (store info in tx logs)
     ***********************************************/

    event DepositEvent(address indexed account, uint256 amount, uint256 round);

    event ManagementFeeEvent(uint256 managementFee, uint256 newManagementFee);

    event PerformanceFeeEvent(uint256 performanceFee, uint256 newPerformanceFee); 

    event WithdrawEvent(address indexed account, uint256 amount, uint256 shares);

    /************************************************
     * Constructor and Initialization
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
     * Permissions and Roles
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
     * Deposits and Withdrawals
     ***********************************************/
}
