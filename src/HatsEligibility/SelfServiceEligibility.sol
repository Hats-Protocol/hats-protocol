// SPDX-License-Identifier: CC0

pragma solidity >=0.8.13;

import "../HatsEligibility/IHatsEligibility.sol";

abstract contract SelfServiceEligibility is IHatsEligibility {
    // global standing
    function standing(address _user)
        public
        view
        virtual
        returns (bool standing_)
    {
        // eg based on some external banList
    }

    // global eligibility
    function eligible(address _user)
        public
        view
        virtual
        returns (bool eligible_)
    {
        // eg wearing a given hat or holding a given token
    }

    function getWearerStatus(address _wearer, uint256 _hatId)
        external
        view
        override
        returns (bool, bool)
    {
        return (eligible(_wearer), standing(_wearer));
    }
}
