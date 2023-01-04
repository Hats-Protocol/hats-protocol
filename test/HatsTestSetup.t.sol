// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Hats.sol";
import "../src/Interfaces/HatsEvents.sol";
import "../src/Interfaces/HatsErrors.sol";
import "../src/Diamond/Facets/ERC1155Facet.sol";
import "../src/Diamond/Facets/HatsCoreFacet.sol";
import "../src/Diamond/Facets/MutableHatsFacet.sol";
import "../src/Diamond/Facets/ViewHatsFacet.sol";
import "../src/Diamond/Lib/LibHatsDiamond.sol";
import "../src/Diamond/HatsDiamond.sol";

abstract contract TestVariables is HatsEvents, HatsErrors {
    HatsDiamond hatsDiamond;
    address hats;

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
    uint8 retlastHatId;
    bool retmutable;
    bool retactive;

    bool active_;
    bool mutable_;

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    bytes4[] selectors0;
    bytes4[] selectors1;
    bytes4[] selectors2;
    bytes4[] selectors3;
}

abstract contract TestSetup is Test, TestVariables {
    function setUp() public virtual {
        setUpVariables();
        // instantiate Hats contract
        hats = deployHatsDiamond();

        // create TopHat
        topHatId = createTopHat();
    }

    function deployHatsDiamond() internal returns (address hats_) {
        // deploy facets and track addresses
        ERC1155Facet erc1155Facet = new ERC1155Facet();
        HatsCoreFacet hatsCoreFacet = new HatsCoreFacet();
        MutableHatsFacet mutableHatsFacet = new MutableHatsFacet();
        ViewHatsFacet viewHatsFacet = new ViewHatsFacet();

        // set up diamond cut object

        // ERC1155 facet cut setup
        selectors0 = new bytes4[](6);

        selectors0 = [
            ERC1155Facet.balanceOfBatch.selector,
            ERC1155Facet.balanceOf.selector,
            ERC1155Facet.safeBatchTransferFrom.selector,
            ERC1155Facet.safeTransferFrom.selector,
            ERC1155Facet.setApprovalForAll.selector,
            ERC1155Facet.uri.selector
        ];

        LibHatsDiamond.FacetCut memory erc1155Cut = LibHatsDiamond.FacetCut(
            address(erc1155Facet),
            LibHatsDiamond.FacetCutAction.Add,
            selectors0
        );

        selectors1 = new bytes4[](11);

        selectors1 = [
            HatsCoreFacet.checkHatStatus.selector,
            HatsCoreFacet.checkHatWearerStatus.selector,
            HatsCoreFacet.createHat.selector,
            HatsCoreFacet.getNextId.selector,
            HatsCoreFacet.mintHat.selector,
            HatsCoreFacet.mintTopHat.selector,
            HatsCoreFacet.renounceHat.selector,
            HatsCoreFacet.setHatStatus.selector,
            HatsCoreFacet.setHatWearerStatus.selector,
            HatsCoreFacet.transferHat.selector,
            HatsCoreFacet.hatSupply.selector
        ];

        LibHatsDiamond.FacetCut memory hatsCoreCut = LibHatsDiamond.FacetCut(
            address(hatsCoreFacet),
            LibHatsDiamond.FacetCutAction.Add,
            selectors1
        );

        selectors2 = new bytes4[](6);
        selectors2 = [
            MutableHatsFacet.changeHatDetails.selector,
            MutableHatsFacet.changeHatEligibility.selector,
            MutableHatsFacet.changeHatImageURI.selector,
            MutableHatsFacet.changeHatMaxSupply.selector,
            MutableHatsFacet.changeHatToggle.selector,
            MutableHatsFacet.makeHatImmutable.selector
        ];

        LibHatsDiamond.FacetCut memory mutableHatsCut = LibHatsDiamond.FacetCut(
            address(mutableHatsFacet),
            LibHatsDiamond.FacetCutAction.Add,
            selectors2
        );

        selectors3 = new bytes4[](14);
        selectors3 = [
            ViewHatsFacet.isActive.selector,
            ViewHatsFacet.isAdminOfHat.selector,
            ViewHatsFacet.isEligible.selector,
            ViewHatsFacet.isInGoodStanding.selector,
            ViewHatsFacet.isMutable.selector,
            ViewHatsFacet.isWearerOfHat.selector,
            ViewHatsFacet.viewHat.selector,
            ViewHatsFacet.name.selector,
            ViewHatsFacet.isTopHat.selector,
            ViewHatsFacet.buildHatId.selector,
            ViewHatsFacet.getHatLevel.selector,
            ViewHatsFacet.getAdminAtLevel.selector,
            ViewHatsFacet.getTophatDomain.selector,
            ViewHatsFacet.getImageURIForHat.selector
        ];

        LibHatsDiamond.FacetCut memory viewHatsCut = LibHatsDiamond.FacetCut(
            address(viewHatsFacet),
            LibHatsDiamond.FacetCutAction.Add,
            selectors3
        );

        // put them all together
        LibHatsDiamond.FacetCut[] memory cuts = new LibHatsDiamond.FacetCut[](
            4
        );
        cuts[0] = erc1155Cut;
        cuts[1] = hatsCoreCut;
        cuts[2] = mutableHatsCut;
        cuts[3] = viewHatsCut;

        // deploy diamond
        hatsDiamond = new HatsDiamond(name, _baseImageURI, cuts);
        hats_ = address(hatsDiamond);
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

    function createTopHat() internal returns (uint256 id) {
        // console2.log("A");
        // emit log_string(vm.toString(HatsCoreFacet.mintTopHat.selector));
        // create TopHat
        id = HatsCoreFacet(hats).mintTopHat(
            topHatWearer,
            "tophat",
            "http://www.tophat.com/"
        );
    }

    /// @dev assumes a tophat has already been created
    /// @dev doesn't apply any imageURIs
    function createHatsBranch(
        uint256 _length,
        uint256 _topHatId,
        address _topHatWearer,
        bool _mutable
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

            id = HatsCoreFacet(hats).createHat(
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
            HatsCoreFacet(hats).mintHat(id, wearer);

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
        secondHatId = HatsCoreFacet(hats).createHat(
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
        HatsCoreFacet(hats).mintHat(secondHatId, secondWearer);
    }
}

abstract contract TestSetupBatch is TestSetup {
    function setUp() public override {
        // expand on TestSetup
        super.setUp();

        // create empty batch create arrays
    }
}
