// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20("MockERC20", "MOCK") {
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
