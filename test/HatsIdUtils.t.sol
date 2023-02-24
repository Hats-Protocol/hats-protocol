// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/HatsIdUtilities.sol";
import "./LinkableHatsIdUtilities.sol";

contract LinkedTreeHatIdUtilTests is Test {
    LinkableHatsIdUtilities utils;

    error InvalidChildHat();

    function setUp() public {
        utils = new LinkableHatsIdUtilities();
    }

    function testLinkedHats() public {
        uint256 admin = 1 << 224;
        uint32 oldTopHat = 2;
        uint256 oldTopHatId = uint256(oldTopHat) << 224;
        uint256 id1 = utils.buildHatId(admin, 1);
        utils.linkTree(oldTopHat, id1);
        assertFalse(utils.isTopHat(oldTopHatId));
        assertEq(utils.getHatLevel(oldTopHatId), utils.getHatLevel(id1) + 1);
        assertEq(utils.getAdminAtLevel(oldTopHatId, 0), admin);

        uint32 admin3 = 3;
        uint256 admin3Id = uint256(admin3) << 224;
        uint256 id3 = utils.buildHatId(admin3Id, 3);
        utils.linkTree(1, id3);
        assertEq(utils.getHatLevel(id1), 3);
        assertEq(utils.getHatLevel(oldTopHatId), utils.getHatLevel(id1) + 1);
        assertEq(utils.getHatLevel(admin), utils.getHatLevel(id3) + 1);
        assertEq(utils.getHatLevel(admin3Id), 0);
        assertFalse(utils.isTopHat(admin));

        assertEq(utils.getAdminAtLevel(id1, 2), admin);
        assertEq(utils.getAdminAtLevel(oldTopHatId, 0), admin3Id);
    }
}

contract HatIdUtilTests is Test {
    HatsIdUtilities utils;
    uint256 tophatBits = 32;
    uint256 levelBits = 16;
    uint256 levels = 14;

    function setUp() public {
        utils = new HatsIdUtilities();
    }

    function testgetHatLevel() public {
        for (uint256 i = 1; 2 ** i < type(uint224).max; i += levelBits) {
            // each `levelBits` bits corresponds with a level
            assertEq(utils.getHatLevel(2 ** i), levels - (i / levelBits));
            if (i > 1) {
                assertEq(utils.getHatLevel(2 ** i + (2 ** levelBits)), levels - 1);
            }
        }
    }

    function testBuildHatId() public {
        // start with a top hat
        uint256 admin = 1 << 224;
        uint256 next;
        for (uint8 i = 1; i < (levels - 1); i++) {
            next = utils.buildHatId(admin, 1);
            assertEq(utils.getHatLevel(next), i);
            assertEq(utils.getAdminAtLevel(next, i - 1), admin);
            admin = next;
        }
    }

    function testTopHatDomain() public {
        uint256 admin = 1 << 224;
        assertEq(utils.isTopHat(admin), true);
        assertEq(utils.isTopHat((admin + 1) << 216), false);
        assertEq(utils.isTopHat(admin + 1), false);
        assertEq(utils.isTopHat(admin - 1), false);

        assertEq(utils.getTopHatDomain(admin + 1), admin >> 224);
        assertEq(utils.getTopHatDomain(1), 0);
        assertEq(utils.getTopHatDomain(admin - 1), 0);
    }
}
