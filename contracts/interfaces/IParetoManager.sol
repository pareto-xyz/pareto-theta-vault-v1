// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.4;

import {Vault} from "../libraries/Vault.sol";

interface IParetoManager {
    function getNextStrikePrice() 
        external
        view
        returns (uint128);

    function getNextVolatility()
        external
        view
        returns (uint32);
}