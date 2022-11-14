// SPDX-License-Identifier: CC0

pragma solidity >=0.8.13;

import "./IHatsEligibility.sol";
import "../Interfaces/IHats.sol";
import "utils/Auth.sol";

abstract contract OwnableHatsEligibility is IHats, IHatsEligibility, Auth {
    event HatStandingSet(
        address _wearer,
        uint256 _hatId,
        bool _eligible,
        bool _standing
    );

    IHats public HATS;

    mapping(address => mapping(uint256 => bool)) public standings;

    constructor(address _hatsContract) {
        HATS = IHats(_hatsContract);
    }

    function getWearerStatus(address _wearer, uint64 _hatId)
        public
        view
        returns (bool)
    {
        return standings[_wearer][_hatId];
    }

    function setWearerStatus(
        address _wearer,
        uint256 _hatId,
        bool _eligible,
        bool _standing
    ) public virtual requiresAuth {
        standings[_wearer][_hatId] = _standing;
        _updateHatWearerStatus(_wearer, _hatId, _eligible, _standing);

        emit HatStandingSet(_wearer, _hatId, _eligible, _standing);
    }

    function _updateHatWearerStatus(
        address _wearer,
        uint256 _hatId,
        bool _eligible,
        bool _standing
    ) internal virtual {
        HATS.setHatWearerStatus(_hatId, _wearer, _eligible, _standing);
    }
}
