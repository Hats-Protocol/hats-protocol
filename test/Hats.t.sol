// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";

contract HatsTest is Test {
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

    function testExample() public {
        assertTrue(true);
    }

    // function testTopHatCreated() public {
    //     topHatId = test.mintTopHat(topHatWearer);
    //     console2.log(topHatId);

    //     bool topHatTest = test.isTopHat(topHatId);
    //     console2.log(topHatTest);

    //     bool wearerTest = test.isWearerOfHat(topHatWearer, topHatId);
    //     console2.log(wearerTest);

    //     bool notWearerTest = test.isWearerOfHat(nonWearer, topHatId);
    //     console2.log(!notWearerTest);

    //     bool activeTest = test.isActive(topHatId);
    //     console2.log(activeTest);
    // }

    // function testHatCreated() public {
    //     topHatId = test.mintTopHat(topHatWearer);
    //     vm.prank(address(topHatWearer));
    //     test.createHat(topHatId, _details, _maxSupply, _oracle, _conditions);
    // }

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
        // vm.prank(address(secondWearer));
        // test.mintHat(fourthHatId, address(4));
    }

    /*
    `forge test -vvv` is currently returning the following error / traces
    PROBLEM is on line 129, where the second Hat (id: 27065258958819196981364933114703301105956039517941121592357921226752) has an `active` value of false.
    During the createHat function for the second hat, it has an `active` value of true (see line 122).

    [FAIL. Reason: Arithmetic over/underflow] testNotTopHatAdminCreated() (gas: 269679)
    Logs:
    _isActive: function start, true
    _isActive: other return data, true
    _isActive: function start, false
    _isActive: other return data, false
    _isActive: function start, false
    _isActive: other return data, false

    Traces:
    [269679] HatsTest::testNotTopHatAdminCreated()
        ├─ [100923] Hats::mintTopHat(0x1000000000000000000000000000000000000000)
        │   ├─ emit HatCreated(id: 26959946667150639794667015087019630673637144422540572481103610249216, details: "", maxSupply: 1, oracle: 0x0000000000000000000000000000000000000000, conditions: 0x0000000000000000000000000000000000000000)
        │   ├─ emit TransferSingle(operator: HatsTest: [0xb4c79dab8f259c7aee6e5b2aa729821864227e84], from: 0x0000000000000000000000000000000000000000, to: 0x1000000000000000000000000000000000000000, id: 26959946667150639794667015087019630673637144422540572481103610249216, amount: 1)
        │   └─ ← 26959946667150639794667015087019630673637144422540572481103610249216
        ├─ [0] VM::prank(0x1000000000000000000000000000000000000000)
        │   └─ ← ()
        ├─ [80782] Hats::createHat(26959946667150639794667015087019630673637144422540572481103610249216, "test details", 1, 0x0010000000000000000000000000000000000000, 0x0001000000000000000000000000000000000000)
        │   ├─ [0] console::log("_isActive: function start", true) [staticcall]
        │   │   └─ ← ()
        │   ├─ [0] 0x0000…0000::getHatStatus(26959946667150639794667015087019630673637144422540572481103610249216) [staticcall]
        │   │   └─ ← ()
        │   ├─ [0] console::log("_isActive: other return data", true) [staticcall]
        │   │   └─ ← ()
        │   ├─ emit HatCreated(id: 27065258958819196981364933114703301105956039517941121592357921226752, details: "test details", maxSupply: 1, oracle: 0x0010000000000000000000000000000000000000, conditions: 0x0001000000000000000000000000000000000000)
        │   └─ ← 27065258958819196981364933114703301105956039517941121592357921226752
        ├─ [0] VM::prank(0x1000000000000000000000000000000000000000)
        │   └─ ← ()
        ├─ [23190] Hats::mintHat(27065258958819196981364933114703301105956039517941121592357921226752, 0x2000000000000000000000000000000000000000)
        │   ├─ [0] console::log("_isActive: function start", false) [staticcall]
        │   │   └─ ← ()
        │   ├─ [0] 0x0000…0000::getHatStatus(26959946667150639794667015087019630673637144422540572481103610249215) [staticcall]
        │   │   └─ ← ()
        │   ├─ [0] console::log("_isActive: other return data", false) [staticcall]
        │   │   └─ ← ()
        │   ├─ [0] console::log("_isActive: function start", false) [staticcall]
        │   │   └─ ← ()
        │   ├─ [0] 0x0000…0000::getHatStatus(105312291668557186697918027683670432318895095400549111254310977535) [staticcall]
        │   │   └─ ← ()
        │   ├─ [0] console::log("_isActive: other return data", false) [staticcall]
        │   │   └─ ← ()
        │   └─ ← "Arithmetic over/underflow"
        └─ ← "Arithmetic over/underflow"
    */
}
