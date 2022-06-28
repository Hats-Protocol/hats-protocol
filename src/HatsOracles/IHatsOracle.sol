// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

interface IHatsOracle {
    function checkWearerStanding(address _wearer, uint256 _hatId)
        external
        view
        returns (bool);
}
