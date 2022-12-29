// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/HatsIdUtilities.sol";

contract HatIdUtilTests is Test {
    HatsIdUtilities utils;

    function setUp() public {
        utils = new HatsIdUtilities();
    }

    function testgetHatLevel() public {
        for (uint256 i = 1; 2**i < type(uint224).max; i += 14) {
            // each 14 bits corresponds with a level
            assertEq(utils.getHatLevel(2**i), 16 - (i / 14));
            if (i > 1) {
                assertEq(utils.getHatLevel(2**i + (2**14)), 15);
            }
        }
    }

    function testBuildHatId() public {
        // start with a top hat
        uint256 admin = 1 << 224;
        uint256 next;
        for (uint8 i = 1; i < 17; i++) {
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

        assertEq(utils.getTophatDomain(admin + 1), admin >> 224);
        assertEq(utils.getTophatDomain(1), 0);
        assertEq(utils.getTophatDomain(admin - 1), 0);
    }
}
