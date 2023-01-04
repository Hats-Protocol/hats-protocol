// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";
import "./HatsTestSetup.t.sol";

contract DeployTest is TestSetup {
    function testDeployWithParams() public {
        assertEq(ViewHatsFacet(hats).name(), name);
    }
}

contract CreateTopHatTest is TestSetup {
    function setUp() public override {
        setUpVariables();

        // instantiate Hats contract
        hats = deployHatsDiamond();
    }

    function testTopHatCreated() public {
        string memory details = "tophat";
        vm.expectEmit(false, false, false, true);
        emit HatCreated(
            2**224,
            details,
            1,
            address(0),
            address(0),
            false,
            topHatImageURI
        );

        topHatId = HatsCoreFacet(hats).mintTopHat(
            topHatWearer,
            details,
            topHatImageURI
        );

        assertTrue(ViewHatsFacet(hats).isTopHat(topHatId));
        assertEq(2**224, topHatId);
    }

    function testTopHatMinted() public {
        vm.expectEmit(true, true, true, true);

        emit TransferSingle(address(this), address(0), topHatWearer, 2**224, 1);

        topHatId = HatsCoreFacet(hats).mintTopHat(
            topHatWearer,
            "tophat",
            topHatImageURI
        );

        assertTrue(ViewHatsFacet(hats).isWearerOfHat(topHatWearer, topHatId));
        assertFalse(ViewHatsFacet(hats).isWearerOfHat(nonWearer, topHatId));
    }

    function testTransferTopHat() public {
        topHatId = HatsCoreFacet(hats).mintTopHat(
            topHatWearer,
            "tophat",
            topHatImageURI
        );

        emit log_uint(topHatId);
        emit log_address(nonWearer);

        vm.prank(address(topHatWearer));
        HatsCoreFacet(hats).transferHat(topHatId, topHatWearer, nonWearer);
    }
}

contract CreateHatsTest is TestSetup {
    function testImmutableHatCreated() public {
        // get prelim values
        (, , , , , , uint8 lastHatId, , ) = ViewHatsFacet(hats).viewHat(
            topHatId
        );

        vm.expectEmit(false, false, false, true);
        emit HatCreated(
            HatsCoreFacet(hats).getNextId(topHatId),
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            false,
            secondHatImageURI
        );

        // topHatId = hats.mintTopHat(topHatWearer, topHatImageURI);
        vm.prank(address(topHatWearer));

        secondHatId = HatsCoreFacet(hats).createHat(
            topHatId,
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            false,
            secondHatImageURI
        );

        // assert admin's lastHatId is incremented
        (, , , , , , uint8 lastHatIdPost, , ) = ViewHatsFacet(hats).viewHat(
            topHatId
        );
        (, , , , , , , mutable_, ) = ViewHatsFacet(hats).viewHat(secondHatId);
        assertEq(lastHatId + 1, lastHatIdPost);
        assertFalse(mutable_);
    }

    function testMutableHatCreated() public {
        vm.expectEmit(false, false, false, true);
        emit HatCreated(
            HatsCoreFacet(hats).getNextId(topHatId),
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            true,
            secondHatImageURI
        );

        console2.log("secondHat");

        vm.prank(address(topHatWearer));
        secondHatId = HatsCoreFacet(hats).createHat(
            topHatId,
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            true,
            secondHatImageURI
        );

        (, , , , , , , mutable_, ) = ViewHatsFacet(hats).viewHat(secondHatId);
        assertTrue(mutable_);
    }

    function testHatsBranchCreated() public {
        // mint TopHat
        // topHatId = hats.mintTopHat(topHatWearer, topHatImageURI);

        (uint256[] memory ids, address[] memory wearers) = createHatsBranch(
            3,
            topHatId,
            topHatWearer,
            false
        );
        assertEq(ViewHatsFacet(hats).getHatLevel(ids[2]), 3);
        assertEq(ViewHatsFacet(hats).getAdminAtLevel(ids[0], 0), topHatId);
        assertEq(ViewHatsFacet(hats).getAdminAtLevel(ids[1], 1), ids[0]);
        assertEq(ViewHatsFacet(hats).getAdminAtLevel(ids[2], 2), ids[1]);
    }
}

// contract BatchCreateHats is TestSetupBatch {
//     function testBatchCreateTwoHats() public {
//         testBatchCreateHatsSameAdmin(2);
//     }

//     function testBatchCreateOneHat() public {
//         testBatchCreateHatsSameAdmin(1);
//     }

//     function testBatchCreateHatsSameAdmin(uint256 count) public {
//         // this is inefficient, but bound() is not working correctly
//         vm.assume(count >= 1);
//         vm.assume(count < 256);

//         adminsBatch = new uint256[](count);
//         detailsBatch = new string[](count);
//         maxSuppliesBatch = new uint32[](count);
//         eligibilityModulesBatch = new address[](count);
//         toggleModulesBatch = new address[](count);
//         mutablesBatch = new bool[](count);
//         imageURIsBatch = new string[](count);

//         vm.prank(topHatWearer);

//         // populate the creating arrays
//         for (uint256 i = 0; i < count; ++i) {
//             adminsBatch[i] = topHatId;
//             detailsBatch[i] = "deets";
//             maxSuppliesBatch[i] = 10;
//             eligibilityModulesBatch[i] = _eligibility;
//             toggleModulesBatch[i] = _toggle;
//             mutablesBatch[i] = false;
//             imageURIsBatch[i] = "";
//         }

//         hats.batchCreateHats(
//             adminsBatch,
//             detailsBatch,
//             maxSuppliesBatch,
//             eligibilityModulesBatch,
//             toggleModulesBatch,
//             mutablesBatch,
//             imageURIsBatch
//         );

//         (, , , , , , uint8 lastHatId, , ) = hats.viewHat(topHatId);

//         assertEq(lastHatId, count);

//         (, , , , address t, , , , ) = hats.viewHat(
//             hats.buildHatId(topHatId, uint8(count))
//         );
//         assertEq(t, _toggle);
//     }

//     function testBatchCreateHatsSkinnyFullBranch() public {
//         uint256 count = 28;

//         adminsBatch = new uint256[](count);
//         detailsBatch = new string[](count);
//         maxSuppliesBatch = new uint32[](count);
//         eligibilityModulesBatch = new address[](count);
//         toggleModulesBatch = new address[](count);
//         mutablesBatch = new bool[](count);
//         imageURIsBatch = new string[](count);

//         uint256 adminId = topHatId;

//         // populate the creating arrays
//         for (uint256 i = 0; i < count; ++i) {
//             uint32 level = uint32(i) + 1;

//             adminsBatch[i] = adminId;
//             detailsBatch[i] = string.concat("level ", vm.toString(level));
//             maxSuppliesBatch[i] = level;
//             eligibilityModulesBatch[i] = _eligibility;
//             toggleModulesBatch[i] = _toggle;
//             mutablesBatch[i] = false;
//             imageURIsBatch[i] = vm.toString(level);

//             adminId = hats.buildHatId(adminId, 1);
//         }

//         vm.prank(topHatWearer);

//         hats.batchCreateHats(
//             adminsBatch,
//             detailsBatch,
//             maxSuppliesBatch,
//             eligibilityModulesBatch,
//             toggleModulesBatch,
//             mutablesBatch,
//             imageURIsBatch
//         );

//         assertEq(
//             hats.getHatLevel( // should be adminId
//                 hats.buildHatId(
//                     hats.getAdminAtLevel(adminId, uint8(count - 1)),
//                     1
//                 )
//             ),
//             count
//         );
//     }

//     function testBatchCreateHatsErrorArrayLength(
//         uint256 count,
//         uint256 offset,
//         uint256 array
//     ) public {
//         count = bound(count, 1, 254);
//         // count = 2;
//         offset = bound(offset, 1, 255 - count);
//         // offset = 1;
//         array = bound(array, 1, 7);

//         uint256 extra = count + offset;
//         // initiate the creation arrays
//         if (array == 1) {
//             adminsBatch = new uint256[](extra);
//             detailsBatch = new string[](count);
//             maxSuppliesBatch = new uint32[](count);
//             eligibilityModulesBatch = new address[](count);
//             toggleModulesBatch = new address[](count);
//             mutablesBatch = new bool[](count);
//             imageURIsBatch = new string[](count);
//         } else if (array == 2) {
//             adminsBatch = new uint256[](count);
//             detailsBatch = new string[](extra);
//             maxSuppliesBatch = new uint32[](count);
//             eligibilityModulesBatch = new address[](count);
//             toggleModulesBatch = new address[](count);
//             mutablesBatch = new bool[](count);
//             imageURIsBatch = new string[](count);
//         } else if (array == 3) {
//             adminsBatch = new uint256[](count);
//             detailsBatch = new string[](count);
//             maxSuppliesBatch = new uint32[](extra);
//             eligibilityModulesBatch = new address[](count);
//             toggleModulesBatch = new address[](count);
//             mutablesBatch = new bool[](count);
//             imageURIsBatch = new string[](count);
//         } else if (array == 4) {
//             adminsBatch = new uint256[](count);
//             detailsBatch = new string[](count);
//             maxSuppliesBatch = new uint32[](count);
//             eligibilityModulesBatch = new address[](extra);
//             toggleModulesBatch = new address[](count);
//             mutablesBatch = new bool[](count);
//             imageURIsBatch = new string[](count);
//         } else if (array == 5) {
//             adminsBatch = new uint256[](count);
//             detailsBatch = new string[](count);
//             maxSuppliesBatch = new uint32[](count);
//             eligibilityModulesBatch = new address[](count);
//             toggleModulesBatch = new address[](extra);
//             mutablesBatch = new bool[](count);
//             imageURIsBatch = new string[](count);
//         } else if (array == 6) {
//             adminsBatch = new uint256[](count);
//             detailsBatch = new string[](count);
//             maxSuppliesBatch = new uint32[](count);
//             eligibilityModulesBatch = new address[](count);
//             toggleModulesBatch = new address[](count);
//             mutablesBatch = new bool[](extra);
//             imageURIsBatch = new string[](count);
//         } else if (array == 7) {
//             adminsBatch = new uint256[](count);
//             detailsBatch = new string[](count);
//             maxSuppliesBatch = new uint32[](count);
//             eligibilityModulesBatch = new address[](count);
//             toggleModulesBatch = new address[](count);
//             mutablesBatch = new bool[](count);
//             imageURIsBatch = new string[](extra);
//         }

//         vm.prank(topHatWearer);

//         // populate the creation arrays
//         for (uint32 i = 0; i < count; ++i) {
//             adminsBatch[i] = topHatId;
//             detailsBatch[i] = vm.toString(i);
//             maxSuppliesBatch[i] = i;
//             eligibilityModulesBatch[i] = _eligibility;
//             toggleModulesBatch[i] = _toggle;
//             mutablesBatch[i] = false;
//             imageURIsBatch[i] = vm.toString(i);
//         }

//         // add `offset` number of hats to the batch, but only with one array filled out
//         for (uint32 j = 0; j < offset; ++j) {
//             if (array == 1) adminsBatch[j] = topHatId;
//             if (array == 2) detailsBatch[j] = vm.toString(j);
//             if (array == 3) maxSuppliesBatch[j] = j;
//             if (array == 4) eligibilityModulesBatch[j] = _eligibility;
//             if (array == 5) toggleModulesBatch[j] = _toggle;
//             if (array == 6) mutablesBatch[j] = false;
//             if (array == 7) imageURIsBatch[j] = vm.toString(j);
//         }

//         // adminsBatch[count] = topHatId;

//         vm.expectRevert(
//             abi.encodeWithSelector(HatsErrors.BatchArrayLengthMismatch.selector)
//         );

//         hats.batchCreateHats(
//             adminsBatch,
//             detailsBatch,
//             maxSuppliesBatch,
//             eligibilityModulesBatch,
//             toggleModulesBatch,
//             mutablesBatch,
//             imageURIsBatch
//         );
//     }
// }

contract ImageURITest is TestSetup2 {
    function testTopHatImageURI() public {
        string memory uri = ViewHatsFacet(hats).getImageURIForHat(topHatId);

        // assertEq(string.concat(topHatImageURI, "0"), uri);
        assertEq(uri, topHatImageURI);
    }

    function testHatImageURI() public {
        string memory uri = ViewHatsFacet(hats).getImageURIForHat(secondHatId);

        // assertEq(string.concat(secondHatImageURI, "0"), uri);
        assertEq(uri, secondHatImageURI);
    }

    function testEmptyHatImageURI() public {
        // create third Hat
        vm.prank(secondWearer);
        thirdHatId = HatsCoreFacet(hats).createHat(
            secondHatId,
            "third hat",
            2, // maxSupply
            _eligibility,
            _toggle,
            false,
            ""
        );

        string memory uri3 = ViewHatsFacet(hats).getImageURIForHat(thirdHatId);

        // assertEq(
        //     uri3,
        //     string.concat(secondHatImageURI, Strings.toString(thirdHatId))
        // );

        assertEq(uri3, secondHatImageURI);
    }

    function testEmptyTopHatImageURI() public {
        uint256 topHat = HatsCoreFacet(hats).mintTopHat(topHatWearer, "", "");

        string memory uri = ViewHatsFacet(hats).getImageURIForHat(topHat);

        // assertEq(uri, string.concat(_baseImageURI, Strings.toString(topHat)));
        assertEq(uri, _baseImageURI);
    }

    function testEmptyHatBranchImageURI() public {
        uint256 topHat = HatsCoreFacet(hats).mintTopHat(topHatWearer, "", "");

        (uint256[] memory ids, ) = createHatsBranch(
            5,
            topHat,
            topHatWearer,
            false
        );

        string memory uri = ViewHatsFacet(hats).getImageURIForHat(ids[4]);

        // assertEq(uri, string.concat(_baseImageURI, Strings.toString(ids[4])));
        assertEq(uri, _baseImageURI);
    }

    // function testChangeGlobalBaseImageURI() public {
    //     // only the Hats.sol contract owner can change it
    // }

    // function testNonOwnerCannotChangeGlobalBaseImageURI() public {
    //     //
    // }
}

contract MintHatsTest is TestSetup {
    function setUp() public override {
        super.setUp();

        vm.prank(topHatWearer);
        secondHatId = HatsCoreFacet(hats).createHat(
            topHatId,
            "second hat",
            2, // maxSupply
            _eligibility,
            _toggle,
            false,
            secondHatImageURI
        );
    }

    function testMintHat() public {
        // get initial values
        uint256 secondWearerBalance = ERC1155Facet(hats).balanceOf(
            secondWearer,
            secondHatId
        );
        uint32 hatSupply = HatsCoreFacet(hats).hatSupply(secondHatId);

        // check transfer event will be emitted
        vm.expectEmit(true, true, true, true);

        emit TransferSingle(
            topHatWearer,
            address(0),
            secondWearer,
            secondHatId,
            1
        );

        // 2-2. mint hat
        vm.prank(address(topHatWearer));
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);

        // assert balance = 1
        assertEq(
            ERC1155Facet(hats).balanceOf(secondWearer, secondHatId),
            ++secondWearerBalance
        );

        // assert iswearer
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        // assert hatSupply is incremented
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), ++hatSupply);
    }

    function testMintAnotherHat() public {
        // store prelim values
        uint256 balance_pre = ERC1155Facet(hats).balanceOf(
            thirdWearer,
            secondHatId
        );
        uint32 supply_pre = HatsCoreFacet(hats).hatSupply(secondHatId);
        (, , , , , , uint8 lastHatId_pre, , ) = ViewHatsFacet(hats).viewHat(
            topHatId
        );

        // mint hat
        vm.prank(address(topHatWearer));
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);

        // mint another of same id to a new wearer
        vm.prank(address(topHatWearer));
        HatsCoreFacet(hats).mintHat(secondHatId, thirdWearer);

        // assert balance is incremented by 1
        assertEq(
            ERC1155Facet(hats).balanceOf(thirdWearer, secondHatId),
            ++balance_pre
        );

        // assert isWearer is true
        assertTrue(ViewHatsFacet(hats).isWearerOfHat(thirdWearer, secondHatId));

        // assert hatSupply is incremented
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), supply_pre + 2);

        // assert admin's lastHatId is *not* incremented
        (, , , , , , uint8 lastHatId_post, , ) = ViewHatsFacet(hats).viewHat(
            topHatId
        );
        assertEq(lastHatId_post, lastHatId_pre);
    }

    function testCannotMint2HatsToSameWearer() public {
        // store prelim values
        uint256 balance_pre = ERC1155Facet(hats).balanceOf(
            thirdWearer,
            secondHatId
        );
        uint32 supply_pre = HatsCoreFacet(hats).hatSupply(secondHatId);
        (, , , , , , uint8 lastHatId_pre, , ) = ViewHatsFacet(hats).viewHat(
            topHatId
        );

        // mint hat
        vm.prank(address(topHatWearer));
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);

        // expect error AlreadyWearingHat()
        vm.expectRevert(
            abi.encodeWithSelector(
                HatsErrors.AlreadyWearingHat.selector,
                secondWearer,
                secondHatId
            )
        );

        // mint another of same id to the same wearer
        vm.prank(address(topHatWearer));
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);

        // assert balance is only incremented by 1
        assertEq(
            ERC1155Facet(hats).balanceOf(secondWearer, secondHatId),
            balance_pre + 1
        );

        // assert isWearer is true
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );

        // assert hatSupply is incremented only by 1
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), supply_pre + 1);

        // assert admin's lastHatId is *not* incremented
        (, , , , , , uint8 lastHatId_post, , ) = ViewHatsFacet(hats).viewHat(
            topHatId
        );
        assertEq(lastHatId_post, lastHatId_pre);
    }

    function testNonAdminCannotMintHat() public {
        // store prelim values
        uint256 balance_pre = ERC1155Facet(hats).balanceOf(
            secondWearer,
            secondHatId
        );
        uint32 supply_pre = HatsCoreFacet(hats).hatSupply(secondHatId);

        // expect NotAdmin Error
        vm.expectRevert(
            abi.encodeWithSelector(
                HatsErrors.NotAdmin.selector,
                nonWearer,
                secondHatId
            )
        );

        // 2-1. try to mint hat from a non-wearer
        vm.prank(address(nonWearer));
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);

        // assert hatSupply is not incremented
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), supply_pre);

        // assert wearer balance is unchanged
        assertEq(
            ERC1155Facet(hats).balanceOf(secondWearer, secondHatId),
            balance_pre
        );
    }

    function testCannotMintMoreThanMaxSupplyErrorAllHatsWorn() public {
        // store prelim values
        uint256 balance1_pre = ERC1155Facet(hats).balanceOf(
            topHatWearer,
            secondHatId
        );
        uint256 balance2_pre = ERC1155Facet(hats).balanceOf(
            secondWearer,
            secondHatId
        );
        uint256 balance3_pre = ERC1155Facet(hats).balanceOf(
            thirdWearer,
            secondHatId
        );
        uint32 supply_pre = HatsCoreFacet(hats).hatSupply(secondHatId);

        // mint hat 1
        vm.startPrank(address(topHatWearer));
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);

        // mint hat 2
        HatsCoreFacet(hats).mintHat(secondHatId, topHatWearer);

        // expect error AllHatsWorn()
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.AllHatsWorn.selector, secondHatId)
        );

        // 2-3. fail to mint hat 3
        HatsCoreFacet(hats).mintHat(secondHatId, thirdWearer);

        // assert balances are modified correctly
        assertEq(
            ERC1155Facet(hats).balanceOf(topHatWearer, secondHatId),
            balance1_pre + 1
        );
        assertEq(
            ERC1155Facet(hats).balanceOf(secondWearer, secondHatId),
            balance2_pre + 1
        );
        assertEq(
            ERC1155Facet(hats).balanceOf(thirdWearer, secondHatId),
            balance3_pre
        );

        // assert correct Wearers is true
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(topHatWearer, secondHatId)
        );
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(thirdWearer, secondHatId)
        );

        // assert hatSupply is incremented only by 2
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), supply_pre + 2);
    }

    function testMintInactiveHat() public {
        // capture pre-values
        uint256 hatSupply_pre = HatsCoreFacet(hats).hatSupply(secondHatId);

        // deactivate the hat
        vm.prank(_toggle);
        HatsCoreFacet(hats).setHatStatus(secondHatId, false);

        // mint the hat to wearer
        vm.prank(topHatWearer);
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);

        // assert that the wearer does not have the hat
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );

        // assert that the hat supply increased
        assertEq(++hatSupply_pre, HatsCoreFacet(hats).hatSupply(secondHatId));
    }

    function testCannotMintNonExistentHat() public {
        vm.prank(topHatWearer);

        uint256 badHatId = 123e18;

        vm.expectRevert(
            abi.encodeWithSelector(
                HatsErrors.HatDoesNotExist.selector,
                badHatId
            )
        );

        HatsCoreFacet(hats).mintHat(badHatId, secondWearer);
    }

    // function testBatchMintHats(uint256 count) public {
    //     vm.assume(count <= 255);

    //     address[] memory wearerBatch = new address[](count);
    //     uint256[] memory hatBatch = new uint256[](count);

    //     vm.prank(topHatWearer);

    //     hats.mintHat(secondHatId, secondWearer);

    //     vm.startPrank(secondWearer);

    //     // create the hats and populate the minting arrays
    //     for (uint256 i = 0; i < count; ++i) {
    //         uint256 id = hats.createHat(
    //             secondHatId,
    //             "",
    //             1,
    //             topHatWearer,
    //             topHatWearer,
    //             false,
    //             ""
    //         );

    //         hatBatch[i] = id;
    //         wearerBatch[i] = address(uint160(10000 + i));
    //     }

    //     hats.batchMintHats(hatBatch, wearerBatch);

    //     (, , , , , , uint8 lastHatId, , ) = hats.viewHat(secondHatId);

    //     assertEq(lastHatId, count);
    // }

    // function testBatchMintHatsErrorArrayLength(uint256 count, uint256 offset)
    //     public
    // {
    //     count = bound(count, 1, 254);
    //     offset = bound(offset, 1, 255 - count);
    //     address[] memory wearerBatch = new address[](count);
    //     uint256[] memory hatBatch = new uint256[](count + offset);

    //     vm.prank(topHatWearer);

    //     hats.mintHat(secondHatId, secondWearer);

    //     vm.startPrank(secondWearer);

    //     // create the hats and populate the minting arrays
    //     for (uint256 i = 0; i < count; ++i) {
    //         uint256 id = hats.createHat(
    //             secondHatId,
    //             "",
    //             1,
    //             topHatWearer,
    //             topHatWearer,
    //             false,
    //             ""
    //         );

    //         hatBatch[i] = id;
    //         wearerBatch[i] = address(uint160(10000 + i));
    //     }

    //     // add `offset` number of hats to the batch, without corresponding wearers
    //     for (uint256 j = 0; j < offset; ++j) {
    //         uint256 id = hats.createHat(
    //             secondHatId,
    //             "",
    //             1,
    //             topHatWearer,
    //             topHatWearer,
    //             false,
    //             ""
    //         );
    //         hatBatch[count - 1 + j] = id;
    //     }

    //     vm.expectRevert(
    //         abi.encodeWithSelector(HatsErrors.BatchArrayLengthMismatch.selector)
    //     );

    //     hats.batchMintHats(hatBatch, wearerBatch);
    // }
}

contract ViewHatTests is TestSetup2 {
    function testViewHat1() public {
        (
            ,
            ,
            ,
            ,
            rettoggle,
            retimageURI,
            retlastHatId,
            retmutable,
            retactive
        ) = ViewHatsFacet(hats).viewHat(secondHatId);

        assertEq(rettoggle, address(333));
        assertEq(retimageURI, secondHatImageURI);
        assertEq(retlastHatId, 0);
        assertEq(retmutable, false);
        assertEq(retactive, true);
    }

    function testViewHat2() public {
        (
            retdetails,
            retmaxSupply,
            retsupply,
            reteligibility,
            ,
            ,
            ,
            ,

        ) = ViewHatsFacet(hats).viewHat(secondHatId);

        // 3-1. viewHat - displays params as expected
        assertEq(retdetails, "second hat");
        assertEq(retmaxSupply, 2);
        assertEq(retsupply, 1);
        assertEq(reteligibility, address(555));
    }

    function testViewHatOfTopHat1() public {
        (
            ,
            ,
            ,
            ,
            rettoggle,
            retimageURI,
            retlastHatId,
            retmutable,
            retactive
        ) = ViewHatsFacet(hats).viewHat(topHatId);

        assertEq(rettoggle, address(0));
        assertEq(retlastHatId, 1);
        assertEq(retmutable, false);
        assertEq(retactive, true);
    }

    function testViewHatOfTopHat2() public {
        (
            retdetails,
            retmaxSupply,
            retsupply,
            reteligibility,
            ,
            ,
            ,
            ,

        ) = ViewHatsFacet(hats).viewHat(topHatId);

        assertEq(retdetails, "tophat");
        assertEq(retmaxSupply, 1);
        assertEq(retsupply, 1);
        assertEq(reteligibility, address(0));
    }

    function testIsAdminOfHat() public {
        assertTrue(ViewHatsFacet(hats).isAdminOfHat(topHatWearer, secondHatId));
    }

    function testGetHatLevel() public {
        assertEq(ViewHatsFacet(hats).getHatLevel(topHatId), 0);
        assertEq(ViewHatsFacet(hats).getHatLevel(secondHatId), 1);
    }
}

contract TransferHatTests is TestSetup2 {
    function testCannotTransferHatFromNonAdmin() public {
        // expect NotAdmin error
        vm.expectRevert(
            abi.encodeWithSelector(
                HatsErrors.NotAdmin.selector,
                nonWearer,
                secondHatId
            )
        );

        // 4-1. transfer from wearer / other wallet
        vm.prank(address(nonWearer));
        HatsCoreFacet(hats).transferHat(secondHatId, secondWearer, thirdWearer);
    }

    function testTransferHat() public {
        uint32 hatSupply = HatsCoreFacet(hats).hatSupply(secondHatId);

        // 4-2. transfer from admin
        vm.prank(address(topHatWearer));
        HatsCoreFacet(hats).transferHat(secondHatId, secondWearer, thirdWearer);

        // assert secondWearer is no longer wearing
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        assertTrue(
            ViewHatsFacet(hats).isInGoodStanding(secondWearer, secondHatId)
        );

        // assert thirdWearer is now wearing
        assertTrue(ViewHatsFacet(hats).isWearerOfHat(thirdWearer, secondHatId));
        assertTrue(
            ViewHatsFacet(hats).isInGoodStanding(thirdWearer, secondHatId)
        );

        // assert hatSupply is not incremented
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), hatSupply);
    }

    function testCannotTransferHatToExistingWearer() public {
        vm.startPrank(topHatWearer);

        HatsCoreFacet(hats).mintHat(secondHatId, thirdWearer);

        vm.expectRevert();

        HatsCoreFacet(hats).transferHat(secondHatId, secondWearer, thirdWearer);
    }

    function testCannotTransferHatToRevokedWearer() public {
        vm.startPrank(topHatWearer);

        // mint the hat
        HatsCoreFacet(hats).mintHat(secondHatId, thirdWearer);

        // revoke the hat, but do not burn it
        // mock calls to eligibility contract to return (eligible = true, standing = true)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature(
                "getWearerStatus(address,uint256)",
                thirdWearer,
                secondHatId
            ),
            abi.encode(false, true)
        );
        // transfer should revert
        vm.expectRevert();

        HatsCoreFacet(hats).transferHat(secondHatId, secondWearer, thirdWearer);
    }
}

contract EligibilitySetHatsTests is TestSetup2 {
    function testDoNotRevokeHatFromEligibleWearerInGoodStanding() public {
        // confirm second hat is worn by second Wearer
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );

        // expectEmit WearerStatus - should be wearing, in good standing
        // vm.expectEmit(false, false, false, true);
        // emit WearerStatus(secondHatId, secondWearer, true, true);

        // 5-6. do not revoke hat
        vm.prank(address(_eligibility));
        HatsCoreFacet(hats).setHatWearerStatus(
            secondHatId,
            secondWearer,
            true,
            true
        );
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        assertTrue(
            ViewHatsFacet(hats).isInGoodStanding(secondWearer, secondHatId)
        );
    }

    function testRevokeHatFromIneligibleWearerInGoodStanding() public {
        uint32 hatSupply = HatsCoreFacet(hats).hatSupply(secondHatId);

        // expectEmit WearerStatus - should not be wearing, in good standing
        // vm.expectEmit(false, false, false, true);
        // emit WearerStatus(secondHatId, secondWearer, false, true);

        // 5-8a. revoke hat
        vm.prank(address(_eligibility));
        HatsCoreFacet(hats).setHatWearerStatus(
            secondHatId,
            secondWearer,
            false,
            true
        );
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        assertTrue(
            ViewHatsFacet(hats).isInGoodStanding(secondWearer, secondHatId)
        );

        // assert hatSupply is decremented
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), --hatSupply);
    }

    function testRevokeHatFromIneligibleWearerInBadStanding() public {
        // expectEmit WearerStatus - should not be wearing, in bad standing
        // vm.expectEmit(false, false, false, true);
        // emit WearerStatus(secondHatId, secondWearer, false, false);

        // 5-8b. revoke hat with bad standing
        vm.prank(address(_eligibility));
        HatsCoreFacet(hats).setHatWearerStatus(
            secondHatId,
            secondWearer,
            false,
            false
        );
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        assertFalse(
            ViewHatsFacet(hats).isInGoodStanding(secondWearer, secondHatId)
        );
    }

    function testRevokeHatFromEligibleWearerInBadStanding() public {
        // expectEmit WearerStatus - should not be wearing, in bad standing
        // vm.expectEmit(false, false, false, true);
        // emit WearerStatus(secondHatId, secondWearer, true, false);

        // 5-8b. revoke hat with bad standing
        vm.prank(address(_eligibility));
        HatsCoreFacet(hats).setHatWearerStatus(
            secondHatId,
            secondWearer,
            true,
            false
        );
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        assertFalse(
            ViewHatsFacet(hats).isInGoodStanding(secondWearer, secondHatId)
        );
    }

    // TODO: do we need to test the following functionality?
    // in the MVP, the following call should never happen:
    //  setHatWearerStatus(secondHatId, secondWearer, false, false);
    //  i.e. WearerStatus - wearing, in bad standing
    // in a future state, this call could happen if there were less severe penalities than revocations

    function testCannotRevokeHatAsNonWearer() public {
        // expect NotHatsEligibility error
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NotHatsEligibility.selector)
        );

        // attempt to setHatWearerStatus as non-wearer
        vm.prank(address(nonWearer));
        HatsCoreFacet(hats).setHatWearerStatus(
            secondHatId,
            secondWearer,
            true,
            false
        );
    }

    function testRemintAfterRevokeHatFromWearerInGoodStanding() public {
        uint32 hatSupply = HatsCoreFacet(hats).hatSupply(secondHatId);

        // revoke hat
        vm.prank(address(_eligibility));
        HatsCoreFacet(hats).setHatWearerStatus(
            secondHatId,
            secondWearer,
            false,
            true
        );

        // 5-4. remint hat
        vm.prank(address(topHatWearer));
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);

        // set eligibility = true in Eligibility Module

        // mock calls to eligibility contract to return (eligible = true, standing = true)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature(
                "getWearerStatus(address,uint256)",
                secondWearer,
                secondHatId
            ),
            abi.encode(true, true)
        );

        // assert balance = 1
        assertEq(ERC1155Facet(hats).balanceOf(secondWearer, secondHatId), 1);

        // assert iswearer
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );

        // assert hatSupply is not incremented
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), hatSupply);
    }
}

contract EligibilityGetHatsTests is TestSetup2 {
    function testCannotGetHatWearerStandingNoFunctionInEligibilityContract()
        public
    {
        // expect NotHatsEligibility error
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NotHatsEligibility.selector)
        );

        // fail attempt to pull wearer status from eligibility
        HatsCoreFacet(hats).checkHatWearerStatus(secondHatId, secondWearer);
    }

    function testCheckEligibilityAndDoNotRevokeHatFromEligibleWearer() public {
        uint32 hatSupply = HatsCoreFacet(hats).hatSupply(secondHatId);

        // confirm second hat is worn by second Wearer
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );

        // expectEmit WearerStatus - should be wearing, in good standing
        // vm.expectEmit(false, false, false, true);
        // emit WearerStatus(secondHatId, secondWearer, true, true);

        // mock calls to eligibility contract to return (eligible = true, standing = true)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature(
                "getWearerStatus(address,uint256)",
                secondWearer,
                secondHatId
            ),
            abi.encode(true, true)
        );

        // 5-1. call checkHatWearerStatus - no revocation
        HatsCoreFacet(hats).checkHatWearerStatus(secondHatId, secondWearer);
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        assertTrue(
            ViewHatsFacet(hats).isInGoodStanding(secondWearer, secondHatId)
        );

        // assert hatSupply is *not* decremented
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), hatSupply);
    }

    function testCheckEligibilityToRevokeHatFromIneligibleWearerInGoodStanding()
        public
    {
        uint32 hatSupply = HatsCoreFacet(hats).hatSupply(secondHatId);

        // expectEmit WearerStatus - should not be wearing, in good standing
        // vm.expectEmit(false, false, false, true);
        // emit WearerStatus(secondHatId, secondWearer, false, true);

        // mock calls to eligibility contract to return (eligible = false, standing = true)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature(
                "getWearerStatus(address,uint256)",
                secondWearer,
                secondHatId
            ),
            abi.encode(false, true)
        );

        // 5-3a. call checkHatWearerStatus to revoke
        HatsCoreFacet(hats).checkHatWearerStatus(secondHatId, secondWearer);
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        assertTrue(
            ViewHatsFacet(hats).isInGoodStanding(secondWearer, secondHatId)
        );

        // assert hatSupply is decremented
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), --hatSupply);
    }

    function testCheckEligibilityToRevokeHatFromIneligibleWearerInBadStanding()
        public
    {
        uint32 hatSupply = HatsCoreFacet(hats).hatSupply(secondHatId);

        // expectEmit WearerStatus - should not be wearing, in bad standing
        // vm.expectEmit(false, false, false, true);
        // emit WearerStatus(secondHatId, secondWearer, false, false);

        // mock calls to eligibility contract to return (eligible = false, standing = false)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature(
                "getWearerStatus(address,uint256)",
                secondWearer,
                secondHatId
            ),
            abi.encode(false, false)
        );

        // 5-3b. call checkHatWearerStatus to revoke
        HatsCoreFacet(hats).checkHatWearerStatus(secondHatId, secondWearer);
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        assertFalse(
            ViewHatsFacet(hats).isInGoodStanding(secondWearer, secondHatId)
        );

        // assert hatSupply is decremented
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), --hatSupply);
    }

    function testCheckEligibilityToRevokeHatFromEligibleWearerInBadStanding()
        public
    {
        uint32 hatSupply = HatsCoreFacet(hats).hatSupply(secondHatId);

        // expectEmit WearerStatus - should not be wearing, in bad standing
        // vm.expectEmit(false, false, false, true);
        // emit WearerStatus(secondHatId, secondWearer, true, false);

        // mock calls to eligibility contract to return (eligible = true, standing = false)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature(
                "getWearerStatus(address,uint256)",
                secondWearer,
                secondHatId
            ),
            abi.encode(true, false)
        );

        // 5-3b. call checkHatWearerStatus to revoke
        HatsCoreFacet(hats).checkHatWearerStatus(secondHatId, secondWearer);
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
        assertFalse(
            ViewHatsFacet(hats).isInGoodStanding(secondWearer, secondHatId)
        );

        // assert hatSupply is decremented
        assertEq(HatsCoreFacet(hats).hatSupply(secondHatId), --hatSupply);
    }
}

contract RenounceHatsTest is TestSetup2 {
    function testRenounceHat() public {
        // expectEmit HatRenounced
        // vm.expectEmit(false, false, false, true);
        // emit HatRenounced(secondHatId, secondWearer);

        //  6-2. renounce hat from wearer2
        vm.prank(address(secondWearer));
        HatsCoreFacet(hats).renounceHat(secondHatId);
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
    }

    function testCannotRenounceHatAsNonWearer() public {
        // expect NotHatWearer error
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NotHatWearer.selector)
        );

        //  6-1. attempt to renounce from non-wearer
        vm.prank(address(nonWearer));
        HatsCoreFacet(hats).renounceHat(secondHatId);
    }
}

contract ToggleSetHatsTest is TestSetup2 {
    function testDeactivateHat() public {
        // confirm second hat is active
        (, , , , , , , , active_) = ViewHatsFacet(hats).viewHat(secondHatId);
        assertTrue(active_);
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );

        // expectEmit HatStatusChanged to false
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, false);

        // 7-2. change Hat Status true->false via setHatStatus
        vm.prank(address(_toggle));
        HatsCoreFacet(hats).setHatStatus(secondHatId, false);
        (, , , , , , , mutable_, ) = ViewHatsFacet(hats).viewHat(secondHatId);
        assertFalse(mutable_);
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
    }

    function testCannotDeactivateHatAsNonWearer() public {
        // expect NotHatstoggle error
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NotHatsToggle.selector)
        );

        // 7-1. attempt to change Hat Status hat from non-wearer
        vm.prank(address(nonWearer));
        HatsCoreFacet(hats).setHatStatus(secondHatId, false);
    }

    function testActivateDeactivatedHat() public {
        // change Hat Status true->false via setHatStatus
        vm.prank(address(_toggle));
        HatsCoreFacet(hats).setHatStatus(secondHatId, false);

        // expectEmit HatStatusChanged to true
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, true);

        // changeHatStatus false->true via setHatStatus
        vm.prank(address(_toggle));
        HatsCoreFacet(hats).setHatStatus(secondHatId, true);
        (, , , , , , , , active_) = ViewHatsFacet(hats).viewHat(secondHatId);
        assertTrue(active_);
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
    }

    function testCannotActivateDeactivatedHatAsNonWearer() public {
        // change Hat Status true->false via setHatStatus
        vm.prank(address(_toggle));
        HatsCoreFacet(hats).setHatStatus(secondHatId, false);

        // expect NotHatstoggle error
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NotHatsToggle.selector)
        );

        // 8-1. attempt to changeHatStatus hat from wearer / other wallet / admin
        vm.prank(address(nonWearer));
        HatsCoreFacet(hats).setHatStatus(secondHatId, true);
    }
}

contract ToggleGetHatsTest is TestSetup2 {
    function testCannotCheckHatStatusNoFunctionInToggleContract() public {
        // expect NotHatsToggle error
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NotHatsToggle.selector)
        );

        // fail attempt to pull Hat Status
        HatsCoreFacet(hats).checkHatStatus(secondHatId);
    }

    function testCheckToggleToDeactivateHat() public {
        // expectEmit HatStatusChanged to false
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, false);

        // encode mock for function inside toggle contract to return false
        vm.mockCall(
            address(_toggle),
            abi.encodeWithSignature("getHatStatus(uint256)", secondHatId),
            abi.encode(false)
        );

        // call mocked function within checkHatStatus to deactivate
        HatsCoreFacet(hats).checkHatStatus(secondHatId);
        (, , , , , , , mutable_, ) = ViewHatsFacet(hats).viewHat(secondHatId);
        assertFalse(mutable_);
        assertFalse(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
    }

    function testCheckToggleToActivateDeactivatedHat() public {
        // change Hat Status true->false via setHatStatus
        vm.prank(address(_toggle));
        HatsCoreFacet(hats).setHatStatus(secondHatId, false);

        // expectEmit HatStatusChanged to true
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, true);

        // encode mock for function inside toggle contract to return false
        vm.mockCall(
            address(_toggle),
            abi.encodeWithSignature("getHatStatus(uint256)", secondHatId),
            abi.encode(true)
        );

        // call mocked function within checkHatStatus to reactivate
        HatsCoreFacet(hats).checkHatStatus(secondHatId);
        (, , , , , , , , active_) = ViewHatsFacet(hats).viewHat(secondHatId);
        assertTrue(active_);
        assertTrue(
            ViewHatsFacet(hats).isWearerOfHat(secondWearer, secondHatId)
        );
    }
}

contract MutabilityTests is TestSetup {
    function setUp() public override {
        super.setUp();

        // create a mutable Hat
        vm.prank(topHatWearer);
        secondHatId = HatsCoreFacet(hats).createHat(
            topHatId,
            "mutable hat",
            2, // maxSupply
            _eligibility,
            _toggle,
            true,
            secondHatImageURI
        );
    }

    function testAdminCanMakeMutableHatImmutable() public {
        (, , , , , , , mutable_, ) = ViewHatsFacet(hats).viewHat(secondHatId);
        assertTrue(mutable_);

        vm.expectEmit(false, false, false, true);
        emit HatMutabilityChanged(secondHatId);

        vm.prank(topHatWearer);
        MutableHatsFacet(hats).makeHatImmutable(secondHatId);

        (, , , , , , , mutable_, ) = ViewHatsFacet(hats).viewHat(secondHatId);
        assertFalse(mutable_);
    }

    function testCannotChangeImmutableHatMutability() public {
        // create immutable hat
        vm.prank(topHatWearer);
        thirdHatId = HatsCoreFacet(hats).createHat(
            topHatId,
            "immutable hat",
            3, // maxSupply
            _eligibility,
            _toggle,
            false,
            secondHatImageURI
        );

        (, , , , , , , mutable_, ) = ViewHatsFacet(hats).viewHat(thirdHatId);
        assertFalse(mutable_);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));

        vm.prank(topHatWearer);
        MutableHatsFacet(hats).makeHatImmutable(thirdHatId);
    }

    function testNonAdminCannotMakeMutableHatImmutable() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                HatsErrors.NotAdmin.selector,
                address(this),
                secondHatId
            )
        );

        MutableHatsFacet(hats).makeHatImmutable(secondHatId);
    }

    function testAdminCannotChangeImutableHatProperties() public {
        vm.startPrank(topHatWearer);
        thirdHatId = HatsCoreFacet(hats).createHat(
            topHatId,
            "immutable hat",
            3, // maxSupply
            _eligibility,
            _toggle,
            false,
            secondHatImageURI
        );

        (, , , , , , , mutable_, ) = ViewHatsFacet(hats).viewHat(thirdHatId);
        assertFalse(mutable_);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        MutableHatsFacet(hats).changeHatDetails(thirdHatId, "should not work");

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        MutableHatsFacet(hats).changeHatEligibility(thirdHatId, address(this));

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        MutableHatsFacet(hats).changeHatToggle(thirdHatId, address(this));

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        MutableHatsFacet(hats).changeHatImageURI(
            thirdHatId,
            "should not work either"
        );

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        MutableHatsFacet(hats).changeHatMaxSupply(thirdHatId, uint32(100));

        vm.stopPrank();
    }

    function testAdminCanChangeMutableHatDetails() public {
        string memory new_ = "should work";

        vm.expectEmit(false, false, false, true);
        emit HatDetailsChanged(secondHatId, new_);

        vm.prank(topHatWearer);
        MutableHatsFacet(hats).changeHatDetails(secondHatId, new_);

        (string memory changed, , , , , , , , ) = ViewHatsFacet(hats).viewHat(
            secondHatId
        );
        assertEq(changed, new_);
    }

    function testAdminCanChangeMutableHatEligibility() public {
        address new_ = address(this);

        vm.expectEmit(false, false, false, true);
        emit HatEligibilityChanged(secondHatId, new_);

        vm.prank(topHatWearer);
        MutableHatsFacet(hats).changeHatEligibility(secondHatId, new_);

        (, , , address changed, , , , , ) = ViewHatsFacet(hats).viewHat(
            secondHatId
        );
        assertEq(changed, new_);
    }

    function testAdminCanChangeMutableHatToggle() public {
        address new_ = address(this);

        vm.expectEmit(false, false, false, true);
        emit HatToggleChanged(secondHatId, new_);

        vm.prank(topHatWearer);
        MutableHatsFacet(hats).changeHatToggle(secondHatId, new_);

        (, , , , address changed, , , , ) = ViewHatsFacet(hats).viewHat(
            secondHatId
        );
        assertEq(changed, new_);
    }

    function testAdminCanChangeMutableHatImageURI() public {
        string memory new_ = "should work";

        vm.expectEmit(false, false, false, true);
        emit HatImageURIChanged(secondHatId, new_);

        vm.prank(topHatWearer);
        MutableHatsFacet(hats).changeHatImageURI(secondHatId, new_);

        (, , , , , string memory changed, , , ) = ViewHatsFacet(hats).viewHat(
            secondHatId
        );
        assertEq(changed, new_);
    }

    function testAdminCanIncreaseMutableHatMaxSupply() public {
        uint32 new_ = 100;

        vm.expectEmit(false, false, false, true);
        emit HatMaxSupplyChanged(secondHatId, new_);

        vm.prank(topHatWearer);
        MutableHatsFacet(hats).changeHatMaxSupply(secondHatId, new_);

        (, uint32 changed, , , , , , , ) = ViewHatsFacet(hats).viewHat(
            secondHatId
        );
        assertEq(changed, new_);
    }

    function testAdminCanDecreaseMutableHatMaxSupplyToAboveCurrentSupply()
        public
    {
        uint32 new_ = 100;
        uint32 decreased = 5;

        vm.startPrank(topHatWearer);
        MutableHatsFacet(hats).changeHatMaxSupply(secondHatId, new_);
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);

        vm.expectEmit(false, false, false, true);
        emit HatMaxSupplyChanged(secondHatId, decreased);

        MutableHatsFacet(hats).changeHatMaxSupply(secondHatId, decreased);

        (, uint32 changed, , , , , , , ) = ViewHatsFacet(hats).viewHat(
            secondHatId
        );
        assertEq(changed, decreased);
    }

    function testAdminCanDecreaseMutableHatMaxSupplyToEqualToCurrentSupply()
        public
    {
        uint32 new_ = 100;
        uint32 decreased = 1;

        vm.startPrank(topHatWearer);
        MutableHatsFacet(hats).changeHatMaxSupply(secondHatId, new_);
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);

        vm.expectEmit(false, false, false, true);
        emit HatMaxSupplyChanged(secondHatId, decreased);

        MutableHatsFacet(hats).changeHatMaxSupply(secondHatId, decreased);

        (, uint32 changed, , , , , , , ) = ViewHatsFacet(hats).viewHat(
            secondHatId
        );
        assertEq(changed, decreased);
    }

    function testAdminCannotDecreaseMutableHatMaxSupplyBelowCurrentSupply()
        public
    {
        uint32 new_ = 100;
        uint32 decreased = 1;

        vm.startPrank(topHatWearer);
        MutableHatsFacet(hats).changeHatMaxSupply(secondHatId, new_);
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);
        HatsCoreFacet(hats).mintHat(secondHatId, thirdWearer);

        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NewMaxSupplyTooLow.selector)
        );

        MutableHatsFacet(hats).changeHatMaxSupply(secondHatId, decreased);
    }
}

contract OverridesHatTests is TestSetup2 {
    function testFailSetApprovalForAll() public {
        ERC1155Facet(hats).setApprovalForAll(topHatWearer, true);
    }

    function testFailSafeTransferFrom() public {
        bytes memory b = bytes("");
        ERC1155Facet(hats).safeTransferFrom(
            secondWearer,
            thirdWearer,
            secondHatId,
            1,
            b
        );
    }

    // TODO: test for a specific URI output
    function testCreateUri() public {
        string memory jsonUri = ERC1155Facet(hats).uri(secondHatId);
        console2.log("encoded URI", jsonUri);
    }

    // TODO: test for a specific URI output
    function testCreateUriForTopHat() public {
        string memory jsonUri = ERC1155Facet(hats).uri(topHatId);
        console2.log("encoded URI", jsonUri);
    }
}
