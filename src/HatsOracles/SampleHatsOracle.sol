// SPDX-License-Identifier: CC0

pragma solidity >=0.8.13;

import "./IHatsOracle.sol";
import "../IHats.sol";
import "solmate/auth/Auth.sol";

abstract contract ExpiringHatsOracle is IHatsOracle {
    event HatTokenExpirySet(address _wearer, uint256 _hatId, uint256 _expiry);

    error TokenExpiryInPast();

    IHats public HATS;

    constructor(address _hatsContract) {
        HATS = IHats(_hatsContract);
    }

    // key1: wearer => key2: hatId => value: token expiry timestamp
    mapping(address => mapping(uint256 => uint256)) public tokenExpiries;

    function ruleOnWearerStanding(address _wearer, uint64 _hatId)
        external
        virtual
    {
        bool ruling = checkWearerStanding(_wearer, _hatId);

        HATS.ruleOnHatWearerStanding(_hatId, _wearer, ruling);
    }

    function checkWearerStanding(address _wearer, uint64 _hatId)
        public
        view
        returns (bool)
    {
        return (block.timestamp < tokenExpiries[_wearer][_hatId]);
    }

    function setTokenExpiry(address _wearer, uint256 _hatId, uint256 _expiry) public virtual {
        if (block.timestamp > _expiry) {
            revert TokenExpiryInPast();
        }

        tokenExpiries[_wearer][_hatId] = _expiry;

        emit HatTokenExpirySet(_wearer, _hatId, _expiry);
    }
}

abstract contract OwnableHatsOracle is IHats, IHatsOracle, Auth {
    event HatStandingSet(address _wearer, uint256 _hatId, bool _standing);

    IHats public HATS;

    mapping(address => mapping(uint256 => bool)) public standing;

    constructor(address _hatsContract) {
        HATS = IHats(_hatsContract);
    }

    // do we want to standardize this function / add to the interface?
    function _ruleOnWearerStanding(address _wearer, uint256 _hatId, bool _ruling)
        internal
        virtual
    {
        HATS.ruleOnHatWearerStanding(_hatId, _wearer, _ruling);
    }

    function checkWearerStanding(address _wearer, uint64 _hatId)
        public
        view
        returns (bool)
    {
        return standing[_wearer][_hatId];
    }

    function setStanding(address _wearer, uint256 _hatId, bool _standing)
        public
        virtual
        requiresAuth
    {
        standing[_wearer][_hatId] = _standing;
        _ruleOnWearerStanding(_wearer, _hatId, _standing);

        emit HatStandingSet(_wearer, _hatId, _standing);
    }
}
