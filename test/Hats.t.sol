// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";
import "./HatsTestSetup.t.sol";

contract CreateTopHatTest is TestSetup {
    function setUp() public override {
        setUpVariables();
        // instantiate Hats contract
        hats = new Hats();
    }

    function testTopHatCreated() public {
        vm.expectEmit(false, false, false, true);
        emit HatCreated(2**224, "", 1, address(0), address(0));

        topHatId = hats.mintTopHat(topHatWearer);

        assertTrue(hats.isTopHat(topHatId));
        assertEq(2**224, topHatId);
    }

    function testTopHatMinted() public {
        vm.expectEmit(true, true, true, true);

        emit TransferSingle(address(this), address(0), topHatWearer, 2**224, 1);

        topHatId = hats.mintTopHat(topHatWearer);

        assertTrue(hats.isWearerOfHat(topHatWearer, topHatId));
        assertFalse(hats.isWearerOfHat(nonWearer, topHatId));
    }
}

contract CreateHatsTest is TestSetup {
    function testHatCreated() public {
        // get prelim values
        (, , , , , uint8 lastHatId, ) = hats.viewHat(topHatId);

        topHatId = hats.mintTopHat(topHatWearer);
        vm.prank(address(topHatWearer));
        hats.createHat(topHatId, _details, _maxSupply, _oracle, _conditions);

        // assert admin's lastHatId is incremented
        (, , , , , uint8 lastHatIdPost, ) = hats.viewHat(topHatId);
        assertEq(++lastHatId, lastHatIdPost);
    }

    function testHatsBranchCreated() public {
        // mint TopHat
        topHatId = hats.mintTopHat(topHatWearer);

        (uint256[] memory ids, address[] memory wearers) = createHatsBranch(3);
        assertEq(hats.getHatLevel(ids[2]), 3);
        assertEq(hats.getAdminAtLevel(ids[0], 0), topHatId);
        assertEq(hats.getAdminAtLevel(ids[1], 1), ids[0]);
        assertEq(hats.getAdminAtLevel(ids[2], 2), ids[1]);
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
            _oracle,
            _conditions
        );
    }

    function testMintHat() public {
        // get initial values
        uint256 secondWearerBalance = hats.balanceOf(secondWearer, secondHatId);
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // check transfer event will be emitted
        vm.expectEmit(true, true, true, true);

        emit TransferSingle(
            topHatWearer,
            address(0),
            secondWearer,
            secondHatId,
            1
        );

        // mint hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);

        // assert balance = 1
        assertEq(
            hats.balanceOf(secondWearer, secondHatId),
            ++secondWearerBalance
        );

        // assert iswearer
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // assert hatSupply is incremented
        assertEq(hats.hatSupply(secondHatId), ++hatSupply);
    }

    function testMintAnotherHat() public {
        // store prelim values
        uint256 balance_pre = hats.balanceOf(thirdWearer, secondHatId);
        uint32 supply_pre = hats.hatSupply(secondHatId);
        (, , , , , uint8 lastHatId_pre, ) = hats.viewHat(topHatId);

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
        (, , , , , uint8 lastHatId_post, ) = hats.viewHat(topHatId);
        assertEq(lastHatId_post, lastHatId_pre);
    }

    // TODO: update to best practice with specific expectRevert
    function testFailMint2HatsToSameWearer() public {
        // store prelim values
        uint256 balance_pre = hats.balanceOf(thirdWearer, secondHatId);
        uint32 supply_pre = hats.hatSupply(secondHatId);
        (, , , , , uint8 lastHatId_pre, ) = hats.viewHat(topHatId);

        // mint hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);

        // mint another of same id to a new wearer
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);

        // assert balance is only incremented by 1 TODO
        // assertEq(hats.balanceOf(secondWearer, secondHatId), ++balance_pre);

        // assert isWearer is true
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // assert hatSupply is incremented only by 1 TODO
        // assertEq(hats.hatSupply(secondHatId), supply_pre + 1);

        // assert admin's lastHatId is *not* incremented
        (, , , , , uint8 lastHatId_post, ) = hats.viewHat(topHatId);
        assertEq(lastHatId_post, lastHatId_pre);
    }

    function testMintHatErrorNotAdmin() public {
        // store prelim values
        uint256 balance_pre = hats.balanceOf(secondWearer, secondHatId);
        uint32 supply_pre = hats.hatSupply(secondHatId);
        // expect NotAdmin Error
        vm.expectRevert(
            abi.encodeWithSelector(NotAdmin.selector, nonWearer, secondHatId)
        );

        // try to mint hat from a non-wearer
        vm.prank(address(nonWearer));

        hats.mintHat(secondHatId, secondWearer);

        // assert hatSupply is not incremented
        assertEq(hats.hatSupply(secondHatId), supply_pre);

        // assert wearer balance is unchanged
        assertEq(hats.balanceOf(secondWearer, secondHatId), balance_pre);
    }

    function testMintHatErrorAllHatsWorn() public {
        // mint hat
        // mint another
        // try to mint another of same id
        // assert AllHatsWorn error thrown
        // assert wearer balance is unchanged
    }

    function testBatchMintHats() public {}

    function testBatchMintHatsErrorArrayLength() public {}
}

contract ViewHatTests is TestSetup2 {
    function testViewHat() public {
        string memory retdetails;
        uint32 retmaxSupply;
        uint32 retsupply;
        address retoracle;
        address retconditions;
        uint8 retlastHatId;
        bool retactive;
        
        (retdetails,
         retmaxSupply,
         retsupply,
         retoracle,
         retconditions,
         retlastHatId,
         retactive) =
            hats.viewHat(secondHatId);
        
        // 3-1. viewHat - displays params as expected
        assertEq(retdetails, "second hat");
        assertEq(retmaxSupply, 2);
        assertEq(retsupply, 1);
        assertEq(retoracle, address(555));
        assertEq(retconditions, address(333));
        assertEq(retlastHatId, 0);
        assertEq(retactive, true);
    }

    function testViewHatOfTopHat() public {
        string memory retdetails;
        uint32 retmaxSupply;
        uint32 retsupply;
        address retoracle;
        address retconditions;
        uint8 retlastHatId;
        bool retactive;
        
        (retdetails,
         retmaxSupply,
         retsupply,
         retoracle,
         retconditions,
         retlastHatId,
         retactive) =
            hats.viewHat(topHatId);
        
        assertEq(retdetails, "");
        assertEq(retmaxSupply, 1);
        assertEq(retsupply, 1);
        assertEq(retoracle, address(0));
        assertEq(retconditions, address(0));
        assertEq(retlastHatId, 1);
        assertEq(retactive, true);
    }

    // TODO: do any other public functions need to be added here?
    // many of the other public functions are tested in the assertions of other tests (e.g. getAdminAtLevel)

    function testIsAdminOfHat() public {
        assertTrue(hats.isAdminOfHat(topHatWearer, secondHatId));
    }

    function testGetHatLevel() public {
        assertEq(hats.getHatLevel(topHatId), 0);
        assertEq(hats.getHatLevel(secondHatId), 1);
    }
}

contract TransferHatTests is TestSetup2 {
    // TODO: add expectRevert -> error OnlyAdminsCanTransfer()
    function testFailTransferHatFromNonAdmin() public {
        // 4-1. transfer from wearer / other wallet
        vm.prank(address(nonWearer));
        hats.transferHat(secondHatId, secondWearer, thirdWearer);
    }

    function testTransferHat() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // 4-2. transfer from admin
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
}

contract OracleSetHatsTests is TestSetup2 {
    function testDoNotRevokeHatFromWearerInGoodStanding() public {
        // confirm second hat is worn by second Wearer
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // expectEmit WearerStatus - should be wearing, in good standing
        vm.expectEmit(false, false, false, true);
        emit WearerStatus(secondHatId, secondWearer, false, true);

        // 5-6. do not revoke hat
        vm.prank(address(_oracle));
        hats.setHatWearerStatus(secondHatId, secondWearer, false, true);
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));
        assertTrue(hats.isInGoodStanding(secondWearer, secondHatId));
    }

    function testRevokeHatFromWearerInGoodStanding() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // expectEmit WearerStatus - should not be wearing, in good standing
        vm.expectEmit(false, false, false, true);
        emit WearerStatus(secondHatId, secondWearer, true, true);

        // 5-8a. revoke hat
        vm.prank(address(_oracle));
        hats.setHatWearerStatus(secondHatId, secondWearer, true, true);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertTrue(hats.isInGoodStanding(secondWearer, secondHatId));

        // assert hatSupply is decremented
        assertEq(hats.hatSupply(secondHatId), --hatSupply);
    }

    function testRevokeHatFromWearerInBadStanding() public {
        // expectEmit WearerStatus - should not be wearing, in bad standing
        vm.expectEmit(false, false, false, true);
        emit WearerStatus(secondHatId, secondWearer, true, false);

        // 5-8b. revoke hat with bad standing
        vm.prank(address(_oracle));
        hats.setHatWearerStatus(secondHatId, secondWearer, true, false);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertFalse(hats.isInGoodStanding(secondWearer, secondHatId));
    }

    // TODO: do we need to test the following functionality?
    // the following call should never happen:
    // setHatWearerStatus(secondHatId, secondWearer, false, false);
    // i.e. WearerStatus - wearing, in bad standing

    // TODO: update to best practice:
    // vm.expectRevert(hats.NotHatOracle.selector);
    // rename function to testCannotRevokeHatAsNonWearer()
    function testFailToRevokeHatAsNonWearer() public {
        vm.prank(address(nonWearer));
        hats.setHatWearerStatus(secondHatId, secondWearer, true, false);
    }

    function testRemintAfterRevokeHatFromWearerInGoodStanding() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);

        // revoke hat
        vm.prank(address(_oracle));
        hats.setHatWearerStatus(secondHatId, secondWearer, true, true);

        // 5-4. remint hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);

        // assert balance = 1
        assertEq(hats.balanceOf(secondWearer, secondHatId), 1);

        // assert iswearer
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // assert hatSupply is not incremented
        assertEq(hats.hatSupply(secondHatId), hatSupply);
    }
}

contract OracleGetHatsTests is TestSetup2 {
    // TODO: should getHatWearerStanding fail in a different way when the Oracle contract doesn't have the function?
    // TODO: update to best practice with specific expectRevert
    function testFailGetHatWearerStandingNoFunctionInOracleContract() public {
        bool standing;
        (, standing) = hats.getHatWearerStatus(secondHatId, secondWearer);
    }

    function testCheckOracleAndDoNotRevokeHatFromWearerInGoodStanding() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);
        bytes4 select0r = 0xbd683872; // TODO: do not hardcode selector

        // confirm second hat is worn by second Wearer
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // expectEmit WearerStatus - should not be wearing, in good standing
        vm.expectEmit(false, false, false, true);
        emit WearerStatus(secondHatId, secondWearer, false, true);

        // mock calls to Oracle contract to return (false, true)
        vm.mockCall(
            address(_oracle),
            abi.encodeWithSelector(select0r),
            abi.encode(false, true)
        );

        // 5-1. call getHatStatus - no revocation
        hats.getHatWearerStatus(secondHatId, secondWearer);
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));
        assertTrue(hats.isInGoodStanding(secondWearer, secondHatId));

        // assert hatSupply is not decremented
        assertEq(hats.hatSupply(secondHatId), hatSupply);
    }

    function testCheckOracleToRevokeHatFromWearerInGoodStanding() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);
        bytes4 select0r = 0xbd683872; // TODO: do not hardcode selector

        // expectEmit WearerStatus - should not be wearing, in good standing
        vm.expectEmit(false, false, false, true);
        emit WearerStatus(secondHatId, secondWearer, true, true);

        // mock calls to Oracle contract to return (true, true)
        vm.mockCall(
            address(_oracle),
            abi.encodeWithSelector(select0r),
            abi.encode(true, true)
        );

        // 5-3a. call getHatStatus to revoke
        hats.getHatWearerStatus(secondHatId, secondWearer);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertTrue(hats.isInGoodStanding(secondWearer, secondHatId));

        // assert hatSupply is decremented
        assertEq(hats.hatSupply(secondHatId), --hatSupply);
    }

    function testCheckOracleToRevokeHatFromWearerInBadStanding() public {
        uint32 hatSupply = hats.hatSupply(secondHatId);
        bytes4 select0r = 0xbd683872; // TODO: do not hardcode selector

        // expectEmit WearerStatus - should not be wearing, in bad standing
        vm.expectEmit(false, false, false, true);
        emit WearerStatus(secondHatId, secondWearer, true, false);

        // mock calls to Oracle contract to return (true, false)
        vm.mockCall(
            address(_oracle),
            abi.encodeWithSelector(select0r),
            abi.encode(true, false)
        );

        // 5-3b. call getHatStatus to revoke
        hats.getHatWearerStatus(secondHatId, secondWearer);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
        assertFalse(hats.isInGoodStanding(secondWearer, secondHatId));

        // assert hatSupply is decremented
        assertEq(hats.hatSupply(secondHatId), --hatSupply);
    }
}

contract RenounceHatsTest is TestSetup2 {
    function testRenounceHat() public {
        // expectEmit HatRenounced
        vm.expectEmit(false, false, false, true);
        emit HatRenounced(secondHatId, secondWearer);

        //  6-2. renounce hat from wearer2
        vm.prank(address(secondWearer));
        hats.renounceHat(secondHatId);
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
    }

    // TODO: update to best practice:
    // vm.expectRevert(hats.NotHatWearer.selector);
    // rename function to testCannotRenounceHatAsNonWearer()
    function testFailToRenounceHatAsNonWearer() public {
        //  6-1. attempt to renounce from admin / other wallet
        vm.prank(address(nonWearer));
        hats.renounceHat(secondHatId);
    }
}

contract ConditionsSetHatsTest is TestSetup2 {
    function testDeactivateHat() public {
        // confirm second hat is active
        assertTrue(hats.isActive(secondHatId));
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));

        // expectEmit HatStatusChanged to false
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, false);

        // 7-2. change Hat Status true->false via setHatStatus
        vm.prank(address(_conditions));
        hats.setHatStatus(secondHatId, false);
        assertFalse(hats.isActive(secondHatId));
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
    }

    // TODO: update to best practice:
    // vm.expectRevert(hats.NotHatConditions.selector);
    // rename function to testCannotDeactivateHatAsNonWearer()
    function testFailToDeactivateHatAsNonWearer() public {
        // 7-1. attempt to change Hat Status hat from wearer / other wallet / admin, should revert
        vm.prank(address(nonWearer));
        hats.setHatStatus(secondHatId, false);
    }

    // function testFailFunctionCallsOnDeactivatedHat() public {
    //     // change Hat Status true->false via setHatStatus
    //     vm.prank(address(_conditions));
    //     hats.setHatStatus(secondHatId, false);
    //     assertFalse(hats.isActive(secondHatId));

    //     // TODO: are there any functions in Hats.sol where we need to check if the hat is active
    //     // before allowing the function to be called?
    //     // 7-3. call various functions in deactivated state again as wearer / other wallet / admin, should revert
    //     // ...
    // }

    function testActivateDeactivatedHat() public {
        // change Hat Status true->false via setHatStatus
        vm.prank(address(_conditions));
        hats.setHatStatus(secondHatId, false);

        // expectEmit HatStatusChanged to true
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, true);

        // changeHatStatus false->true via setHatStatus
        vm.prank(address(_conditions));
        hats.setHatStatus(secondHatId, true);
        assertTrue(hats.isActive(secondHatId));
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));
    }

    // TODO: update to best practice:
    // vm.expectRevert(hats.NotHatConditions.selector);
    // rename function to testCannotActivateDeactivatedHatAsNonWearer()
    function testFailToActivateDeactivatedHatAsNonWearer() public {
        // change Hat Status true->false via setHatStatus
        vm.prank(address(_conditions));
        hats.setHatStatus(secondHatId, false);

        // 8-1. attempt to changeHatStatus hat from wearer / other wallet / admin
        vm.prank(address(nonWearer));
        hats.setHatStatus(secondHatId, true);
    }
}

contract ConditionsGetHatsTest is TestSetup2 {
    // TODO: should getHatStatus fail in a different way when the Conditions contract doesn't have the function?
    // TODO: update to best practice with specific expectRevert
    function testFailGetHatStatusNoFunctionInConditionsContract() public {
        hats.getHatStatus(secondHatId);
    }

    function testCheckConditionsToDeactivateHat() public {
        // expectEmit HatStatusChanged to false
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, false);
        
        // mock getHatStatus calls to Conditions contract to return false
        vm.mockCall(
            address(_conditions),
            abi.encodeWithSelector(hats.getHatStatus.selector),
            abi.encode(false)
        );

        // call getHatStatus to deactivate
        hats.getHatStatus(secondHatId);
        assertFalse(hats.isActive(secondHatId));
        assertFalse(hats.isWearerOfHat(secondWearer, secondHatId));
    }

    function testCheckConditionsToActivateDeactivatedHat() public {
        // change Hat Status true->false via setHatStatus
        vm.prank(address(_conditions));
        hats.setHatStatus(secondHatId, false);

        // expectEmit HatStatusChanged to true
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, true);
        
        // mock getHatStatus calls to Conditions contract to return true
        vm.mockCall(
            address(_conditions),
            abi.encodeWithSelector(hats.getHatStatus.selector),
            abi.encode(true)
        );

        // call getHatStatus to activate
        hats.getHatStatus(secondHatId);
        assertTrue(hats.isActive(secondHatId));
        assertTrue(hats.isWearerOfHat(secondWearer, secondHatId));
    }
}