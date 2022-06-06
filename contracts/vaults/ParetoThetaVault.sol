// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

// Standard imports from OpenZeppelin
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ParetoThetaVaultStorage} from "../storage/ParetoThetaVaultStorage.sol";
import {Vault} from "../libraries/Vault.sol";
import {VaultLifecycle} from "../libraries/VaultLifecycle.sol";
import {VaultMath} from "../libraries/VaultMath.sol";
import {ParetoVault} from "./ParetoVault.sol";

/**
 * UPGRADEABILITY: Since we use the upgradeable proxy pattern, we must observe
 * the inheritance chain closely.
 *
 * Any changes/appends in storage variable needs to happen in ParetoThetaVaultStorage.
 * ParetoThetaVault should not inherit from any other contract aside from ParetoVault,
 * ParetoThetaVaultStorage.
 */
contract ParetoThetaVault is ParetoVault, ParetoThetaVaultStorage {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using VaultMath for Vault.DepositReceipt;

    /************************************************
     *  Immutables and Constants
     ***********************************************/

    // TODO - any for Primitive?

    /************************************************
     *  Events
     ***********************************************/

    event OpenPositionEvent(
        address indexed options,
        uint256 depositAmount,
        address indexed manager
    );

    event ClosePositionEvent(
        address indexed options,
        uint256 withdrawAmount,
        address indexed manager
    );

    event NewStrikeSelectedEvent(uint256 strikePrice, uint256 delta);

    event NewIVSelectedEvent(uint256 impliedVol, uint256 delta);

    /************************************************
     *  Constructor and Initialization
     ***********************************************/

    /**
     * Initializes the `ParetoVault`
     * --
     * @param _weth is the Wrapped Ether contract
     * @param _usdc is the USDC contract
     * --
     * See https://securitygrind.com/solidity-constructors-and-inheritance
     */
    constructor(address _weth, address _usdc) ParetoVault(_weth, _usdc) {
        // TODO - do something
    }
}
