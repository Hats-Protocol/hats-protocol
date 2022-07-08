// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";
// import "../src/HatsConditions/SampleHatsConditions.sol";

abstract contract TestVariables {
    Hats test;
    uint256 testNumber;
    address internal topHatWearer;
    address internal secondWearer;
    address internal thirdWearer;
    address internal nonWearer;

    uint256 internal _admin;
    string internal _details;
    uint32 internal _maxSupply;
    address internal _oracle;
    address internal _conditions;

    uint256 internal topHatId;
    uint256 internal secondHatId;
    uint256 internal thirdHatId;

    event HatCreated(
        uint256 id,
        string details,
        uint32 maxSupply,
        address oracle,
        address conditions
    );
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );
    event HatRenounced(uint256 hatId, address wearer);
    event HatStatusChanged(uint256 hatId, bool newStatus);
}

// contract HatsRevokeTests is Test, TestVariables {
//     function setUp() public {
//         testNumber = 42;
//         topHatWearer = address(1);
//         secondWearer = address(2);
//         thirdWearer = address(3);
//         nonWearer = address(9);

//         // instantiate Hats contract
//         test = new Hats();

//         // set variables
//         //_admin = 1;
//         _details = "test details";
//         _maxSupply = 1;
//         _oracle = address(555);
//         _conditions = address(333);
//     }

//     function testTopHatCreated1() public {
//         topHatId = test.mintTopHat(topHatWearer);

//         assertTrue(test.isTopHat(topHatId));
//         assertEq(2**224, topHatId);
//     }
// }

contract CreateHatsTest is Test, TestVariables {
    function setUp() public {
        testNumber = 42;
        topHatWearer = address(1);
        secondWearer = address(2);
        thirdWearer = address(3);
        nonWearer = address(9);

        // instantiate Hats contract
        test = new Hats();

        // set variables
        //_admin = 1;
        _details = "test details";
        _maxSupply = 1;
        _oracle = address(555);
        _conditions = address(333);
    }

    function testTopHatCreated() public {
        vm.expectEmit(false, false, false, true);
        emit HatCreated(2**224, "", 1, address(0), address(0));

        topHatId = test.mintTopHat(topHatWearer);

        assertTrue(test.isTopHat(topHatId));
        assertEq(2**224, topHatId);
    }

    function testTopHatMinted() public {
        vm.expectEmit(true, true, true, true);

        emit TransferSingle(address(this), address(0), topHatWearer, 2**224, 1);

        topHatId = test.mintTopHat(topHatWearer);

        assertTrue(test.isWearerOfHat(topHatWearer, topHatId));
        assertFalse(test.isWearerOfHat(nonWearer, topHatId));
    }

    function testHatCreated() public {
        // get prelim values
        (, , , , , uint8 lastHatId, ) = test.viewHat(topHatId);

        topHatId = test.mintTopHat(topHatWearer);
        vm.prank(address(topHatWearer));
        test.createHat(topHatId, _details, _maxSupply, _oracle, _conditions);

        // assert admin's lastHatId is incremented
        (, , , , , uint8 lastHatIdPost, ) = test.viewHat(topHatId);
        assertEq(++lastHatId, lastHatIdPost);
    }

    function testNotTopHatAdminCreated() public {
        // mint TopHat
        topHatId = test.mintTopHat(topHatWearer);

        // create a second Hat with TopHat as admin
        vm.prank(address(topHatWearer));
        secondHatId = test.createHat(
            topHatId,
            "second hat",
            _maxSupply,
            _oracle,
            _conditions
        );

        // mint second Hat to another wearer
        vm.prank(address(topHatWearer));
        test.mintHat(secondHatId, secondWearer);

        // create a third Hat with secondHat as admin
        vm.prank(address(secondWearer));
        thirdHatId = test.createHat(
            secondHatId,
            "third hat",
            _maxSupply,
            _oracle,
            _conditions
        );

        // mint third Hat to another wearer
        vm.prank(address(secondWearer));
        test.mintHat(thirdHatId, thirdWearer);

        // create a fourth Hat with secondHat as admin
        vm.prank(address(secondWearer));
        uint256 fourthHatId = test.createHat(
            secondHatId,
            "fourth hat",
            _maxSupply,
            _oracle,
            _conditions
        );

        // mint fourth Hat to another wearer
        vm.prank(address(secondWearer));
        test.mintHat(fourthHatId, address(4));
    }
}

contract MintHatsTest is Test, TestVariables {
    function setUp() public {
        topHatWearer = address(1);
        secondWearer = address(2);
        thirdWearer = address(3);
        nonWearer = address(9);

        // instantiate Hats contract
        test = new Hats();

        // create new Hat
        topHatId = test.mintTopHat(topHatWearer);

        vm.prank(topHatWearer);
        secondHatId = test.createHat(
            topHatId,
            "second hat",
            2, // maxSupply
            _oracle,
            _conditions
        );

        // set variables
        _maxSupply = 1;
        _oracle = address(555);
        _conditions = address(333);
    }

    function testMintHat() public {
        // get initial values
        uint256 secondWearerBalance = test.balanceOf(secondWearer, secondHatId);
        uint32 hatSupply = test.hatSupply(secondHatId);

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
        test.mintHat(secondHatId, secondWearer);

        // assert balance = 1
        assertEq(
            test.balanceOf(secondWearer, secondHatId),
            ++secondWearerBalance
        );

        // assert iswearer
        assertTrue(test.isWearerOfHat(secondWearer, secondHatId));

        // assert hatSupply is incremented
        assertEq(test.hatSupply(secondHatId), ++hatSupply);
    }

    function testMintAnotherHat() public {
        // mint hat
        // mint another of same id to a new wearer
        // assert balance is incremented by 1
        // assert isWearer is true
        // assert hatSupply is incremented
        // assert admin's lastHatId is properly incremented
    }

    function testMint2HatsToSameWearer() public {
        // mint hat
        // mint another hat of same id to same wearer
        // assert wearer balance is only incremented by 1
        // assert isWearer is true
        // what happens to the hatSupply?
    }

    function testMintHatErrorNotAdmin() public {
        // try to mint hat from a non-wearer
        // assert NotAdmin error thrown
        // assert hatSupply is not incremented
        // assert wearer balance is unchanged
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

contract RenounceHatsTest is Test, TestVariables {
    function setUp() public {
        // set variables: addresses
        topHatWearer = address(1);
        secondWearer = address(2);
        thirdWearer = address(3);
        nonWearer = address(9);

        // set variables: Hat parameters
        _maxSupply = 1;
        _oracle = address(555);
        _conditions = address(333);

        // instantiate Hats contract
        test = new Hats();

        // create TopHat
        topHatId = test.mintTopHat(topHatWearer);

        // create second Hat
        vm.prank(topHatWearer);
        secondHatId = test.createHat(
            topHatId,
            "second hat",
            2, // maxSupply
            _oracle,
            _conditions
        );
       
        // mint second hat
        vm.prank(address(topHatWearer));
        test.mintHat(secondHatId, secondWearer);
    }

    function testRenounceHat() public {
        // expectEmit HatRenounced
        vm.expectEmit(false, false, false, true);
        emit HatRenounced(secondHatId, secondWearer);

        //  6-2. renounce hat from wearer2
        vm.prank(address(secondWearer));
        test.renounceHat(secondHatId);
        assertFalse(test.isWearerOfHat(secondWearer, secondHatId));
    }

    // TODO: update to best practice: 
    // vm.expectRevert(test.NotHatWearer.selector);
    // rename function to testCannotRenounceHatAsNonWearer()
    function testFailToRenounceHatByNonWearer() public {
        //  6-1. attempt to renounce from admin / other wallet
        vm.prank(address(nonWearer));
        test.renounceHat(secondHatId);
    }
}

contract DeactivateHatsTest is Test, TestVariables {
    function setUp() public {
        // set variables: addresses
        topHatWearer = address(1);
        secondWearer = address(2);
        thirdWearer = address(3);
        nonWearer = address(9);

        // set variables: Hat parameters
        _maxSupply = 1;
        _oracle = address(555);
        _conditions = address(333);

        // instantiate Hats contract
        test = new Hats();

        // create TopHat
        topHatId = test.mintTopHat(topHatWearer);

        // create second Hat
        vm.prank(topHatWearer);
        secondHatId = test.createHat(
            topHatId,
            "second hat",
            2, // maxSupply
            _oracle,
            _conditions
        );
       
        // mint second hat
        vm.prank(address(topHatWearer));
        test.mintHat(secondHatId, secondWearer);
    }

    function testDeactivateHat() public {
        // confirm second hat is active
        assertTrue(test.isActive(secondHatId));
        assertTrue(test.isWearerOfHat(secondWearer, secondHatId));
        
        // expectEmit HatStatusChanged to false
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, false);
        
        // 7-2. changeHatStatus true->false via setHatStatus
        vm.prank(address(_conditions));
        test.setHatStatus(secondHatId, false);
        assertFalse(test.isActive(secondHatId));
        assertFalse(test.isWearerOfHat(secondWearer, secondHatId));
    }

    // TODO: update to best practice: 
    // vm.expectRevert(test.NotHatConditions.selector);
    // rename function to testCannotCallFunctionsOnDeactivatedHat()
    function testFailToDeactivateHatByNonWearer() public {
        // 7-1. attempt to changeHatStatus hat from wearer / other wallet / admin, should revert
        vm.prank(address(nonWearer));
        test.setHatStatus(secondHatId, false);
    }

    // function testFailFunctionCallsOnDeactivatedHat() public {
    //     // changeHatStatus true->false via setHatStatus
    //     vm.prank(address(_conditions));
    //     test.setHatStatus(secondHatId, false);
    //     assertFalse(test.isActive(secondHatId));

    //     // TODO: are there any functions in Hats.sol where we need to check if the hat is active 
    //     // before allowing the function to be called?
    //     // 7-3. call various functions in deactivated state again as wearer / other wallet / admin, should revert
    //     // ...
    // }

    function testActivateDeactivatedHat() public {
        // changeHatStatus true->false via setHatStatus
        vm.prank(address(_conditions));
        test.setHatStatus(secondHatId, false);

        // expectEmit HatStatusChanged to true
        vm.expectEmit(false, false, false, true);
        emit HatStatusChanged(secondHatId, true);

        // changeHatStatus false->true via setHatStatus
        vm.prank(address(_conditions));
        test.setHatStatus(secondHatId, true);
        assertTrue(test.isActive(secondHatId));
        assertTrue(test.isWearerOfHat(secondWearer, secondHatId));
    }

    // TODO: update to best practice: 
    // vm.expectRevert(test.NotHatConditions.selector);
    // rename function to testCannotActivateDeactivatedHat()
    function testFailToActivateDeactivatedHatByNonWearer() public {
        // changeHatStatus true->false via setHatStatus
        vm.prank(address(_conditions));
        test.setHatStatus(secondHatId, false);

        // 8-1. attempt to changeHatStatus hat from wearer / other wallet / admin
        vm.prank(address(nonWearer));
        test.setHatStatus(secondHatId, true);
    }
}