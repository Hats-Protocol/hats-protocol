// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";
import "./HatsTestSetup.t.sol";
import { LongStrings } from "./LongStrings.sol";

contract DeployTest is TestSetup {
    function testDeployWithParams() public {
        assertEq(hats.name(), name);
    }
}

contract CreateTopHatTest is TestSetup {
    function setUp() public override {
        setUpVariables();

        // instantiate Hats contract
        hats = new Hats(name, _baseImageURI);
    }

    function testTopHatCreated() public {
        string memory details = "tophat";
        vm.expectEmit(false, false, false, true);
        emit HatCreated(2 ** 224, details, 1, address(0), address(0), false, topHatImageURI);

        topHatId = hats.mintTopHat(topHatWearer, details, topHatImageURI);

        assertTrue(hats.isTopHat(topHatId));
        assertEq(2 ** 224, topHatId);
    }

    function testTopHatMinted() public {
        vm.expectEmit(true, true, true, true);

        emit TransferSingle(address(this), address(0), topHatWearer, 2 ** 224, 1);

        topHatId = hats.mintTopHat(topHatWearer, "tophat", topHatImageURI);

        assertTrue(hats.isWearerOfHat(topHatWearer, topHatId));
        assertFalse(hats.isWearerOfHat(nonWearer, topHatId));
    }

    function testTransferTopHat() public {
        topHatId = hats.mintTopHat(topHatWearer, "tophat", topHatImageURI);

        emit log_uint(topHatId);
        emit log_address(nonWearer);

        vm.prank(address(topHatWearer));
        hats.transferHat(topHatId, topHatWearer, nonWearer);
    }
}

contract CreateHatsTest is TestSetup {
    function testImmutableHatCreated() public {
        // get prelim values
        (,,,,,, uint16 lastHatId,,) = hats.viewHat(topHatId);

        vm.expectEmit(false, false, false, true);
        emit HatCreated(hats.getNextId(topHatId), _details, _maxSupply, _eligibility, _toggle, false, secondHatImageURI);

        // topHatId = hats.mintTopHat(topHatWearer, topHatImageURI);
        vm.prank(address(topHatWearer));

        secondHatId = hats.createHat(topHatId, _details, _maxSupply, _eligibility, _toggle, false, secondHatImageURI);

        // assert admin's lastHatId is incremented
        (,,,,,, uint16 lastHatIdPost,,) = hats.viewHat(topHatId);
        (,,,,,,, mutable_,) = hats.viewHat(secondHatId);
        assertEq(lastHatId + 1, lastHatIdPost);
        assertFalse(mutable_);
    }

    function testMutableHatCreated() public {
        vm.expectEmit(false, false, false, true);
        emit HatCreated(hats.getNextId(topHatId), _details, _maxSupply, _eligibility, _toggle, true, secondHatImageURI);

        console2.log("secondHat");

        vm.prank(address(topHatWearer));
        secondHatId = hats.createHat(topHatId, _details, _maxSupply, _eligibility, _toggle, true, secondHatImageURI);

        (,,,,,,, mutable_,) = hats.viewHat(secondHatId);
        assertTrue(mutable_);
    }

    function testHatsBranchCreated() public {
        // mint TopHat
        // topHatId = hats.mintTopHat(topHatWearer, topHatImageURI);

        (uint256[] memory ids,) = createHatsBranch(3, topHatId, topHatWearer, false);
        assertEq(hats.getHatLevel(ids[2]), 3);
        assertEq(hats.getAdminAtLevel(ids[0], 0), topHatId);
        assertEq(hats.getAdminAtLevel(ids[1], 1), ids[0]);
        assertEq(hats.getAdminAtLevel(ids[2], 2), ids[1]);
    }

    function testCannotCreateHatWithZeroAddressEligibility() public {
        vm.expectRevert(HatsErrors.ZeroAddress.selector);
        vm.prank(topHatWearer);
        thirdHatId = hats.createHat(topHatId, _details, _maxSupply, address(0), _toggle, true, thirdHatImageURI);
    }

    function testCannotCreateHatWithZeroAddressToggle() public {
        vm.expectRevert(HatsErrors.ZeroAddress.selector);
        vm.prank(topHatWearer);
        thirdHatId = hats.createHat(topHatId, _details, _maxSupply, _eligibility, address(0), true, thirdHatImageURI);
    }

    function testCannotCreateHatWithInvalidAdmin() public {
        uint256 invalidAdmin = 0x0000000100000001000000000000000000000000000000000000000000000000;
        vm.prank(topHatWearer);
        vm.expectRevert(HatsErrors.InvalidHatId.selector);
        hats.createHat(invalidAdmin, _details, _maxSupply, _eligibility, _toggle, true, "invalid admin id");
    }
}

contract BatchCreateHats is TestSetupBatch {
    function testBatchCreateTwoHats() public {
        testBatchCreateHatsSameAdmin(2);
    }

    function testBatchCreateOneHat() public {
        testBatchCreateHatsSameAdmin(1);
    }

    function testBatchCreateHatsSameAdmin(uint256 count) public {
        // this is inefficient, but bound() is not working correctly
        vm.assume(count >= 1);
        vm.assume(count < 256);

        adminsBatch = new uint256[](count);
        detailsBatch = new string[](count);
        maxSuppliesBatch = new uint32[](count);
        eligibilityModulesBatch = new address[](count);
        toggleModulesBatch = new address[](count);
        mutablesBatch = new bool[](count);
        imageURIsBatch = new string[](count);

        vm.prank(topHatWearer);

        // populate the creating arrays
        for (uint256 i = 0; i < count; ++i) {
            adminsBatch[i] = topHatId;
            detailsBatch[i] = "deets";
            maxSuppliesBatch[i] = 10;
            eligibilityModulesBatch[i] = _eligibility;
            toggleModulesBatch[i] = _toggle;
            mutablesBatch[i] = false;
            imageURIsBatch[i] = "";
        }

        hats.batchCreateHats(
            adminsBatch,
            detailsBatch,
            maxSuppliesBatch,
            eligibilityModulesBatch,
            toggleModulesBatch,
            mutablesBatch,
            imageURIsBatch
        );

        (,,,,,, uint16 lastHatId,,) = hats.viewHat(topHatId);

        assertEq(lastHatId, count);

        (,,,, address t,,,,) = hats.viewHat(hats.buildHatId(topHatId, uint16(count)));
        assertEq(t, _toggle);
    }

    function testBatchCreateHatsSkinnyFullBranch() public {
        uint256 count = 14;

        adminsBatch = new uint256[](count);
        detailsBatch = new string[](count);
        maxSuppliesBatch = new uint32[](count);
        eligibilityModulesBatch = new address[](count);
        toggleModulesBatch = new address[](count);
        mutablesBatch = new bool[](count);
        imageURIsBatch = new string[](count);

        uint256 adminId = topHatId;

        // populate the creating arrays
        for (uint256 i = 0; i < count; ++i) {
            uint32 level = uint32(i) + 1;

            adminsBatch[i] = adminId;
            detailsBatch[i] = string.concat("level ", vm.toString(level));
            maxSuppliesBatch[i] = level;
            eligibilityModulesBatch[i] = _eligibility;
            toggleModulesBatch[i] = _toggle;
            mutablesBatch[i] = false;
            imageURIsBatch[i] = vm.toString(level);

            adminId = hats.buildHatId(adminId, 1);
        }

        vm.prank(topHatWearer);

        hats.batchCreateHats(
            adminsBatch,
            detailsBatch,
            maxSuppliesBatch,
            eligibilityModulesBatch,
            toggleModulesBatch,
            mutablesBatch,
            imageURIsBatch
        );

        assertEq(
            hats.getHatLevel( // should be adminId
            hats.buildHatId(hats.getAdminAtLevel(adminId, uint8(count - 1)), 1)),
            count
        );
    }

    function testBatchCreateHatsErrorArrayLength(uint256 count, uint256 offset, uint256 array) public {
        count = bound(count, 1, 254);
        // count = 2;
        offset = bound(offset, 1, 255 - count);
        // offset = 1;
        array = bound(array, 1, 7);

        uint256 extra = count + offset;
        // initiate the creation arrays
        if (array == 1) {
            adminsBatch = new uint256[](extra);
            detailsBatch = new string[](count);
            maxSuppliesBatch = new uint32[](count);
            eligibilityModulesBatch = new address[](count);
            toggleModulesBatch = new address[](count);
            mutablesBatch = new bool[](count);
            imageURIsBatch = new string[](count);
        } else if (array == 2) {
            adminsBatch = new uint256[](count);
            detailsBatch = new string[](extra);
            maxSuppliesBatch = new uint32[](count);
            eligibilityModulesBatch = new address[](count);
            toggleModulesBatch = new address[](count);
            mutablesBatch = new bool[](count);
            imageURIsBatch = new string[](count);
        } else if (array == 3) {
            adminsBatch = new uint256[](count);
            detailsBatch = new string[](count);
            maxSuppliesBatch = new uint32[](extra);
            eligibilityModulesBatch = new address[](count);
            toggleModulesBatch = new address[](count);
            mutablesBatch = new bool[](count);
            imageURIsBatch = new string[](count);
        } else if (array == 4) {
            adminsBatch = new uint256[](count);
            detailsBatch = new string[](count);
            maxSuppliesBatch = new uint32[](count);
            eligibilityModulesBatch = new address[](extra);
            toggleModulesBatch = new address[](count);
            mutablesBatch = new bool[](count);
            imageURIsBatch = new string[](count);
        } else if (array == 5) {
            adminsBatch = new uint256[](count);
            detailsBatch = new string[](count);
            maxSuppliesBatch = new uint32[](count);
            eligibilityModulesBatch = new address[](count);
            toggleModulesBatch = new address[](extra);
            mutablesBatch = new bool[](count);
            imageURIsBatch = new string[](count);
        } else if (array == 6) {
            adminsBatch = new uint256[](count);
            detailsBatch = new string[](count);
            maxSuppliesBatch = new uint32[](count);
            eligibilityModulesBatch = new address[](count);
            toggleModulesBatch = new address[](count);
            mutablesBatch = new bool[](extra);
            imageURIsBatch = new string[](count);
        } else if (array == 7) {
            adminsBatch = new uint256[](count);
            detailsBatch = new string[](count);
            maxSuppliesBatch = new uint32[](count);
            eligibilityModulesBatch = new address[](count);
            toggleModulesBatch = new address[](count);
            mutablesBatch = new bool[](count);
            imageURIsBatch = new string[](extra);
        }

        vm.prank(topHatWearer);

        // populate the creation arrays
        for (uint32 i = 0; i < count; ++i) {
            adminsBatch[i] = topHatId;
            detailsBatch[i] = vm.toString(i);
            maxSuppliesBatch[i] = i;
            eligibilityModulesBatch[i] = _eligibility;
            toggleModulesBatch[i] = _toggle;
            mutablesBatch[i] = false;
            imageURIsBatch[i] = vm.toString(i);
        }

        // add `offset` number of hats to the batch, but only with one array filled out
        for (uint32 j = 0; j < offset; ++j) {
            if (array == 1) adminsBatch[j] = topHatId;
            if (array == 2) detailsBatch[j] = vm.toString(j);
            if (array == 3) maxSuppliesBatch[j] = j;
            if (array == 4) eligibilityModulesBatch[j] = _eligibility;
            if (array == 5) toggleModulesBatch[j] = _toggle;
            if (array == 6) mutablesBatch[j] = false;
            if (array == 7) imageURIsBatch[j] = vm.toString(j);
        }

        // adminsBatch[count] = topHatId;

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.BatchArrayLengthMismatch.selector));

        hats.batchCreateHats(
            adminsBatch,
            detailsBatch,
            maxSuppliesBatch,
            eligibilityModulesBatch,
            toggleModulesBatch,
            mutablesBatch,
            imageURIsBatch
        );
    }

    function testCreatingSkippedHatDoesNotOverwriteChildHat() public {
        uint32 testMax = 99;
        // first, skip a level to create a hat
        uint256 level1Hat = 0x000000010001 << (224 - 16);
        vm.startPrank(topHatWearer);
        uint256 level2HatA = hats.createHat(
            level1Hat, "should not be overwritten", testMax, _eligibility, _toggle, false, "amistillhere.com"
        );

        // then, create the hat at the skipped level
        uint256 skippedHat =
            hats.createHat(topHatId, "At first I was skipped, now I'm here", 1, _eligibility, _toggle, false, "gm");
        assertEq(skippedHat, level1Hat);

        // finally, attempt to create a new child of skippedHat
        uint256 level2HatB = hats.createHat(skippedHat, "i should be hat 2", 1, _eligibility, _toggle, false, "");
        assertEq(level2HatB, 0x0000000100010002 << (224 - 32));
        assertFalse(level2HatB == level2HatA);
        (, uint32 max,,,,,,,) = hats.viewHat(level2HatA);
        assertEq(max, testMax);
    }
}

contract ImageURITest is TestSetup2 {
    function testTopHatImageURI() public {
        string memory uri = hats.getImageURIForHat(topHatId);

        // assertEq(string.concat(topHatImageURI, "0"), uri);
        assertEq(uri, topHatImageURI);
    }

    function testHatImageURI() public {
        string memory uri = hats.getImageURIForHat(secondHatId);

        // assertEq(string.concat(secondHatImageURI, "0"), uri);
        assertEq(uri, secondHatImageURI);
    }

    function testEmptyHatImageURI() public {
        // create third Hat
        vm.prank(secondWearer);
        thirdHatId = hats.createHat(
            secondHatId,
            "third hat",
            2, // maxSupply
            _eligibility,
            _toggle,
            false,
            ""
        );

        string memory uri3 = hats.getImageURIForHat(thirdHatId);

        assertEq(uri3, secondHatImageURI);
    }

    function testFallbackToTopHatImageURI() public {
        vm.startPrank(topHatWearer);
        uint256 newHatId = hats.createHat(topHatId, "new hat", 1, _eligibility, _toggle, false, "");

        hats.getImageURIForHat(newHatId);
        assertEq(hats.getImageURIForHat(newHatId), topHatImageURI);
    }

    function testEmptyTopHatImageURI() public {
        uint256 topHat = hats.mintTopHat(topHatWearer, "", "");

        string memory uri = hats.getImageURIForHat(topHat);

        // assertEq(uri, string.concat(_baseImageURI, Strings.toString(topHat)));
        assertEq(uri, _baseImageURI);
    }

    function testEmptyHatBranchImageURI() public {
        uint256 topHat = hats.mintTopHat(topHatWearer, "", "");

        (uint256[] memory ids,) = createHatsBranch(5, topHat, topHatWearer, false);

        string memory uri = hats.getImageURIForHat(ids[4]);

        // assertEq(uri, string.concat(_baseImageURI, Strings.toString(ids[4])));
        assertEq(uri, _baseImageURI);
    }
}

contract MintHatsTest is TestSetup {
    function setUp() public override {
        super.setUp();

        vm.prank(topHatWearer);
        secondHatId = hats.createHat(
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
        uint256 secondWearerBalance = hats.balanceOf(secondWearer, secondHatId);
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // check transfer event will be emitted
        vm.expectEmit(true, true, true, true);

        emit TransferSingle(topHatWearer, address(0), secondWearer, secondHatId, 1);

        // 2-2. mint hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);

        // assert balance = 1
        assertEq(hats.balanceOf(secondWearer, secondHatId), ++secondWearerBalance);

        // assert iswearer
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // assert hatSupply is incremented
        assertEq(hats.hatSupply(secondHatId), ++hatSupply);
    }

    function testMintAnotherHat() public {
        // store prelim values
        uint256 balance_pre = hats.balanceOf(thirdWearer, secondHatId);
        uint32 supply_pre = hats.hatSupply(secondHatId);
        (,,,,,, uint16 lastHatId_pre,,) = hats.viewHat(topHatId);

        // mint hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);

        // mint another of same id to a new wearer
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, thirdWearer);

        // assert balance is incremented by 1
        assertEq(hats.balanceOf(thirdWearer, secondHatId), ++balance_pre);

        // assert isWearer is true
        assertTrue(hats.isWearerOfHat(thirdWearer, secondHatId));

        // assert hatSupply is incremented
        assertEq(hats.hatSupply(secondHatId), supply_pre + 2);

        // assert admin's lastHatId is *not* incremented
        (,,,,,, uint16 lastHatId_post,,) = hats.viewHat(topHatId);
        assertEq(lastHatId_post, lastHatId_pre);
    }

    function testCannotMint2HatsToSameWearer() public {
        // store prelim values
        uint256 balance_pre = hats.balanceOf(thirdWearer, secondHatId);
        uint32 supply_pre = hats.hatSupply(secondHatId);
        (,,,,,, uint16 lastHatId_pre,,) = hats.viewHat(topHatId);

        // mint hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);

        // expect error AlreadyWearingHat()
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.AlreadyWearingHat.selector, secondWearer, secondHatId));

        // mint another of same id to the same wearer
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);

        // assert balance is only incremented by 1
        assertEq(hats.balanceOf(secondWearer, secondHatId), balance_pre + 1);

        // assert isWearer is true
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // assert hatSupply is incremented only by 1
        assertEq(hats.hatSupply(secondHatId), supply_pre + 1);

        // assert admin's lastHatId is *not* incremented
        (,,,,,, uint16 lastHatId_post,,) = hats.viewHat(topHatId);
        assertEq(lastHatId_post, lastHatId_pre);
    }

    function testMintHatErrorNotAdmin() public {
        // store prelim values
        uint256 balance_pre = hats.balanceOf(secondWearer, secondHatId);
        uint32 supply_pre = hats.hatSupply(secondHatId);

        // expect NotAdmin Error
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdmin.selector, nonWearer, secondHatId));

        // 2-1. try to mint hat from a non-wearer
        vm.prank(address(nonWearer));
        hats.mintHat(secondHatId, secondWearer);

        // assert hatSupply is not incremented
        assertEq(hats.hatSupply(secondHatId), supply_pre);

        // assert wearer balance is unchanged
        assertEq(hats.balanceOf(secondWearer, secondHatId), balance_pre);
    }

    function testCannotMintMoreThanMaxSupplyErrorAllHatsWorn() public {
        // store prelim values
        uint256 balance1_pre = hats.balanceOf(topHatWearer, secondHatId);
        uint256 balance2_pre = hats.balanceOf(secondWearer, secondHatId);
        uint256 balance3_pre = hats.balanceOf(thirdWearer, secondHatId);
        uint32 supply_pre = hats.hatSupply(secondHatId);

        // mint hat 1
        vm.startPrank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);

        // mint hat 2
        hats.mintHat(secondHatId, topHatWearer);

        // expect error AllHatsWorn()
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.AllHatsWorn.selector, secondHatId));

        // 2-3. fail to mint hat 3
        hats.mintHat(secondHatId, thirdWearer);

        // assert balances are modified correctly
        assertEq(hats.balanceOf(topHatWearer, secondHatId), balance1_pre + 1);
        assertEq(hats.balanceOf(secondWearer, secondHatId), balance2_pre + 1);
        assertEq(hats.balanceOf(thirdWearer, secondHatId), balance3_pre);

        // assert correct Wearers is true
        assertTrue(hats.isWearerOfHat(topHatWearer, secondHatId));
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));
        assertFalse(hats.isWearerOfHat(thirdWearer, secondHatId));

        // assert hatSupply is incremented only by 2
        assertEq(hats.hatSupply(secondHatId), supply_pre + 2);
    }

    function testCannotMintNonExistentHat() public {
        vm.prank(topHatWearer);

        uint256 badHatId = 123e18;

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.HatDoesNotExist.selector, badHatId));

        hats.mintHat(badHatId, secondWearer);
    }

    function testCannotMintHatToIneligibleWearer() public {
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(false, true)
        );

        vm.expectRevert(HatsErrors.NotEligible.selector);
        vm.prank(topHatWearer);
        hats.mintHat(secondHatId, secondWearer);
    }

    function testCannotMintInactiveHat() public {
        // mock a toggle call to return inactive
        vm.mockCall(address(_toggle), abi.encodeWithSignature("getHatStatus(uint256)", secondHatId), abi.encode(false));

        vm.prank(topHatWearer);
        // expect hat not active error
        vm.expectRevert(HatsErrors.HatNotActive.selector);
        hats.mintHat(secondHatId, secondWearer);
    }

    function testBatchMintHats(uint256 count) public {
        vm.assume(count <= 255);

        address[] memory wearerBatch = new address[](count);
        uint256[] memory hatBatch = new uint256[](count);

        vm.prank(topHatWearer);

        hats.mintHat(secondHatId, secondWearer);

        vm.startPrank(secondWearer);

        // create the hats and populate the minting arrays
        for (uint256 i = 0; i < count; ++i) {
            uint256 id = hats.createHat(secondHatId, "", 1, topHatWearer, topHatWearer, false, "");

            hatBatch[i] = id;
            wearerBatch[i] = address(uint160(10_000 + i));
        }

        hats.batchMintHats(hatBatch, wearerBatch);

        (,,,,,, uint16 lastHatId,,) = hats.viewHat(secondHatId);

        assertEq(lastHatId, count);
    }

    function testBatchMintHatsErrorArrayLength(uint256 count, uint256 offset) public {
        count = bound(count, 1, 254);
        offset = bound(offset, 1, 255 - count);
        address[] memory wearerBatch = new address[](count);
        uint256[] memory hatBatch = new uint256[](count + offset);

        vm.prank(topHatWearer);

        hats.mintHat(secondHatId, secondWearer);

        vm.startPrank(secondWearer);

        // create the hats and populate the minting arrays
        for (uint256 i = 0; i < count; ++i) {
            uint256 id = hats.createHat(secondHatId, "", 1, topHatWearer, topHatWearer, false, "");

            hatBatch[i] = id;
            wearerBatch[i] = address(uint160(10_000 + i));
        }

        // add `offset` number of hats to the batch, without corresponding wearers
        for (uint256 j = 0; j < offset; ++j) {
            uint256 id = hats.createHat(secondHatId, "", 1, topHatWearer, topHatWearer, false, "");
            hatBatch[count - 1 + j] = id;
        }

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.BatchArrayLengthMismatch.selector));

        hats.batchMintHats(hatBatch, wearerBatch);
    }
}

contract ViewHatTests is TestSetup2 {
    function testViewHat1() public {
        (,,,, rettoggle, retimageURI, retlastHatId, retmutable, retactive) = hats.viewHat(secondHatId);

        assertEq(rettoggle, address(333));
        assertEq(retimageURI, secondHatImageURI);
        assertEq(retlastHatId, 0);
        assertEq(retmutable, false);
        assertEq(retactive, true);
    }

    function testViewHat2() public {
        (retdetails, retmaxSupply, retsupply, reteligibility,,,,,) = hats.viewHat(secondHatId);

        // 3-1. viewHat - displays params as expected
        assertEq(retdetails, "second hat");
        assertEq(retmaxSupply, 2);
        assertEq(retsupply, 1);
        assertEq(reteligibility, address(555));
    }

    function testViewHatOfTopHat1() public {
        (,,,, rettoggle, retimageURI, retlastHatId, retmutable, retactive) = hats.viewHat(topHatId);

        assertEq(rettoggle, address(0));
        assertEq(retlastHatId, 1);
        assertEq(retmutable, false);
        assertEq(retactive, true);
    }

    function testViewHatOfTopHat2() public {
        (retdetails, retmaxSupply, retsupply, reteligibility,,,,,) = hats.viewHat(topHatId);

        assertEq(retdetails, "tophat");
        assertEq(retmaxSupply, 1);
        assertEq(retsupply, 1);
        assertEq(reteligibility, address(0));
    }

    function testIsAdminOfHat() public {
        assertTrue(hats.isAdminOfHat(topHatWearer, secondHatId));
    }

    function testGetHatLevel() public {
        assertEq(hats.getHatLevel(topHatId), 0);
        assertEq(hats.getHatLevel(secondHatId), 1);
    }
}

contract TransferHatTests is TestSetupMutable {
    function setUp() public override {
        super.setUp();

        vm.prank(address(topHatWearer));

        hats.mintHat(secondHatId, secondWearer);
    }

    function testCannotTransferHatFromNonAdmin() public {
        // expect NotAdmin error
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdmin.selector, nonWearer, secondHatId));

        // 4-1. transfer from wearer / other wallet
        vm.prank(address(nonWearer));
        hats.transferHat(secondHatId, secondWearer, thirdWearer);
    }

    function testTransferMutableHat() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);

        vm.prank(address(topHatWearer));

        hats.transferHat(secondHatId, secondWearer, thirdWearer);

        // assert secondWearer is no longer wearing
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertTrue(hats.isInGoodStanding(secondWearer, secondHatId));

        // assert thirdWearer is now wearing
        assertTrue(hats.isWearerOfHat(thirdWearer, secondHatId));
        assertTrue(hats.isInGoodStanding(thirdWearer, secondHatId));

        // assert hatSupply is not incremented
        assertEq(hats.hatSupply(secondHatId), hatSupply);
    }

    function testCannotTransferHatToExistingWearer() public {
        vm.startPrank(topHatWearer);

        hats.mintHat(secondHatId, thirdWearer);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.AlreadyWearingHat.selector, thirdWearer, secondHatId));

        hats.transferHat(secondHatId, secondWearer, thirdWearer);
    }

    function testCannotTransferHatToRevokedWearer() public {
        vm.startPrank(topHatWearer);

        // mint the hat
        hats.mintHat(secondHatId, thirdWearer);

        // revoke the hat, but do not burn it
        // mock calls to eligibility contract to return (eligible = false, standing = true)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", thirdWearer, secondHatId),
            abi.encode(false, true)
        );

        assertFalse(hats.isWearerOfHat(thirdWearer, secondHatId));
        // transfer should revert
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.AlreadyWearingHat.selector, thirdWearer, secondHatId));

        hats.transferHat(secondHatId, secondWearer, thirdWearer);
    }

    function testCannotTransferHatToIneligibleWearer() public {
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", thirdWearer, secondHatId),
            abi.encode(false, true)
        );

        vm.expectRevert(HatsErrors.NotEligible.selector);
        vm.prank(topHatWearer);
        hats.transferHat(secondHatId, secondWearer, thirdWearer);
    }

    function testCannotTransferInactiveHat() public {
        vm.mockCall(_toggle, abi.encodeWithSignature("getHatStatus(uint256)", secondHatId), abi.encode(false));

        vm.expectRevert(HatsErrors.HatNotActive.selector);
        vm.prank(topHatWearer);
        hats.transferHat(secondHatId, secondWearer, thirdWearer);
    }
}

contract EligibilitySetHatsTests is TestSetup2 {
    function testDoNotRevokeHatFromEligibleWearerInGoodStanding() public {
        // confirm second hat is worn by second Wearer
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // 5-6. do not revoke hat
        vm.prank(address(_eligibility));
        hats.setHatWearerStatus(secondHatId, secondWearer, true, true);
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));
        assertTrue(hats.isInGoodStanding(secondWearer, secondHatId));
    }

    function testRevokeHatFromIneligibleWearerInGoodStanding() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // 5-8a. revoke hat
        vm.prank(address(_eligibility));
        hats.setHatWearerStatus(secondHatId, secondWearer, false, true);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertTrue(hats.isInGoodStanding(secondWearer, secondHatId));

        // assert hatSupply is decremented
        assertEq(hats.hatSupply(secondHatId), --hatSupply);
    }

    function testRevokeHatFromIneligibleWearerInBadStanding() public {
        // expectEmit WearerStandingChanged
        vm.expectEmit(false, false, false, true);
        emit WearerStandingChanged(secondHatId, secondWearer, false);

        // 5-8b. revoke hat with bad standing
        vm.prank(address(_eligibility));
        hats.setHatWearerStatus(secondHatId, secondWearer, false, false);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertFalse(hats.isInGoodStanding(secondWearer, secondHatId));
    }

    function testRevokeHatFromEligibleWearerInBadStanding() public {
        // expectEmit WearerStandingChanged
        vm.expectEmit(false, false, false, true);
        emit WearerStandingChanged(secondHatId, secondWearer, false);

        // 5-8b. revoke hat with bad standing
        vm.prank(address(_eligibility));
        hats.setHatWearerStatus(secondHatId, secondWearer, true, false);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertFalse(hats.isInGoodStanding(secondWearer, secondHatId));
    }

    function testCannotRevokeHatAsNonWearer() public {
        // expect NotHatsEligibility error
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotHatsEligibility.selector));

        // attempt to setHatWearerStatus as non-wearer
        vm.prank(address(nonWearer));
        hats.setHatWearerStatus(secondHatId, secondWearer, true, false);
    }

    function testRemintAfterRevokeHatFromWearerInGoodStanding() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // revoke hat
        vm.prank(address(_eligibility));
        hats.setHatWearerStatus(secondHatId, secondWearer, false, true);

        // 5-4. remint hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);

        // set eligibility = true in Eligibility Module

        // mock calls to eligibility contract to return (eligible = true, standing = true)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(true, true)
        );

        // assert balance = 1
        assertEq(hats.balanceOf(secondWearer, secondHatId), 1);

        // assert iswearer
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // assert hatSupply is not incremented
        assertEq(hats.hatSupply(secondHatId), hatSupply);
    }

    function testSetWearerBackInGoodStanding() public {
        // set to bad standing
        vm.startPrank(address(_eligibility));

        vm.expectEmit(false, false, false, true);
        emit WearerStandingChanged(secondHatId, secondWearer, false);

        hats.setHatWearerStatus(secondHatId, secondWearer, false, false);

        // set back to good standing

        vm.expectEmit(false, false, false, true);
        emit WearerStandingChanged(secondHatId, secondWearer, true);

        hats.setHatWearerStatus(secondHatId, secondWearer, false, true);
    }
}

contract EligibilityCheckHatsTests is TestSetup2 {
    function testCannotGetHatWearerStandingNoFunctionInEligibilityContract() public {
        // expect NotHatsEligibility error
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotHatsEligibility.selector));

        // fail attempt to pull wearer status from eligibility
        hats.checkHatWearerStatus(secondHatId, secondWearer);
    }

    function testCheckEligibilityAndDoNotRevokeHatFromEligibleWearer() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // confirm second hat is worn by second Wearer
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // mock calls to eligibility contract to return (eligible = true, standing = true)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(true, true)
        );

        // 5-1. call checkHatWearerStatus - no revocation
        hats.checkHatWearerStatus(secondHatId, secondWearer);
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));
        assertTrue(hats.isInGoodStanding(secondWearer, secondHatId));

        // assert hatSupply is *not* decremented
        assertEq(hats.hatSupply(secondHatId), hatSupply);
    }

    function testCheckEligibilityToRevokeHatFromIneligibleWearerInGoodStanding() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // mock calls to eligibility contract to return (eligible = false, standing = true)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(false, true)
        );

        // 5-3a. call checkHatWearerStatus to revoke
        hats.checkHatWearerStatus(secondHatId, secondWearer);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertTrue(hats.isInGoodStanding(secondWearer, secondHatId));

        // assert hatSupply is decremented
        assertEq(hats.hatSupply(secondHatId), --hatSupply);
    }

    function testCheckEligibilityToRevokeHatFromIneligibleWearerInBadStanding() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // expectEmit WearerStandingChanged
        vm.expectEmit(false, false, false, true);
        emit WearerStandingChanged(secondHatId, secondWearer, false);

        // mock calls to eligibility contract to return (eligible = false, standing = false)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(false, false)
        );

        // 5-3b. call checkHatWearerStatus to revoke
        hats.checkHatWearerStatus(secondHatId, secondWearer);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertFalse(hats.isInGoodStanding(secondWearer, secondHatId));

        // assert hatSupply is decremented
        assertEq(hats.hatSupply(secondHatId), --hatSupply);
    }

    function testCheckEligibilityToRevokeHatFromEligibleWearerInBadStanding() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // expectEmit WearerStandingChanged
        vm.expectEmit(false, false, false, true);
        emit WearerStandingChanged(secondHatId, secondWearer, false);

        // mock calls to eligibility contract to return (eligible = true, standing = false)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(true, false)
        );

        // 5-3b. call checkHatWearerStatus to revoke
        hats.checkHatWearerStatus(secondHatId, secondWearer);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertFalse(hats.isInGoodStanding(secondWearer, secondHatId));

        // assert hatSupply is decremented
        assertEq(hats.hatSupply(secondHatId), --hatSupply);
    }

    function testCheckWearerBackInGoodStanding() public {
        // set to bad standing
        // mock call to eligibility contract to return (eligible = true, standing = false)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(true, false)
        );

        vm.expectEmit(false, false, false, true);
        emit WearerStandingChanged(secondHatId, secondWearer, false);

        hats.checkHatWearerStatus(secondHatId, secondWearer);

        // set back to good standing
        // mock call to eligibility contract to return (eligible = true, standing = true)
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(true, true)
        );

        vm.expectEmit(false, false, false, true);
        emit WearerStandingChanged(secondHatId, secondWearer, true);

        hats.checkHatWearerStatus(secondHatId, secondWearer);
    }
}

contract RenounceHatsTest is TestSetup2 {
    function testRenounceHat() public {
        // expectEmit HatRenounced
        // vm.expectEmit(false, false, false, true);
        // emit HatRenounced(secondHatId, secondWearer);

        //  6-2. renounce hat from wearer2
        vm.prank(address(secondWearer));
        hats.renounceHat(secondHatId);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
    }

    function testCannotRenounceHatAsNonWearerWithNoStaticBalance() public {
        // expect NotHatWearer error
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotHatWearer.selector));

        //  6-1. attempt to renounce from non-wearer
        vm.prank(address(nonWearer));
        hats.renounceHat(secondHatId);
    }

    function testCanRenounceHatAsNonWearerWithStaticBalance() public {
        // wearer becomes ineligible
        // encode mock for function inside eligibility contract to return false (inelible), true (good standing)
        vm.mockCall(
            _eligibility,
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(false, true)
        );

        // show that admin can't mint again to secondWearer, ie because they have a static balance
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotEligible.selector));
        hats.mintHat(secondHatId, secondWearer);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));

        // renounce should now succeed
        vm.prank(address(secondWearer));
        hats.renounceHat(secondHatId);

        // now, admin should be able to mint again if eligibility no longer returns false
        vm.clearMockedCalls();
        vm.prank(topHatWearer);
        hats.mintHat(secondHatId, secondWearer);
    }
}

contract ToggleSetHatsTest is TestSetup2 {
    function testDeactivateHat() public {
        // confirm second hat is active
        (,,,,,,,, active_) = hats.viewHat(secondHatId);
        assertTrue(active_);
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // expectEmit HatStatusChanged to false
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, false);

        // 7-2. change Hat Status true->false via setHatStatus
        vm.prank(address(_toggle));
        hats.setHatStatus(secondHatId, false);
        (,,,,,,, mutable_,) = hats.viewHat(secondHatId);
        assertFalse(mutable_);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
    }

    function testCannotDeactivateHatAsNonWearer() public {
        // expect NotHatstoggle error
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotHatsToggle.selector));

        // 7-1. attempt to change Hat Status hat from non-wearer
        vm.prank(address(nonWearer));
        hats.setHatStatus(secondHatId, false);
    }

    function testActivateDeactivatedHat() public {
        // change Hat Status true->false via setHatStatus
        vm.prank(address(_toggle));
        hats.setHatStatus(secondHatId, false);

        // expectEmit HatStatusChanged to true
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, true);

        // changeHatStatus false->true via setHatStatus
        vm.prank(address(_toggle));
        hats.setHatStatus(secondHatId, true);
        (,,,,,,,, active_) = hats.viewHat(secondHatId);
        assertTrue(active_);
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));
    }

    function testCannotActivateDeactivatedHatAsNonWearer() public {
        // change Hat Status true->false via setHatStatus
        vm.prank(address(_toggle));
        hats.setHatStatus(secondHatId, false);

        // expect NotHatstoggle error
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotHatsToggle.selector));

        // 8-1. attempt to changeHatStatus hat from wearer / other wallet / admin
        vm.prank(address(nonWearer));
        hats.setHatStatus(secondHatId, true);
    }

    function testCannotSetToggleOffToArbitrarilyIncrementHatSupply() public {
        // hat gets toggled off
        vm.prank(address(_toggle));
        hats.setHatStatus(secondHatId, false);

        // artificially mint again to secondWearer
        vm.prank(topHatWearer);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.HatNotActive.selector));

        hats.mintHat(secondHatId, secondWearer);

        (,, retsupply,,,,,,) = hats.viewHat(secondHatId);
        assertEq(retsupply, 1);

        // toggle hat back on
        vm.prank(address(_toggle));
        hats.setHatStatus(secondHatId, true);
        assertEq(hats.balanceOf(secondWearer, secondHatId), 1);
    }
}

contract ToggleCheckHatsTest is TestSetup2 {
    function testCannotCheckHatStatusNoFunctionInToggleContract() public {
        // expect NotHatsToggle error
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotHatsToggle.selector));

        // fail attempt to pull Hat Status
        hats.checkHatStatus(secondHatId);
    }

    function testCheckToggleToDeactivateHat() public {
        // expectEmit HatStatusChanged to false
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, false);

        // encode mock for function inside toggle contract to return false
        vm.mockCall(address(_toggle), abi.encodeWithSignature("getHatStatus(uint256)", secondHatId), abi.encode(false));

        // call mocked function within checkHatStatus to deactivate
        hats.checkHatStatus(secondHatId);
        (,,,,,,, mutable_,) = hats.viewHat(secondHatId);
        assertFalse(mutable_);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
    }

    function testCheckToggleToActivateDeactivatedHat() public {
        // change Hat Status true->false via setHatStatus
        vm.prank(address(_toggle));
        hats.setHatStatus(secondHatId, false);

        // expectEmit HatStatusChanged to true
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, true);

        // encode mock for function inside toggle contract to return false
        vm.mockCall(address(_toggle), abi.encodeWithSignature("getHatStatus(uint256)", secondHatId), abi.encode(true));

        // call mocked function within checkHatStatus to reactivate
        hats.checkHatStatus(secondHatId);
        (,,,,,,,, active_) = hats.viewHat(secondHatId);
        assertTrue(active_);
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));
    }

    function testCannotCheckToggleOffToArbitrarilyIncrementHatSupply() public {
        // hat gets toggled off
        // encode mock for function inside toggle contract to return false
        vm.mockCall(address(_toggle), abi.encodeWithSignature("getHatStatus(uint256)", secondHatId), abi.encode(false));

        // artificially mint again to secondWearer
        vm.prank(topHatWearer);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.HatNotActive.selector));

        hats.mintHat(secondHatId, secondWearer);

        (,, retsupply,,,,,,) = hats.viewHat(secondHatId);
        assertEq(retsupply, 1);

        // toggle hat back on
        // encode mock for function inside toggle contract to return false
        vm.mockCall(address(_toggle), abi.encodeWithSignature("getHatStatus(uint256)", secondHatId), abi.encode(true));
        assertEq(hats.balanceOf(secondWearer, secondHatId), 1);
    }
}

contract MutabilityTests is TestSetupMutable, LongStrings {
    function testAdminCanMakeMutableHatImmutable() public {
        (,,,,,,, mutable_,) = hats.viewHat(secondHatId);
        assertTrue(mutable_);

        vm.expectEmit(false, false, false, true);
        emit HatMutabilityChanged(secondHatId);

        vm.prank(topHatWearer);
        hats.makeHatImmutable(secondHatId);

        (,,,,,,, mutable_,) = hats.viewHat(secondHatId);
        assertFalse(mutable_);
    }

    function testCannotChangeImmutableHatMutability() public {
        // create immutable hat
        vm.prank(topHatWearer);
        thirdHatId = hats.createHat(
            topHatId,
            "immutable hat",
            3, // maxSupply
            _eligibility,
            _toggle,
            false,
            secondHatImageURI
        );

        (,,,,,,, mutable_,) = hats.viewHat(thirdHatId);
        assertFalse(mutable_);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));

        vm.prank(topHatWearer);
        hats.makeHatImmutable(thirdHatId);
    }

    function testNonAdminCannotMakeMutableHatImmutable() public {
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdmin.selector, address(this), secondHatId));

        hats.makeHatImmutable(secondHatId);
    }

    function testAdminCannotChangeImutableHatProperties() public {
        vm.startPrank(topHatWearer);
        thirdHatId = hats.createHat(
            topHatId,
            "immutable hat",
            3, // maxSupply
            _eligibility,
            _toggle,
            false,
            secondHatImageURI
        );

        (,,,,,,, mutable_,) = hats.viewHat(thirdHatId);
        assertFalse(mutable_);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        hats.changeHatDetails(thirdHatId, "should not work");

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        hats.changeHatEligibility(thirdHatId, address(this));

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        hats.changeHatToggle(thirdHatId, address(this));

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        hats.changeHatImageURI(thirdHatId, "should not work either");

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        hats.changeHatMaxSupply(thirdHatId, uint32(100));

        vm.stopPrank();
    }

    function testTopHatCanChangeOwnDetails() public {
        string memory new_ = "should work";

        vm.expectEmit(false, false, false, true);
        emit HatDetailsChanged(topHatId, new_);

        vm.prank(topHatWearer);
        hats.changeHatDetails(topHatId, new_);

        (string memory changed,,,,,,,,) = hats.viewHat(topHatId);
        assertEq(changed, new_);
    }

    function testTopHatCanChangeOwnImageURI() public {
        string memory new_ = "should work";

        vm.expectEmit(false, false, false, true);
        emit HatImageURIChanged(topHatId, new_);

        vm.prank(topHatWearer);
        hats.changeHatImageURI(topHatId, new_);

        (,,,,, string memory changed,,,) = hats.viewHat(topHatId);
        assertEq(changed, new_);
    }

    function testTopHatCannotChangeOtherProperties() public {
        vm.startPrank(topHatWearer);

        (,,,,,,, mutable_,) = hats.viewHat(topHatId);
        assertFalse(mutable_);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        hats.changeHatEligibility(topHatId, address(this));

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        hats.changeHatToggle(topHatId, address(this));

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        hats.changeHatMaxSupply(topHatId, uint32(100));

        vm.stopPrank();
    }

    function testNonTopHatCannotChangeTopHatProperties() public {
        vm.startPrank(secondWearer);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdmin.selector, secondWearer, topHatId));
        hats.changeHatImageURI(topHatId, "should fail");

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdmin.selector, secondWearer, topHatId));
        hats.changeHatDetails(topHatId, "should also fail");
    }

    function testAdminCanChangeMutableHatDetails() public {
        string memory new_ = "should work";

        vm.expectEmit(false, false, false, true);
        emit HatDetailsChanged(secondHatId, new_);

        vm.prank(topHatWearer);
        hats.changeHatDetails(secondHatId, new_);

        (string memory changed,,,,,,,,) = hats.viewHat(secondHatId);
        assertEq(changed, new_);
    }

    function testAdminCanChangeMutableHatEligibility() public {
        address new_ = address(this);

        vm.expectEmit(false, false, false, true);
        emit HatEligibilityChanged(secondHatId, new_);

        vm.prank(topHatWearer);
        hats.changeHatEligibility(secondHatId, new_);

        (,,, address changed,,,,,) = hats.viewHat(secondHatId);
        assertEq(changed, new_);
    }

    function testAdminCanChangeMutableHatToggle() public {
        address new_ = address(this);

        vm.expectEmit(false, false, false, true);
        emit HatToggleChanged(secondHatId, new_);

        vm.prank(topHatWearer);
        hats.changeHatToggle(secondHatId, new_);

        (,,,, address changed,,,,) = hats.viewHat(secondHatId);
        assertEq(changed, new_);
    }

    function testAdminCanChangeMutableHatImageURI() public {
        string memory new_ = "should work";

        vm.expectEmit(false, false, false, true);
        emit HatImageURIChanged(secondHatId, new_);

        vm.prank(topHatWearer);
        hats.changeHatImageURI(secondHatId, new_);

        (,,,,, string memory changed,,,) = hats.viewHat(secondHatId);
        assertEq(changed, new_);
    }

    function testAdminCanIncreaseMutableHatMaxSupply() public {
        uint32 new_ = 100;

        vm.expectEmit(false, false, false, true);
        emit HatMaxSupplyChanged(secondHatId, new_);

        vm.prank(topHatWearer);
        hats.changeHatMaxSupply(secondHatId, new_);

        (, uint32 changed,,,,,,,) = hats.viewHat(secondHatId);
        assertEq(changed, new_);
    }

    function testAdminCanDecreaseMutableHatMaxSupplyToAboveCurrentSupply() public {
        uint32 new_ = 100;
        uint32 decreased = 5;

        vm.startPrank(topHatWearer);
        hats.changeHatMaxSupply(secondHatId, new_);
        hats.mintHat(secondHatId, secondWearer);

        vm.expectEmit(false, false, false, true);
        emit HatMaxSupplyChanged(secondHatId, decreased);

        hats.changeHatMaxSupply(secondHatId, decreased);

        (, uint32 changed,,,,,,,) = hats.viewHat(secondHatId);
        assertEq(changed, decreased);
    }

    function testAdminCanDecreaseMutableHatMaxSupplyToEqualToCurrentSupply() public {
        uint32 new_ = 100;
        uint32 decreased = 1;

        vm.startPrank(topHatWearer);
        hats.changeHatMaxSupply(secondHatId, new_);
        hats.mintHat(secondHatId, secondWearer);

        vm.expectEmit(false, false, false, true);
        emit HatMaxSupplyChanged(secondHatId, decreased);

        hats.changeHatMaxSupply(secondHatId, decreased);

        (, uint32 changed,,,,,,,) = hats.viewHat(secondHatId);
        assertEq(changed, decreased);
    }

    function testAdminCannotDecreaseMutableHatMaxSupplyBelowCurrentSupply() public {
        uint32 new_ = 100;
        uint32 decreased = 1;

        vm.startPrank(topHatWearer);
        hats.changeHatMaxSupply(secondHatId, new_);
        hats.mintHat(secondHatId, secondWearer);
        hats.mintHat(secondHatId, thirdWearer);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NewMaxSupplyTooLow.selector));

        hats.changeHatMaxSupply(secondHatId, decreased);
    }

    function testAdminCannotTransferImmutableHat() public {
        vm.startPrank(topHatWearer);
        thirdHatId = hats.createHat(
            topHatId,
            "immutable hat",
            3, // maxSupply
            _eligibility,
            _toggle,
            false,
            secondHatImageURI
        );

        (,,,,,,, mutable_,) = hats.viewHat(thirdHatId);
        assertFalse(mutable_);

        hats.mintHat(thirdHatId, thirdWearer);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.Immutable.selector));
        hats.transferHat(thirdHatId, thirdWearer, secondWearer);
    }

    function testAdminCannotChangeEligibilityToZeroAddress() public {
        vm.expectRevert(HatsErrors.ZeroAddress.selector);
        vm.prank(topHatWearer);
        hats.changeHatEligibility(secondHatId, address(0));
    }

    function testAdminCannotChangeToggleToZeroAddress() public {
        vm.expectRevert(HatsErrors.ZeroAddress.selector);
        vm.prank(topHatWearer);
        hats.changeHatToggle(secondHatId, address(0));
    }

    function testMechanisticToggleOutputSavedWhenChangingToHumanisticToggle() public {
        // mock a getHatStatus call to return false (inactive) for secondHatId
        vm.mockCall(
            address(_toggle), abi.encodeWithSelector(IHatsToggle.getHatStatus.selector, secondHatId), abi.encode(false)
        );
        (,,,,,,,, bool status) = hats.viewHat(secondHatId);
        assertFalse(status);
        // change the toggle to a humanistic module
        vm.prank(topHatWearer);
        hats.changeHatToggle(secondHatId, address(5));
        // ensure that hat status is still active
        (,,,,,,,, status) = hats.viewHat(secondHatId);
        assertFalse(status);
    }

    function testAdminCannotChangeDetailsToTooLongString() public {
        vm.prank(topHatWearer);
        // console2.log("string length", bytes(long7050).length);
        vm.expectRevert(HatsErrors.StringTooLong.selector);
        hats.changeHatDetails(secondHatId, long7050);
    }

    function testAdminCannotChangeImageURIToTooLongString() public {
        vm.prank(topHatWearer);
        // console2.log("string length", bytes(long7050).length);
        vm.expectRevert(HatsErrors.StringTooLong.selector);
        hats.changeHatImageURI(secondHatId, long7050);
    }
}

contract OverridesHatTests is TestSetup2 {
    function testFailSetApprovalForAll() public view {
        hats.setApprovalForAll(topHatWearer, true);
    }

    function testFailSafeTransferFrom() public view {
        bytes memory b = bytes("");
        hats.safeTransferFrom(secondWearer, thirdWearer, secondHatId, 1, b);
    }

    function testCreateUri() public view {
        string memory jsonUri = hats.uri(secondHatId);
        console2.log("encoded URI", jsonUri);
    }

    function testCreateUriForTopHat() public view {
        string memory jsonUri = hats.uri(topHatId);
        console2.log("encoded URI", jsonUri);
    }

    function testBalanceOfBatch() public {
        // create and mint two separate hats to two separate wearers

        // build this test result array
        // secondWearer wears secondHatId, ie 1
        // thirdWearer wearss thidrHatId, 1
        // nonWearer doesn't wear secondHatId, 0
        uint256[] memory test = new uint256[](3);
        test[0] = 1;
        test[1] = 1;
        test[2] = 0;

        address[] memory wearers = new address[](3);
        wearers[0] = secondWearer;
        wearers[1] = thirdWearer;
        wearers[2] = nonWearer;

        // create and mint thirdHatId to thirdWearer
        vm.prank(topHatWearer);
        thirdHatId = hats.createHat(
            topHatId,
            "third hat",
            3, // maxSupply
            _eligibility,
            _toggle,
            true,
            ""
        );

        uint256[] memory ids = new uint256[](3);
        ids[0] = secondHatId;
        ids[1] = thirdHatId;
        ids[2] = secondHatId;

        vm.prank(topHatWearer);
        hats.mintHat(thirdHatId, thirdWearer);

        uint256[] memory balances = hats.balanceOfBatch(wearers, ids);

        assertEq(balances, test);

        // try balance of batch with three hats and three wearers
    }
}

contract LinkHatsTests is TestSetup2 {
    uint256 internal secondTopHatId;
    uint32 topHatDomain;
    uint32 secondTopHatDomain;
    uint256 level13HatId;
    uint256 level14HatId;

    function setUp() public override {
        super.setUp();

        secondTopHatId = hats.mintTopHat(thirdWearer, "for linking", "http://www.tophat.com/");

        topHatDomain = hats.getTopHatDomain(topHatId);
        secondTopHatDomain = hats.getTopHatDomain(secondTopHatId);
        level13HatId = 0x0000000100050001000100010001000100010001000100010001000100010000;

        vm.prank(topHatWearer);

        level14HatId = hats.createHat(level13HatId, "level 14 hat", _maxSupply, _eligibility, _toggle, false, "");
    }

    function testRequestLinking() public {
        vm.prank(thirdWearer);

        vm.expectEmit(true, true, true, true);
        emit TopHatLinkRequested(secondTopHatDomain, secondHatId);

        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);

        assertEq(secondHatId, hats.linkedTreeRequests(secondTopHatDomain));
    }

    function testWearerCanApproveLinkRequest() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);

        // approve
        vm.prank(secondWearer);

        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, secondHatId);

        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 2);
        assertTrue(hats.isAdminOfHat(secondWearer, secondTopHatId));
        assertEq(hats.linkedTreeRequests(secondTopHatDomain), 0);
    }

    function testAdminCanApproveLinkRequest() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);

        // approve
        vm.prank(topHatWearer);

        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, secondHatId);

        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 2);
        console2.log("starting isAdminOfHat assertion");
        assertTrue(hats.isAdminOfHat(secondWearer, secondTopHatId));
        assertEq(hats.linkedTreeRequests(secondTopHatDomain), 0);
    }

    function testAdminCanApproveLinkToLastLevelHat() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, level14HatId);

        // approve
        vm.prank(topHatWearer);

        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, level14HatId);

        hats.approveLinkTopHatToTree(secondTopHatDomain, level14HatId, address(0), address(0), "", "");

        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 15);
        assertTrue(hats.isAdminOfHat(topHatWearer, secondTopHatId));
        assertEq(hats.linkedTreeRequests(secondTopHatDomain), 0);
    }

    function testWearerCanApproveLinkToLastLevelHat() public {
        // mint last level hat to wearer
        vm.prank(topHatWearer);
        hats.mintHat(level14HatId, fourthWearer);

        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, level14HatId);

        // approve
        vm.prank(fourthWearer);

        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, level14HatId);

        hats.approveLinkTopHatToTree(secondTopHatDomain, level14HatId, address(0), address(0), "", "");

        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 15);
        assertTrue(hats.isAdminOfHat(fourthWearer, secondTopHatId));
        assertEq(hats.linkedTreeRequests(secondTopHatDomain), 0);
    }

    function testNonAdminNonWearerCannotApproveLinktoLastLevelHat() public {
        // mint last level hat to wearer
        vm.prank(topHatWearer);
        hats.mintHat(level14HatId, fourthWearer);

        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, level14HatId);

        // attempt to approve from non-admin and non-wearer of new admin hat
        assertFalse(hats.isWearerOfHat(secondWearer, level14HatId));
        assertFalse(hats.isAdminOfHat(secondWearer, level14HatId));

        vm.prank(secondWearer);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdminOrWearer.selector));
        hats.approveLinkTopHatToTree(secondTopHatDomain, level14HatId, address(0), address(0), "", "");
    }

    function testCannotApproveUnrequestedLink() public {
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.LinkageNotRequested.selector));
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");
    }

    function testAdminCanRelinkTopHatWithinTree() public {
        // first link
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, secondHatId);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");
        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 2);

        // relink
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, topHatId);
        hats.relinkTopHatWithinTree(secondTopHatDomain, topHatId, address(0), address(0), "", "");
        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 1);
    }

    function testNewAdminWearerCanRelinkTopHatWithinTree() public {
        vm.startPrank(secondWearer);
        uint256 level2HatId = hats.createHat(secondHatId, "", _maxSupply, _eligibility, _toggle, false, "");
        hats.mintHat(level2HatId, fourthWearer);
        vm.stopPrank();
        // first link
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, level2HatId);
        vm.prank(fourthWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, level2HatId, address(0), address(0), "", "");
        assertEq(hats.getHatLevel(secondTopHatId), 3);

        // relink to secondHatId
        vm.prank(secondWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, secondHatId);
        hats.relinkTopHatWithinTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");
        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 2);
    }

    function testNewAdminAdminCanRelinkToLastLevelWithinTree() public {
        // first link
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        // relink
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, level14HatId);
        hats.relinkTopHatWithinTree(secondTopHatDomain, level14HatId, address(0), address(0), "", "");
        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 15);
        assertTrue(hats.isAdminOfHat(topHatWearer, secondTopHatId));
        assertEq(hats.linkedTreeRequests(secondTopHatDomain), 0);
    }

    function testNewAdminNonAdminNonWearerCannotRelink() public {
        // first link to secondHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");
        assertTrue(hats.isAdminOfHat(secondWearer, secondTopHatId));

        // attempt relink to tophatId from secondWearer, who is an admin of secondTopHatId but not an admin or wearer of tophatId
        vm.startPrank(secondWearer);
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NotAdmin.selector, secondWearer, hats.buildHatId(topHatId, 1))
        );
        hats.relinkTopHatWithinTree(secondTopHatDomain, topHatId, address(0), address(0), "", "");
    }

    function testNewAdminNonAdminCannotRelinkToLastLevelWithinTree() public {
        // first link to secondHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");
        assertTrue(hats.isAdminOfHat(secondWearer, secondTopHatId));

        // attempt relink to 14th level from secondhatwearer, who is an admin of secondTopHatId but not an admin or wearer of tophatId
        vm.startPrank(secondWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdminOrWearer.selector));
        hats.relinkTopHatWithinTree(secondTopHatDomain, level14HatId, address(0), address(0), "", "");
    }

    function testTreeRootNonAdminCannotRelink() public {
        // create another hat under tophat
        vm.prank(topHatWearer);
        uint256 newHatId = hats.createHat(topHatId, "", _maxSupply, _eligibility, _toggle, false, "");

        // first link to secondHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        // attempt relink to new hat from secondWearer
        vm.startPrank(secondWearer);
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NotAdmin.selector, secondWearer, hats.buildHatId(newHatId, 1))
        );
        hats.relinkTopHatWithinTree(secondTopHatDomain, newHatId, address(0), address(0), "", "");
    }

    function testAdminCanRequestNewLink() public {
        // first link to secondHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");
        assertEq(hats.linkedTreeRequests(secondTopHatDomain), 0);

        // request new link from secondWearer
        vm.prank(secondWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinkRequested(secondTopHatDomain, topHatId);
        hats.requestLinkTopHatToTree(secondTopHatDomain, topHatId);
        assertEq(hats.linkedTreeRequests(secondTopHatDomain), topHatId);
    }

    function testNewAdminAdminCanApproveNewLinkRequest() public {
        // first link to secondHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        // request new link from secondWearer
        vm.prank(secondWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, topHatId);

        // approve new link from tophatwearer
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, topHatId);
        hats.approveLinkTopHatToTree(secondTopHatDomain, topHatId, address(0), address(0), "", "");
        assertEq(hats.linkedTreeRequests(secondTopHatDomain), 0);
        assertEq(hats.getHatLevel(secondTopHatId), 1);
    }

    function testLinkedTopHatWearerCannotRequestNewLink() public {
        // first link
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, secondHatId);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");
        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 2);

        // attempt second link from wearer
        console2.log("attempting second link");
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdmin.selector, thirdWearer, secondTopHatId));
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, topHatId);
    }

    function testPreventingCircularLinking() public {
        // request
        vm.prank(topHatWearer);
        hats.requestLinkTopHatToTree(topHatDomain, secondHatId);

        // try approving
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.CircularLinkage.selector));
        hats.approveLinkTopHatToTree(topHatDomain, secondHatId, address(0), address(0), "", "");

        // test a recursive call
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        vm.prank(topHatWearer);
        hats.requestLinkTopHatToTree(topHatDomain, secondTopHatId);
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.CircularLinkage.selector));
        hats.approveLinkTopHatToTree(topHatDomain, secondTopHatId, address(0), address(0), "", "");
    }

    function testRelinkingCannotCreateCircularLink() public {
        // first link, under secondHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        // second link, under first link
        uint256 thirdTopHatId = hats.mintTopHat(fourthWearer, "for linking", "http://www.tophat.com/");
        uint32 thirdTopHatDomain = hats.getTopHatDomain(thirdTopHatId);

        vm.prank(fourthWearer);
        hats.requestLinkTopHatToTree(thirdTopHatDomain, secondTopHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(thirdTopHatDomain, secondTopHatId, address(0), address(0), "", "");

        // try relink second tophat under third tophat
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.CircularLinkage.selector));
        hats.relinkTopHatWithinTree(secondTopHatDomain, thirdTopHatId, address(0), address(0), "", "");
    }

    function testCannotCrossTreeRelink() public {
        // create third tophat
        uint256 thirdTopHatId = hats.mintTopHat(fourthWearer, "invalid relink recipient", "http://www.tophat.com/");

        // link secondTopHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(secondWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        // attempt link secondTopHat to third tophat (worn by fourthWearer)
        vm.prank(secondWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, thirdTopHatId);
        vm.prank(fourthWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.CrossTreeLinkage.selector));
        hats.approveLinkTopHatToTree(secondTopHatDomain, thirdTopHatId, address(0), address(0), "", "");
    }

    function testCannotApproveCrossTreeLink() public {
        // create third tophat
        uint256 thirdTopHatId = hats.mintTopHat(topHatWearer, "invalid relink recipient", "http://www.tophat.com/");

        // link secondTopHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(secondWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        // attempt relink secondTopHat to third tophat (worn by topHatWearer)
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.CrossTreeLinkage.selector));
        hats.relinkTopHatWithinTree(secondTopHatDomain, thirdTopHatId, address(0), address(0), "", "");
    }

    function testTreeLinkingAndUnlinking() public {
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdmin.selector, address(this), secondTopHatId));
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);

        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, secondHatId);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");
        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 2);
        assertEq(hats.linkedTreeRequests(secondTopHatDomain), 0);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdmin.selector, address(this), secondTopHatId));
        hats.unlinkTopHatFromTree(secondTopHatDomain, thirdWearer);

        vm.prank(secondWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, 0);
        hats.unlinkTopHatFromTree(secondTopHatDomain, thirdWearer);
        assertEq(hats.isTopHat(secondTopHatId), true);
    }

    function testUnlinkedHatCannotBeLinkedAgainWithoutPermission() public {
        // first link of tophat to tree A
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        // tophat wearer creates a new tree B
        vm.startPrank(topHatWearer);
        uint256 treeB = hats.mintTopHat(topHatWearer, "for rugging", "http://www.tophat.com/");

        // tree A requests new link to a different tree B
        // this is possible because tree A is an admin for the tophat
        hats.requestLinkTopHatToTree(secondTopHatDomain, treeB);

        // tree A unlinks the tophat
        hats.unlinkTopHatFromTree(secondTopHatDomain, thirdWearer);

        // admin B should not be able to rug the tree by approving the link without the tree's permission
        vm.expectRevert(HatsErrors.LinkageNotRequested.selector);
        hats.approveLinkTopHatToTree(secondTopHatDomain, treeB, address(0), address(0), "", "");

        assertTrue(hats.isAdminOfHat(thirdWearer, secondTopHatId));
    }

    function testCanChangeModulesAndMetadataWhenApprovingOrRelinking() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);

        // approve with updated modules and metadata
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, _eligibility, _toggle, "details", "image");
        (string memory details,,, address eligibility, address toggle, string memory image,,,) =
            hats.viewHat(secondTopHatId);
        assertEq(details, "details");
        assertEq(image, "image");
        assertEq(eligibility, _eligibility);
        assertEq(toggle, _toggle);

        // relink with updated modules and metadata
        vm.prank(topHatWearer);
        hats.relinkTopHatWithinTree(secondTopHatDomain, secondHatId, address(100), address(101), "details2", "image2");
        (details,,, eligibility, toggle, image,,,) = hats.viewHat(secondTopHatId);
        assertEq(details, "details2");
        assertEq(image, "image2");
        assertEq(eligibility, address(100));
        assertEq(toggle, address(101));

        // check that linked top hat can be toggled off
        vm.mockCall(address(101), abi.encodeWithSignature("getHatStatus(uint256)", secondTopHatId), abi.encode(false));
        (,,,,,,,, bool status) = hats.viewHat(secondTopHatId);
        assertFalse(status);

        // modules values reset on unlink
        // first need to toggle back on
        vm.mockCall(address(101), abi.encodeWithSignature("getHatStatus(uint256)", secondTopHatId), abi.encode(true));
        (,,,,,,,, status) = hats.viewHat(secondTopHatId);
        assertTrue(status);
        vm.prank(topHatWearer);
        hats.unlinkTopHatFromTree(secondTopHatDomain, thirdWearer);
        (,,, eligibility, toggle,,,,) = hats.viewHat(secondTopHatId);
        assertEq(eligibility, address(0));
        assertEq(toggle, address(0));
    }

    function testAdminCanBurnAndRemintLinkedTopHat() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        // approve
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, _eligibility, address(0), "", "");

        // mock wearer ineligible
        vm.mockCall(
            _eligibility,
            abi.encodeWithSignature("getWearerStatus(address,uint256)", thirdWearer, secondTopHatId),
            abi.encode(false, true)
        );
        assertFalse(hats.isEligible(thirdWearer, secondTopHatId));
        // burn the hat
        hats.checkHatWearerStatus(secondTopHatId, thirdWearer);

        // remint
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(topHatWearer, address(0), address(99), secondTopHatId, 1);
        vm.prank(topHatWearer);
        hats.mintHat(secondTopHatId, address(99));
    }

    function testAdminCannotTransferLinkedTopHat() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        // approve
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(0), "", "");

        // attempt transfer
        vm.prank(topHatWearer);
        vm.expectRevert(HatsErrors.Immutable.selector);
        hats.transferHat(secondTopHatId, thirdWearer, address(99));
    }

    function testAdminCannotUnlinkInactivefTopHat() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        // approve
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, address(0), address(101), "", "");

        // toggle off linked tophat
        vm.mockCall(address(101), abi.encodeWithSignature("getHatStatus(uint256)", secondTopHatId), abi.encode(false));
        hats.checkHatStatus(secondTopHatId);
        (,,,,,,,, bool status) = hats.viewHat(secondTopHatId);
        assertFalse(status);

        // attempt unlink
        vm.prank(topHatWearer);
        vm.expectRevert(HatsErrors.InvalidUnlink.selector);
        hats.unlinkTopHatFromTree(secondTopHatDomain, thirdWearer);
    }

    function testAdminCannotUnlinkBurnedTopHat() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        // approve
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, _eligibility, address(0), "", "");

        // mock wearer ineligible
        vm.mockCall(
            _eligibility,
            abi.encodeWithSignature("getWearerStatus(address,uint256)", thirdWearer, secondTopHatId),
            abi.encode(false, true)
        );
        assertFalse(hats.isEligible(thirdWearer, secondTopHatId));
        // burn the hat
        hats.checkHatWearerStatus(secondTopHatId, thirdWearer);

        // attempt unlink
        vm.prank(topHatWearer);
        vm.expectRevert(HatsErrors.InvalidUnlink.selector);
        hats.unlinkTopHatFromTree(secondTopHatDomain, thirdWearer);
    }

    function testAdminCannotUnlinkRevokedTopHat() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        // approve
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, _eligibility, address(0), "", "");

        // mock wearer ineligible
        vm.mockCall(
            _eligibility,
            abi.encodeWithSignature("getWearerStatus(address,uint256)", thirdWearer, secondTopHatId),
            abi.encode(false, true)
        );
        assertFalse(hats.isEligible(thirdWearer, secondTopHatId));

        // attempt unlink
        vm.prank(topHatWearer);
        vm.expectRevert(HatsErrors.InvalidUnlink.selector);
        hats.unlinkTopHatFromTree(secondTopHatDomain, thirdWearer);
    }

    function testAdminCannotUnlinkTopHatWhenWearerIsInBadStanding() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        // approve
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, _eligibility, address(0), "", "");

        // mock wearer ineligible
        vm.mockCall(
            _eligibility,
            abi.encodeWithSignature("getWearerStatus(address,uint256)", thirdWearer, secondTopHatId),
            abi.encode(true, false)
        );
        assertFalse(hats.isEligible(thirdWearer, secondTopHatId));

        // attempt unlink
        vm.prank(topHatWearer);
        vm.expectRevert(HatsErrors.InvalidUnlink.selector);
        hats.unlinkTopHatFromTree(secondTopHatDomain, thirdWearer);
    }

    function testAdminCannotUnlinkTopHatWornByZeroAddress() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        // approve
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, _eligibility, address(0), "", "");

        // revoke top hat
        vm.prank(_eligibility);
        hats.setHatWearerStatus(secondTopHatId, thirdWearer, false, true);

        // remint it to address(0)
        vm.prank(topHatWearer);
        hats.mintHat(secondTopHatId, address(0));

        // attempt unlink
        vm.prank(topHatWearer);
        vm.expectRevert(HatsErrors.InvalidUnlink.selector);
        hats.unlinkTopHatFromTree(secondTopHatDomain, address(0));
    }

    function testAdminCannotUnlinkRenouncedTopHat() public {
        // request
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        // approve
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId, _eligibility, address(0), "", "");

        // the tophat is renounced
        vm.prank(thirdWearer);
        hats.renounceHat(secondTopHatId);

        // attempt unlink
        vm.prank(topHatWearer);
        vm.expectRevert(HatsErrors.InvalidUnlink.selector);
        hats.unlinkTopHatFromTree(secondTopHatDomain, address(0));
    }
}

contract MalformedInputsTests is TestSetup2 {
    string internal constant longString =
        "this is a super long string that hopefully is longer than 32 bytes. What say we make this especially loooooooooong?";
    address internal constant badAddress = address(0xbadadd55e);
    uint256 internal constant badUint = 2;

    function testCatchMalformedEligibilityData_isEligible() public {
        // mock malformed return data from eligibility
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(
                longString, // malformed; should be a bool
                true
            )
        );
        hats.isEligible(secondWearer, secondHatId);

        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(
                badUint, // malformed; should be a bool
                true
            )
        );
        hats.isEligible(secondWearer, secondHatId);

        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(
                badAddress, // malformed; should be a bool
                true
            )
        );
        hats.isEligible(secondWearer, secondHatId);
    }

    function testCatchMalformedEligibilityData_isInGoodStanding() public {
        // mock malformed return data from eligibility
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(
                longString, // malformed; should be a bool
                true
            )
        );
        hats.isInGoodStanding(secondWearer, secondHatId);

        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(
                badUint, // malformed; should be a bool
                true
            )
        );
        hats.isInGoodStanding(secondWearer, secondHatId);

        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(
                badAddress, // malformed; should be a bool
                true
            )
        );
        hats.isInGoodStanding(secondWearer, secondHatId);
    }

    function testCatchMalformedEligibilityData_checkHatWearerStatus() public {
        // mock malformed return data from eligibility
        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(
                longString, // malformed; should be a bool
                true
            )
        );
        vm.expectRevert(HatsErrors.NotHatsEligibility.selector);
        hats.checkHatWearerStatus(secondHatId, secondWearer);

        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(
                badUint, // malformed; should be a bool
                true
            )
        );
        vm.expectRevert(HatsErrors.NotHatsEligibility.selector);
        hats.checkHatWearerStatus(secondHatId, secondWearer);

        vm.mockCall(
            address(_eligibility),
            abi.encodeWithSignature("getWearerStatus(address,uint256)", secondWearer, secondHatId),
            abi.encode(
                badAddress, // malformed; should be a bool
                true
            )
        );
        vm.expectRevert(HatsErrors.NotHatsEligibility.selector);
        hats.checkHatWearerStatus(secondHatId, secondWearer);
    }

    function testCatchMalformedToggleData_isWearerOfHat() public {
        // mock malformed return data as a string
        vm.mockCall(
            address(_toggle),
            abi.encodeWithSignature("getHatStatus(uint256)", secondHatId),
            abi.encode(
                longString // malformed; should be a bool
            )
        );
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // mock malformed return data as a uint
        vm.mockCall(
            address(_toggle),
            abi.encodeWithSignature("getHatStatus(uint256)", secondHatId),
            abi.encode(
                badUint // malformed; should be a bool
            )
        );
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // mock malformed return data as an address
        vm.mockCall(
            address(_toggle),
            abi.encodeWithSignature("getHatStatus(uint256)", secondHatId),
            abi.encode(
                badAddress // malformed; should be a bool
            )
        );
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));
    }

    function testCatchMalformedToggleData_checkHatStatus() public {
        // mock malformed return data as a string
        vm.mockCall(
            address(_toggle),
            abi.encodeWithSignature("getHatStatus(uint256)", secondHatId),
            abi.encode(
                longString // malformed; should be a bool
            )
        );
        vm.expectRevert(HatsErrors.NotHatsToggle.selector);
        hats.checkHatStatus(secondHatId);

        // mock malformed return data as a uint
        vm.mockCall(
            address(_toggle),
            abi.encodeWithSignature("getHatStatus(uint256)", secondHatId),
            abi.encode(
                badUint // malformed; should be a bool
            )
        );
        vm.expectRevert(HatsErrors.NotHatsToggle.selector);
        hats.checkHatStatus(secondHatId);

        // mock malformed return data as an address
        vm.mockCall(
            address(_toggle),
            abi.encodeWithSignature("getHatStatus(uint256)", secondHatId),
            abi.encode(
                badAddress // malformed; should be a bool
            )
        );
        vm.expectRevert(HatsErrors.NotHatsToggle.selector);
        hats.checkHatStatus(secondHatId);
    }
}

contract MulticallTests is TestSetup {
    bytes[] data;
    string topDeets;
    string secondDeets;
    string topImage;
    string secondImage;

    function test_mintNewTopHat_andCreateHat() public {
        topHatId = 0x00000002_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        secondHatId = 0x00000002_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        topDeets = "multicall tophat";
        secondDeets = "multicall second hat";
        topImage = "hatsprotocol.eth/tophat.png";
        secondImage = "hatsprotocol.eth/secondhat.png";

        // craft the data for the mintTopHat call
        bytes memory mintTopHatData =
            abi.encodeWithSignature("mintTopHat(address,string,string)", topHatWearer, topDeets, topImage);

        // craft the data for the createHat call
        bytes memory createHatData = abi.encodeWithSignature(
            "createHat(uint256,string,uint32,address,address,bool,string)",
            topHatId,
            secondDeets,
            500,
            _eligibility,
            _toggle,
            true,
            secondImage
        );

        // craft the data for the multicall
        data = new bytes[](2);
        data[0] = mintTopHatData;
        data[1] = createHatData;

        // expect hat created, hat minted, and hat created events
        vm.expectEmit();
        emit HatCreated(topHatId, topDeets, 1, address(0), address(0), false, topImage);
        vm.expectEmit();
        emit TransferSingle(topHatWearer, address(0), topHatWearer, topHatId, 1);
        vm.expectEmit();
        emit HatCreated(secondHatId, secondDeets, 500, _eligibility, _toggle, true, secondImage);

        // call the multicall from topHatWearer
        vm.prank(topHatWearer);
        hats.multicall(data);

        // check that the hats were created
        assertTrue(hats.isWearerOfHat(topHatWearer, topHatId));
        assertEq(hats.getHatMaxSupply(secondHatId), 500);
    }

    function test_editHat() public {
        // create a mutable hat
        test_mintNewTopHat_andCreateHat();

        // craft the data for the details change
        bytes memory changeDetailsData =
            abi.encodeWithSignature("changeHatDetails(uint256,string)", secondHatId, "new details");

        // craft the data for the image change
        bytes memory changeImageData =
            abi.encodeWithSignature("changeHatImageURI(uint256,string)", secondHatId, "hatsprotocol.eth/newimage.png");

        // craft the data for the eligibility change
        bytes memory changeEligibilityData =
            abi.encodeWithSignature("changeHatEligibility(uint256,address)", secondHatId, address(1234));

        // craft the data for the toggle change
        bytes memory changeToggleData =
            abi.encodeWithSignature("changeHatToggle(uint256,address)", secondHatId, address(5678));

        // craft the data for the max supply change
        bytes memory changeMaxSupplyData =
            abi.encodeWithSignature("changeHatMaxSupply(uint256,uint32)", secondHatId, 1000);

        // craft the data to make the hat immutable
        bytes memory makeHatImmutableData = abi.encodeWithSignature("makeHatImmutable(uint256)", secondHatId);

        // craft the data for the multicall
        data = new bytes[](6);
        data[0] = changeDetailsData;
        data[1] = changeImageData;
        data[2] = changeEligibilityData;
        data[3] = changeToggleData;
        data[4] = changeMaxSupplyData;
        data[5] = makeHatImmutableData;

        // expect the details, image, eligibility, toggle, max supply, and immutable events
        vm.expectEmit();
        emit HatDetailsChanged(secondHatId, "new details");
        vm.expectEmit();
        emit HatImageURIChanged(secondHatId, "hatsprotocol.eth/newimage.png");
        vm.expectEmit();
        emit HatEligibilityChanged(secondHatId, address(1234));
        vm.expectEmit();
        emit HatToggleChanged(secondHatId, address(5678));
        vm.expectEmit();
        emit HatMaxSupplyChanged(secondHatId, 1000);
        vm.expectEmit();
        emit HatMutabilityChanged(secondHatId);

        // call the multicall from topHatWearer
        vm.prank(topHatWearer);
        hats.multicall(data);
    }
}
