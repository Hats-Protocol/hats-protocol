// SPDX-License-Identifier: CC0

pragma solidity >=0.8.13;

import "./IHatsToggle.sol";
import "../IHats.sol";
import "utils/Auth.sol";

abstract contract ExpiringHatsToggle is IHatsToggle {
    event HatExpirySet(uint256 _hatId, uint256 _expiry);

    error ExpiryInPast();

    mapping(uint256 => uint256) public expiries; // key: hatId => value: expiry timestamp

    function getHatStatus(uint256 _hatId) public view virtual returns (bool) {
        return (block.timestamp < expiries[_hatId]);
    }

    function setExpiry(uint256 _hatId, uint256 _expiry) public virtual {
        if (block.timestamp > _expiry) {
            revert ExpiryInPast();
        }

        expiries[_hatId] = _expiry;

        emit HatExpirySet(_hatId, _expiry);
    }
}

abstract contract OwnableHatsToggle is IHatsToggle, Auth {
    event HatStatusSet(uint256 _hatId, bool _status);

    IHats public HATS;

    mapping(uint256 => bool) public status;

    constructor(address _hatsContract) {
        HATS = IHats(_hatsContract);
    }

    function getHatStatus(uint256 _hatId) public view virtual returns (bool) {
        return (status[_hatId]);
    }

    function setHatStatus(uint256 _hatId, bool _status)
        public
        virtual
        requiresAuth
    {
        status[_hatId] = _status;
        _updateHatStatus(_hatId, _status);

        emit HatStatusSet(_hatId, _status);
    }

    function _updateHatStatus(uint256 _hatId, bool _status) internal virtual {
        HATS.setHatStatus(_hatId, _status);
    }
}
