// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

import {ERC1155} from "solmate/tokens/ERC1155.sol";
// do we need an interface for Hatter / admin?
import "forge-std/Test.sol"; //remove after testing
import "./HatsConditions/IHatsConditions.sol";
import "./HatsOracles/IHatsOracle.sol";
import "utils/BASE64.sol";
import "utils/Strings.sol";

/// @title Hats Protocol
/// @notice Hats are DAO-native revocable roles that are represented as semi-fungable tokens for composability
/// @dev This contract can manage all Hats for a given chain
/// @author Hats Protocol
contract Hats is ERC1155 {
    /*//////////////////////////////////////////////////////////////
                              HATS ERRORS
    //////////////////////////////////////////////////////////////*/

    // QUESTION should we add arguments to any of these errors? See github issue #21
    error NotAdmin(address _user, uint256 _hatId);
    error AllHatsWorn();
    error AlreadyWearingHat();
    error NoApprovalsNeeded();
    error OnlyAdminsCanTransfer();
    error NotHatWearer();
    error NotHatConditions();
    error NotHatOracle();
    error NotIHatsConditionsContract();
    error NotIHatsOracleContract();
    error BatchArrayLengthMismatch();
    error SafeTransfersNotNecessary();
    error MaxTreeDepthReached();

    /*//////////////////////////////////////////////////////////////
                              HATS DATA MODELS
    //////////////////////////////////////////////////////////////*/

    struct Hat {
        // 1st storage slot
        address oracle; // can revoke Hat based on ruling; 20 bytes (+20)
        uint32 maxSupply; // the max number of identical hats that can exist; 24 bytes (+4)
        bool active; // can be altered by conditions, via setHatStatus(); 25 bytes (+1)
        uint8 lastHatId; // indexes how many different hats an admin is holding; 26 bytes (+1)
        // 2nd storage slot
        address conditions; // controls when Hat is active; 20 bytes (+20)
        // 3rd+ storage slot
        string details;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS STORAGE
    //////////////////////////////////////////////////////////////*/

    uint32 public lastTopHatId; // initialized at 0

    /**
     * Hat IDs act like addresses. The top level consists of 4 bytes and references all tophats
     * Each level below consists of 1 byte, which can contain up to 255 types of hats.
     *
     * A uint256 contains 4 bytes of space for tophat addresses and 28 bytes of space
     * for 28 levels of heirarchy of ownership, with the admin at each level having space
     * for 255 different hats.
     *
     */
    mapping(uint256 => Hat) internal _hats;

    // string public baseImageURI = "https://images.hatsprotocol.xyz/"

    mapping(uint256 => uint32) public hatSupply; // key: hatId => value: supply

    // for external contracts to check if Hat was revoked because the wearer is in bad standing
    mapping(uint256 => mapping(address => bool)) public badStandings; // key: hatId => value: (key: wearer => value: badStanding?)

    /*//////////////////////////////////////////////////////////////
                              HATS EVENTS
    //////////////////////////////////////////////////////////////*/

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

    constructor() {
        // lastTopHatId = 0;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates and mints a Hat that is its own admin, i.e. a "topHat"
    /// @dev A topHat has no oracle and no conditions
    /// @param _target The address to which the newly created topHat is minted
    /// @return topHatId The id of the newly created topHat
    function mintTopHat(address _target) public returns (uint256 topHatId) {
        // create hat

        topHatId = uint256(++lastTopHatId) << 224;

        _createHat(
            topHatId,
            "", // details
            1, // maxSupply = 1
            address(0), // there is no oracle
            address(0) // it has no conditions
        );

        _mint(_target, topHatId, 1, "");
    }

    /// @notice Mints a topHat to the msg.sender and creates another Hat admin'd by the topHat
    /// @param _details A description of the hat
    /// @param _maxSupply The total instances of the Hat that can be worn at once
    /// @param _oracle The address that can report on the Hat wearer's standing
    /// @param _conditions The address that can deactivate the hat
    /// @return topHatId The id of the newly created topHat
    /// @return firstHatId The id of the other newly created hat
    function createTopHatAndHat(
        string memory _details, // encode as bytes32 ??
        uint32 _maxSupply,
        address _oracle,
        address _conditions
    ) public returns (uint256 topHatId, uint256 firstHatId) {
        topHatId = mintTopHat(msg.sender);

        firstHatId = createHat(
            topHatId,
            _details,
            _maxSupply,
            _oracle,
            _conditions
        );

        return (topHatId, firstHatId);
    }

    /// @notice Creates a new hat. The msg.sender must wear the `_admin` hat.
    /// @dev Initializes a new Hat struct, but does not mint any tokens.
    /// @param _details A description of the Hat
    /// @param _maxSupply The total instances of the Hat that can be worn at once
    /// @param _admin The id of the Hat that will control who wears the newly created hat
    /// @param _oracle The address that can report on the Hat wearer's status
    /// @param _conditions The address that can deactivate the Hat
    /// @return newHatId The id of the newly created Hat
    function createHat(
        uint256 _admin,
        string memory _details, // encode as bytes32 ??
        uint32 _maxSupply,
        address _oracle,
        address _conditions
    ) public returns (uint256 newHatId) {
        // to create a hat, you must be wearing the Hat of its admin
        if (!isWearerOfHat(msg.sender, _admin)) {
            revert NotAdmin(msg.sender, _admin);
        }
        if (uint8(_admin) > 0) {
            revert MaxTreeDepthReached();
        }

        newHatId = _buildNextId(_admin);
        // create the new hat
        _createHat(newHatId, _details, _maxSupply, _oracle, _conditions);
        // increment _admin.lastHatId
        ++_hats[_admin].lastHatId;
    }

    function _buildNextId(uint256 _admin) internal returns (uint256) {
        uint8 nextHatId = _hats[_admin].lastHatId + 1;

        if (uint224(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 216);
        }
        if (uint216(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 208);
        }
        if (uint208(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 200);
        }
        if (uint200(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 192);
        }
        if (uint192(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 184);
        }
        if (uint184(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 176);
        }
        if (uint176(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 168);
        }
        if (uint168(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 160);
        }
        if (uint160(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 152);
        }
        if (uint152(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 144);
        }
        if (uint144(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 136);
        }
        if (uint136(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 128);
        }
        if (uint128(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 120);
        }
        if (uint120(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 112);
        }
        if (uint112(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 104);
        }
        if (uint104(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 96);
        }
        if (uint96(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 88);
        }
        if (uint88(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 80);
        }
        if (uint80(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 72);
        }
        if (uint72(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 64);
        }
        if (uint64(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 56);
        }
        if (uint56(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 48);
        }
        if (uint48(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 40);
        }

        if (uint40(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 32);
        }

        if (uint32(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 24);
        }

        if (uint24(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 16);
        }

        if (uint16(_admin) == 0) {
            return _admin | (uint256(nextHatId) << 8);
        }

        return _admin | uint256(nextHatId);
    }

    /// @notice Mints an ERC1155 token of the Hat to a recipient, who then "wears" the hat
    /// @dev The msg.sender must wear the admin Hat of `_hatId`
    /// @param _hatId The id of the Hat to mint
    /// @param _wearer The address to which the Hat is minted
    /// @return bool Whether the mint succeeded
    function mintHat(uint256 _hatId, address _wearer) public returns (bool) {
        Hat memory hat = _hats[_hatId];
        // only the wearer of a hat's admin Hat can mint it
        if (!isAdminOfHat(msg.sender, _hatId)) {
            revert NotAdmin(msg.sender, _hatId);
        }

        if (hatSupply[_hatId] >= hat.maxSupply) {
            revert AllHatsWorn();
        }

        if (isWearerOfHat(_wearer, _hatId)) {
            revert AlreadyWearingHat();
        }

        _mint(_wearer, uint256(_hatId), 1, "");

        return true;
    }

    /// @notice Toggles a Hat's status from active to deactive, or vice versa
    /// @dev The msg.sender must be set as the hat's Conditions
    /// @param _hatId The id of the Hat for which to adjust status
    /// @return bool Whether the status was toggled
    function setHatStatus(uint256 _hatId, bool newStatus)
        external
        returns (bool)
    {
        Hat storage hat = _hats[_hatId];

        if (msg.sender != hat.conditions) {
            revert NotHatConditions();
        }

        return _processHatStatus(_hatId, newStatus);
    }

    /// @notice Checks a hat's Conditions and, if new, toggle's the hat's status
    /// @dev // TODO
    /// @param _hatId The id of the Hat whose Conditions we are checking
    /// @return bool Whether there was a new status
    function pullHatStatusFromConditions(uint256 _hatId)
        external
        returns (bool)
    {
        Hat memory hat = _hats[_hatId];
        bool newStatus;

        bytes memory data = abi.encodeWithSignature(
            "getHatStatus(uint256)",
            _hatId
        );

        (bool success, bytes memory returndata) = hat.conditions.staticcall(
            data
        );

        // if function call succeeds with data of length > 0
        // then we know the contract exists and has the getWearerStatus function
        if (success && returndata.length > 0) {
            newStatus = abi.decode(returndata, (bool));
        } else {
            revert NotIHatsConditionsContract();
        }

        return _processHatStatus(_hatId, newStatus);
    }

    /// @notice Report from a hat's Oracle on the status of one of its wearers and, if `false`, revoke their hat
    /// @dev Burns the wearer's hat, if revoked
    /// @param _hatId The id of the hat
    /// @param _wearer The address of the hat wearer whose status is being reported
    /// @param _revoke True if the wearer should no longer wear the hat
    /// @param _wearerStanding False if the wearer is no longer in good standing (and potentially should be penalized)
    /// @return bool Whether the report succeeded
    function setHatWearerStatus(
        uint256 _hatId,
        address _wearer,
        bool _revoke,
        bool _wearerStanding
    ) external returns (bool) {
        Hat memory hat = _hats[_hatId];

        if (msg.sender != hat.oracle) {
            revert NotHatOracle();
        }

        _processHatWearerStatus(_hatId, _wearer, _revoke, _wearerStanding);

        return true;
    }

    /// @notice Check a hat's Oracle for a report on the status of one of the hat's wearers and, if `false`, revoke their hat
    /// @dev Burns the wearer's hat, if revoked
    /// @param _hatId The id of the hat
    /// @param _wearer The address of the Hat wearer whose status report is being requested
    function pullHatWearerStatusFromOracle(uint256 _hatId, address _wearer)
        public
        returns (bool)
    {
        Hat memory hat = _hats[_hatId];
        bool revoke;
        bool wearerStanding;

        bytes memory data = abi.encodeWithSignature(
            "getWearerStatus(address,uint256)",
            _wearer,
            _hatId
        );

        (bool success, bytes memory returndata) = hat.oracle.staticcall(data);

        // if function call succeeds with data of length > 0
        // then we know the contract exists and has the getWearerStatus function
        if (success && returndata.length > 0) {
            (revoke, wearerStanding) = abi.decode(returndata, (bool, bool));
        } else {
            revert NotIHatsOracleContract();
        }

        return _processHatWearerStatus(_hatId, _wearer, revoke, wearerStanding);
    }

    /// @notice Stop wearing a hat, aka "renounce" it
    /// @dev Burns the msg.sender's hat
    /// @param _hatId The id of the Hat being renounced
    function renounceHat(uint256 _hatId) external {
        if (!isWearerOfHat(msg.sender, _hatId)) {
            revert NotHatWearer();
        }
        // remove the hat
        _burn(msg.sender, _hatId, 1);

        emit HatRenounced(_hatId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                              HATS INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal call for creating a new hat
    /// @dev Initializes a new Hat struct, but does not mint any tokens
    /// @param _id ID of the hat to be stored
    /// @param _details A description of the hat
    /// @param _maxSupply The total instances of the Hat that can be worn at once
    /// @param _oracle The address that can report on the Hat wearer's status
    /// @param _conditions The address that can deactivate the hat
    /// @return hat The contents of the newly created hat
    function _createHat(
        uint256 _id,
        string memory _details, // encode as bytes32 ??
        uint32 _maxSupply,
        address _oracle,
        address _conditions
    ) internal returns (Hat memory hat) {
        hat.details = _details;

        hat.maxSupply = _maxSupply;

        hat.oracle = _oracle;

        hat.conditions = _conditions;
        hat.active = true;

        _hats[_id] = hat;

        emit HatCreated(_id, _details, _maxSupply, _oracle, _conditions);
    }

    // TODO write comment
    function _processHatStatus(uint256 _hatId, bool _newStatus)
        internal
        returns (bool updated)
    {
        // optimize later
        Hat storage hat = _hats[_hatId];

        if (_newStatus != hat.active) {
            hat.active = _newStatus;
            emit HatStatusChanged(_hatId, _newStatus);
            updated = true;
        }
    }

    /// @notice Internal call to revoke a Hat from a wearer
    /// @dev Burns the wearer's Hat token
    /// @param _hatId The id of the Hat to revoke
    /// @param _wearer The address of the wearer from whom to revoke the hat
    /// @param _wearerStanding Whether or to make a record of the revocation on-chain for other contracts to use
    function _processHatWearerStatus(
        uint256 _hatId,
        address _wearer,
        bool _revoke,
        bool _wearerStanding
    ) internal returns (bool updated) {
        if (_revoke) {
            // revoke the Hat by burning it
            _burn(_wearer, _hatId, 1);
        }

        // record standing for use by other contracts
        // note: here, wearerStanding and badStandings are opposite
        // i.e. if wearerStanding (true = good standing)
        // then badStandings[_hatId][wearer] will be false
        // if they are different, then something has changed, and we need to update
        // badStandings marker
        if (_wearerStanding == badStandings[_hatId][_wearer]) {
            badStandings[_hatId][_wearer] = !_wearerStanding;
            updated = true;
        }

        emit WearerStatus(_hatId, _wearer, _revoke, _wearerStanding);

        return updated;
    }

    function transferHat(
        uint256 _hatId,
        address _from,
        address _to
    ) public {
        if (!isAdminOfHat(msg.sender, _hatId)) {
            revert OnlyAdminsCanTransfer();
        }

        uint256 id = uint256(_hatId);

        // Checks storage instead of `isWearerOfHat` since admins may want to transfer revoked Hats to new wearers
        if (balanceOf(_from, id) < 1) {
            revert NotHatWearer();
        }

        //Adjust balances
        --_balanceOf[_from][id];
        ++_balanceOf[_to][id];

        emit TransferSingle(msg.sender, _from, _to, id, 1);
    }

    /*//////////////////////////////////////////////////////////////
                              HATS VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice View the properties of a given Hat
    /// @param _hatId The id of the Hat
    /// @return details The details of the Hat
    /// @return maxSupply The max supply of tokens for this Hat
    /// @return supply The number of current wearers of this Hat
    /// @return oracle The Oracle address for this Hat
    /// @return conditions The Conditions address for this Hat
    /// @return lastHatId The most recently created Hat with this Hat as admin; also the count of Hats with this Hat as admin
    /// @return active Whether the Hat is current active, as read from `_isActive`
    function viewHat(uint256 _hatId)
        public
        view
        returns (
            string memory details,
            uint32 maxSupply,
            uint32 supply,
            address oracle,
            address conditions,
            uint8 lastHatId,
            bool active
        )
    {
        Hat memory hat = _hats[_hatId];
        details = hat.details;
        maxSupply = hat.maxSupply;
        supply = hatSupply[_hatId];
        oracle = hat.oracle;
        conditions = hat.conditions;
        lastHatId = hat.lastHatId;
        active = _isActive(hat, _hatId);
    }

    /// @notice Chcecks whether a Hat is a topHat
    /// @dev For use when passing a Hat object is not appropriate
    /// @param _hatId The Hat in question
    /// @return bool Whether the Hat is a topHat
    function isTopHat(uint256 _hatId) public pure returns (bool) {
        return _hatId > 0 && uint224(_hatId) == 0;
    }

    /// @notice Checks whether a given address wears a given Hat
    /// @dev Convenience function that wraps `balanceOf`
    /// @param _user The address in question
    /// @param _hatId The id of the Hat that the `_user` might wear
    /// @return bool Whether the `_user` wears the Hat.
    function isWearerOfHat(address _user, uint256 _hatId)
        public
        view
        returns (bool)
    {
        return (balanceOf(_user, _hatId) >= 1);
    }

    /// @notice Checks whether a given address serves as the admin of a given Hat
    /// @dev Recursively checks if `_user` wears the admin Hat of the Hat in question. This is recursive since there may be a string of Hats as admins of Hats.
    /// @param _user The address in question
    /// @param _hatId The id of the Hat for which the `_user` might be the admin
    /// @return bool Whether the `_user` has admin rights for the Hat
    function isAdminOfHat(address _user, uint256 _hatId)
        public
        view
        returns (bool)
    {
        // if Hat is a topHat, then the _user cannot be the admin
        if (isTopHat(_hatId)) {
            return false;
        }

        uint8 adminHatLevel = getHatLevel(_hatId) - 1;

        while (adminHatLevel >= 1) {
            if (isWearerOfHat(_user, getAdminAtLevel(_hatId, adminHatLevel))) {
                return true;
            }
            adminHatLevel--;
        }
        return isWearerOfHat(_user, getAdminAtLevel(_hatId, 0));
    }

    function getHatLevel(uint256 _hatId) public pure returns (uint8 level) {
        // TODO: invert the order for optimization
        if (uint8(_hatId) > 0) return 28;
        if (uint16(_hatId) > 0) return 27;
        if (uint24(_hatId) > 0) return 26;
        if (uint32(_hatId) > 0) return 25;
        if (uint40(_hatId) > 0) return 24;
        if (uint48(_hatId) > 0) return 23;
        if (uint56(_hatId) > 0) return 22;
        if (uint64(_hatId) > 0) return 21;
        if (uint72(_hatId) > 0) return 20;
        if (uint80(_hatId) > 0) return 19;
        if (uint88(_hatId) > 0) return 18;
        if (uint96(_hatId) > 0) return 17;
        if (uint104(_hatId) > 0) return 16;
        if (uint112(_hatId) > 0) return 15;
        if (uint120(_hatId) > 0) return 14;
        if (uint128(_hatId) > 0) return 13;
        if (uint136(_hatId) > 0) return 12;
        if (uint144(_hatId) > 0) return 11;
        if (uint152(_hatId) > 0) return 10;
        if (uint160(_hatId) > 0) return 9;
        if (uint168(_hatId) > 0) return 8;
        if (uint176(_hatId) > 0) return 7;
        if (uint184(_hatId) > 0) return 6;
        if (uint192(_hatId) > 0) return 5;
        if (uint200(_hatId) > 0) return 4;
        if (uint208(_hatId) > 0) return 3;
        if (uint216(_hatId) > 0) return 2;
        if (uint224(_hatId) > 0) return 1;
        return 0;
    }

    function getAdminAtLevel(uint256 _hatId, uint8 _level)
        public
        pure
        returns (uint256 admin)
    {
        uint256 operAND = type(uint256).max << (8 * (28 - _level));

        return _hatId & operAND;
    }

    /// @notice Checks the active status of a hat
    /// @dev For internal use instead of `isActive` when passing Hat as param is preferable
    /// @param _hat The Hat struct
    /// @return active The active status of the hat
    function _isActive(Hat memory _hat, uint256 _hatId)
        internal
        view
        returns (bool active)
    {
        bytes memory data = abi.encodeWithSignature(
            "getHatStatus(uint256)",
            _hatId
        );

        (bool success, bytes memory returndata) = _hat.conditions.staticcall(
            data
        );

        if (success && returndata.length > 0) {
            active = abi.decode(returndata, (bool));
        } else {
            active = _hat.active;
        }
    }

    /// @notice Checks the active status of a hat
    /// @dev Use `_isActive` for internal calls that can take a Hat as a param
    /// @param _hatId The id of the hat
    /// @return bool The active status of the hat
    function isActive(uint256 _hatId) public view returns (bool) {
        Hat memory hat = _hats[_hatId];
        return _isActive(hat, _hatId);
    }

    /// @notice Internal call to check whether a wearer of a Hat is in good standing
    /// @dev Tries an external call to the Hat's Conditions address, defaulting to existing badStandings state if the call fails (ie if the Conditions address does not conform to it IConditions interface)
    /// @param _hat The Hat object
    /// @param _wearer The address of the Hat wearer
    /// @return standing Whether the wearer is in good standing
    function _isInGoodStanding(
        address _wearer,
        Hat memory _hat,
        uint256 _hatId
    ) internal view returns (bool standing) {
        bytes memory data = abi.encodeWithSignature(
            "getWearerStatus(address,uint256)",
            _wearer,
            _hatId
        );

        (bool success, bytes memory returndata) = _hat.oracle.staticcall(data);

        if (success && returndata.length > 0) {
            (, standing) = abi.decode(returndata, (bool, bool));
        } else {
            standing = !badStandings[_hatId][_wearer];
        }
    }

    /// @notice Checks whether a wearer of a Hat is in good standing
    /// @dev Public function for use when passing a Hat object is not possible or preferable
    /// @param _hatId The id of the Hat
    /// @param _wearer The address of the Hat wearer
    /// @return bool
    function isInGoodStanding(address _wearer, uint256 _hatId)
        public
        view
        returns (bool)
    {
        Hat memory hat = _hats[_hatId];
        return _isInGoodStanding(_wearer, hat, _hatId);
    }

    /// @notice Constructs the URI for a Hat, using data from the Hat struct
    /// @param _hatId The id of the Hat
    /// @return uri_ An ERC1155-compatible JSON string
    function _constructURI(uint256 _hatId)
        internal
        view
        returns (string memory uri_)
    {
        Hat memory hat = _hats[_hatId];

        uint256 hatAdmin;

        if (isTopHat(_hatId)) {
            hatAdmin = _hatId;
        } else {
            hatAdmin = getAdminAtLevel(_hatId, getHatLevel(_hatId) - 1);
        }

        string memory domain = Strings.toString(
            getAdminAtLevel(_hatId, 0) >> (8 * 28)
        );

        bytes memory properties = abi.encodePacked(
            '{"current supply": "',
            Strings.toString(hatSupply[_hatId]),
            '", "supply cap": "',
            Strings.toString(hat.maxSupply),
            '", "admin (id)": "',
            Strings.toString(hatAdmin),
            '", "admin (pretty id)": "',
            prettyHatId(hatAdmin),
            '", "oracle address": "',
            Strings.toHexString(hat.oracle),
            '", "conditions address": "',
            Strings.toHexString(hat.conditions),
            '"}'
        );
        string memory status = (_isActive(hat, _hatId) ? "active" : "inactive");

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name & description": "',
                        hat.details, // alternatively, could point to a URI for offchain flexibility
                        '", "domain": "',
                        domain,
                        '", "id": "',
                        Strings.toString(_hatId),
                        '", "pretty id": "',
                        // Strings.toHexString(_hatId, 32),
                        prettyHatId(_hatId),
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

    function prettyHatId(uint256 _hatId) public pure returns (string memory) {
        // initialize with the domain
        // this should be a hex string with 8 characters, eg 00000001 for the first topHat
        string memory prettyId = Strings.toHexStringClean(
            _hatId >> (28 * 8),
            4
        );

        // get hat level
        uint8 hatLevel = getHatLevel(_hatId);

        // if _hatId is a tophat, then return just the domain
        if (hatLevel == 0) return prettyId;

        // else, loop through and add levels to prettyId
        for (uint256 i = 1; i <= hatLevel; ++i) {
            uint256 shifter = 8 * (28 - i);

            // find id at level
            uint256 nextLevelId = (_hatId & (0xff << shifter)) >> shifter;

            // convert to hex and concatenate along with "."
            string memory nextLevelString = string.concat(
                ".",
                Strings.toHexStringClean(nextLevelId)
            );

            // append
            prettyId = string.concat(prettyId, nextLevelString);
        }

        return prettyId;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC1155 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the Hat token balance of a user for a given Hat
    /// @param wearer The address whose balance is being checked
    /// @param hatId The id of the Hat
    /// @return balance The `_user`'s balance of the Hat tokens. Will typically not be greater than 1.
    function balanceOf(address wearer, uint256 hatId)
        public
        view
        override
        returns (uint256 balance)
    {
        Hat memory hat = _hats[hatId];

        balance = 0;

        if (_isActive(hat, hatId) && _isInGoodStanding(wearer, hat, hatId)) {
            balance = super.balanceOf(wearer, hatId);
        }

        return balance;
    }

    /// @notice Mints a Hat token to `to`
    /// @dev Overrides ERC1155._mint: skips the typical 1155TokenReceiver hook since Hat wearers don't control their own Hat, and adds Hats-specific state changes
    /// @param to The wearer of the Hat and the recipient of the newly minted token
    /// @param id The id of the Hat to mint, cast to uint256
    /// @param amount Must always be 1, since it's not possible wear >1 Hat
    /// @param data Can be empty since we skip the 1155TokenReceiver hook
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal override {
        _balanceOf[to][id] += amount;

        // increment Hat supply counter
        ++hatSupply[uint256(id)];

        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    /// @notice Burns a wearer's (`from`'s) Hat token
    /// @dev Overrides ERC1155._burn: adds Hats-specific state change
    /// @param from The wearer from which to burn the Hat token
    /// @param id The id of the Hat to burn, cast to uint256
    /// @param amount Must always be 1, since it's not possible wear >1 Hat
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal override {
        _balanceOf[from][id] -= amount;

        // decrement Hat supply counter
        --hatSupply[uint256(id)];

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }

    function setApprovalForAll(address operator, bool approved)
        public
        pure
        override
    {
        revert NoApprovalsNeeded();
    }

    /// @notice Safe transfers are not necessary for Hats since transfers are not handled by the wearer
    /// @dev Use `Hats.TransferHat()` instead
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public pure override {
        revert SafeTransfersNotNecessary();
    }

    /// @notice Safe transfers are not necessary for Hats since transfers are not handled by the wearer
    /// @dev Use `Hats.BatchTransferHats()` instead
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public pure override {
        revert SafeTransfersNotNecessary();
    }

    /// @notice View the uri for a Hat
    /// @param id The id of the Hat
    /// @return string An 1155-compatible JSON object
    function uri(uint256 id) public view override returns (string memory) {
        return _constructURI(uint256(id));
    }
}
