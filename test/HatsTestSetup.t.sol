// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";
import "../src/Interfaces/HatsEvents.sol";
import "../src/Interfaces/HatsErrors.sol";

abstract contract TestVariables is HatsEvents, HatsErrors {
    Hats hats;

    address internal topHatWearer;
    address internal secondWearer;
    address internal thirdWearer;
    address internal fourthWearer;
    address internal nonWearer;

    uint256 internal _admin;
    string internal _details;
    uint32 internal _maxSupply;
    address internal _eligibility;
    address internal _toggle;
    string internal _baseImageURI;

    string internal topHatImageURI;
    string internal secondHatImageURI;
    string internal thirdHatImageURI;

    uint256 internal topHatId;
    uint256 internal secondHatId;
    uint256 internal thirdHatId;

    string internal name;

    uint256[] adminsBatch;
    string[] detailsBatch;
    uint32[] maxSuppliesBatch;
    address[] eligibilityModulesBatch;
    address[] toggleModulesBatch;
    bool[] mutablesBatch;
    string[] imageURIsBatch;

    string retdetails;
    uint32 retmaxSupply;
    uint32 retsupply;
    address reteligibility;
    address rettoggle;
    string retimageURI;
    uint16 retlastHatId;
    bool retmutable;
    bool retactive;

    bool active_;
    bool mutable_;

    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount
    );

    error InvalidChildHat();
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
        _eligibility = address(555);
        _toggle = address(333);

        topHatImageURI = "http://www.tophat.com/";
        secondHatImageURI = "http://www.second.com/";
        thirdHatImageURI = "http://www.third.com/";

        name = "Hats Test Contract";
    }

    function createTopHat() internal {
        // create TopHat
        topHatId = hats.mintTopHat(topHatWearer, "tophat", "http://www.tophat.com/");
    }

    /// @dev assumes a tophat has already been created
    /// @dev doesn't apply any imageURIs
    function createHatsBranch(uint256 _length, uint256 _topHatId, address _topHatWearer, bool _mutable)
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
            admin = (i == 0) ? _topHatId : ids[i - 1];

            adminWearer = (i == 0) ? _topHatWearer : wearers[i - 1];

            // create ith hat from the admin
            vm.prank(adminWearer);

            id = hats.createHat(
                admin,
                string.concat("hat ", vm.toString(i + 2)),
                _maxSupply,
                _eligibility,
                _toggle,
                _mutable,
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
    function setUp() public virtual override {
        // expand on TestSetup
        super.setUp();

        // create second Hat
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

        // mint second hat
        vm.prank(address(topHatWearer));
        hats.mintHat(secondHatId, secondWearer);
    }
}

abstract contract TestSetupMutable is TestSetup {
    function setUp() public virtual override {
        // expand on TestSetup
        super.setUp();

        // create a mutable Hat
        vm.prank(topHatWearer);
        secondHatId = hats.createHat(
            topHatId,
            "mutable hat",
            2, // maxSupply
            _eligibility,
            _toggle,
            true,
            secondHatImageURI
        );
    }
}

abstract contract TestSetupBatch is TestSetup {
    function setUp() public override {
        // expand on TestSetup
        super.setUp();

        // create empty batch create arrays
    }
}
