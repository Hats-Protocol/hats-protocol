// SPDX-License-Identifier: CC0

pragma solidity >=0.8.13;

import "hats-auth/HatsOwned.sol";
import "../HatsEligibility/IHatsEligibility.sol";

/// @notice
/// For use in combination with ../HatsEligibility/SelfServiceEligibility.sol
/// @dev This contract must wear the ADMIN_HAT
abstract contract SelfServiceHatter is HatsOwned {
    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotEligible();

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event AdminHatSet(uint256 adminHat);

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public adminHat;

    IHatsEligibility public selfServiceEligibility;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 _ownerHat,
        address _hatsAddress,
        uint256 _adminHat
    ) HatsOwned(_ownerHat, _hatsAddress) {
        adminHat = _adminHat;
    }

    /*//////////////////////////////////////////////////////////////
                    FUNCTIONS -- EXTERNAL & PUBLIC
    //////////////////////////////////////////////////////////////*/

    function setAdminHat(uint256 _newAdminHat) external onlyOwner {
        adminHat = _newAdminHat;

        emit AdminHatSet(_newAdminHat);
    }

    function selfMintNewHat(
        string memory _details,
        uint32 _maxSupply,
        address _toggle,
        string memory _imageURI
    ) public virtual returns (uint256 _newHatId) {
        // create new hat
        _newHatId = HATS.createHat(
            adminHat,
            _details,
            _maxSupply,
            address(selfServiceEligibility),
            _toggle,
            _imageURI
        );

        // check if
        if (_isEligible(msg.sender, _newHatId)) {
            revert NotEligible();
        }

        // mint the newly created hat to msg.sender
        HATS.mintHat(_newHatId, msg.sender);
    }

    function selfMintExistingHat(uint256 _hatId) public virtual returns (bool) {
        if (_isEligible(msg.sender, _hatId)) {
            revert NotEligible();
        }

        return HATS.mintHat(_hatId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                    FUNCTIONS -- INTERNAL & PRIVATE
    //////////////////////////////////////////////////////////////*/

    function _isEligible(address _user, uint256 _hatId)
        internal
        view
        returns (bool)
    {
        (bool eligible, bool standing) = selfServiceEligibility.getWearerStatus(
            _user,
            _hatId
        );

        return eligible && standing;
    }
}
