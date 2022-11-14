// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

import "./IHatsIdUtilities.sol";

interface IHatsIdUtilities{
    function buildHatId(uint256 _admin, uint8 _newHat)
        external
        pure
        returns (uint256 id);

    function getHatLevel(uint256 _hatId) external pure returns (uint8);

    function isTopHat(uint256 _hatId) external pure returns (bool);

    function getAdminAtLevel(uint256 _hatId, uint8 _level)
        external
        pure
        returns (uint256);

    function getTophatDomain(uint256 _hatId) external pure returns (uint256);
}
