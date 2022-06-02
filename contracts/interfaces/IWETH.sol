// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

/**
 * Interface for WETH.
 */
interface IWETH {
    // `payable` allows a function to receive ether when called
    function deposit() external payable;

    function withdraw(uint256) external;

    function balanceOf(address account) external view returns (uint256);

    // transfers to recipient
    function transfer(address recipient, uint256 amount) 
        external returns (bool);

    // transfers from sender to recipient
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function decimals() external view returns (uint256);
}