// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";
import "./HatsTestSetup.t.sol";

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

    function testMintInactiveHat() public {
        // capture pre-values
        uint256 hatSupply_pre = hats.hatSupply(secondHatId);

        // deactivate the hat
        vm.prank(_toggle);
        hats.setHatStatus(secondHatId, false);

        // mint the hat to wearer
        vm.prank(topHatWearer);
        hats.mintHat(secondHatId, secondWearer);

        // assert that the wearer does not have the hat
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));

        // assert that the hat supply increased
        assertEq(++hatSupply_pre, hats.hatSupply(secondHatId));
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
        // hat gets toggled off
        // encode mock for function inside toggle contract to return false
        vm.mockCall(address(_toggle), abi.encodeWithSignature("getHatStatus(uint256)", secondHatId), abi.encode(false));

        // show that admin can't mint again to secondWearer, ie because they have a static balance
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.AlreadyWearingHat.selector, secondWearer, secondHatId));
        hats.mintHat(secondHatId, secondWearer);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));

        // renounce should now succeed
        vm.prank(address(secondWearer));
        hats.renounceHat(secondHatId);

        // now, admin should be able to mint again
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

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.AlreadyWearingHat.selector, secondWearer, secondHatId));

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

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.AlreadyWearingHat.selector, secondWearer, secondHatId));

        hats.mintHat(secondHatId, secondWearer);

        (,, retsupply,,,,,,) = hats.viewHat(secondHatId);
        assertEq(retsupply, 1);

        // toggle hat back on
        // encode mock for function inside toggle contract to return false
        vm.mockCall(address(_toggle), abi.encodeWithSignature("getHatStatus(uint256)", secondHatId), abi.encode(true));
        assertEq(hats.balanceOf(secondWearer, secondHatId), 1);
    }
}

contract MutabilityTests is TestSetupMutable {
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
        console2.log("creating level 14 hat");
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

        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);

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

        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);

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

        hats.approveLinkTopHatToTree(secondTopHatDomain, level14HatId);

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

        hats.approveLinkTopHatToTree(secondTopHatDomain, level14HatId);

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
        hats.approveLinkTopHatToTree(secondTopHatDomain, level14HatId);
    }

    function testCannotApproveUnrequestedLink() public {
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.LinkageNotRequested.selector));
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);
    }

    function testAdminCanRelinkTopHatWithinTree() public {
        // first link
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, secondHatId);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);
        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 2);

        // relink
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, topHatId);
        hats.relinkTopHatWithinTree(secondTopHatDomain, topHatId);
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
        hats.approveLinkTopHatToTree(secondTopHatDomain, level2HatId);
        assertEq(hats.getHatLevel(secondTopHatId), 3);

        // relink to secondHatId
        vm.prank(secondWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, secondHatId);
        hats.relinkTopHatWithinTree(secondTopHatDomain, secondHatId);
        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 2);
    }

    function testNewAdminAdminCanRelinkToLastLevelWithinTree() public {
        // first link
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);

        // relink
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, level14HatId);
        hats.relinkTopHatWithinTree(secondTopHatDomain, level14HatId);
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
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);
        assertTrue(hats.isAdminOfHat(secondWearer, secondTopHatId));

        // attempt relink to tophatId from secondWearer, who is an admin of secondTopHatId but not an admin or wearer of tophatId
        vm.startPrank(secondWearer);
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NotAdmin.selector, secondWearer, hats.buildHatId(topHatId, 1))
        );
        hats.relinkTopHatWithinTree(secondTopHatDomain, topHatId);
    }

    function testNewAdminNonAdminCannotRelinkToLastLevelWithinTree() public {
        // first link to secondHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);
        assertTrue(hats.isAdminOfHat(secondWearer, secondTopHatId));

        // attempt relink to 14th level from secondhatwearer, who is an admin of secondTopHatId but not an admin or wearer of tophatId
        vm.startPrank(secondWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdminOrWearer.selector));
        hats.relinkTopHatWithinTree(secondTopHatDomain, level14HatId);
    }

    function testTreeRootNonAdminCannotRelink() public {
        // create another hat under tophat
        vm.prank(topHatWearer);
        uint256 newHatId = hats.createHat(topHatId, "", _maxSupply, _eligibility, _toggle, false, "");

        // first link to secondHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);

        // attempt relink to new hat from secondWearer
        vm.startPrank(secondWearer);
        vm.expectRevert(
            abi.encodeWithSelector(HatsErrors.NotAdmin.selector, secondWearer, hats.buildHatId(newHatId, 1))
        );
        hats.relinkTopHatWithinTree(secondTopHatDomain, newHatId);
    }

    function testAdminCanRequestNewLink() public {
        // first link to secondHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);
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
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);

        // request new link from secondWearer
        vm.prank(secondWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, topHatId);

        // approve new link from tophatwearer
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, topHatId);
        hats.approveLinkTopHatToTree(secondTopHatDomain, topHatId);
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
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);
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
        hats.approveLinkTopHatToTree(topHatDomain, secondHatId);

        // test a recursive call
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);

        vm.prank(topHatWearer);
        hats.requestLinkTopHatToTree(topHatDomain, secondTopHatId);
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.CircularLinkage.selector));
        hats.approveLinkTopHatToTree(topHatDomain, secondTopHatId);
    }

    function testRelinkingCannotCreateCircularLink() public {
        // first link, under secondHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);

        // second link, under first link
        uint256 thirdTopHatId = hats.mintTopHat(fourthWearer, "for linking", "http://www.tophat.com/");
        uint32 thirdTopHatDomain = hats.getTopHatDomain(thirdTopHatId);

        vm.prank(fourthWearer);
        hats.requestLinkTopHatToTree(thirdTopHatDomain, secondTopHatId);
        vm.prank(topHatWearer);
        hats.approveLinkTopHatToTree(thirdTopHatDomain, secondTopHatId);

        // try relink second tophat under third tophat
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.CircularLinkage.selector));
        hats.relinkTopHatWithinTree(secondTopHatDomain, thirdTopHatId);
    }

    function testCannotCrossTreeRelink() public {
        // create third tophat
        uint256 thirdTopHatId = hats.mintTopHat(fourthWearer, "invalid relink recipient", "http://www.tophat.com/");

        // link secondTopHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(secondWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);

        // attempt link secondTopHat to third tophat (worn by fourthWearer)
        vm.prank(secondWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, thirdTopHatId);
        vm.prank(fourthWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.CrossTreeLinkage.selector));
        hats.approveLinkTopHatToTree(secondTopHatDomain, thirdTopHatId);
    }

    function testCannotApproveCrossTreeLink() public {
        // create third tophat
        uint256 thirdTopHatId = hats.mintTopHat(topHatWearer, "invalid relink recipient", "http://www.tophat.com/");

        // link secondTopHat
        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(secondWearer);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);

        // attempt relink secondTopHat to third tophat (worn by topHatWearer)
        vm.prank(topHatWearer);
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.CrossTreeLinkage.selector));
        hats.relinkTopHatWithinTree(secondTopHatDomain, thirdTopHatId);
    }

    function testTreeLinkingAndUnlinking() public {
        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdmin.selector, address(this), secondTopHatId));
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);

        vm.prank(thirdWearer);
        hats.requestLinkTopHatToTree(secondTopHatDomain, secondHatId);
        vm.prank(topHatWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, secondHatId);
        hats.approveLinkTopHatToTree(secondTopHatDomain, secondHatId);
        assertFalse(hats.isTopHat(secondTopHatId));
        assertEq(hats.getHatLevel(secondTopHatId), 2);
        assertEq(hats.linkedTreeRequests(secondTopHatDomain), 0);

        vm.expectRevert(abi.encodeWithSelector(HatsErrors.NotAdmin.selector, address(this), secondTopHatId));
        hats.unlinkTopHatFromTree(secondTopHatDomain);

        vm.prank(secondWearer);
        vm.expectEmit(true, true, true, true);
        emit TopHatLinked(secondTopHatDomain, 0);
        hats.unlinkTopHatFromTree(secondTopHatDomain);
        assertEq(hats.isTopHat(secondTopHatId), true);
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
