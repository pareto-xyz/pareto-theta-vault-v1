// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.6;

interface IParetoVault {
    function deposit(uint256 deposit) external;

    function requestWithdraw(uint256 shares) external;

    function completeWithdraw(uint256 shares) external;

    function getAccountBalance(address account) 
        external 
        view 
        returns (uint256, uint256);
}
