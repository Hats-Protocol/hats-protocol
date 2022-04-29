pragma solidity >=0.8.0;

import "/ERC721.sol";
import "HatsConditions/IConditions.sol";
import "HatsOracles/IOracle.sol";
import "HatsEligibility/IHatsEligibility.sol";

interface IHats is ERC721 {
    // Hats Errors --------

    error NotHatOwner();

    error NotHatsEligility();

    error NotHatOracle();

    error NotHatConditions();

    error NotEligible();

    error offerNotActive();

    // Hats Data Types ----

    struct Hat {
        string name; // do we need to store this?
        string details; // do we need to store this?
        uint256 elgibilityThreshold;
        address wearer;
        address owner;
        address oracle;
        address conditions;
        bool active;
    }

    // do we need to store Hat wearing history on-chain?

    enum OfferStatus {
        Empty,
        Active,
        Accepted,
        Rejected,
        Withdrawn
    }

    struct Offer {
        uint256 hatRack;
        address submitter; // the prospective wearer
        uint256 amount; // the amount of eligibility "offered"
        OfferStatus status; // 0:Empty, 1:Active, 2:Accepted, 3:Rejected, 4:Withdrawn
    }

    // Hats Storage -------

    address public immutable eligibility;

    Hats[] private hats; // keeping private to avoid wearer conflict with ERC721.ownerOf
    mapping(bytes32 => Hat) private hatIds; // how do we handle unique hat IDs? (this is related to the namespace problem)

    Offers[] public offers;

    // Hats Events --------

    event HatCreated(
        string name,
        string details,
        uint256 eligibilityThreshold,
        address owner,
        address oracle,
        address conditions
    );

    event OfferSubmitted(uint256 hatId, address submitter, uint256 amount);

    event OfferAccepted(uint256 offerId);

    event HatRelinquished(uint256 hatId);

    event Ruling(uint256 hatId, bool ruling);

    event HatDeactivated(uint256 hatId);

    // Hats Functions -----

    function createHat(
        string _name, // encode as bytes32 ??
        string _details, // encode as bytes32 ??
        uint256 _eligibilityThreshold,
        address _owner,
        address _oracle,
        address _conditions
    ) public returns (uint256 hatId) {
        Hat memory hat;
        hat.name = _name;
        hat.details = _details;
        hat.eligibilityThreshold = _eligibilityThreshold;
        // hat.wearer initializes as 0 (the 0x address)
        hat.owner = _owner;
        hat.oracle = _oracle;
        hat.conditions = _conditions;
        hat.active = true;

        hats.push[hat];
        // may also need to add to mapping
    }

    function recordOffer(
        uint256 _hatId,
        address _submitter,
        uint256 _amount
    ) onlyHatsEligibility returns (uint256 offerId) {
        Offer memory offer;
        offer.hat = _hatId;
        offer.submitter = _submitter;
        offer.amount = _amount;

        offers.push(offer);
    }

    function acceptOffer(uint256 offerId) onlyHatOwner returns (bool) {
        Offer storage offer = offers[offerId];

        if (offer.status != 1) {
            revert(offerNotActive());
        }

        Hat storage hat = hats[offer.hat];

        // potentially need to check if hat is still active?

        // do we want to destroy any other offers on the same hat?
    }

    function mintHat(uint256 hatId, address wearer) internal returns (bool);

    function burnHat(uint256 hatId) internal returns (bool);

    function checkHatConditions(uint256 hatId) public returns (bool);

    function deactivateHat(uint256 hatId) onlyConditions returns (bool) {
        // do we also destroy any offers associated with this hat?
    }

    function requestOracleRuling(uint256 hatId) public returns (bool);

    function ruleOnHat(uint256 hatId, bool ruling) onlyOracle returns (bool);

    function recordRelinquishment(uint256 hatId, address wearer)
        onlyHatsEligibility
        returns (bool success, uint256 amount)
    {
        // changes hat.wearer to 0x and transfers NFT to 0x address
    }

    function unlockEligibility(uint256 hatId, address wearer)
        internal
        returns (bool);

    // Hats View Functions-

    function viewHat(uint256 _hatId)
        public
        view
        returns (
            string name,
            string details,
            uint256 eligibilityThreshold,
            address wearer,
            address owner,
            address oracle,
            address conditions
        )
    {
        // may not be necessary, but including for now to provide a way to read the properties of an unworn hat, especially for the wearer
        Hat memory hat = hats[hatId];
        name = hat.name;
        details = hat.details;
        eligibilityThreshold = hat.eligibilityThreshold;
        wearer = ownerOf(hatId);
        owner = hat.owner;
        oracle = hat.oracle;
        conditions = hat.conditions;
    }

    // Hats Modifiers -----

    modifier onlyHatsEligibility() {
        //
        require(msg.sender == eligibility, "must be HatsElgibility Contract");
        _;
    }

    modifier onlyHatOwner() {
        //
        _;
    }

    modifier onlyConditions() {
        //
        _;
    }

    modifier onlyOracle() {
        //
        _;
    }

    // ERC721 Functions ---

    mapping(tokenId => address) private owners;

    function ownerOf(uint256 tokenId) public view override returns (address) {
        // have this dynamically update based on Conditions and Eligibility
        address owner;
        if (ICONDITIONS.checkConditions() && IELIGIBILITY.checkEligibility()) {
            owner = owners[tokenId];
        } else owner = address(0);
        // but also include a separate function that fires a transfer event so that front ends can stay up to date
    }

    function tokenURI() public view override {}

    function playNiceWithFrontEnds(uint256 hatId) external returns (bool) {
        // check for ownerOf changes
        // if changed, fire transfer event
        if (hats[hatId].wearer != ownerOf(hatId)) {
            // how do we handle the case where there's a new wearer?
            // fire transfer event
        }

        // no need to actually do any transfering or state changes
    }
}
