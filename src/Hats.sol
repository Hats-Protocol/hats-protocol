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

    // QUESTION should we add arguments to any of these errors?
    error HatNotActive();
    error NotAdmin();
    error AllHatsWorn();
    error AlreadyWearingHat();
    error NoApprovalsNeeded();
    error OnlyAdminsCanTransfer();
    error CannotTransferMultiple();
    error NotHatWearer();
    error NotHatConditions();
    error NotHatOracle();
    error BatchArrayLengthMismatch();

    /*//////////////////////////////////////////////////////////////
                              HATS DATA MODELS
    //////////////////////////////////////////////////////////////*/

    struct Hat {
        // 1st storage slot
        address oracle; // can revoke Hat based on ruling; 20 bytes (+20)
        uint64 id; // will be used as the 1155 token ID; 28 bytes (+8)
        uint32 maxSupply; // the max number of identical hats that can exist; 32 bytes (+4)
        // 2nd storage slot
        address conditions; // controls when Hat is active; 20 bytes (+20)
        uint64 admin; // controls who wears this hat; 28 bytes (+8)
        bool active; // can be altered by conditions, via deactivateHat(); 29 bytes (+1)
        // 3rd+ storage slot
        string details;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS STORAGE
    //////////////////////////////////////////////////////////////*/

    uint64 public nextHatId; // initialized at 0

    Hat[] private hats; // can retrieve Hat info via viewHat(hatId) or via uri(hatId);

    mapping(uint64 => uint32) public hatSupply; // key: hatId => value: supply

    // for external contracts to check if Hat was reounced or revoked
    mapping(uint64 => mapping(address => bool)) public revocations; // key: hatId => value: (key: wearer => value: revoked?)

    // QUESTION do we need to store Hat wearing history on-chain? In other words, do other contracts need access to said history? See github issue #12.

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

    /// @notice Creates and mints a Hat that is its own admin, i.e. a "topHat"
    /// @dev A topHat has no oracle and no conditions
    /// @param _target The address to which the newly created topHat is minted
    /// @return topHatId The id of the newly created topHat
    function mintTopHat(address _target) public returns (uint64 topHatId) {
        // create hat

        topHatId = createHat(
            "", // details
            1, // maxSupply = 1
            nextHatId, // a topHat is its own admin
            address(0), // there is no oracle
            address(0) // it has no conditions
        );

        _mintHat(nextHatId, _target);

        return topHatId;
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
    ) public returns (uint64 topHatId, uint64 firstHatId) {
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

    /// @notice Creates a new hat. The msg.sender must wear the `_admin` hat.
    /// @dev Initializes a new Hat struct, but does not mint any tokens.
    /// @param _details A description of the Hat
    /// @param _maxSupply The total instances of the Hat that can be worn at once
    /// @param _admin The id of the Hat that will control who wears the newly created hat
    /// @param _oracle The address that can report on the Hat wearer's standing
    /// @param _conditions The address that can deactivate the Hat
    /// @return newHatId The id of the newly created Hat
    function createHat(
        string memory _details, // encode as bytes32 ??
        uint32 _maxSupply,
        uint64 _admin, // hatId
        address _oracle,
        address _conditions
    ) public returns (uint64 newHatId) {
        // to create a hat, you must be wearing the Hat of its admin
        if (!isWearerOfHat(msg.sender, _admin)) {
            revert NotAdmin();
        }

        // create the new hat
        newHatId = _createHat(
            _details,
            _maxSupply,
            _admin,
            _oracle,
            _conditions
        );
    }

    /// @notice Creates a tree new Hats, where the root Hat is under admin control by the msg.sender. Especially useful for forking an existing Hat tree or initiating a template Hat tree structure.
    /// @dev The admin for each Hat must exist before the Hat is created, so Hats must be created before Hats for which they serve as admin
    /// @param _details Descriptions of the Hats
    /// @param _maxSupplies The total instances of the Hats that can be worn at once
    /// @param _firstAdmin The hatId of the admin of the first Hat to create; it must already exist
    /// @param _adminOffsets The deltas between the ids of the Hats that will control who wears the newly created hat
    /// @param _oracles The addresses that can report on the Hat wearers' standings
    /// @param _conditions The addresses that can deactivate the Hats
    function createHatsTree(
        string[] memory _details,
        uint32[] memory _maxSupplies,
        uint64 _firstAdmin,
        uint64[] memory _adminOffsets, // _adminOffsets.length + 1 = _details.length
        address[] memory _oracles,
        address[] memory _conditions
    ) public {
        // check that array lengths match
        uint256 length = _maxSupplies.length; // saves an MLOAD

        bool lengthsCheck = ((_details.length == length) &&
            (length == _adminOffsets.length + 1) &&
            (length == _oracles.length) &&
            (length == _conditions.length));

        if (!lengthsCheck) {
            revert BatchArrayLengthMismatch();
        }

        // create a new Hat for each qualifying item
        for (uint256 i = 0; i < length; ++i) {
            // calculate the admin id for this Hat
            uint64 admin;
            if (i == 0) {
                // first Hat created gets the _firstAdmin
                admin = _firstAdmin;
            } else {
                /* subsequent Hats are assigned admins based on an offset.
                Example: if nextHatId is 10, and the admin of the next Hat we want to create is id 8, then the offset would be 2.
                */
                admin = nextHatId - _adminOffsets[i - 1];
            }

            /* Only create the new Hat if it would not be a topHat (a Hat that is its own admin) and if the msg.sender serves as its admin, otherwise skip to the next item.
            This requires that Hats must be created prior to any Hat(s) they are an admin for.
            */
            if ((admin != nextHatId) && isWearerOfHat(msg.sender, admin)) {
                _createHat(
                    _details[i],
                    _maxSupplies[i],
                    admin,
                    _oracles[i],
                    _conditions[i]
                );
            }
        }
    }

    /// @notice Mints an ERC1155 token of the Hat to a recipient, who then "wears" the hat
    /// @dev The msg.sender must wear the admin Hat of `_hatId`
    /// @param _hatId The id of the Hat to mint
    /// @param _wearer The address to which the Hat is minted
    /// @return bool Whether the mint succeeded
    function mintHat(uint64 _hatId, address _wearer) external returns (bool) {
        Hat memory hat = hats[_hatId];
        // only the wearer of a hat's admin Hat can mint it
        if (isAdminOfHat(msg.sender, hat.admin)) {
            revert NotAdmin();
        }

        if (hatSupply[_hatId] >= hat.maxSupply) {
            revert AllHatsWorn();
        }

        _mintHat(_hatId, _wearer);

        return true;
    }

    /// @notice Mints a batch of ERC1155 tokens representing Hats to a set of recipients, who each then "wears" their respective Hat
    /// @dev The msg.sender must serve as the admin for each of the Hats in `_hatIds`
    /// @param _hatIds The ids of the Hats to mint
    /// @param _wearers The addresses to which the Hats are minted
    /// @return bool Whether the mints succeeded
    function batchMintHats(uint64[] memory _hatIds, address[] memory _wearers)
        public
        returns (bool)
    {
        // create an array of equal length to _hatIds with 1s
        uint256 length = _hatIds.length;
        uint256[] memory amounts;

        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = 1;
        }

        _batchMintHats(_wearers, _hatIds, amounts, "");

        return true;
    }

    /// @notice Deactivates a hat
    /// @dev The msg.sender must be set as the hat's Conditions
    /// @param _hatId The id of the Hat to deactivate
    /// @return bool Whether the deactivation succeeded
    function deactivateHat(uint64 _hatId) external returns (bool) {
        Hat storage hat = hats[_hatId];

        if (msg.sender != hat.conditions) {
            revert NotHatConditions();
        }

        hat.active = false;

        return true;
    }

    /// @notice Checks a hat's Conditions and, if `false`, deactivates the hat
    /// @dev // TODO
    /// @param _hatId The id of the Hat whose Conditions we are checking
    /// @return bool Whether the check succeeded
    function checkConditions(uint64 _hatId) external returns (bool) {
        Hat storage hat = hats[_hatId];

        IHatsConditions CONDITIONS = IHatsConditions(hat.conditions);

        bool status = CONDITIONS.checkConditions(_hatId); // FIXME what happens if CONDITIONS doesn't have a checkConditions() function?

        if (!status) {
            hat.active = false;
        }

        return true;
    }

    /// @notice Report from a hat's Oracle on the standing of one of its wearers and, if `false`, revoke their hat
    /// @dev Burns the wearer's hat, if revoked
    /// @param _hatId The id of the hat
    /// @param _wearer The address of the Hat wearer whose standing is being reported
    /// @return bool Whether the report succeeded
    function ruleOnHatWearerStanding(
        uint64 _hatId,
        address _wearer,
        bool _ruling // return false if the wearar is not fulfilling the duties of the hat
    ) external returns (bool) {
        Hat memory hat = hats[_hatId];

        if (msg.sender != hat.oracle) {
            revert NotHatOracle();
        }

        if (!_ruling) {
            _revokeHat(_hatId, _wearer);
        }

        emit Ruling(_hatId, _wearer, _ruling);

        return true;
    }

    /// @notice Check a hat's Oracle for a report on the standing of one of the hat's wearers and, if `false`, revoke their hat
    /// @dev Burns the wearer's hat, if revoked
    /// @param _hatId The id of the hat
    /// @param _wearer The address of the Hat wearer whose standing ruling is being request
    function checkHatWearerStanding(uint64 _hatId, address _wearer)
        public
        returns (bool)
    {
        Hat memory hat = hats[_hatId];
        IHatsOracle ORACLE = IHatsOracle(hat.oracle);

        bool ruling = ORACLE.checkWearerStanding(_wearer, _hatId); // FIXME what happens if ORACLE doesn't have a checkWearerStanding() function?

        if (!ruling) {
            _revokeHat(_hatId, _wearer);
        }

        emit Ruling(_hatId, _wearer, ruling);

        return ruling;
    }

    /// @notice Stop wearing a hat, aka "renounce" it
    /// @dev Burns the msg.sender's hat
    /// @param _hatId The id of the Hat being renounced
    function renounceHat(uint64 _hatId) external {
        if (!isWearerOfHat(msg.sender, _hatId)) {
            revert NotHatWearer();
        }
        // remove the hat
        _burnHat(_hatId, msg.sender);

        emit HatRenounced(_hatId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                              HATS INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal call for creating a new hat
    /// @dev Initializes a new Hat struct, but does not mint any tokens
    /// @param _details A description of the hat
    /// @param _maxSupply The total instances of the Hat that can be worn at once
    /// @param _admin The id of the Hat that will control who wears the newly created hat
    /// @param _oracle The address that can report on the Hat wearer's standing
    /// @param _conditions The address that can deactivate the hat
    /// @return hatId The id of the newly created hat
    function _createHat(
        string memory _details, // encode as bytes32 ??
        uint32 _maxSupply,
        uint64 _admin, // hatId
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

    /// @notice Internal call to mint ERC1155 token of the Hat to a recipient, who then "wears" the hat
    /// @dev Mints 1 Hat token, with no data passed to the receiver
    /// @param _hatId The id of the Hat to mint
    /// @param _wearer The address to which the Hat is minted
    function _mintHat(uint64 _hatId, address _wearer) internal {
        _mint(_wearer, _hatId, 1, "");

        // increment Hat supply
        ++hatSupply[_hatId];
    }

    /// @notice Internal call to revoke a Hat from a wearer
    /// @dev Burns the wearer's Hat token
    /// @param _hatId The id of the Hat to revoke
    /// @param _wearer The address of the wearer from whom to revoke the hat
    function _revokeHat(uint64 _hatId, address _wearer) internal {
        // revoke the Hat by burning it
        _burnHat(_hatId, _wearer);

        // record revocation for use by other contracts
        revocations[_hatId][_wearer] = true;
    }

    /// @notice Internal call to burn a wearer's hat
    /// @dev Burns 1 Hat token
    /// @param _hatId The id of the Hat to burn
    /// @param _wearer The address of the wearer who's Hat is being burned
    function _burnHat(uint64 _hatId, address _wearer) internal {
        _burn(_wearer, _hatId, 1);

        // decrement Hat supply
        --hatSupply[_hatId];
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
    /// @return admin The Hat that serves as admin for this Hat
    /// @return oracle The Oracle address for this Hat
    /// @return conditions The Conditions address for this Hat
    /// @return active Whether the Hat is current active, as read from `_isActive`
    function viewHat(uint64 _hatId)
        public
        view
        returns (
            string memory details,
            uint64 id,
            uint32 maxSupply,
            uint32 supply,
            uint64 admin,
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

    /// @notice Internal call to check whether a Hat is a topHat
    /// @dev For use when passing a Hat object is appropriate
    /// @param hat The Hat in question
    /// @return bool Whether the Hat is a topHat
    function _isTopHat(Hat memory hat) internal pure returns (bool) {
        // a topHat is a Hat that is its own admin
        return (hat.id == hat.admin);
    }

    /// @notice Chcecks whether a Hat is a topHat
    /// @dev For use when passing a Hat object is not appropriate
    /// @param _hatId The Hat in question
    /// @return bool Whether the Hat is a topHat
    function isTopHat(uint64 _hatId) public view returns (bool) {
        Hat memory hat = hats[_hatId];
        return _isTopHat(hat);
    }

    /// @notice Checks whether a given address wears a given Hat
    /// @dev Convenience function that wraps `balanceOf`
    /// @param _user The address in question
    /// @param _hatId The id of the Hat that the `_user` might wear
    /// @return bool Whether the `_user` wears the Hat.
    function isWearerOfHat(address _user, uint64 _hatId)
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
    function isAdminOfHat(address _user, uint64 _hatId)
        public
        view
        returns (bool)
    {
        Hat memory hat = hats[_hatId];

        // if Hat is a topHat, then the _user cannot be the admin
        if (_isTopHat(hat)) {
            return false;
        }

        if (isWearerOfHat(_user, hat.admin)) {
            return true;
        } else {
            // recursion
            return isAdminOfHat(_user, hat.admin);
        }
    }

    /// @notice Checks the active status of a hat
    /// @dev For internal use instead of `isActive` when passing Hat as param is preferable
    /// @param _hat The Hat struct
    /// @return bool The active status of the hat
    // FIXME need to figure out all the permutations
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

    /// @notice Checks the active status of a hat
    /// @dev Use `_isActive` for internal calls that can take a Hat as a param
    /// @param _hatId The id of the hat
    /// @return bool The active status of the hat
    function isActive(uint64 _hatId) public view returns (bool) {
        Hat memory hat = hats[_hatId];
        return _isActive(hat);
    }

    /// @notice Internal call to check whether a wearer of a Hat is in good standing
    /// @dev // TODO
    /// @param _hat The Hat object
    /// @param _wearer The address of the Hat wearer
    /// @return bool Whether the wearer is in good standing
    function _isInGoodStanding(address _wearer, Hat memory _hat)
        public
        view
        returns (bool)
    {
        IHatsOracle ORACLE = IHatsOracle(_hat.oracle);
        return (ORACLE.checkWearerStanding(_wearer, _hat.id)); // FIXME what happens if ORACLE doesn't have a checkWearerStanding() function?
    }

    /// @notice Checks whether a wearer of a Hat is in good standing
    /// @dev // TODO
    /// @param _hatId The id of the Hat
    /// @param _wearer The address of the Hat wearer
    /// @return bool
    function isInGoodStanding(address _wearer, uint64 _hatId)
        public
        view
        returns (bool)
    {
        Hat memory hat = hats[_hatId];
        return _isInGoodStanding(_wearer, hat);
    }

    /// @notice Constructs the URI for a Hat, using data from the Hat struct
    /// @param _hatId The id of the Hat
    /// @return uri_ An ERC1155-compatible JSON string
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

    /// @notice Gets the Hat token balance of a user for a given Hat
    /// @param wearer The address whose balance is being checked
    /// @param id The id of the Hat
    /// @return balance The `_user`'s balance of the Hat tokens. Will typically not be greater than 1.
    function balanceOf(address wearer, uint256 id)
        public
        view
        override
        returns (uint256 balance)
    {
        uint64 hatId = uint64(id); // QUESTION do we need to cast this? what happens if it overflows?
        Hat memory hat = hats[hatId];

        balance = 0;

        if (_isActive(hat) && _isInGoodStanding(wearer, hat)) {
            balance = super.balanceOf(wearer, hatId);
        }

        return balance;
    }

    /// @notice overloads ERC1155._batchMint to add Hats-specific checks and state changes
    function _batchMintHats(
        address[] memory tos,
        uint64[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ++i) {
            uint64 hatId = uint64(ids[i]);
            Hat memory hat = hats[hatId];

            if (isAdminOfHat(msg.sender, hat.admin)) {
                revert NotAdmin();
            }

            if (hatSupply[hatId] >= hat.maxSupply) {
                revert AllHatsWorn();
            }

            _balanceOf[tos[i]][ids[i]] += amounts[i];

            ++hatSupply[hatId];
        }

        // FIXME
        // emit TransferBatch(msg.sender, address(0), tos, ids, amounts);
    }

    function setApprovalForAll(address operator, bool approved)
        public
        pure
        override
    {
        revert NoApprovalsNeeded();
    }

    /// @notice Transfers a Hat token to a new wearer; if called by the Hat's admin
    /// @dev Skips the typical 1155TokenReceiver hook since Hat wearers don't control their own Hat
    /// @param from The old wearer of the Hat
    /// @param to The new wearer of the Hat
    /// @param id The id of the Hat to transfer
    /// @param amount Must always be 1, since it's not possible wear >1 Hat
    /// @param data Should be empty since we skip the 1155TokenReceiver hook
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public override {
        if (!isAdminOfHat(msg.sender, uint64(id))) {
            revert OnlyAdminsCanTransfer();
        }

        if (amount > 1) {
            revert CannotTransferMultiple();
        }

        // Checks storage instead of `isWearerOfHat` since admins may want to transfer revoked Hats to new wearers
        if (_balanceOf[from][id] < 1) {
            revert NotHatWearer();
        }

        _balanceOf[from][id] -= amount;
        _balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    /// @notice Transfer a batch of Hat tokens to new wearers, if called by a given Hat's admin
    /// @dev Skips the typical 1155TokenReceiver hook since Hat wearers don't control their own Hat
    /// @param from The old wearers of the Hats
    /// @param to The new wearers of the Hats
    /// @param ids The ids of the Hats to transfer
    /// @param amounts Must always be 1, since it's not possible wear >1 Hat
    /// @param data Should be empty since we skip the 1155TokenReceiver hook
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public override {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = uint64(ids[i]);
            amount = amounts[i];
            if (
                !isAdminOfHat(msg.sender, uint64(id)) ||
                amount > 1 ||
                _balanceOf[from][id] < 1
            ) {
                // An array can't have a total length
                // larger than the max uint256 value.
                unchecked {
                    ++i;
                }
            }
            // Checks storage instead of `isWearerOfHat` since admins may want to transfer revoked Hats to new wearers
            else if (_balanceOf[from][id] < 1) {
                unchecked {
                    ++i;
                }
            }

            _balanceOf[from][id] -= amount;
            _balanceOf[to][id] += amount;

            unchecked {
                ++i;
            }

            emit TransferBatch(msg.sender, from, to, ids, amounts);
        }
    }

    /// @notice View the uri for a Hat
    /// @param id The id of the Hat
    /// @return string An 1155-compatible JSON object
    function uri(uint256 id) public view override returns (string memory) {
        return _constructURI(uint64(id));
    }
}
