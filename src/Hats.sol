// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import "./HatsConditions/IHatsConditions.sol";
import "./HatsOracles/IHatsOracle.sol";
import "utils/BASE64.sol";

/// @title Hats Protocol
/// @notice Hats are DAO-native revocable roles that are represented as semi-fungable tokens for composability
/// @dev This contract can manage all Hats for a given chain
/// @author Hats Protocol
contract Hats is ERC1155 {
    /*//////////////////////////////////////////////////////////////
                              HATS ERRORS
    //////////////////////////////////////////////////////////////*/

    // QUESTION should we add arguments to any of these errors? See github issue #21
    error HatNotActive();
    error NotAdmin();
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

    /*//////////////////////////////////////////////////////////////
                              HATS DATA MODELS
    //////////////////////////////////////////////////////////////*/

    struct Hat {
        // 1st storage slot
        address oracle; // can revoke Hat based on ruling; 20 bytes (+20)
        uint32 maxSupply; // the max number of identical hats that can exist; 24 bytes (+4)
        bool active; // can be altered by conditions, via deactivateHat(); 25 bytes (+1)
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
    mapping(uint256 => Hat) public hats;

    // string public baseImageURI = "https://images.hatsprotocol.xyz/"

    mapping(uint256 => uint32) public hatSupply; // key: hatId => value: supply

    // for external contracts to check if Hat was revoked because the wearer is in bad standing
    mapping(uint256 => mapping(address => bool)) public badStandings; // key: hatId => value: (key: wearer => value: badStanding?)

    // QUESTION do we need to store Hat wearing history on-chain? In other words, do other contracts need access to said history? See github issue #12.

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

    event HatRevoked(uint256 hatId, address wearer);

    event HatStatusChanged(uint256 hatId, bool newStatus);

    // event HatSupplyChanged(uint256 hatId, uint256 newSupply);

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

        createHat(
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
            revert NotAdmin();
        }
        if (uint8(_admin) > 0) {
            revert MaxTreeDepthReached();
        }

        newHatId = _buildNextId(_admin);
        // create the new hat
        _createHat(newHatId, _details, _maxSupply, _oracle, _conditions);
    }

    function _buildNextId(uint256 _admin) internal returns (uint256) {
        uint8 nextHatId = hats[_admin].lastHatId++;

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

    /// @notice Creates a tree new Hats, where the root Hat is under admin control by the msg.sender. Especially useful for forking an existing Hat tree or initiating a template Hat tree structure.
    /// @dev The admin for each Hat must exist before the Hat is created, so Hats must be created before Hats for which they serve as admin
    /// @param _details Descriptions of the Hats
    /// @param _maxSupplies The total instances of the Hats that can be worn at once
    /// @param _firstAdmin The hatId of the admin of the first Hat to create; it must already exist
    /// @param _oracles The addresses that can report on the Hat wearers' status
    /// @param _conditions The addresses that can deactivate the Hats
    function createHatsTree(
        string[] memory _details,
        uint32[] memory _maxSupplies,
        uint256 _firstAdmin,
        address[] memory _oracles,
        address[] memory _conditions
    ) public {
        // check that array lengths match
        uint256 length = _maxSupplies.length; // saves an MLOAD

        bool lengthsCheck = ((_details.length == length) &&
            (length == _oracles.length) &&
            (length == _conditions.length));

        if (!lengthsCheck) {
            revert BatchArrayLengthMismatch();
        }

        // TODO reimplement
    }

    /// @notice Mints an ERC1155 token of the Hat to a recipient, who then "wears" the hat
    /// @dev The msg.sender must wear the admin Hat of `_hatId`
    /// @param _hatId The id of the Hat to mint
    /// @param _wearer The address to which the Hat is minted
    /// @return bool Whether the mint succeeded
    function mintHat(uint256 _hatId, address _wearer) public returns (bool) {
        Hat memory hat = hats[_hatId];
        // only the wearer of a hat's admin Hat can mint it
        if (isAdminOfHat(msg.sender, _hatId)) {
            revert NotAdmin();
        }

        if (hatSupply[_hatId] >= hat.maxSupply) {
            revert AllHatsWorn();
        }

        _mint(_wearer, uint256(_hatId), 1, "");

        return true;
    }

    /// @notice Mints a batch of ERC1155 tokens representing Hats to a set of recipients, who each then "wears" their respective Hat
    /// @dev The msg.sender must serve as the admin for each of the Hats in `_hatIds`
    /// @param _hatIds The ids of the Hats to mint
    /// @param _wearers The addresses to which the Hats are minted
    /// @return bool Whether the mints succeeded
    function batchMintHats(uint256[] memory _hatIds, address[] memory _wearers)
        public
        returns (bool)
    {
        uint256 length = _hatIds.length;
        if (length != _wearers.length) {
            revert BatchArrayLengthMismatch();
        }

        for (uint256 i = 0; i < length; ++i) {
            uint256 hatId = _hatIds[i];

            mintHat(hatId, _wearers[i]); // QUESTION if this fails, how do mint revert errors bubble up here, if at all? See github issue #22
        }

        return true;
    }

    /// @notice Toggles a Hat's status from active to deactive, or vice versa
    /// @dev The msg.sender must be set as the hat's Conditions
    /// @param _hatId The id of the Hat for which to adjust status
    /// @return bool Whether the status was toggled
    function changeHatStatus(uint256 _hatId, bool newStatus)
        external
        returns (bool)
    {
        Hat storage hat = hats[_hatId];

        if (msg.sender != hat.conditions) {
            revert NotHatConditions();
        }

        if (newStatus != hat.active) {
            hat.active = newStatus;
            emit HatStatusChanged(_hatId, newStatus);
            return true;
        } else return false;
    }

    /// @notice Checks a hat's Conditions and, if new, toggle's the hat's status
    /// @dev // TODO
    /// @param _hatId The id of the Hat whose Conditions we are checking
    /// @return bool Whether the check succeeded
    function checkConditions(uint256 _hatId) external returns (bool) {
        Hat storage hat = hats[_hatId];

        IHatsConditions CONDITIONS = IHatsConditions(hat.conditions);

        // FIXME what happens if CONDITIONS doesn't have a checkConditions() function?
        // likely answer: the whole thing reverts, which is actually what we want
        bool newStatus = CONDITIONS.checkConditions(_hatId);

        if (newStatus != hat.active) {
            hat.active = newStatus;
            emit HatStatusChanged(_hatId, newStatus);
            return true;
        } else return false;
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
        Hat memory hat = hats[_hatId];

        if (msg.sender != hat.oracle) {
            revert NotHatOracle();
        }

        if (_revoke) {
            _revokeHat(_hatId, _wearer, _wearerStanding);
        }

        emit WearerStatus(_hatId, _wearer, _revoke, _wearerStanding);

        return true;
    }

    /// @notice Check a hat's Oracle for a report on the status of one of the hat's wearers and, if `false`, revoke their hat
    /// @dev Burns the wearer's hat, if revoked
    /// @param _hatId The id of the hat
    /// @param _wearer The address of the Hat wearer whose status report is being requested
    function getHatWearerStatus(uint256 _hatId, address _wearer)
        public
        returns (bool revoke, bool wearerStanding)
    {
        Hat memory hat = hats[_hatId];
        IHatsOracle ORACLE = IHatsOracle(hat.oracle);

        // FIXME what happens if ORACLE doesn't have a getWearerStatus() function?
        // likely answer: the whole thing reverts, which is actually what we want
        (revoke, wearerStanding) = ORACLE.getWearerStatus(_wearer, _hatId);

        if (revoke) {
            _revokeHat(_hatId, _wearer, wearerStanding);
        }

        emit WearerStatus(_hatId, _wearer, revoke, wearerStanding);
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
        hats[_id] = hat;

        // may also need to add to mapping

        emit HatCreated(_id, _details, _maxSupply, _oracle, _conditions);
    }

    /// @notice Internal call to revoke a Hat from a wearer
    /// @dev Burns the wearer's Hat token
    /// @param _hatId The id of the Hat to revoke
    /// @param _wearer The address of the wearer from whom to revoke the hat
    /// @param _wearerStanding Whether or to make a record of the revocation on-chain for other contracts to use
    function _revokeHat(
        uint256 _hatId,
        address _wearer,
        bool _wearerStanding
    ) internal {
        // revoke the Hat by burning it
        _burn(_wearer, _hatId, 1);

        if (_wearerStanding) {
            // record revocation for use by other contracts
            badStandings[_hatId][_wearer] = true;
        }

        // emit HatRevoked(_hatId, _wearer);
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

        //TODO Adjust balances
        //--_balanceOf[_from][id];
        //++_balanceOf[_to][id];

        emit TransferSingle(msg.sender, _from, _to, id, 1);
    }

    function batchTransferHats(
        uint256[] memory _hatIds,
        address[] memory _froms,
        address[] memory _tos
    ) external {
        uint256 length = _hatIds.length;
        bool lengthsCheck = ((_froms.length == length) &&
            (length == _tos.length));

        if (!lengthsCheck) {
            revert BatchArrayLengthMismatch();
        }

        for (uint256 i = 0; i < length; ) {
            transferHat(_hatIds[i], _froms[i], _tos[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              HATS VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice View the properties of a given Hat
    /// @param _hatId The id of the Hat
    /// @return details The details of the Hat
    /// @return id The id of the Hat
    /// @return maxSupply The max supply of tokens for this Hat
    /// @return supply The number of current wearers of this Hat
    /// @return oracle The Oracle address for this Hat
    /// @return conditions The Conditions address for this Hat
    /// @return active Whether the Hat is current active, as read from `_isActive`
    function viewHat(uint256 _hatId)
        public
        view
        returns (
            string memory details,
            uint256 id,
            uint32 maxSupply,
            uint32 supply,
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
        oracle = hat.oracle;
        conditions = hat.conditions;
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

        uint8 adminHatLevel = getHatLevel(_hatId);

        while (adminHatLevel >= 0) {
            if (isWearerOfHat(_user, getAdminAtLevel(_hatId, adminHatLevel))) {
                return true;
            }
            adminHatLevel--;
        }
        return false;
    }

    function getHatLevel(uint256 _hatId) public pure returns (uint8 level) {
        // TODO: invert the order for optimization
        if (_hatId < 2**8) return 28;
        if (_hatId < 2**16) return 27;
        if (_hatId < 2**24) return 26;
        if (_hatId < 2**32) return 25;
        if (_hatId < 2**40) return 24;
        if (_hatId < 2**48) return 23;
        if (_hatId < 2**56) return 22;
        if (_hatId < 2**64) return 21;
        if (_hatId < 2**72) return 20;
        if (_hatId < 2**80) return 19;
        if (_hatId < 2**88) return 18;
        if (_hatId < 2**96) return 17;
        if (_hatId < 2**104) return 16;
        if (_hatId < 2**112) return 15;
        if (_hatId < 2**120) return 14;
        if (_hatId < 2**128) return 13;
        if (_hatId < 2**136) return 12;
        if (_hatId < 2**144) return 11;
        if (_hatId < 2**152) return 10;
        if (_hatId < 2**160) return 9;
        if (_hatId < 2**168) return 8;
        if (_hatId < 2**176) return 7;
        if (_hatId < 2**184) return 6;
        if (_hatId < 2**192) return 5;
        if (_hatId < 2**200) return 4;
        if (_hatId < 2**208) return 3;
        if (_hatId < 2**216) return 2;
        if (_hatId < 2**224) return 1;
        return 0;
    }

    function getAdminAtLevel(uint256 _hatId, uint8 _level)
        public
        pure
        returns (uint256 admin)
    {
        return uint256(_hatId - 2**(8 * (28 - _level)) - 1);
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
        IHatsConditions CONDITIONS = IHatsConditions(_hat.conditions);

        return (CONDITIONS.checkConditions(_hatId) && _hat.active);

        try CONDITIONS.checkConditions(_hatId) returns (bool status_) {
            active = status_;
        } catch {
            // if the external call reverts, default to the existing state
            active = _hat.active;
        }
    }

    /// @notice Checks the active status of a hat
    /// @dev Use `_isActive` for internal calls that can take a Hat as a param
    /// @param _hatId The id of the hat
    /// @return bool The active status of the hat
    function isActive(uint256 _hatId) public view returns (bool) {
        Hat memory hat = hats[_hatId];
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
    ) public view returns (bool standing) {
        IHatsOracle ORACLE = IHatsOracle(_hat.oracle);

        try ORACLE.getWearerStatus(_wearer, _hatId) returns (
            bool revoke_,
            bool standing_
        ) {
            standing = standing_;
        } catch {
            // if the external call reverts, default to the existing state
            standing = badStandings[_hatId][_wearer];
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
        Hat memory hat = hats[_hatId];
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
        Hat memory hat = hats[_hatId];

        bytes memory properties = abi.encodePacked(
            '{"current supply": "',
            hatSupply[_hatId],
            '", "supply cap": "',
            hat.maxSupply,
            '", "admin (hat)": "',
            getAdminAtLevel(_hatId, getHatLevel(_hatId) - 1),
            '", "oracle (address)": "',
            hat.oracle,
            '", "conditions (address)": "',
            hat.conditions,
            '"}'
        );
        string memory status = (_isActive(hat, _hatId) ? "active" : "inactive");

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
        Hat memory hat = hats[hatId];

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
        //_balanceOf[to][id] += amount;

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
        //_balanceOf[from][id] -= amount;

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
