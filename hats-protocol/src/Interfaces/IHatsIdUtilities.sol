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

interface IHatsIdUtilities {
    function buildHatId(uint256 _admin, uint16 _newHat) external pure returns (uint256 id);

    function getHatLevel(uint256 _hatId) external view returns (uint8);

    function isTopHat(uint256 _hatId) external view returns (bool);

    function getAdminAtLevel(uint256 _hatId, uint8 _level) external view returns (uint256);

    function getTreeAdminAtLevel(uint256 _hatId, uint8 _level) external pure returns (uint256);

    function getTophatDomain(uint256 _hatId) external view returns (uint32);

    function getTippyTophatDomain(uint32 _topHatDomain) external view returns (uint32);

    function noCircularLinkage(uint32 _topHatDomain, uint256 _linkedAdmin) external view returns (bool);

    function sameTippyTophatDomain(uint32 _topHatDomain, uint256 _newAdminHat) external view returns (bool);
}
