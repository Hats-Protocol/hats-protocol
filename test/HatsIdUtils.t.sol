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

    function testBuildHatIdRevertsAfterMaxLevel() public {
        uint256 admin = 0x0000000100010001000100010001000100010001000100010001000100010001;
        vm.expectRevert(MaxLevelsReached.selector);
        uint256 invalidChild = utils.buildHatId(admin, 1);
        console2.log(invalidChild);
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

    function testGetAdminAtLocalHatLevel() public {
        uint256 hat = 0x000000FF000100020003000400050006000700080009000a000b000c000d000e;
        assertEq(utils.getLocalHatLevel(hat), 14);
        assertEq(
            utils.getAdminAtLocalLevel(hat, 13), 0x000000FF000100020003000400050006000700080009000a000b000c000d0000
        );
        assertEq(
            utils.getAdminAtLocalLevel(hat, 12), 0x000000FF000100020003000400050006000700080009000a000b000c00000000
        );
    }

    function testIsValidHatId_Valid() public {
        uint256 good = 0x000000FF000100020003000400050006000700080009000a000b000c000d000e;
        assertTrue(utils.isValidHatId(good));
    }

    function testIsValidHatId_Invalid1() public {
        uint256 empty1 = 0x000000FF000000020003000400050006000700080009000a000b000c000d000e;
        uint256 empty2 = 0x000000FF000100000003000400050006000700080009000a000b000c000d000e;
        uint256 empty3 = 0x000000FF000100020000000400050006000700080009000a000b000c000d000e;
        uint256 empty4 = 0x000000FF000100020003000000050006000700080009000a000b000c000d000e;
        uint256 empty5 = 0x000000FF000100020003000400000006000700080009000a000b000c000d000e;
        uint256 empty6 = 0x000000FF000100020003000400050000000700080009000a000b000c000d000e;
        uint256 empty7 = 0x000000FF000100020003000400050006000000080009000a000b000c000d000e;

        assertFalse(utils.isValidHatId(empty1));
        assertFalse(utils.isValidHatId(empty2));
        assertFalse(utils.isValidHatId(empty3));
        assertFalse(utils.isValidHatId(empty4));
        assertFalse(utils.isValidHatId(empty5));
        assertFalse(utils.isValidHatId(empty6));
        assertFalse(utils.isValidHatId(empty7));
    }

    function testIsValidHatId_Invalid2() public {
        uint256 empty8 = 0x000000FF000100020003000400050006000700000009000a000b000c000d000e;
        uint256 empty9 = 0x000000FF000100020003000400050006000700080000000a000b000c000d000e;
        uint256 emptya = 0x000000FF0001000200030004000500060007000800090000000b000c000d000e;
        uint256 emptyb = 0x000000FF000100020003000400050006000700080009000a0000000c000d000e;
        uint256 emptyc = 0x000000FF000100020003000400050006000700080009000a000b0000000d000e;
        uint256 emptyd = 0x000000FF000100020003000400050006000700080009000a000b000c0000000e;
        uint256 emptye = 0x000000FF000100020003000400050006000700080009000a000b000c000d0000;

        assertFalse(utils.isValidHatId(empty8));
        assertFalse(utils.isValidHatId(empty9));
        assertFalse(utils.isValidHatId(emptya));
        assertFalse(utils.isValidHatId(emptyb));
        assertFalse(utils.isValidHatId(emptyc));
        assertFalse(utils.isValidHatId(emptyd));
        // this is the same as a valid level 13 hat
        assertTrue(utils.isValidHatId(emptye));
    }
}
