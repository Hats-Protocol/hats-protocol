// SPDX-License-Identifier: AGPL-3.0
// Copyright (C) 2023 Haberdasher Labs
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
/// @author Haberdasher Labs
contract HatsIdUtilities is IHatsIdUtilities {
    /// @notice Mapping of tophats requesting to link to admin hats in other trees
    /// @dev Linkage only occurs if request is approved by the new admin
    mapping(uint32 => uint256) public linkedTreeRequests; // topHatDomain => requested new admin

    /// @notice Mapping of approved & linked tophats to admin hats in other trees, used for grafting one hats tree onto another
    /// @dev Trees can only be linked to another tree via their tophat
    mapping(uint32 => uint256) public linkedTreeAdmins; // topHatDomain => hatId

    /**
     * Hat Ids serve as addresses. A given Hat's Id represents its location in its
     * hat tree: its level, its admin, its admin's admin (etc, all the way up to the
     * tophat).
     *
     * The top level consists of 4 bytes and references all tophats.
     *
     * Each level below consists of 16 bits, and contains up to 65,536 child hats.
     *
     * A uint256 contains 4 bytes of space for tophat addresses, giving room for ((256 -
     * 32) / 16) = 14 levels of delegation, with the admin at each level having space for
     * 65,536 different child hats.
     *
     * A hat tree consists of a single tophat and has a max depth of 14 levels.
     */

    /// @dev Number of bits of address space for tophat ids, ie the tophat domain
    uint256 internal constant TOPHAT_ADDRESS_SPACE = 32;

    /// @dev Number of bits of address space for each level below the tophat
    uint256 internal constant LOWER_LEVEL_ADDRESS_SPACE = 16;

    /// @dev Maximum number of levels below the tophat, ie max tree depth
    ///      (256 - TOPHAT_ADDRESS_SPACE) / LOWER_LEVEL_ADDRESS_SPACE;
    uint256 internal constant MAX_LEVELS = 14;

    /// @notice Constructs a valid hat id for a new hat underneath a given admin
    /// @param _admin the id of the admin for the new hat
    /// @param _newHat the uint16 id of the new hat
    /// @return id The constructed hat id
    function buildHatId(uint256 _admin, uint16 _newHat) public pure returns (uint256 id) {
        uint256 mask;
        for (uint256 i = 0; i < MAX_LEVELS;) {
            unchecked {
                mask = uint256(
                    type(uint256).max
                    // should not overflow given known constants
                    >> (TOPHAT_ADDRESS_SPACE + (LOWER_LEVEL_ADDRESS_SPACE * i))
                );
            }
            if (_admin & mask == 0) {
                unchecked {
                    id = _admin
                        | (
                            uint256(_newHat)
                            // should not overflow given known constants
                            << (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - 1 - i))
                        );
                }
                return id;
            }

            // should not overflow based on < MAX_LEVELS stopping condition
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Identifies the level a given hat in its hat tree
    /// @param _hatId the id of the hat in question
    /// @return level (0 to type(uint32).max)
    function getHatLevel(uint256 _hatId) public view returns (uint32 level) {
        // uint256 mask;
        // uint256 i;
        level = getLocalHatLevel(_hatId);
        // for (i = 0; i < MAX_LEVELS;) {
        //     mask = uint256(type(uint256).max >> (TOPHAT_ADDRESS_SPACE + (LOWER_LEVEL_ADDRESS_SPACE * i)));

        //     if (_hatId & mask == 0) break;

        //     // should not overflow based on < MAX_LEVELS stopping condition
        //     unchecked {
        //         ++i;
        //     }
        // }

        uint256 treeAdmin = linkedTreeAdmins[getTophatDomain(_hatId)];

        if (treeAdmin != 0) {
            level = 1 + level + getHatLevel(treeAdmin);
        }

        // return uint32(i);
    }

    /// @notice Identifies the level a given hat in its local hat tree
    /// @dev Similar to getHatLevel, but does not account for linked trees
    /// @param _hatId the id of the hat in question
    /// @return level The local level, from 0 to 14
    function getLocalHatLevel(uint256 _hatId) public pure returns (uint32 level) {
        if (_hatId & uint256(type(uint224).max) == 0) return 0;
        if (_hatId & uint256(type(uint208).max) == 0) return 1;
        if (_hatId & uint256(type(uint192).max) == 0) return 2;
        if (_hatId & uint256(type(uint176).max) == 0) return 3;
        if (_hatId & uint256(type(uint160).max) == 0) return 4;
        if (_hatId & uint256(type(uint144).max) == 0) return 5;
        if (_hatId & uint256(type(uint128).max) == 0) return 6;
        if (_hatId & uint256(type(uint112).max) == 0) return 7;
        if (_hatId & uint256(type(uint96).max) == 0) return 8;
        if (_hatId & uint256(type(uint80).max) == 0) return 9;
        if (_hatId & uint256(type(uint64).max) == 0) return 10;
        if (_hatId & uint256(type(uint48).max) == 0) return 11;
        if (_hatId & uint256(type(uint32).max) == 0) return 12;
        if (_hatId & uint256(type(uint16).max) == 0) return 13;
        return 14;
    }

    /// @notice Checks whether a hat is a topHat
    /// @param _hatId The hat in question
    /// @return bool Whether the hat is a topHat
    function isTopHat(uint256 _hatId) public view returns (bool) {
        return isLocalTopHat(_hatId) && linkedTreeAdmins[getTophatDomain(_hatId)] == 0;
    }

    /// @notice Checks whether a hat is a topHat in its local hat tree
    /// @dev Similar to isTopHat, but does not account for linked trees
    /// @param _hatId The hat in question
    /// @return bool Whether the hat is a topHat for its local tree
    function isLocalTopHat(uint256 _hatId) public pure returns (bool) {
        return _hatId > 0 && uint224(_hatId) == 0;
    }

    /// @notice Gets the hat id of the admin at a given level of a given hat
    /// @dev This function traverses trees by following the linkedTreeAdmin
    ///       pointer to a hat located in a different tree
    /// @param _hatId the id of the hat in question
    /// @param _level the admin level of interest
    /// @return uint256 The hat id of the resulting admin
    function getAdminAtLevel(uint256 _hatId, uint32 _level) public view returns (uint256) {
        uint256 linkedTreeAdmin = linkedTreeAdmins[getTophatDomain(_hatId)];
        if (linkedTreeAdmin == 0) return getLocalAdminAtLevel(_hatId, _level);

        uint32 localTopHatLevel = getHatLevel(getLocalAdminAtLevel(_hatId, 0));

        if (localTopHatLevel <= _level) return getLocalAdminAtLevel(_hatId, _level - localTopHatLevel);

        return getAdminAtLevel(linkedTreeAdmin, _level);
    }

    /// @notice Gets the hat id of the admin at a given level of a given hat
    ///         local to the tree containing the hat.
    /// @param _hatId the id of the hat in question
    /// @param _level the admin level of interest
    /// @return uint256 The hat id of the resulting admin
    function getLocalAdminAtLevel(uint256 _hatId, uint32 _level) public pure returns (uint256) {
        uint256 mask = type(uint256).max << (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - _level));

        return _hatId & mask;
    }

    /// @notice Gets the tophat domain of a given hat
    /// @dev A domain is the identifier for a given hat tree, stored in the first 4 bytes of a hat's id
    /// @param _hatId the id of the hat in question
    /// @return uint32 The domain
    function getTophatDomain(uint256 _hatId) public pure returns (uint32) {
        return uint32(_hatId >> (LOWER_LEVEL_ADDRESS_SPACE * MAX_LEVELS));
    }

    /// @notice Gets the domain of the highest parent tophat — the "tippy tophat"
    /// @param _topHatDomain the 32 bit domain of a (likely linked) tophat
    /// @return The tippy tophat domain
    function getTippyTophatDomain(uint32 _topHatDomain) public view returns (uint32) {
        uint256 linkedAdmin = linkedTreeAdmins[_topHatDomain];
        if (linkedAdmin == 0) return _topHatDomain;
        return getTippyTophatDomain(getTophatDomain(linkedAdmin));
    }

    /// @notice Checks For any circular linkage of trees
    /// @param _topHatDomain the 32 bit domain of the tree to be linked
    /// @param _linkedAdmin the hatId of the potential tree admin
    /// @return bool circular link has been found
    function noCircularLinkage(uint32 _topHatDomain, uint256 _linkedAdmin) public view returns (bool) {
        if (_linkedAdmin == 0) return true;
        uint32 adminDomain = getTophatDomain(_linkedAdmin);
        if (_topHatDomain == adminDomain) return false;
        uint256 parentAdmin = linkedTreeAdmins[adminDomain];
        return noCircularLinkage(_topHatDomain, parentAdmin);
    }

    /// @notice Checks that a tophat domain and its potential linked admin are from the same tree, ie have the same tippy tophat domain
    /// @param _topHatDomain The 32 bit domain of the tophat to be linked
    /// @param _newAdminHat The new admin for the linked tree
    function sameTippyTophatDomain(uint32 _topHatDomain, uint256 _newAdminHat) public view returns (bool) {
        // get highest parent domains for current and new tree root admins
        uint32 currentTippyTophatDomain = getTippyTophatDomain(_topHatDomain);
        uint32 newAdminDomain = getTophatDomain(_newAdminHat);
        uint32 newHTippyTophatDomain = getTippyTophatDomain(newAdminDomain);

        // check that both domains are equal
        return (currentTippyTophatDomain == newHTippyTophatDomain);
    }
}
