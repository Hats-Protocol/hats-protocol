// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";

abstract contract TestVariables {
    Hats hats;

    address internal topHatWearer;
    address internal secondWearer;
    address internal thirdWearer;
    address internal fourthWearer;
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
    event HatRenounced(uint256 hatId, address wearer);
    event WearerStatus(
        uint256 hatId,
        address wearer,
        bool revoke,
        bool wearerStanding
    );
    event HatStatusChanged(uint256 hatId, bool newStatus);
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    error HatNotActive();
    error NotAdmin(address _user, uint256 _hatId);
    error AllHatsWorn();
    error AlreadyWearingHat();
    error NoApprovalsNeeded();
    error OnlyAdminsCanTransfer();
    error NotHatWearer();
    error NotHatConditions();
    error NotHatOracle();
    error BatchArrayLengthMismatch();
    error SafeTransfersNotNecessary();
    error MaxTreeDepthReached();
}

abstract contract TestSetup is Test, TestVariables {
    function setUp() public virtual {
        setUpVariables();
        // instantiate Hats contract
        hats = new Hats();

        // create TopHat
        createTopHat();
    }

    function setUpVariables() internal {
        // set variables: addresses
        topHatWearer = address(1);
        secondWearer = address(2);
        thirdWearer = address(3);
        fourthWearer = address(4);
        nonWearer = address(100);

        // set variables: Hat parameters
        _maxSupply = 1;
        _oracle = address(555);
        _conditions = address(333);
    }

    function createTopHat() internal {
        // create TopHat
        topHatId = hats.mintTopHat(topHatWearer);
    }

    /// @dev assumes a tophat has already been created
    function createHatsBranch(uint256 _length)
        internal
        returns (uint256[] memory ids, address[] memory wearers)
    {
        uint256 id;
        address wearer;
        uint256 admin;
        address adminWearer;

        ids = new uint256[](_length);
        wearers = new address[](_length);

        for (uint256 i = 0; i < _length; ++i) {
            admin = (i == 0) ? topHatId : ids[i - 1];

            adminWearer = (i == 0) ? topHatWearer : wearers[i - 1];

            // create ith hat from the admin
            vm.prank(adminWearer);

            id = hats.createHat(
                admin,
                string.concat("hat ", vm.toString(i + 2)),
                _maxSupply,
                _oracle,
                _conditions
            );
            ids[i] = id;

            // mint ith hat from the admin, to the ith wearer
            vm.prank(adminWearer);
            wearer = address(uint160(i));
            hats.mintHat(id, wearer);

            wearers[i] = wearer;
        }
    }
}

// in addition to TestSetup, TestSetup2 creates and mints a second hat
abstract contract TestSetup2 is TestSetup {
     function setUp() public override {
        
        // expand on TestSetup
        super.setUp();
        
        // create second Hat
        vm.prank(topHatWearer);
        secondHatId = hats.createHat(
            topHatId,
            "second hat",
            2, // maxSupply
            _oracle,
            _conditions
        );

        // mint second hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);
    }
}
