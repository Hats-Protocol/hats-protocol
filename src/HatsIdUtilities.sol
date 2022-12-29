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

import "./Interfaces/IHatsIdUtilities.sol";

/// @title Hats Id Utilities
/// @dev Functions for working with Hat Ids from Hats Protocol. Factored out of Hats.sol
/// for easier use by other contracts.
/// @author Hats Protocol
contract HatsIdUtilities is IHatsIdUtilities {
    /**
     * Hat Ids serve as addresses. A given Hat's Id represents its location in its
     * hat tree: its level, its admin, its admin's admin (etc, all the way up to the
     * tophat).
     *
     * The top level consists of 4 bytes and references all tophats.
     *
     * Each level below consists of 14 bits, and contains up to 16,384 child hats.
     *
     * A uint256 contains 4 bytes of space for tophat addresses and (224 / 14) = 16
     * additional bytes of space, giving room for 28 levels of delegation, with the admin
     * at each level having space for 16,384 different child hats.
     *
     * A hat tree consists of a single tophat and has a max depth of 16 levels.
     */

    uint256 internal constant TOPHAT_ADDRESS_SPACE = 32; // 32 bits (4 bytes) of space for tophats, aka the "domain"
    uint256 internal constant LOWER_LEVEL_ADDRESS_SPACE = 14; // 14 bits of space for each of the levels below the tophat
    uint256 internal constant MAX_LEVELS = 16; // 16 levels below the tophat

    /// @notice Constructs a valid hat id for a new hat underneath a given admin
    /// @dev Check hats[_admin].lastHatId for the previous hat created underneath _admin
    /// @param _admin the id of the admin for the new hat
    /// @param _newHat the uint16 id of the new hat (must be < 2**14)
    /// @return id The constructed hat id
    function buildHatId(uint256 _admin, uint16 _newHat)
        public
        pure
        returns (uint256 id)
    {
        if (_newHat > 2**14 - 1) revert(); // TODO add a custom error
        uint256 mask;
        // TODO: remove this loop
        for (uint256 i = 0; i < MAX_LEVELS; ++i) {
            mask = uint256(
                type(uint256).max >>
                    (TOPHAT_ADDRESS_SPACE + (LOWER_LEVEL_ADDRESS_SPACE * i))
            );
            if (_admin & mask == 0) {
                id =
                    _admin |
                    (uint256(_newHat) <<
                        (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - 1 - i)));
                return id;
            }
        }
    }

    /// @notice Identifies the level a given hat in its hat tree
    /// @param _hatId the id of the hat in question
    /// @return level (0 to MAX_LEVELS)
    function getHatLevel(uint256 _hatId) public pure returns (uint8) {
        uint256 mask;
        uint256 i;
        // TODO: get rid of this for loop and possibly use the YUL switch/case
        // syntax. Otherwise, return to the original syntax
        for (i = 0; i < MAX_LEVELS; ++i) {
            mask = uint256(
                type(uint256).max >>
                    (TOPHAT_ADDRESS_SPACE + (LOWER_LEVEL_ADDRESS_SPACE * i))
            );

            if (_hatId & mask == 0) return uint8(i);
        }

        return uint8(MAX_LEVELS);
    }

    /// @notice Checks whether a hat is a topHat
    /// @dev For use when passing a Hat object is not appropriate
    /// @param _hatId The hat in question
    /// @return bool Whether the hat is a topHat
    function isTopHat(uint256 _hatId) public pure returns (bool) {
        return _hatId > 0 && uint224(_hatId) == 0;
    }

    /// @notice Gets the hat id of the admin at a given level of a given hat
    /// @param _hatId the id of the hat in question
    /// @param _level the admin level of interest
    /// @return uint256 The hat id of the resulting admin
    function getAdminAtLevel(uint256 _hatId, uint8 _level)
        public
        pure
        returns (uint256)
    {
        uint256 mask = type(uint256).max <<
            (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - _level));

        return _hatId & mask;
    }

    /// @notice Gets the tophat domain of a given hat
    /// @dev A domain is the identifier for a given hat tree, stored in the first 4 bytes of a hat's id
    /// @param _hatId the id of the hat in question
    /// @return uint256 The domain
    function getTophatDomain(uint256 _hatId) public pure returns (uint256) {
        return
            getAdminAtLevel(_hatId, 0) >>
            (LOWER_LEVEL_ADDRESS_SPACE * MAX_LEVELS);
    }
}
