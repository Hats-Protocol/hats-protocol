// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

interface IHatsEligibility {
    function checkEligibility(address _user, uint256 _hatId)
        external
        view
        returns (bool);

    function triggerAccountability(address _wearer, uint256 _hatId)
        external
        returns (bool);
}
