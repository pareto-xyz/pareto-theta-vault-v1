// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.6;

import {ERC20} from "./ERC20.sol";
import "hardhat/console.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals) {}

    function testLog() public view {
      console.log("hi");
    }

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}