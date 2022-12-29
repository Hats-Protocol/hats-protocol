// Copyright (C) 2022 Hats Protocol
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.8.13;

import "../Lib/LibHatsStorage.sol";
import {HatsErrors} from "../../Interfaces/HatsErrors.sol";
import {LibHatsDiamond} from "../Lib/LibHatsDiamond.sol";

contract ViewHatsFacet {
    LibHatsStorage.Storage internal s;

    /// @notice View the properties of a given Hat
    /// @param _hatId The id of the Hat
    /// @return details The details of the Hat
    /// @return maxSupply The max supply of tokens for this Hat
    /// @return supply The number of current wearers of this Hat
    /// @return eligibility The eligibility address for this Hat
    /// @return toggle The toggle address for this Hat
    /// @return imageURI The image URI used for this Hat
    /// @return lastHatId The most recently created Hat with this Hat as admin; also the count of Hats with this Hat as admin
    /// @return mutable_ Whether this hat's properties can be changed
    /// @return active Whether the Hat is current active, as read from `_isActive`
    function viewHat(uint256 _hatId)
        public
        view
        returns (
            string memory details,
            uint32 maxSupply,
            uint32 supply,
            address eligibility,
            address toggle,
            string memory imageURI,
            uint8 lastHatId,
            bool mutable_,
            bool active
        )
    {
        LibHatsStorage.Hat memory hat = s._hats[_hatId];
        details = hat.details;
        maxSupply = hat.maxSupply;
        supply = s.hatSupply[_hatId];
        eligibility = hat.eligibility;
        toggle = hat.toggle;
        imageURI = LibHatsDiamond._getImageURIForHat(_hatId);
        lastHatId = hat.lastHatId;
        mutable_ = LibHatsDiamond._isMutable(hat);
        active = LibHatsDiamond._isActive(hat, _hatId);
    }

    /// @notice Checks whether a given address wears a given Hat
    /// @dev Convenience function that wraps `balanceOf`
    /// @param _user The address in question
    /// @param _hatId The id of the Hat that the `_user` might wear
    /// @return bool Whether the `_user` wears the Hat.
    function isWearerOfHat(address _user, uint256 _hatId)
        public
        view
        returns (bool)
    {
        return LibHatsDiamond._isWearerOfHat(_user, _hatId);
    }

    /// @notice Checks whether a given address serves as the admin of a given Hat
    /// @dev Recursively checks if `_user` wears the admin Hat of the Hat in question. This is recursive since there may be a string of Hats as admins of Hats.
    /// @param _user The address in question
    /// @param _hatId The id of the Hat for which the `_user` might be the admin
    /// @return bool Whether the `_user` has admin rights for the Hat
    function isAdminOfHat(address _user, uint256 _hatId)
        public
        view
        returns (bool)
    {
        return LibHatsDiamond._isAdminOfHat(_user, _hatId);
    }

    /// @notice Checks whether a wearer of a Hat is in good standing
    /// @dev Public function for use when pa    ssing a Hat object is not possible or preferable
    /// @param _wearer The address of the Hat wearer
    /// @param _hatId The id of the Hat
    /// @return standing Whether the wearer is in good standing
    function isInGoodStanding(address _wearer, uint256 _hatId)
        public
        view
        returns (bool standing)
    {
        standing = LibHatsDiamond._isInGoodStanding(_wearer, _hatId);
    }

    /// @notice Checks whether an address is eligible for a given Hat
    /// @dev Public function for use when passing a Hat object is not possible or preferable
    /// @param _hatId The id of the Hat
    /// @param _wearer The address to check
    /// @return bool
    function isEligible(address _wearer, uint256 _hatId)
        public
        view
        returns (bool)
    {
        return LibHatsDiamond._isEligible(_wearer, s._hats[_hatId], _hatId);
    }

    /// @notice Checks the active status of a hat
    /// @dev Use `_isActive` for internal calls that can take a Hat as a param
    /// @param _hatId The id of the hat
    /// @return bool The active status of the hat
    function isActive(uint256 _hatId) public view returns (bool) {
        return LibHatsDiamond._isActive(s._hats[_hatId], _hatId);
    }

    function isMutable(uint256 _hatId) public view returns (bool) {
        return LibHatsDiamond._isMutable(s._hats[_hatId]);
    }
}
