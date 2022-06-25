// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.6;

import {
    ABDKMath64x64
} from "@primitivefi/rmm-core/contracts/libraries/ABDKMath64x64.sol";
import {
    CumulativeNormalDistribution
} from "@primitivefi/rmm-core/contracts/libraries/CumulativeNormalDistribution.sol";
import {Units} from "@primitivefi/rmm-core/contracts/libraries/Units.sol";

/**
 * @notice Replication math useful for vaults
 */

library ReplicationMath {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;
    using CumulativeNormalDistribution for int128;
    using Units for int128;
    using Units for uint256;

    int128 internal constant ONE_INT = 0x10000000000000000;

    function getRiskyPerLp(
        uint256 spot,
        uint256 strike,
        uint256 sigma,
        uint256 tau
    ) internal pure returns (uint256 riskyForLp) {}
}
