// SPDX-License-Identifier: CC0

pragma solidity >=0.8.13;

import "./IHatsConditions.sol";
import "solmate/auth/Auth.sol";

abstract contract ExpiringHatsConditions is IHatsConditions {
    event HatExpirySet(uint256 _hatId, uint256 _expiry);

    error ExpiryInPast();

    mapping(uint256 => uint256) public expiries; // key: hatId => value: expiry timestamp

    function checkConditions(uint256 _hatId)
        public
        view
        virtual
        returns (bool)
    {
        return (now < expiries[_hatId]);
    }

    function setExpiry(uint256 _hatId, uint256 _expiry) public virtual {
        if (now > _expiry) {
            revert ExpiryInPast();
        }

        expiries[_hatId] = _expiry;

        emit HatExpirySet(_hatId, _expiry);
    }
}

abstract contract OwnableHatsConditions is IHats, IHatsConditions, Auth {
    event HatStatusSet(uint256 _hatId, bool _status);

    IHats public HATS;

    mapping(uint256 => bool) public status;

    constructor(address _hatsContract) {
        HATS = IHats(_hatsContract);
    }

    function checkConditions(uint256 _hatId)
        public
        view
        virtual
        returns (bool)
    {
        return (status[_hatId]);
    }

    function setStatus(uint256 _hatId, bool _status)
        public
        virtual
        requiresAuth
    {
        status[_hatId] = _status;
        _updateHatStatus(_hatId, _status);

        emit HatStatusSet(_hatId, _status);
    }

    function _updateHatStatus(_uint256 _hatId, bool _status) internal virtual {
        HATS.changeHatStatus(_hatId, _status);
    }
}
