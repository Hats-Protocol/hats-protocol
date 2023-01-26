// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/HatsIdUtilities.sol";

contract LinkableHatsIdUtilities is HatsIdUtilities {
    function linkTree(uint32 _topHatId, uint256 _hatId) public {
        linkedTreeAdmins[_topHatId] = _hatId;
    }
}
