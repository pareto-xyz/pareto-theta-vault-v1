// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import {MoreReplicationMath} from "../libraries/MoreReplicationMath.sol";

/**
 * @notice Test contract to wrap around ReplicationMath.sol library
 */
contract TestMoreReplicationMath {
    function getRiskyPerLp(
        uint256 spot,
        uint256 strike,
        uint256 sigma,
        uint256 tau,
        uint256 scaleFactorRisky,
        uint256 scaleFactorStable
    ) external pure returns (uint256 riskyForLp) {
        return
            MoreReplicationMath.getRiskyPerLp(
                spot,
                strike,
                sigma,
                tau,
                scaleFactorRisky,
                scaleFactorStable
            );
    }
}
