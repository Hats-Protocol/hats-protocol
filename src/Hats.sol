// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

import "solmate/tokens/ERC1155.sol";
import "./HatsConditions/IHatsConditions.sol";
import "./HatsOracles/IHatsOracle.sol";
import "utils/BASE64.sol";

contract Hats is ERC1155 {
    /*//////////////////////////////////////////////////////////////
                              HATS ERRORS
    //////////////////////////////////////////////////////////////*/

    // QUESTION should we add arguments to any of these errors?
    error NotHatOracle();
    error CannotRuleOnHat();
    error NotHatConditions();
    error CannotDeactivateHat();
    error HatNotActive();
    error AllHatsWorn();
    error NoTransfersAllowed();
    error NotHatWearer();

    /*//////////////////////////////////////////////////////////////
                              HATS DATA MODELS
    //////////////////////////////////////////////////////////////*/

    // TODO can probably figure out a way to pack all this stuff into fewer storage slots. Most of it doesn't change, anyways
    struct Hat {
        string name; // QUESTION can this be included in details?
        string details;
        uint256 id; // will be used as the 1155 token ID
        uint256 maxSupply; // the max number of identical hats that can exist
        bytes20 owner; // controls who wears this hat; can convert to address via address(owner)
        bytes20 oracle; // can revoke hat based on ruling
        bytes20 conditions; // controls when hat is active
        bool active; // can be altered by conditions, via deactivateHat()
    }

    /*//////////////////////////////////////////////////////////////
                              HATS STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public nextHatId; // initialized at 0

    // holding zone for inactive hats ("hat rack")
    address private constant HAT_RACK = address(0x4a15); // 0xhats :)

    // we don't need to pass data into ERC1155 mint or transfer functions
    bytes private constant EMPTY_DATA = "";

    Hat[] private hats; // can retrieve hat info via viewHat(hatId) or via uri(hatId);

    mapping(uint256 => uint256) public hatSupply; // key: hatId => value: supply

    // for external contracts to check if hat was reounced or revoked
    mapping(uint256 => mapping(address => bool)) public revocations; // key: hatId => value: (key: wearer => value: revoked?)

    // QUESTION do we need to store Hat wearing history on-chain? In other words, do other contracts need access to said history?

    /*//////////////////////////////////////////////////////////////
                              HATS EVENTS
    //////////////////////////////////////////////////////////////*/

    event HatCreated(
        string name,
        string details,
        uint256 id,
        uint256 maxSupply,
        bytes20 owner,
        bytes20 oracle,
        bytes20 conditions
    );

    event HatRenounced(uint256 hatId, address wearer);

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

    function mintTopHat(address _target) public returns (uint256 topHatId) {
        // create hat

        topHatId = createHat(
            "Top Hat", // name
            "", // details
            1, // maxSupply = 1
            nextHatId, // the topHat owns itself
            address(0), // there is no oracle
            address(0) // it has no conditions
        );

        _mintHat(hatId, _target);

        return topHatId;
    }

    function createTopHatAndHat(
        string memory _name, // encode as bytes32 ??
        string memory _details, // encode as bytes32 ??
        uint256 _maxSupply,
        address _oracle,
        address _conditions
    ) public returns (uint256 topHatId, uint256 firstHatId) {
        topHatId = mintTopHat(msg.sender);

        firstHatId = createHat(
            _name,
            _details,
            _maxSupply,
            topHatId, // the topHat is the owner
            _oracle,
            _conditions
        );

        return (topHatId, firstHatId);
    }

    function createHat(
        string memory _name, // encode as bytes32 ??
        string memory _details, // encode as bytes32 ??
        uint256 _maxSupply,
        uint256 _owner, // hatId
        address _oracle,
        address _conditions
    ) public returns (uint256 hatId) {
        Hat memory hat;
        hat.name = _name;
        hat.details = _details;

        hatId = nextHatId; // QUESTION maybe saves an SLOAD??
        ++nextHatId; // increment the next Hat id

        hat.id = hatId;

        hat.maxSupply = _maxSupply;

        hat.owner = _owner;

        hat.oracle = _oracle;

        hat.conditions = _conditions;
        hat.active = true;

        hats.push(hat);
        // may also need to add to mapping

        emit HatCreated(
            _name,
            _details,
            hatId,
            _maxSupply,
            _owner,
            _oracle,
            _conditions
        );
    }

    function mintHat(uint256 _hatId, address _wearer) external returns (bool) {
        Hat memory hat = hats[_hatId];
        if (msg.sender != hat.owner) {
            revert CannotMintHat();
        }

        if (hatSupply[hat] >= hat.maxSupply) {
            revert AllHatsWorn();
        }

        _mintHat(_hatId, _wearer);

        return true;
    }

    function deactivateHat(uint256 _hatId) external returns (bool) {
        Hat storage hat = hats[_hatId];

        if (msg.sender != _hatDeactivator(hat)) {
            revert CannotDeactivateHat();
        }

        hat.active = false;

        return true;
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

        if (isHatRuler(msg.sender, hat)) {
            revert CannotRuleOnHat();
        }

        if (!_ruling) {
            // revoke the hat by burning it
            _burnHat(_hatId, _wearer);

            // record revocation for use by other contracts
            revocations[_hatId][_wearer] = true;
        }

        emit Ruling(_hatId, _wearer, _ruling);

        return true;
    }

    function renounceHat(uint256 _hatId) external returns (bool) {
        if (!isWearerOfHa(msg.sender, _hatId)) {
            revert NotHatWearer();
        }
        // remove the hat
        _burnHat(_hatId, _wearer);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mintHat(uint256 _hatId, address _wearer) internal {
        _mint(_wearer, _hatId, 1, EMPTY_DATA);

        // increment Hat supply
        ++hatSupply[_hatId];

        // assign wearer to hat
        hatWearers[_hatId] = _wearer;
    }

    // QUESTION do we want the ability to batch mint hats?

    function _burnHat(uint256 _hatId, address _wearer) internal {
        _burn(_wearer, _hatId, 1, EMPTY_DATA);

        // decrement Hat supply
        --hatSupply[_hatId];

        // unassign wearer from hat
        hatWearers[_hatId] = bytes20(0x0);
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
        owner = hat.owner;
        oracle = hat.oracle;
        conditions = hat.conditions;
        active = _isActive(hat);
    }

    function isWearerOfHat(uint160 _user, uint256 _hatId)
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

        if (_isActive(hat) && _isInGoodStanding(owner, hat)) {
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
