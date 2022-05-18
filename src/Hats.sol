// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

import "solmate/tokens/ERC1155.sol";
import "./HatsConditions/IHatsConditions.sol";
import "./HatsOracles/IHatsOracle.sol";
import "./HatsEligibility/IHatsEligibility.sol";
import "utils/BASE64.sol";

contract Hats is ERC1155 {
    /*//////////////////////////////////////////////////////////////
                              HATS ERRORS
    //////////////////////////////////////////////////////////////*/

    // QUESTION should we add arguments to any of these errors?
    error NotOfferAccepter();
    error NotHatsEligibility();
    error NotHatOracle();
    error CannotRuleOnHat();
    error NotHatConditions();
    error CannotDeactivateHat();
    error NotEligible();
    error HatNotActive();
    error AllHatsFilled();
    error OfferNotActive();
    error NotOfferSubmitter();
    error TriggerAccountabilityFailed();
    error NoTransfersAllowed();

    /*//////////////////////////////////////////////////////////////
                              HATS DATA MODELS
    //////////////////////////////////////////////////////////////*/

    // TODO can probably figure out a way to pack all this stuff into fewer storage slots. Most of it doesn't change, anyways
    struct Hat {
        string name; // QUESTION do we need to store this?
        string details; // QUESTION do we need to store this?
        uint256 id; // will be used as the 1155 token ID
        uint256 maxSupply; // the max number of identical hats that can exist
        uint256 eligibilityThreshold; // the required amount from HatsEligibility
        address eligibility; // eligibility contract
        bytes20 owner; // can accept Offers to wear this hat; can convert to address via address(owner)
        bytes20 oracle; // rules on
        bytes20 conditions;
        bool active; // can be altered by conditions, via deactivateHat()
    }

    enum OfferStatus {
        Empty,
        Active,
        Accepted,
        Withdrawn
    }

    struct Offer {
        uint256 hat; // the hat to wear
        address submitter; // the prospective wearer
        uint256 amount; // the amount of eligibility "offered"; can be higher than the eligibility threshold
        OfferStatus status; // 0:Empty, 1:Active, 2:Accepted, 3:Withdrawn
    }

    /*//////////////////////////////////////////////////////////////
                              HATS STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public nextHatId; // initialized at 0
    uint256 public nextOfferId; // initialized at 0; QUESTION Or should this be some kind of concatenation w/ hatId so its easier to retrieve the hat from the offerId?

    // holding zone for inactive hats ("hat rack")
    address private constant HAT_RACK = address(0x4a15); // 0xhats :)

    // we don't need to pass data into ERC1155 mint or transfer functions
    bytes private constant EMPTY_DATA = "";

    Hat[] private hats; // can retrieve hat info via viewHat(hatId) or via uri(hatId);

    Offer[] public offers;

    mapping(uint256 => uint256) public hatSupply; // key: hatId => value: supply

    mapping(uint256 => mapping(address => bool)) hatWearers; // hatId => (wearer => true/false)

    // QUESTION do we need to store Hat wearing history on-chain? In other words, do other contracts need access to said history?

    /*//////////////////////////////////////////////////////////////
                              HATS EVENTS
    //////////////////////////////////////////////////////////////*/

    event HatCreated(
        string name,
        string details,
        uint256 id,
        uint256 maxSupply,
        uint256 eligibilityThreshold,
        address eligibility,
        bytes20 owner,
        bytes20 oracle,
        bytes20 conditions
    );

    event OfferSubmitted(
        uint256 hatId,
        address submitter,
        uint256 amount,
        uint256 offerId
    );

    event OfferAccepted(uint256 offerId); // QUESTION do we need this? In theory, the subgraph can know this from the 1155 transfer event

    event HatRelinquished(uint256 hatId, address wearer);

    event Ruling(uint256 hatId, address wearer, bool ruling);

    event HatDeactivated(uint256 hatId);

    // event HatSupplyChanged(uint256 hatId, uint256 newSupply);

    /*//////////////////////////////////////////////////////////////
                              HATS VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor() {
        // nextHatId = 0;
        // nextOfferId = 0;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS LOGIC
    //////////////////////////////////////////////////////////////*/

    function setAddressUp(address _target) public returns (uint256 hatId) {
        // check if already has first hat???
        // create hat
        // hat.owner = hat.id
        // mint hat to target
        // return hat.id
        // TODO
    }

    function setupAndCreateHat(params)
        public
        returns (uint256 firstHatId, uint256 hatId)
    {
        // setYourselfUp();
        // createHat(params);
        // TODO
    }

    function createHat(
        string memory _name, // encode as bytes32 ??
        string memory _details, // encode as bytes32 ??
        uint256 _maxSupply,
        uint256 _eligibilityThreshold,
        address _eligibility,
        bytes20 _owner,
        bytes20 _oracle,
        bytes20 _conditions
    ) public returns (uint256 hatId) {
        Hat memory hat;
        hat.name = _name;
        hat.details = _details;

        hatId = nextHatId; // QUESTION maybe saves an SLOAD??
        ++nextHatId; // increment the next Hat id

        hat.id = hatId;

        hat.maxSupply = _maxSupply;
        hat.eligibilityThreshold = _eligibilityThreshold;
        hat.eligibility = _eligibility;
        // hat.wearer initializes as 0 (the 0x address)

        // if _owner is 20 bytes, then hat.owner = setAddressUp()
        // if _owner is <20 bytes, then hat.owner = uint256(_owner) // hatId
        hat.owner = _owner;

        // if _oracle is 20 bytes, then hat.oracle = setAddressUp()
        // if _oracle is <20 bytes, then hat.oracle = uint256(_oracle) // hatId
        hat.oracle = _oracle;

        // if _conditions is 20 bytes, then hat.conditions = setAddressUp()
        // if _conditions is <20 bytes, then hat.conditions = uint256(_conditions) // hatId
        hat.conditions = _conditions;
        hat.active = true;

        hats.push(hat);
        // may also need to add to mapping

        emit HatCreated(
            _name,
            _details,
            hatId,
            _maxSupply,
            _eligibilityThreshold,
            _eligibility,
            _owner,
            _oracle,
            _conditions
        );
    }

    function recordOffer(
        uint256 _hatId,
        address _submitter,
        uint256 _amount
    ) external onlyHatsEligibility(_hatId) returns (uint256 offerId) {
        if (!isEligible(_submitter, _hatId)) {
            revert NotEligible();
        }

        offerId = nextOfferId;
        // increment next offer id
        ++nextOfferId;

        Offer memory offer;
        offer.hat = _hatId;
        offer.submitter = _submitter;
        offer.amount = _amount;
        offer.status = OfferStatus.Active;

        offers.push(offer);

        emit OfferSubmitted(_hatId, _submitter, _amount, offerId);

        return offerId;
    }

    function recordOfferWithdrawal(uint256 offerId, address _submitter)
        external
        returns (bool)
    {
        Offer storage offer = offers[offerId];
        Hat memory hat = hats[offer.hat];

        if (msg.sender != hat.eligibility) {
            revert NotHatsEligibility();
        }

        if (_submitter != offer.submitter) {
            revert NotOfferSubmitter();
        }

        offer.status = OfferStatus.Withdrawn;

        return true;
    }

    function acceptOffer(uint256 offerId) external returns (bool) {
        Offer storage offer = offers[offerId];

        // offer must be active
        if (offer.status != OfferStatus.Active) {
            revert OfferNotActive();
        }

        uint256 hatId = offer.hat;
        Hat memory hat = hats[hatId];

        // hat must be active
        if (!_isActive(hat)) {
            revert HatNotActive();

            // QUESTION do we want to destroy any other offers on the same hat?
        }

        // only the hat owner can accept an offer; might be either an explicit address or the wearer of some other hat
        if (msg.sender != _hatOfferAccepter(hat)) {
            revert NotOfferAccepter();
        }

        // hat max supply must not be reached
        if (hatSupply[hatId] == hat.maxSupply) {
            revert AllHatsFilled();
        }

        address submitter = offer.submitter;

        // Submitter must be eligible for Hat
        if (!_isEligible(submitter, hat)) {
            revert NotEligible();
        }

        // now we can finally accept the offer!
        // update Offer status
        offer.status = OfferStatus.Accepted;

        // mint Hat token to submitter
        _mintHat(hatId, submitter);

        // emit OfferAccepted event
        emit OfferAccepted(offerId);

        return true;
    }

    // DECISION out of scope for mvp
    // function changeHatSupply(uint256 _hatId, uint256 _newSupply)
    //     external
    //     returns (bool)
    // {
    //     // TODO revert if not hat owner
    //     // TODO revert if hatSupply(_hatId) > _newSupply
    //     // TODO revert if hats[_hatId].supply == _newSupply

    //     emit HatSupplyChanged(_hatId, _newSupply);

    //     return true;
    // }

    function deactivateHat(uint256 _hatId) external returns (bool) {
        Hat storage hat = hats[_hatId];

        if (msg.sender != _hatDeactivator(hat)) {
            revert CannotDeactivateHat();
        }

        hat.active = false;

        return true;

        // QUESTION do we also destroy any offers associated with this hat? A: probably not worth the gas to do so
    }

    function requestOracleRuling(uint256 _hatId) public returns (bool) {
        // TODO
    }

    function ruleOnHatWearer(
        uint256 _hatId,
        address _wearer,
        bool _ruling // return false if the wearar is not fulfilling the duties of the hat
    ) external returns (bool) {
        Hat memory hat = hats[_hatId];

        if (msg.sender != hatRuler(hat)) {
            revert CannotRuleOnHat();
        }

        if (!_ruling) {
            // take away the hat by burning it
            _burnHat(_hatId, _wearer);

            // penalize the wearer
            _triggerAccountability(hat, _wearer);
        }

        emit Ruling(_hatId, _wearer, _ruling);

        return true;
    }

    function recordRelinquishment(uint256 _hatId, address _wearer)
        external
        onlyHatsEligibility(_hatId)
        returns (bool)
    {
        // remove the hat
        _burnHat(_hatId, _wearer);

        // hat.eligibilty will handle the unlocking of eligibility

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mintHat(uint256 _hatId, address _wearer) internal {
        _mint(_wearer, _hatId, 1, EMPTY_DATA);

        // increment Hat supply
        ++hatSupply[_hatId];
    }

    // QUESTION do we want the ability to batch mint hats?

    function _burnHat(uint256 _hatId, address _wearer) internal {
        _burn(_wearer, _hatId, 1, EMPTY_DATA);

        // decrement Hat supply
        --hatSupply[_hatId];
    }

    function _triggerAccountability(uint256 _hatId, address _wearer) internal {
        IHatsEligibility ELIGIBILITY = IHatsEligibility(hat.eligibility);
        bool success = ELIGIBILITY.triggerAccountability(_wearer, _hatId);
        if (!success) {
            revert TriggerAccountabilityFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                              HATS VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function viewHat(uint256 _hatId)
        public
        view
        returns (
            string memory name,
            string memory details,
            uint256 id,
            uint256 maxSupply,
            uint256 supply,
            uint256 eligibilityThreshold,
            address eligibility,
            address owner,
            address oracle,
            address conditions,
            bool active
        )
    {
        Hat memory hat = hats[_hatId];
        name = hat.name;
        details = hat.details;
        id = _hatId;
        maxSupply = hat.maxSupply;
        supply = hatSupply[_hatId];
        eligibilityThreshold = hat.eligibilityThreshold;
        eligibility = hat.eligibility;
        owner = hat.owner;
        oracle = hat.oracle;
        conditions = hat.conditions;
        active = _isActive(hat);
    }

    // alternative name: `wearsHat`
    function isWearerOfHat(address _user, uint256 _hatId)
        public
        view
        returns (bool)
    {
        return (balanceOf(_user, _hatId) >= 1);
    }

    // Hat is deemed active if both Conditions contract and hat's active property are TRUE
    // FIXME this may cause issues for hats whose status goes from inactive to active based on programmatic Conditions.
    // for use internally (can pass Hat object)
    function _isActive(Hat memory _hat) internal view returns (bool) {
        IHatsConditions CONDITIONS = IHatsConditions(_hat.conditions);
        return (CONDITIONS.checkConditions(_hat.id) && _hat.active); // FIXME what happens if the `checkConditions` call reverts, eg if the conditions address is humanistic
    }

    // for use externally (when can't pass Hat object)
    function isActive(uint256 _hatId) public view returns (bool) {
        Hat memory hat = hats[_hatId];
        return _isActive(hat);
    }

    // Wearer is deemed eligible if Eligibilty contract says so
    // for use internally (can pass Hat object)
    function _isEligible(address _wearer, Hat memory _hat)
        internal
        view
        returns (bool)
    {
        IHatsEligibility ELIGIBILITY = IHatsEligibility(_hat.eligibility);
        return (ELIGIBILITY.checkEligibility(_wearer, _hat.id));
    }

    // for use externally (when can't pass Hat object)
    function isEligible(address _wearer, uint256 _hatId)
        public
        view
        returns (bool)
    {
        Hat memory hat = hats[_hatId];
        return _isEligible(_wearer, hat);
    }

    function _isInGoodStanding(address _wearer, Hat memory _hat)
        public
        view
        returns (bool)
    {
        IHatsOracle ORACLE = IHatsOracle(_hat.oracle);
        return (ORACLE.checkWearerStanding(_wearer, _hat.id));
    }

    function isInGoodStanding(address _wearer, uint256 _hatId)
        public
        view
        returns (bool)
    {
        Hat memory hat = hats[_hatsId];
        return _isInGoodStanding(_wearer, hat);
    }

    function _hatOfferAccepter(Hat memory _hat)
        internal
        view
        returns (address)
    {
        // if _hat.owner is 20 bytes (i.e. an address), check if _user == _hat.owner
        // if _hat.owner is <20 bytes, check if _user wears _hat.owner , ie
        //      isWearerOfHat(_user, _hat.owner) // only works using the sequential integer hat id model
        // TODO
    }

    function _hatRuler(Hat memory _hat) internal view returns (address) {
        // if _hat.owner is 20 bytes (i.e. an address), check if _user == _hat.oracle
        // if _hat.owner is <20 bytes, check if _user wears _hat.oracle , ie
        //      isWearerOfHat(_user, _hat.oracle) // only works using the sequential integer hat id model
        // TODO
    }

    function _hatDeactivator(Hat memory _hat) internal view returns (address) {
        // if _hat.owner is 20 bytes (i.e. an address), check if _user == _hat.conditions
        // if _hat.owner is <20 bytes, check if _user wears _hat.conditions , ie
        //      isWearerOfHat(_user, _hat.conditions) // only works using the sequential integer hat id model
        // TODO
    }

    // effectively a wrapper around `viewHat` that formats the output as a json string
    function _constructURI(uint256 _hatId)
        internal
        view
        returns (string memory uri_)
    {
        Hat memory hat = hats[_hatId];

        bytes memory properties = abi.encodePacked(
            '{"current supply": "',
            hatSupply[_hatId],
            '", "supply cap": "',
            hat.maxSupply,
            '", "eligibility threshold": "',
            hat.eligibilityThreshold,
            '", "eligibility contract": "',
            hat.eligibility,
            '", "owner": "',
            hat.owner,
            '", "oracle": "',
            hat.oracle,
            '", "conditions": "',
            hat.conditions,
            '"}'
        );

        string memory status = (_isActive(hat) ? "active" : "inactive");

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        hat.name, // alternatively, could point to a URI for offchain flexibility
                        '", "description": "',
                        hat.details, // alternatively, could point to a URI for offchain flexibility
                        '", "id": "',
                        _hatId,
                        '", "status": "',
                        status,
                        //'", "image": "',
                        // some image URI,
                        '", "properties": ',
                        properties,
                        "}"
                    )
                )
            )
        );

        uri_ = string(abi.encodePacked("data:application/json;base64,", json));

        return uri_;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyHatsEligibility(uint256 _hatId) {
        //
        Hat memory hat = hats[_hatId];
        if (msg.sender != hat.eligibility) {
            revert NotHatsEligibility();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC1155 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address owner, uint256 id)
        public
        override
        returns (uint256)
    {
        Hat memory hat = hats[id];

        uint256 balance = 0;

        if (
            _isActive(hat) &&
            _isEligible(owner, hat) &&
            _isInGoodStanding(owner, hat)
        ) {
            balance = balanceOf[_user][_hatId];
        }

        return balance;
    }

    function setApprovalForAll(address operator, bool approved)
        public
        override
    {
        revert NoTransfersAllowed();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public override {
        revert NoTransfersAllowed();
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public override {
        revert NoTransfersAllowed();
    }

    function uri(uint256 id) public view override returns (string memory) {
        return _constructURI(id);
    }

    // function playNiceWithFrontEnds(uint256 hatId) external returns (bool) {
    //     // check for ownerOf changes
    //     // if changed, fire transfer event
    //     if (hats[hatId].wearer != ownerOf(hatId)) {
    //         // QUESTION how do we handle the case where there's a new wearer?
    //         // emit transfer event
    //     }

    //     // no need to actually do any transfering or state changes
    // }
}
