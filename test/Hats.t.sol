// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";

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
}

contract HatsRevokeTests is Test, TestVariables {
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

    function testTopHatCreated1() public {
        topHatId = test.mintTopHat(topHatWearer);

        assertTrue(test.isTopHat(topHatId));
        assertEq(2**224, topHatId);
    }
}

contract HatsTest is Test, TestVariables {
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
        topHatId = test.mintTopHat(topHatWearer);
        vm.prank(address(topHatWearer));
        test.createHat(topHatId, _details, _maxSupply, _oracle, _conditions);
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
