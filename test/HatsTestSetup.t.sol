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
    address internal _wearerCriteria;
    address internal _conditions;
    string internal _baseImageURI;

    string internal topHatImageURI;
    string internal secondHatImageURI;
    string internal thirdHatImageURI;

    uint256 internal topHatId;
    uint256 internal secondHatId;
    uint256 internal thirdHatId;

    string internal name;

    event HatCreated(
        uint256 id,
        string details,
        uint32 maxSupply,
        address wearerCriteria,
        address conditions,
        string imageURI
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
}

abstract contract TestSetup is Test, TestVariables {
    function setUp() public virtual {
        setUpVariables();
        // instantiate Hats contract
        hats = new Hats(name, _baseImageURI);

        // create TopHat
        createTopHat();
    }

    function setUpVariables() internal {
        // set variables: deploy
        _baseImageURI = "https://www.images.hats.work/";

        // set variables: addresses
        topHatWearer = address(1);
        secondWearer = address(2);
        thirdWearer = address(3);
        fourthWearer = address(4);
        nonWearer = address(100);

        // set variables: Hat parameters
        _maxSupply = 1;
        _wearerCriteria = address(555);
        _conditions = address(333);

        topHatImageURI = "http://www.tophat.com/";
        secondHatImageURI = "http://www.second.com/";
        thirdHatImageURI = "http://www.third.com/";

        name = "Hats Test Contract";
    }

    function createTopHat() internal {
        // create TopHat
        topHatId = hats.mintTopHat(topHatWearer, "http://www.tophat.com/");
    }

    /// @dev assumes a tophat has already been created
    /// @dev doesn't apply any imageURIs
    function createHatsBranch(
        uint256 _length,
        uint256 _topHatId,
        address _topHatWearer
    ) internal returns (uint256[] memory ids, address[] memory wearers) {
        uint256 id;
        address wearer;
        uint256 admin;
        address adminWearer;

        ids = new uint256[](_length);
        wearers = new address[](_length);

        for (uint256 i = 0; i < _length; ++i) {
            admin = (i == 0) ? _topHatId : ids[i - 1];

            adminWearer = (i == 0) ? _topHatWearer : wearers[i - 1];

            // create ith hat from the admin
            vm.prank(adminWearer);

            id = hats.createHat(
                admin,
                string.concat("hat ", vm.toString(i + 2)),
                _maxSupply,
                _wearerCriteria,
                _conditions,
                "" // imageURI
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
            _wearerCriteria,
            _conditions,
            secondHatImageURI
        );

        // mint second hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);
    }
}
