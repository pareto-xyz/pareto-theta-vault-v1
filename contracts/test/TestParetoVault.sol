// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import {Vault} from "../libraries/Vault.sol";
import {ParetoVault} from "../vaults/ParetoVault.sol";
import {console} from "hardhat/console.sol";

/**
 * @notice Test contract for ParetoVault
 *         Goal is to add public versions for all internal functions
 * @dev This contract is only for testing purposes. Do not deploy
 *      All test functions will start with `test...`
 *      See `ParetoVault.sol` for parameter and function descriptions
 */
contract TestParetoVault is ParetoVault {
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
    )
        ParetoVault(
            _keeper,
            _feeRecipient,
            _vaultManager,
            _primitiveManager,
            _primitiveEngine,
            _primitiveFactory,
            _uniswapRouter,
            _risky,
            _stable,
            _managementFee,
            _performanceFee
        )
    {}

    function testProcessDeposit(uint256 riskyAmount, address creditor) public {
        _processDeposit(riskyAmount, creditor);
    }

    function testRequestWithdraw(uint256 shares) public {
        _requestWithdraw(shares);
    }

    function testCompleteWithdraw() public returns (uint256, uint256) {
        return _completeWithdraw();
    }

    function testPrepareNextPool(bytes32 currPoolId)
        public
        returns (
            bytes32 nextPoolId,
            uint128 nextStrikePrice,
            uint32 nextVolatility,
            uint32 nextGamma
        )
    {
        return _prepareNextPool(currPoolId);
    }

    function testPrepareRollover()
        public
        returns (
            bytes32,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return _prepareRollover();
    }

    function testRebalance(uint256 initialRisky, uint256 initialStable)
        public
        returns (uint256, uint256)
    {
        return _rebalance(initialRisky, initialStable);
    }

    function testGetBestSwap(
        uint256 riskyAmount,
        uint256 stableAmount,
        uint256 riskyToStablePrice,
        uint256 riskyPerLp,
        uint256 stablePerLp
    ) public view returns (uint256, uint256) {
        return
            _getBestSwap(
                riskyAmount,
                stableAmount,
                riskyToStablePrice,
                riskyPerLp,
                stablePerLp
            );
    }

    function testCheckVaultSuccess(Vault.VaultSuccessInput memory inputs)
        public
        view
        returns (
            bool,
            bool,
            uint256
        )
    {
        return _checkVaultSuccess(inputs);
    }

    function testGetVaultFees(Vault.FeeCalculatorInput memory feeParams)
        public
        view
        returns (uint256, uint256)
    {
        return _getVaultFees(feeParams);
    }

    function testSwapRiskyForStable(
        uint256 riskyToSwap,
        uint256 stableMinExpected
    ) public returns (uint256) {
        return _swapRiskyForStable(riskyToSwap, stableMinExpected);
    }

    function testSwapStableForRisky(
        uint256 stableToSwap,
        uint256 riskyMinExpected
    ) public returns (uint256) {
        return _swapStableForRisky(stableToSwap, riskyMinExpected);
    }

    function testGetNextMaturity(bytes32 poolId) public view returns (uint32) {
        return getNextMaturity(poolId);
    }

    function testGetNextFriday(uint256 timestamp) public pure returns (uint32) {
        return getNextFriday(timestamp);
    }

    function testGetPoolMaturity(bytes32 poolId) public view returns (uint32) {
        return _getPoolMaturity(poolId);
    }

    function testDeployPool(Vault.PoolParams memory poolParams)
        public
        returns (bytes32)
    {
        return _deployPool(poolParams);
    }

    function testDepositLiquidity(
        bytes32 poolId,
        uint256 riskyAmount,
        uint256 stableAmount
    ) public returns (uint256) {
        return _depositLiquidity(poolId, riskyAmount, stableAmount);
    }

    function testRemoveLiquidity(bytes32 poolId, uint256 liquidity)
        public
        returns (uint256, uint256)
    {
        return _removeLiquidity(poolId, liquidity);
    }
}
