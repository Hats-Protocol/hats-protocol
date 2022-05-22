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
    error HatNotActive();
    error NotAdmin();
    error AllHatsWorn();
    error NoTransfersAllowed();
    error NotHatWearer();
    error NotHatCondition();
    error NotHatOracle();

    /*//////////////////////////////////////////////////////////////
                              HATS DATA MODELS
    //////////////////////////////////////////////////////////////*/

    struct Hat {
        // 1st storage slot
        address oracle; // can revoke hat based on ruling; 20 bytes (+20)
        uint64 id; // will be used as the 1155 token ID; 28 bytes (+8)
        uint32 maxSupply; // the max number of identical hats that can exist; 32 bytes (+4)
        // 2nd storage slot
        address conditions; // controls when hat is active; 20 bytes (+20)
        uint64 admin; // controls who wears this hat; can convert to address via address(admin); 28 bytes (+8)
        bool active; // can be altered by conditions, via deactivateHat(); 29 bytes (+1)
        // 3rd+ storage slot
        string details;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS STORAGE
    //////////////////////////////////////////////////////////////*/

    uint64 public nextHatId; // initialized at 0

    Hat[] private hats; // can retrieve hat info via viewHat(hatId) or via uri(hatId);

    mapping(uint64 => uint32) public hatSupply; // key: hatId => value: supply

    // for external contracts to check if hat was reounced or revoked
    mapping(uint64 => mapping(address => bool)) public revocations; // key: hatId => value: (key: wearer => value: revoked?)

    // QUESTION do we need to store Hat wearing history on-chain? In other words, do other contracts need access to said history?

    /*//////////////////////////////////////////////////////////////
                              HATS EVENTS
    //////////////////////////////////////////////////////////////*/

    event HatCreated(
        string details,
        uint64 id,
        uint32 maxSupply,
        uint64 admin,
        address oracle,
        address conditions
    );

    event HatRenounced(uint64 hatId, address wearer);

    event Ruling(uint64 hatId, address wearer, bool ruling);

    event HatDeactivated(uint64 hatId);

    // event HatSupplyChanged(uint64 hatId, uint256 newSupply);

    constructor() {
        // nextHatId = 0;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS LOGIC
    //////////////////////////////////////////////////////////////*/

    function mintTopHat(address _target) public returns (uint256 topHatId) {
        // create hat

        topHatId = createHat(
            "", // details
            1, // maxSupply = 1
            nextHatId, // a topHat is its own admin
            address(0), // there is no oracle
            address(0) // it has no conditions
        );

        _mintHat(hatId, _target);

        return topHatId;
    }

    function createTopHatAndHat(
        string memory _details, // encode as bytes32 ??
        uint256 _maxSupply,
        address _oracle,
        address _conditions
    ) public returns (uint256 topHatId, uint256 firstHatId) {
        topHatId = mintTopHat(msg.sender);

        firstHatId = createHat(
            _details,
            _maxSupply,
            topHatId, // the topHat is the admin
            _oracle,
            _conditions
        );

        return (topHatId, firstHatId);
    }

    function createHat(
        string memory _details, // encode as bytes32 ??
        uint256 _maxSupply,
        uint256 _admin, // hatId
        address _oracle,
        address _conditions
    ) public returns (uint64 hatId) {
        // to create a hat, you must be wearing the hat of its admin
        if (!isWearerOfHat(msg.sender, _admin)) {
            revert NotAdmin();
        }

        // create the new hat
        hatId = _createHat(_details, _maxSupply, _admin, _oracle, _conditions);
    }

    function mintHat(uint64 _hatId, address _wearer) external returns (bool) {
        Hat memory hat = hats[_hatId];
        // only the wearer of a hat's admin hat can mint it
        if (_isAdminOfHat(hat)) {
            revert NotAdmin();
        }

        if (hatSupply[hat] >= hat.maxSupply) {
            revert AllHatsWorn();
        }

        _mintHat(_hatId, _wearer);

        return true;
    }

    function deactivateHat(uint64 _hatId) external returns (bool) {
        Hat storage hat = hats[_hatId];

        if (msg.sender != hat.conditions) {
            revert NotHatConditions();
        }

        hat.active = false;

        return true;
    }

    function requestConditions(uint64 _hatId) external returns (bool) {
        Hat storage hat = hats[_hatId];

        IHatsConditions CONDITIONS = IHatsConditions(hat.conditions);

        bool status = ORACLE.checkCondtions(_hat.id); // FIXME what happens if CONDITIONS doesn't have a checkConditions() function?

        if (!status) {
            hat.active = false;
        }

        return true;
    }

    function ruleOnHatWearer(
        uint64 _hatId,
        address _wearer,
        bool _ruling // return false if the wearar is not fulfilling the duties of the hat
    ) external returns (bool) {
        Hat memory hat = hats[_hatId];

        if (hat != hat.oracle) {
            revert NotHatOracle();
        }

        if (!_ruling) {
            _revokeHat(_wearer, _hatId);
        }

        emit Ruling(_hatId, _wearer, _ruling);

        return true;
    }

    function requestOracleRuling(address _wearer, uint64 _hatId)
        public
        returns (bool)
    {
        Hat memory hat = hats[_hatId];
        IHatsOracle ORACLE = IHatsOracle(hat.oracle);

        bool ruling = ORACLE.checkWearerStanding(_wearer, _hat.id); // FIXME what happens if ORACLE doesn't have a checkWearerStanding() function?

        if (!ruling) {
            _revokeHat(_wearer, _hatId);
        }

        emit Ruling(_hatId, _wearer, ruling);

        return ruling;
    }

    function renounceHat(uint64 _hatId) external returns (bool) {
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

    function _createHat(
        string memory _details, // encode as bytes32 ??
        uint256 _maxSupply,
        uint256 _admin, // hatId
        address _oracle,
        address _conditions
    ) internal returns (uint64 hatId) {
        Hat memory hat;
        hat.details = _details;

        hatId = nextHatId;
        ++nextHatId; // increment the next Hat id

        hat.id = hatId;

        hat.maxSupply = _maxSupply;

        hat.admin = _admin;

        hat.oracle = _oracle;

        hat.conditions = _conditions;
        hat.active = true;

        hats.push(hat);
        // may also need to add to mapping

        emit HatCreated(
            _details,
            hatId,
            _maxSupply,
            _admin,
            _oracle,
            _conditions
        );
    }

    function _mintHat(uint64 _hatId, address _wearer) internal {
        _mint(_wearer, _hatId, 1, "");

        // increment Hat supply
        ++hatSupply[_hatId];
    }

    function _revokeHat(address _wearer, uint64 _hatId) internal {
        // revoke the hat by burning it
        _burnHat(_hatId, _wearer);

        // record revocation for use by other contracts
        revocations[_hatId][_wearer] = true;
    }

    function _burnHat(uint64 _hatId, address _wearer) internal {
        _burn(_wearer, _hatId, 1, "");

        // decrement Hat supply
        --hatSupply[_hatId];
    }

    /*//////////////////////////////////////////////////////////////
                              HATS VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function viewHat(uint64 _hatId)
        public
        view
        returns (
            string memory details,
            uint64 id,
            uint256 maxSupply,
            uint256 supply,
            address admin,
            address oracle,
            address conditions,
            bool active
        )
    {
        Hat memory hat = hats[_hatId];
        details = hat.details;
        id = _hatId;
        maxSupply = hat.maxSupply;
        supply = hatSupply[_hatId];
        admin = hat.admin;
        oracle = hat.oracle;
        conditions = hat.conditions;
        active = _isActive(hat);
    }

    function _isTopHat(Hat memory hat) internal view returns (bool) {
        // a topHat is a hat that is its own admin
        return (hat == hat.admin);
    }

    function isTopHat(uint64 _hatId) public view returns (bool) {
        Hat memory hat = hats[_hatId];
        _isTopHat(hat);
    }

    function isWearerOfHat(address _user, uint64 _hatId)
        public
        view
        returns (bool)
    {
        return (balanceOf(_user, _hatId) >= 1);
    }

    function isAdminOfHat(address _user, uint64 _hatId)
        public
        view
        returns (bool)
    {
        Hat memory hat = hats[_hatId];

        // if hat is a topHat, then we know that _user is not the admin
        if (_isTopHat(hat)) {
            return false;
        }

        if (isWearerOfHat(_user, hat.admin)) {
            return true;
        } else {
            // recursion
            isAdminOfHat(_user, hat.admin);
        }
    }

    // FIXME need to figure out all the permutations
    // for use internally (can pass Hat object)
    function _isActive(Hat memory _hat) internal view returns (bool) {
        IHatsConditions CONDITIONS = IHatsConditions(_hat.conditions);

        return (CONDITIONS.checkConditions(_hat.id) && _hat.active);

        /* 
        hat.active is TRUE when...
            - deactivateHat() has not been called
        hat.active is FALSE when...
            - deactivateHat() has been called

        checkConditions() can return TRUE or FALSE when Conditions is a contract with a checkConditions() function

        QUESTION: what happens to checkConditions() if Conditions is a contract without a checkConditions() function?

        QUESTION: what happens to checkConditions() if Conditions is an EOA?

        */
    }

    // for use externally (when can't pass Hat object)
    function isActive(uint64 _hatId) public view returns (bool) {
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

    function isInGoodStanding(address _wearer, uint64 _hatId)
        public
        view
        returns (bool)
    {
        Hat memory hat = hats[_hatsId];
        return _isInGoodStanding(_wearer, hat);
    }

    // effectively a wrapper around `viewHat` that formats the output as a json string
    function _constructURI(uint64 _hatId)
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
            '", "admin (hat)": "',
            hat.admin,
            '", "oracle (address)": "',
            hat.oracle,
            '", "conditions (address)": "',
            hat.conditions,
            '"}'
        );

        string memory status = (_isActive(hat) ? "active" : "inactive");

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name & description": "',
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
                              ERC1155 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address admin, uint256 id)
        public
        override
        returns (uint256)
    {
        uint64 hatID = uint64(id); // QUESTION do we need to cast this? what happens if it overflows?
        Hat memory hat = hats[hatId];

        uint256 balance = 0;

        if (_isActive(hat) && _isInGoodStanding(admin, hat)) {
            balance = balanceOf[_user][hatId];
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
        Hat memory hat = hats[uint64(id)];
        if (!_isHatAdmin(hat)) {
            revert OnlyAdminsCanTransfer();
        }

        // TODO
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
        return _constructURI(uint64(id));
    }
}
