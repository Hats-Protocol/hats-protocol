// Copyright (C) 2022 Hats Protocol
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.8.13;

import {ERC1155} from "ERC1155/ERC1155.sol";
// import "forge-std/Test.sol"; //remove after testing
import "./Interfaces/IHats.sol";
import "./HatsIdUtilities.sol";
import "./HatsToggle/IHatsToggle.sol";
import "./HatsEligibility/IHatsEligibility.sol";
import "solbase/utils/Base64.sol";
import "solbase/utils/LibString.sol";

/// @title Hats Protocol
/// @notice Hats are DAO-native revocable roles that are represented as semi-fungable tokens for composability
/// @dev This is a multitenant contract that can manage all Hats for a given chain
/// @author Hats Protocol
contract Hats is IHats, ERC1155, HatsIdUtilities {
    /*//////////////////////////////////////////////////////////////
                              HATS DATA MODELS
    //////////////////////////////////////////////////////////////*/

    struct Hat {
        // 1st storage slot
        address eligibility; // ─┐ can revoke Hat based on ruling | 20
        uint32 maxSupply; //     │ the max number of identical hats that can exist | 4
        uint16 lastHatId; //    ─┘ indexes how many different hats an admin is holding | 1
        // 2nd slot
        address toggle; // ─┐ controls when Hat is active | 20
        uint96 config; //  ─┘ active status & other settings (see schema below) | 12
        // 3rd+ slot (optional)
        string details;
        string imageURI;
    }

    /* Hat.config schema (by bit)
     *  0th bit  | `active` status; can be altered by toggle, via setHatStatus()
     *  1        | `mutable` option
     *  2 - 95   | unassigned
     */

    /*//////////////////////////////////////////////////////////////
                              HATS STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    uint32 public lastTopHatId; // initialized at 0

    string public baseImageURI;

    // see HatsIdUtilities.sol for more info on how Hat Ids work
    mapping(uint256 => Hat) internal _hats; // key: hatId => value: Hat struct

    mapping(uint256 => uint32) public hatSupply; // key: hatId => value: supply

    // for external contracts to check if Hat was revoked because the wearer is in bad standing
    mapping(uint256 => mapping(address => bool)) public badStandings; // key: hatId => value: (key: wearer => value: badStanding?)

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _baseImageURI) {
        name = _name;
        baseImageURI = _baseImageURI;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates and mints a Hat that is its own admin, i.e. a "topHat"
    /// @dev A topHat has no eligibility and no toggle
    /// @param _target The address to which the newly created topHat is minted
    /// @param _imageURI The image uri for this top hat and the fallback for its
    ///                  downstream hats [optional]
    /// @return topHatId The id of the newly created topHat
    function mintTopHat(
        address _target,
        string memory _details,
        string memory _imageURI
    ) public returns (uint256 topHatId) {
        // create hat

        topHatId = uint256(++lastTopHatId) << 224;

        _createHat(
            topHatId,
            _details, // details
            1, // maxSupply = 1
            address(0), // there is no eligibility
            address(0), // it has no toggle
            false, // its immutable
            _imageURI
        );

        _mint(_target, topHatId, 1, "");
    }

    // /// @notice Mints a topHat to the msg.sender and creates another Hat admin'd by the topHat
    // /// @param _details A description of the hat
    // /// @param _maxSupply The total instances of the Hat that can be worn at once
    // /// @param _eligibility The address that can report on the Hat wearer's standing
    // /// @param _toggle The address that can deactivate the hat [optional]
    // /// @param _mutable Whether the hat's properties are changeable after creation
    // /// @param _topHatImageURI The image uri for this top hat and the fallback for its
    // ///                        downstream hats [optional]
    // /// @param _firstHatImageURI The image uri for the first hat and the fallback for its
    // ///                        downstream hats [optional]
    // /// @return topHatId The id of the newly created topHat
    // /// @return firstHatId The id of the other newly created hat
    // function createTopHatAndHat(
    //     string memory _details, // encode as bytes32 ??
    //     uint32 _maxSupply,
    //     address _eligibility,
    //     address _toggle,
    //     bool _mutable,
    //     string memory _topHatImageURI,
    //     string memory _firstHatImageURI
    // ) public returns (uint256 topHatId, uint256 firstHatId) {
    //     topHatId = mintTopHat(msg.sender, _topHatImageURI);

    //     firstHatId = createHat(
    //         topHatId,
    //         _details,
    //         _maxSupply,
    //         _eligibility,
    //         _toggle,
    //         _mutable,
    //         _firstHatImageURI
    //     );
    // }

    /// @notice Creates a new hat. The msg.sender must wear the `_admin` hat.
    /// @dev Initializes a new Hat struct, but does not mint any tokens.
    /// @param _details A description of the Hat
    /// @param _maxSupply The total instances of the Hat that can be worn at once
    /// @param _admin The id of the Hat that will control who wears the newly created hat
    /// @param _eligibility The address that can report on the Hat wearer's status
    /// @param _toggle The address that can deactivate the Hat
    /// @param _mutable Whether the hat's properties are changeable after creation
    /// @param _imageURI The image uri for this hat and the fallback for its
    ///                  downstream hats [optional]
    /// @return newHatId The id of the newly created Hat
    function createHat(
        uint256 _admin,
        string memory _details, // encode as bytes32 ??
        uint32 _maxSupply,
        address _eligibility,
        address _toggle,
        bool _mutable,
        string memory _imageURI
    ) public returns (uint256 newHatId) {
        if (uint8(_admin) > 0) {
            revert MaxLevelsReached();
        }

        newHatId = getNextId(_admin);

        // to create a hat, you must be wearing one of its admin hats
        _checkAdmin(newHatId);

        // create the new hat
        _createHat(
            newHatId,
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            _mutable,
            _imageURI
        );

        // increment _admin.lastHatId
        ++_hats[_admin].lastHatId;
    }

    /// @notice Creates new hats in batch. The msg.sender must be an admin of each hat.
    /// @dev This is a convenience function that loops through the arrays and calls `createHat`.
    /// @param _admins Array of ids of admins for each hat to create
    /// @param _details Array of details for each hat to create
    /// @param _maxSupplies Array of supply caps for each hat to create
    /// @param _eligibilityModules Array of eligibility module addresses for each hat to
    /// create
    /// @param _toggleModules Array of toggle module addresses for each hat to create
    /// @param _imageURIs Array of imageURIs for each hat to create
    /// @return bool True if all createHat calls succeeded
    function batchCreateHats(
        uint256[] memory _admins,
        string[] memory _details,
        uint32[] memory _maxSupplies,
        address[] memory _eligibilityModules,
        address[] memory _toggleModules,
        bool[] memory _mutables,
        string[] memory _imageURIs
    ) public returns (bool) {
        // check if array lengths are the same
        uint256 length = _admins.length; // save an MLOAD

        bool sameLengths = (length == _details.length &&
            length == _maxSupplies.length &&
            length == _eligibilityModules.length &&
            length == _toggleModules.length &&
            length == _mutables.length &&
            length == _imageURIs.length);

        if (!sameLengths) revert BatchArrayLengthMismatch();

        // loop through and create each hat
        for (uint256 i = 0; i < length; ++i) {
            createHat(
                _admins[i],
                _details[i],
                _maxSupplies[i],
                _eligibilityModules[i],
                _toggleModules[i],
                _mutables[i],
                _imageURIs[i]
            );
        }

        return true;
    }

    function getNextId(uint256 _admin) public view returns (uint256) {
        uint16 nextHatId = _hats[_admin].lastHatId + 1;
        return buildHatId(_admin, nextHatId);
    }

    /// @notice Mints an ERC1155 token of the Hat to a recipient, who then "wears" the hat
    /// @dev The msg.sender must wear the admin Hat of `_hatId`
    /// @param _hatId The id of the Hat to mint
    /// @param _wearer The address to which the Hat is minted
    /// @return bool Whether the mint succeeded
    function mintHat(uint256 _hatId, address _wearer) public returns (bool) {
        Hat memory hat = _hats[_hatId];
        if (hat.maxSupply == 0) revert HatDoesNotExist(_hatId);

        // only the wearer of a hat's admin Hat can mint it
        _checkAdmin(_hatId);

        if (hatSupply[_hatId] >= hat.maxSupply) {
            revert AllHatsWorn(_hatId);
        }

        if (isWearerOfHat(_wearer, _hatId)) {
            revert AlreadyWearingHat(_wearer, _hatId);
        }

        _mint(_wearer, uint256(_hatId), 1, "");

        return true;
    }

    function batchMintHats(uint256[] memory _hatIds, address[] memory _wearers)
        public
        returns (bool)
    {
        uint256 length = _hatIds.length;
        if (length != _wearers.length) revert BatchArrayLengthMismatch();

        for (uint256 i = 0; i < length; ++i) {
            mintHat(_hatIds[i], _wearers[i]);
        }

        return true;
    }

    /// @notice Toggles a Hat's status from active to deactive, or vice versa
    /// @dev The msg.sender must be set as the hat's toggle
    /// @param _hatId The id of the Hat for which to adjust status
    /// @return bool Whether the status was toggled
    function setHatStatus(uint256 _hatId, bool newStatus)
        external
        returns (bool)
    {
        Hat storage hat = _hats[_hatId];

        if (msg.sender != hat.toggle) {
            revert NotHatsToggle();
        }

        return _processHatStatus(_hatId, newStatus);
    }

    /// @notice Checks a hat's toggle and, if new, toggle's the hat's status
    /// @dev // TODO
    /// @param _hatId The id of the Hat whose toggle we are checking
    /// @return bool Whether there was a new status
    function checkHatStatus(uint256 _hatId) external returns (bool) {
        Hat memory hat = _hats[_hatId];
        bool newStatus;

        bytes memory data = abi.encodeWithSignature(
            "getHatStatus(uint256)",
            _hatId
        );

        (bool success, bytes memory returndata) = hat.toggle.staticcall(data);

        // if function call succeeds with data of length > 0
        // then we know the contract exists and has the getWearerStatus function
        if (success && returndata.length > 0) {
            newStatus = abi.decode(returndata, (bool));
        } else {
            revert NotHatsToggle();
        }

        return _processHatStatus(_hatId, newStatus);
    }

    /// @notice Report from a hat's eligibility on the status of one of its wearers and, if `false`, revoke their hat
    /// @dev Burns the wearer's hat, if revoked
    /// @param _hatId The id of the hat
    /// @param _wearer The address of the hat wearer whose status is being reported
    /// @param _eligible Whether the wearer is eligible for the hat (will be revoked if
    /// false)
    /// @param _standing False if the wearer is no longer in good standing (and potentially should be penalized)
    /// @return bool Whether the report succeeded
    function setHatWearerStatus(
        uint256 _hatId,
        address _wearer,
        bool _eligible,
        bool _standing
    ) external returns (bool) {
        Hat memory hat = _hats[_hatId];

        if (msg.sender != hat.eligibility) {
            revert NotHatsEligibility();
        }

        _processHatWearerStatus(_hatId, _wearer, _eligible, _standing);

        return true;
    }

    /// @notice Check a hat's eligibility for a report on the status of one of the hat's wearers and, if `false`, revoke their hat
    /// @dev Burns the wearer's hat, if revoked
    /// @param _hatId The id of the hat
    /// @param _wearer The address of the Hat wearer whose status report is being requested
    function checkHatWearerStatus(uint256 _hatId, address _wearer)
        public
        returns (bool)
    {
        Hat memory hat = _hats[_hatId];
        bool eligible;
        bool standing;

        bytes memory data = abi.encodeWithSignature(
            "getWearerStatus(address,uint256)",
            _wearer,
            _hatId
        );

        (bool success, bytes memory returndata) = hat.eligibility.staticcall(
            data
        );

        // if function call succeeds with data of length > 0
        // then we know the contract exists and has the getWearerStatus function
        if (success && returndata.length > 0) {
            (eligible, standing) = abi.decode(returndata, (bool, bool));
        } else {
            revert NotHatsEligibility();
        }

        return _processHatWearerStatus(_hatId, _wearer, eligible, standing);
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

        // emit HatRenounced(_hatId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                              HATS INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal call for creating a new hat
    /// @dev Initializes a new Hat struct, but does not mint any tokens
    /// @param _id ID of the hat to be stored
    /// @param _details A description of the hat
    /// @param _maxSupply The total instances of the Hat that can be worn at once
    /// @param _eligibility The address that can report on the Hat wearer's status
    /// @param _toggle The address that can deactivate the hat [optional]
    /// @param _mutable Whether the hat's properties are changeable after creation
    /// @param _imageURI The image uri for this top hat and the fallback for its
    ///                  downstream hats [optional]
    /// @return hat The contents of the newly created hat
    function _createHat(
        uint256 _id,
        string memory _details, // encode as bytes32 ??
        uint32 _maxSupply,
        address _eligibility,
        address _toggle,
        bool _mutable,
        string memory _imageURI
    ) internal returns (Hat memory hat) {
        hat.details = _details;
        hat.maxSupply = _maxSupply;
        hat.eligibility = _eligibility;
        hat.toggle = _toggle;
        hat.imageURI = _imageURI;
        hat.config = _mutable ? uint96(3 << 94) : uint96(1 << 95);
        _hats[_id] = hat;

        emit HatCreated(
            _id,
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            _mutable,
            _imageURI
        );
    }

    // TODO write comment
    function _processHatStatus(uint256 _hatId, bool _newStatus)
        internal
        returns (bool updated)
    {
        // optimize later
        Hat storage hat = _hats[_hatId];

        if (_newStatus != _getHatStatus(hat)) {
            _setHatStatus(hat, _newStatus);
            emit HatStatusChanged(_hatId, _newStatus);
            updated = true;
        }
    }

    /// @notice Internal call to process wearer status from the eligibility module
    /// @dev Burns the wearer's Hat token if _eligible is false, and updates badStandings
    /// state if necessary
    /// @param _hatId The id of the Hat to revoke
    /// @param _wearer The address of the wearer in question
    /// @param _eligible Whether _wearer is eligible for the Hat (if false, this function
    /// will revoke their Hat)
    /// @param _standing Whether _wearer is in good standing (to be recorded in storage)
    function _processHatWearerStatus(
        uint256 _hatId,
        address _wearer,
        bool _eligible,
        bool _standing
    ) internal returns (bool updated) {
        // revoke/burn the hat if _wearer has a positive balance
        if (_balanceOf[_wearer][_hatId] > 0) {
            // always ineligible if in bad standing
            if (!_eligible || !_standing) {
                _burn(_wearer, _hatId, 1);
            }
        }

        // record standing for use by other contracts
        // note: here, standing and badStandings are opposite
        // i.e. if standing (true = good standing)
        // then badStandings[_hatId][wearer] will be false
        // if they are different, then something has changed, and we need to update
        // badStandings marker
        if (_standing == badStandings[_hatId][_wearer]) {
            badStandings[_hatId][_wearer] = !_standing;
            updated = true;

            emit WearerStandingChanged(_hatId, _wearer, _standing);
        }
    }

    function transferHat(
        uint256 _hatId,
        address _from,
        address _to
    ) public {
        _checkAdmin(_hatId);

        // cannot transfer immutable hats, except for tophats, which can always transfer themselves
        if (!isTopHat(_hatId)) {
            if (!_isMutable(_hats[_hatId])) revert Immutable();
        }

        // Checks storage instead of `isWearerOfHat` since admins may want to transfer revoked Hats to new wearers
        if (_balanceOf[_from][_hatId] < 1) {
            revert NotHatWearer();
        }

        // Check if recipient is already wearing hat; also checks storage to maintain balance == 1 invariant
        if (_balanceOf[_to][_hatId] > 0) {
            revert AlreadyWearingHat(_to, _hatId);
        }

        //Adjust balances
        --_balanceOf[_from][_hatId];
        ++_balanceOf[_to][_hatId];

        emit TransferSingle(msg.sender, _from, _to, _hatId, 1);
    }

    /*//////////////////////////////////////////////////////////////
                              HATS ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _checkAdmin(uint256 _hatId) internal {
        if (!isAdminOfHat(msg.sender, _hatId)) {
            revert NotAdmin(msg.sender, _hatId);
        }
    }

    /// @notice Set a mutable hat to immutable
    /// @dev Sets the second bit of hat.config to 0
    /// @param _hatId The id of the Hat to make immutable
    function makeHatImmutable(uint256 _hatId) external {
        _checkAdmin(_hatId);

        Hat storage hat = _hats[_hatId];

        if (!_isMutable(hat)) {
            revert Immutable();
        }

        hat.config &= ~uint96(1 << 94);

        emit HatMutabilityChanged(_hatId);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable
    /// @param _hatId The id of the Hat to change
    /// @param _newDetails The new details
    function changeHatDetails(uint256 _hatId, string memory _newDetails)
        external
    {
        _checkAdmin(_hatId);
        Hat storage hat = _hats[_hatId];

        if (!_isMutable(hat)) {
            revert Immutable();
        }

        hat.details = _newDetails;

        emit HatDetailsChanged(_hatId, _newDetails);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable
    /// @param _hatId The id of the Hat to change
    /// @param _newEligibility The new eligibility module
    function changeHatEligibility(uint256 _hatId, address _newEligibility)
        external
    {
        _checkAdmin(_hatId);
        Hat storage hat = _hats[_hatId];

        if (!_isMutable(hat)) {
            revert Immutable();
        }

        hat.eligibility = _newEligibility;

        emit HatEligibilityChanged(_hatId, _newEligibility);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable
    /// @param _hatId The id of the Hat to change
    /// @param _newToggle The new toggle module
    function changeHatToggle(uint256 _hatId, address _newToggle) external {
        _checkAdmin(_hatId);
        Hat storage hat = _hats[_hatId];

        if (!_isMutable(hat)) {
            revert Immutable();
        }

        hat.toggle = _newToggle;

        emit HatToggleChanged(_hatId, _newToggle);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable
    /// @param _hatId The id of the Hat to change
    /// @param _newImageURI The new imageURI
    function changeHatImageURI(uint256 _hatId, string memory _newImageURI)
        external
    {
        _checkAdmin(_hatId);
        Hat storage hat = _hats[_hatId];

        if (!_isMutable(hat)) {
            revert Immutable();
        }

        hat.imageURI = _newImageURI;

        emit HatImageURIChanged(_hatId, _newImageURI);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable; new max supply cannot be greater than current supply
    /// @param _hatId The id of the Hat to change
    /// @param _newMaxSupply The new max supply
    function changeHatMaxSupply(uint256 _hatId, uint32 _newMaxSupply) external {
        _checkAdmin(_hatId);
        Hat storage hat = _hats[_hatId];

        if (!_isMutable(hat)) {
            revert Immutable();
        }

        if (_newMaxSupply < hatSupply[_hatId]) {
            revert NewMaxSupplyTooLow();
        }

        hat.maxSupply = _newMaxSupply;

        emit HatMaxSupplyChanged(_hatId, _newMaxSupply);
    }

    /// @notice Nest a Tree structure under a parent tree
    /// @dev The tree root can have at most one link at a given time.
    /// @param _topHatId The domain of the tophat to link
    /// @param _newAdminHat The hat that will administer the linked tree
    function linkTopHatToTree(uint32 _topHatId, uint256 _newAdminHat) external {
        if (!noCircularLinkage(_topHatId, _newAdminHat)) revert CircularLinkage();
        if (linkedTreeAdmins[_topHatId] > 0) revert DomainLinked();

        uint256 fullTopHatId = uint256(_topHatId) << 224; // (256 - TOPHAT_ADDRESS_SPACE);
        if (!isWearerOfHat(msg.sender, fullTopHatId)) revert NotHatWearer();
        linkedTreeAdmins[_topHatId] = _newAdminHat;
        emit TopHatLinked(_topHatId, _newAdminHat);
    }

    /// @notice Unlink a Tree from the parent tree
    /// @dev This can only be called by an admin of the tree root
    /// @param _topHatId The domain of the tophat to unlink
    function unlinkTopHatFromTree(uint32 _topHatId) external {
        uint256 adminHat = linkedTreeAdmins[_topHatId];
        uint256 fullTopHatId = uint256(_topHatId) << 224; // (256 - TOPHAT_ADDRESS_SPACE);
        if(!isAdminOfHat(msg.sender, fullTopHatId))
          revert  NotAdmin(msg.sender, _topHatId);

        delete linkedTreeAdmins[_topHatId];
        emit TopHatLinked(_topHatId, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              HATS VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice View the properties of a given Hat
    /// @param _hatId The id of the Hat
    /// @return details The details of the Hat
    /// @return maxSupply The max supply of tokens for this Hat
    /// @return supply The number of current wearers of this Hat
    /// @return eligibility The eligibility address for this Hat
    /// @return toggle The toggle address for this Hat
    /// @return imageURI The image URI used for this Hat
    /// @return lastHatId The most recently created Hat with this Hat as admin; also the count of Hats with this Hat as admin
    /// @return mutable_ Whether this hat's properties can be changed
    /// @return active Whether the Hat is current active, as read from `_isActive`
    function viewHat(uint256 _hatId)
        public
        view
        returns (
            string memory details,
            uint32 maxSupply,
            uint32 supply,
            address eligibility,
            address toggle,
            string memory imageURI,
            uint16 lastHatId,
            bool mutable_,
            bool active
        )
    {
        Hat memory hat = _hats[_hatId];
        details = hat.details;
        maxSupply = hat.maxSupply;
        supply = hatSupply[_hatId];
        eligibility = hat.eligibility;
        toggle = hat.toggle;
        imageURI = getImageURIForHat(_hatId);
        lastHatId = hat.lastHatId;
        mutable_ = _isMutable(hat);
        active = _isActive(hat, _hatId);
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
        if (isTopHat(_hatId)) {
            return (isWearerOfHat(_user, _hatId));
        }

        uint8 adminHatLevel = getHatLevel(_hatId) - 1;

        while (adminHatLevel > 0) {
            if (isWearerOfHat(_user, getAdminAtLevel(_hatId, adminHatLevel))) {
                return true;
            }

            adminHatLevel--;
        }

        return isWearerOfHat(_user, getAdminAtLevel(_hatId, 0));
    }

    /// @notice Checks the active status of a hat
    /// @dev For internal use instead of `isActive` when passing Hat as param is preferable
    /// @param _hat The Hat struct
    /// @param _hatId The id of the hat
    /// @return active The active status of the hat
    function _isActive(Hat memory _hat, uint256 _hatId)
        internal
        view
        returns (bool)
    {
        bytes memory data = abi.encodeWithSignature(
            "getHatStatus(uint256)",
            _hatId
        );

        (bool success, bytes memory returndata) = _hat.toggle.staticcall(data);

        if (success && returndata.length > 0) {
            return abi.decode(returndata, (bool));
        } else {
            return _getHatStatus(_hat);
        }
    }

    // /// @notice Checks the active status of a hat
    // /// @dev Use `_isActive` for internal calls that can take a Hat as a param
    // /// @param _hatId The id of the hat
    // /// @return bool The active status of the hat
    // function isActive(uint256 _hatId) public view returns (bool) {
    //     return _isActive(_hats[_hatId], _hatId);
    // }

    function _getHatStatus(Hat memory _hat) internal view returns (bool) {
        return (_hat.config >> 95 != 0);
    }

    function _setHatStatus(Hat storage _hat, bool _status) internal {
        if (_status) {
            _hat.config |= uint96(1 << 95);
        } else {
            _hat.config &= ~uint96(1 << 95);
        }
    }

    function _isMutable(Hat memory _hat) internal view returns (bool) {
        return (_hat.config & uint96(1 << 94) != 0);
    }

    // function isMutable(uint256 _hatId) public view returns (bool) {
    //     return _isMutable(_hats[_hatId]);
    // }

    /// @notice Checks whether a wearer of a Hat is in good standing
    /// @dev Public function for use when pa    ssing a Hat object is not possible or preferable
    /// @param _wearer The address of the Hat wearer
    /// @param _hatId The id of the Hat
    /// @return standing Whether the wearer is in good standing
    function isInGoodStanding(address _wearer, uint256 _hatId)
        public
        view
        returns (bool standing)
    {
        (bool success, bytes memory returndata) = _hats[_hatId]
            .eligibility
            .staticcall(
                abi.encodeWithSignature(
                    "getWearerStatus(address,uint256)",
                    _wearer,
                    _hatId
                )
            );

        if (success && returndata.length > 0) {
            (, standing) = abi.decode(returndata, (bool, bool));
        } else {
            standing = !badStandings[_hatId][_wearer];
        }
    }

    /// @notice Internal call to check whether an address is eligible for a given Hat
    /// @dev Tries an external call to the Hat's eligibility module, defaulting to existing badStandings state if the call fails (ie if the eligibility module address does not conform to the IHatsEligibility interface)
    /// @param _wearer The address of the Hat wearer
    /// @param _hat The Hat object
    /// @param _hatId The id of the Hat
    /// @return eligible Whether the wearer is eligible for the Hat
    function _isEligible(
        address _wearer,
        Hat memory _hat,
        uint256 _hatId
    ) internal view returns (bool eligible) {
        (bool success, bytes memory returndata) = _hat.eligibility.staticcall(
            abi.encodeWithSignature(
                "getWearerStatus(address,uint256)",
                _wearer,
                _hatId
            )
        );

        if (success && returndata.length > 0) {
            bool standing;
            (eligible, standing) = abi.decode(returndata, (bool, bool));
            // never eligible if in bad standing
            if (eligible && !standing) eligible = false;
        } else {
            eligible = !badStandings[_hatId][_wearer];
        }
    }

    /// @notice Checks whether an address is eligible for a given Hat
    /// @dev Public function for use when passing a Hat object is not possible or preferable
    /// @param _hatId The id of the Hat
    /// @param _wearer The address to check
    /// @return bool
    function isEligible(address _wearer, uint256 _hatId)
        public
        view
        returns (bool)
    {
        // Hat memory hat = _hats[_hatId];
        return _isEligible(_wearer, _hats[_hatId], _hatId);
    }

    /// @notice Gets the imageURI for a given hat
    /// @dev If this hat does not have an imageURI set, recursively get the imageURI from
    ///      its admin
    /// @param _hatId The hat whose imageURI we're looking for
    /// @return imageURI The imageURI of this hat or, if empty, its admin
    function getImageURIForHat(uint256 _hatId)
        public
        view
        returns (string memory)
    {
        // check _hatId first to potentially avoid the `getHatLevel` call
        Hat memory hat = _hats[_hatId];

        string memory imageURI = hat.imageURI; // save 1 SLOAD

        // if _hatId has an imageURI, we return it
        if (bytes(imageURI).length > 0) {
            return imageURI;

            /// TODO bring back the following in a way that actually works
            // since there's only one hat with this imageURI at this level, by convention
            // we refer to it with `id = 0`
            // return string.concat(imageURI, "0");
        }

        // otherwise, we check its branch of admins
        uint256 level = getHatLevel(_hatId);

        // but first we check if _hatId is a tophat, in which case we fall back to the global image uri
        if (level == 0) return baseImageURI;

        // otherwise, we check each of its admins for a valid imageURI
        uint256 id;

        // already checked at `level` above, so we start the loop at `level - 1`
        for (uint256 i = level - 1; i > 0; --i) {
            id = getAdminAtLevel(_hatId, uint8(i));
            hat = _hats[id];
            imageURI = hat.imageURI;

            if (bytes(imageURI).length > 0) {
                return imageURI;

                /// TODO bring back the following in a way that actually works
                // since there are multiple hats with this imageURI at _hatId's level,
                // we need to use _hatId to disambiguate
                // return string.concat(imageURI, LibString.toString(_hatId));
            }
        }

        // if none of _hatId's admins has an imageURI of its own, we again fall back to the global image uri
        return baseImageURI;

        /// TODO bring back the following in a way that actually works
        // return string.concat(baseImageURI, LibString.toString(_hatId));
    }

    /// @notice Constructs the URI for a Hat, using data from the Hat struct
    /// @param _hatId The id of the Hat
    /// @return An ERC1155-compatible JSON string
    function _constructURI(uint256 _hatId)
        internal
        view
        returns (string memory)
    {
        Hat memory hat = _hats[_hatId];

        uint256 hatAdmin;

        if (isTopHat(_hatId)) {
            hatAdmin = _hatId;
        } else {
            hatAdmin = getAdminAtLevel(_hatId, getHatLevel(_hatId) - 1);
        }

        // split into two objects to avoid stack too deep error
        string memory idProperties = string.concat(
            '"domain": "',
            LibString.toString(getTophatDomain(_hatId)),
            '", "id": "',
            LibString.toString(_hatId),
            '", "pretty id": "',
            "{id}",
            '",'
        );

        string memory otherProperties = string.concat(
            '"status": "',
            (_isActive(hat, _hatId) ? "active" : "inactive"),
            '", "current supply": "',
            LibString.toString(hatSupply[_hatId]),
            '", "supply cap": "',
            LibString.toString(hat.maxSupply),
            '", "admin (id)": "',
            LibString.toString(hatAdmin),
            '", "admin (pretty id)": "',
            LibString.toHexString(hatAdmin, 32),
            '", "eligibility module": "',
            LibString.toHexString(hat.eligibility),
            '", "toggle module": "',
            LibString.toHexString(hat.toggle),
            '", "mutable": "',
            _isMutable(hat) ? "true" : "false",
            '"'
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            string.concat(
                                '{"name": "',
                                "Hat",
                                '", "description": "',
                                hat.details,
                                '", "image": "',
                                getImageURIForHat(_hatId),
                                '",',
                                '"properties": ',
                                "{",
                                idProperties,
                                otherProperties,
                                "}",
                                "}"
                            )
                        )
                    )
                )
            );
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
        override(ERC1155, IHats)
        returns (uint256 balance)
    {
        Hat memory hat = _hats[hatId];

        balance = 0;

        if (_isActive(hat, hatId) && _isEligible(wearer, hat, hatId)) {
            balance = super.balanceOf(wearer, hatId);
        }
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
        revert();
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
        revert();
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
        revert();
    }

    /// @notice View the uri for a Hat
    /// @param id The id of the Hat
    /// @return string An 1155-compatible JSON object
    function uri(uint256 id)
        public
        view
        override(ERC1155, IHats)
        returns (string memory)
    {
        return _constructURI(uint256(id));
    }
}
