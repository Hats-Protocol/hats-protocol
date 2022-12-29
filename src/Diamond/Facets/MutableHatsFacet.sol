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

import {LibHatsDiamond} from "../Lib/LibHatsDiamond.sol";
import "../Lib/LibHatsStorage.sol";
import {HatsErrors} from "../../Interfaces/HatsErrors.sol";

contract MutableHatsFacet {
    LibHatsStorage.Storage internal s;

    /// @notice Set a mutable hat to immutable
    /// @dev Sets the second bit of hat.config to 0
    /// @param _hatId The id of the Hat to make immutable
    function makeHatImmutable(uint256 _hatId) external {
        LibHatsDiamond._checkAdmin(_hatId);

        LibHatsStorage.Hat storage hat = s._hats[_hatId];

        if (!LibHatsDiamond._isMutable(hat)) {
            revert HatsErrors.Immutable();
        }

        hat.config &= ~uint96(1 << 94);

        emit LibHatsStorage.HatMutabilityChanged(_hatId);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable
    /// @param _hatId The id of the Hat to change
    /// @param _newDetails The new details
    function changeHatDetails(uint256 _hatId, string memory _newDetails)
        external
    {
        LibHatsDiamond._checkAdmin(_hatId);
        LibHatsStorage.Hat storage hat = s._hats[_hatId];

        if (!LibHatsDiamond._isMutable(hat)) {
            revert HatsErrors.Immutable();
        }

        hat.details = _newDetails;

        emit LibHatsStorage.HatDetailsChanged(_hatId, _newDetails);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable
    /// @param _hatId The id of the Hat to change
    /// @param _newEligibility The new eligibility module
    function changeHatEligibility(uint256 _hatId, address _newEligibility)
        external
    {
        LibHatsDiamond._checkAdmin(_hatId);
        LibHatsStorage.Hat storage hat = s._hats[_hatId];

        if (!LibHatsDiamond._isMutable(hat)) {
            revert HatsErrors.Immutable();
        }

        hat.eligibility = _newEligibility;

        emit LibHatsStorage.HatEligibilityChanged(_hatId, _newEligibility);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable
    /// @param _hatId The id of the Hat to change
    /// @param _newToggle The new toggle module
    function changeHatToggle(uint256 _hatId, address _newToggle) external {
        LibHatsDiamond._checkAdmin(_hatId);
        LibHatsStorage.Hat storage hat = s._hats[_hatId];

        if (!LibHatsDiamond._isMutable(hat)) {
            revert HatsErrors.Immutable();
        }

        hat.toggle = _newToggle;

        emit LibHatsStorage.HatToggleChanged(_hatId, _newToggle);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable
    /// @param _hatId The id of the Hat to change
    /// @param _newImageURI The new imageURI
    function changeHatImageURI(uint256 _hatId, string memory _newImageURI)
        external
    {
        LibHatsDiamond._checkAdmin(_hatId);
        LibHatsStorage.Hat storage hat = s._hats[_hatId];

        if (!LibHatsDiamond._isMutable(hat)) {
            revert HatsErrors.Immutable();
        }

        hat.imageURI = _newImageURI;

        emit LibHatsStorage.HatImageURIChanged(_hatId, _newImageURI);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable; new max supply cannot be greater than current supply
    /// @param _hatId The id of the Hat to change
    /// @param _newMaxSupply The new max supply
    function changeHatMaxSupply(uint256 _hatId, uint32 _newMaxSupply) external {
        LibHatsDiamond._checkAdmin(_hatId);
        LibHatsStorage.Hat storage hat = s._hats[_hatId];

        if (!LibHatsDiamond._isMutable(hat)) {
            revert HatsErrors.Immutable();
        }

        if (_newMaxSupply < s.hatSupply[_hatId]) {
            revert HatsErrors.NewMaxSupplyTooLow();
        }

        hat.maxSupply = _newMaxSupply;

        emit LibHatsStorage.HatMaxSupplyChanged(_hatId, _newMaxSupply);
    }
}
