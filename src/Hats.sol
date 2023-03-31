// SPDX-License-Identifier: AGPL-3.0
// Copyright (C) 2023 Haberdasher Labs
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

import { ERC1155 } from "lib/ERC1155/ERC1155.sol";
// import { console2 } from "forge-std/Test.sol"; //remove after testing
import "./Interfaces/IHats.sol";
import "./HatsIdUtilities.sol";
import "./Interfaces/IHatsToggle.sol";
import "./Interfaces/IHatsEligibility.sol";
import "solbase/utils/Base64.sol";
import "solbase/utils/LibString.sol";

/// @title Hats Protocol
/// @notice Hats are DAO-native, revocable, and programmable roles that are represented as non-transferable ERC-1155-similar tokens for composability
/// @dev This is a multitenant contract that can manage all hats for a given chain. While it fully implements the ERC1155 interface, it does not fully comply with the ERC1155 standard.
/// @author Haberdasher Labs
contract Hats is IHats, ERC1155, HatsIdUtilities {
    /*//////////////////////////////////////////////////////////////
                              HATS DATA MODELS
    //////////////////////////////////////////////////////////////*/

    /// @notice A Hat object containing the hat's properties
    /// @dev The members are packed to minimize storage costs
    /// @custom:member eligibility Module that rules on wearer eligibiliy and standing
    /// @custom:member maxSupply The max number of hats with this id that can exist
    /// @custom:member supply The number of this hat that currently exist
    /// @custom:member lastHatId Indexes how many different child hats an admin has
    /// @custom:member toggle Module that sets the hat's status
    /**
     * @custom:member config Holds status and other settings, with this bitwise schema:
     *
     *  0th bit  | `active` status; can be altered by toggle
     *  1        | `mutable` setting
     *  2 - 95   | unassigned
     */
    /// @custom:member details Holds arbitrary metadata about the hat
    /// @custom:member imageURI A uri pointing to an image for the hat
    struct Hat {
        // 1st storage slot
        address eligibility; // ─┐ 20
        uint32 maxSupply; //     │ 4
        uint32 supply; //        │ 4
        uint16 lastHatId; //    ─┘ 2
        // 2nd slot
        address toggle; //      ─┐ 20
        uint96 config; //       ─┘ 12
        // 3rd+ slot (optional)
        string details;
        string imageURI;
    }

    /*//////////////////////////////////////////////////////////////
                              HATS STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the contract, typically including the version
    string public name;

    /// @notice The first 4 bytes of the id of the last tophat created.
    uint32 public lastTopHatId; // first tophat id starts at 1

    /// @notice The fallback image URI for hat tokens with no `imageURI` specified in their branch
    string public baseImageURI;

    /// @dev Internal mapping of hats to hat ids. See HatsIdUtilities.sol for more info on how hat ids work
    mapping(uint256 => Hat) internal _hats; // key: hatId => value: Hat struct

    /// @notice Mapping of wearers in bad standing for certain hats
    /// @dev Used by external contracts to trigger penalties for wearers in bad standing
    ///      hatId => wearer => !standing
    mapping(uint256 => mapping(address => bool)) public badStandings;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice All arguments are immutable; they can only be set once during construction
    /// @param _name The name of this contract, typically including the version
    /// @param _baseImageURI The fallback image URI
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
    /// @param _details A description of the Hat [optional]. Should not be larger than 7000 bytes
    ///                 (enforced in changeHatDetails)
    /// @param _imageURI The image uri for this top hat and the fallback for its
    ///                  downstream hats [optional]. Should not be large than 7000 bytes
    ///                  (enforced in changeHatImageURI)
    /// @return topHatId The id of the newly created topHat
    function mintTopHat(address _target, string calldata _details, string calldata _imageURI)
        public
        returns (uint256 topHatId)
    {
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

        _mintHat(_target, topHatId);
    }

    /// @notice Creates a new hat. The msg.sender must wear the `_admin` hat.
    /// @dev Initializes a new Hat struct, but does not mint any tokens.
    /// @param _details A description of the Hat. Should not be larger than 7000 bytes (enforced in changeHatDetails)
    /// @param _maxSupply The total instances of the Hat that can be worn at once
    /// @param _admin The id of the Hat that will control who wears the newly created hat
    /// @param _eligibility The address that can report on the Hat wearer's status
    /// @param _toggle The address that can deactivate the Hat
    /// @param _mutable Whether the hat's properties are changeable after creation
    /// @param _imageURI The image uri for this hat and the fallback for its
    ///                  downstream hats [optional]. Should not be larger than 7000 bytes (enforced in changeHatImageURI)
    /// @return newHatId The id of the newly created Hat
    function createHat(
        uint256 _admin,
        string calldata _details,
        uint32 _maxSupply,
        address _eligibility,
        address _toggle,
        bool _mutable,
        string calldata _imageURI
    ) public returns (uint256 newHatId) {
        if (uint16(_admin) > 0) {
            revert MaxLevelsReached();
        }

        if (_eligibility == address(0)) revert ZeroAddress();
        if (_toggle == address(0)) revert ZeroAddress();
        // check that the admin id is valid, ie does not contain empty levels between filled levels
        if (!isValidHatId(_admin)) revert InvalidHatId();
        // construct the next hat id
        newHatId = getNextId(_admin);
        // to create a hat, you must be wearing one of its admin hats
        _checkAdmin(newHatId);
        // create the new hat
        _createHat(newHatId, _details, _maxSupply, _eligibility, _toggle, _mutable, _imageURI);
        // increment _admin.lastHatId
        // use the overflow check to constrain to correct number of hats per level
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
    /// @param _mutables Array of mutable flags for each hat to create
    /// @param _imageURIs Array of imageURIs for each hat to create
    /// @return success True if all createHat calls succeeded
    function batchCreateHats(
        uint256[] calldata _admins,
        string[] calldata _details,
        uint32[] calldata _maxSupplies,
        address[] memory _eligibilityModules,
        address[] memory _toggleModules,
        bool[] calldata _mutables,
        string[] calldata _imageURIs
    ) public returns (bool success) {
        // check if array lengths are the same
        uint256 length = _admins.length; // save an MLOAD

        {
            bool sameLengths = (
                length == _details.length // details
                    && length == _maxSupplies.length // supplies
                    && length == _eligibilityModules.length // eligibility
                    && length == _toggleModules.length // toggle
                    && length == _mutables.length // mutable
                    && length == _imageURIs.length
            ); // imageURI
            if (!sameLengths) revert BatchArrayLengthMismatch();
        }

        // loop through and create each hat
        for (uint256 i = 0; i < length;) {
            createHat(
                _admins[i],
                _details[i],
                _maxSupplies[i],
                _eligibilityModules[i],
                _toggleModules[i],
                _mutables[i],
                _imageURIs[i]
            );

            unchecked {
                ++i;
            }
        }

        success = true;
    }

    /// @notice Gets the id of the next child hat of the hat `_admin`
    /// @dev Does not incrememnt lastHatId
    /// @param _admin The id of the hat to serve as the admin for the next child hat
    /// @return nextId The new hat id
    function getNextId(uint256 _admin) public view returns (uint256 nextId) {
        uint16 nextHatId = _hats[_admin].lastHatId + 1;
        nextId = buildHatId(_admin, nextHatId);
    }

    /// @notice Mints an ERC1155-similar token of the Hat to an eligible recipient, who then "wears" the hat
    /// @dev The msg.sender must wear an admin Hat of `_hatId`, and the recipient must be eligible to wear `_hatId`
    /// @param _hatId The id of the Hat to mint
    /// @param _wearer The address to which the Hat is minted
    /// @return success Whether the mint succeeded
    function mintHat(uint256 _hatId, address _wearer) public returns (bool success) {
        Hat storage hat = _hats[_hatId];
        if (hat.maxSupply == 0) revert HatDoesNotExist(_hatId);
        // only eligible wearers can receive minted hats
        if (!isEligible(_wearer, _hatId)) revert NotEligible();
        // only active hats can be minted
        if (!_isActive(hat, _hatId)) revert HatNotActive();
        // only the wearer of one of a hat's admins can mint it
        _checkAdmin(_hatId);
        // hat supply cannot exceed maxSupply
        if (hat.supply >= hat.maxSupply) revert AllHatsWorn(_hatId);
        // wearers cannot wear the same hat more than once
        if (_staticBalanceOf(_wearer, _hatId) > 0) revert AlreadyWearingHat(_wearer, _hatId);
        // if we've made it through all the checks, mint the hat
        _mintHat(_wearer, _hatId);

        success = true;
    }

    /// @notice Mints new hats in batch. The msg.sender must be an admin of each hat.
    /// @dev This is a convenience function that loops through the arrays and calls `mintHat`.
    /// @param _hatIds Array of ids of hats to mint
    /// @param _wearers Array of addresses to which the hats will be minted
    /// @return success True if all mintHat calls succeeded
    function batchMintHats(uint256[] calldata _hatIds, address[] calldata _wearers) public returns (bool success) {
        uint256 length = _hatIds.length;
        if (length != _wearers.length) revert BatchArrayLengthMismatch();

        for (uint256 i = 0; i < length;) {
            mintHat(_hatIds[i], _wearers[i]);
            unchecked {
                ++i;
            }
        }

        success = true;
    }

    /// @notice Toggles a Hat's status from active to deactive, or vice versa
    /// @dev The msg.sender must be set as the hat's toggle
    /// @param _hatId The id of the Hat for which to adjust status
    /// @param _newStatus The new status to set
    /// @return toggled Whether the status was toggled
    function setHatStatus(uint256 _hatId, bool _newStatus) external returns (bool toggled) {
        Hat storage hat = _hats[_hatId];

        if (msg.sender != hat.toggle) {
            revert NotHatsToggle();
        }

        toggled = _processHatStatus(_hatId, _newStatus);
    }

    /// @notice Checks a hat's toggle module and processes the returned status
    /// @dev May change the hat's status in storage
    /// @param _hatId The id of the Hat whose toggle we are checking
    /// @return toggled Whether there was a new status
    function checkHatStatus(uint256 _hatId) public returns (bool toggled) {
        Hat storage hat = _hats[_hatId];

        // attempt to retrieve the hat's status from the toggle module
        (bool success, bool newStatus) = _pullHatStatus(hat, _hatId);

        // if unsuccessful (ie toggle was humanistic), process the new status
        if (!success) revert NotHatsToggle();

        // if successful (ie toggle was mechanistic), process the new status
        toggled = _processHatStatus(_hatId, newStatus);
    }

    function _pullHatStatus(Hat storage _hat, uint256 _hatId) internal view returns (bool success, bool newStatus) {
        bytes memory data = abi.encodeWithSignature("getHatStatus(uint256)", _hatId);
        bytes memory returndata;
        (success, returndata) = _hat.toggle.staticcall(data);

        /* 
        * if function call succeeds with data of length == 32, then we know the contract exists 
        * and has the getHatStatus function.
        * But — since function selectors don't include return types — we still can't assume that the return data is a boolean, 
        * so we treat it as a uint so it will always safely decode without throwing.
        */
        if (success && returndata.length == 32) {
            // check the returndata manually
            uint256 uintReturndata = abi.decode(returndata, (uint256));
            // false condition
            if (uintReturndata == 0) {
                newStatus = false;
                // true condition
            } else if (uintReturndata == 1) {
                newStatus = true;
            }
            // invalid condition
            else {
                success = false;
            }
        } else {
            success = false;
        }
    }

    /// @notice Report from a hat's eligibility on the status of one of its wearers and, if `false`, revoke their hat
    /// @dev Burns the wearer's hat, if revoked
    /// @param _hatId The id of the hat
    /// @param _wearer The address of the hat wearer whose status is being reported
    /// @param _eligible Whether the wearer is eligible for the hat (will be revoked if
    /// false)
    /// @param _standing False if the wearer is no longer in good standing (and potentially should be penalized)
    /// @return updated Whether the report succeeded
    function setHatWearerStatus(uint256 _hatId, address _wearer, bool _eligible, bool _standing)
        external
        returns (bool updated)
    {
        Hat storage hat = _hats[_hatId];

        if (msg.sender != hat.eligibility) {
            revert NotHatsEligibility();
        }

        updated = _processHatWearerStatus(_hatId, _wearer, _eligible, _standing);
    }

    /// @notice Check a hat's eligibility for a report on the status of one of the hat's wearers and, if `false`, revoke their hat
    /// @dev Burns the wearer's hat, if revoked
    /// @param _hatId The id of the hat
    /// @param _wearer The address of the Hat wearer whose status report is being requested
    /// @return updated Whether the wearer's status was altered
    function checkHatWearerStatus(uint256 _hatId, address _wearer) public returns (bool updated) {
        bool eligible;
        bool standing;

        (bool success, bytes memory returndata) = _hats[_hatId].eligibility.staticcall(
            abi.encodeWithSignature("getWearerStatus(address,uint256)", _wearer, _hatId)
        );

        /* 
        * if function call succeeds with data of length == 64, then we know the contract exists 
        * and has the getWearerStatus function (which returns two words).
        * But — since function selectors don't include return types — we still can't assume that the return data is two booleans, 
        * so we treat it as a uint so it will always safely decode without throwing.
        */
        if (success && returndata.length == 64) {
            // check the returndata manually
            (uint256 firstWord, uint256 secondWord) = abi.decode(returndata, (uint256, uint256));
            // returndata is valid
            if (firstWord < 2 && secondWord < 2) {
                standing = (secondWord == 1) ? true : false;
                // never eligible if in bad standing
                eligible = (standing && firstWord == 1) ? true : false;
            }
            // returndata is invalid
            else {
                revert NotHatsEligibility();
            }
        } else {
            revert NotHatsEligibility();
        }

        updated = _processHatWearerStatus(_hatId, _wearer, eligible, standing);
    }

    /// @notice Stop wearing a hat, aka "renounce" it
    /// @dev Burns the msg.sender's hat
    /// @param _hatId The id of the Hat being renounced
    function renounceHat(uint256 _hatId) external {
        if (_staticBalanceOf(msg.sender, _hatId) < 1) {
            revert NotHatWearer();
        }
        // remove the hat
        _burnHat(msg.sender, _hatId);
    }

    /*//////////////////////////////////////////////////////////////
                              HATS INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal call for creating a new hat
    /// @dev Initializes a new Hat in storage, but does not mint any tokens
    /// @param _id ID of the hat to be stored
    /// @param _details A description of the hat
    /// @param _maxSupply The total instances of the Hat that can be worn at once
    /// @param _eligibility The address that can report on the Hat wearer's status
    /// @param _toggle The address that can deactivate the hat [optional]
    /// @param _mutable Whether the hat's properties are changeable after creation
    /// @param _imageURI The image uri for this top hat and the fallback for its
    ///                  downstream hats [optional]
    function _createHat(
        uint256 _id,
        string calldata _details,
        uint32 _maxSupply,
        address _eligibility,
        address _toggle,
        bool _mutable,
        string calldata _imageURI
    ) internal {
        /* 
          We write directly to storage instead of first building the Hat struct in memory.
          This allows us to cheaply use the existing lastHatId value in case it was incremented by creating a hat while skipping admin levels.
          (Resetting it to 0 would be bad since this hat's child hat(s) would overwrite the previously created hat(s) at that level.)
        */
        Hat storage hat = _hats[_id];
        hat.details = _details;
        hat.maxSupply = _maxSupply;
        hat.eligibility = _eligibility;
        hat.toggle = _toggle;
        hat.imageURI = _imageURI;
        // config is a concatenation of the status and mutability properties
        hat.config = _mutable ? uint96(3 << 94) : uint96(1 << 95);

        emit HatCreated(_id, _details, _maxSupply, _eligibility, _toggle, _mutable, _imageURI);
    }

    /// @notice Internal function to process hat status
    /// @dev Updates a hat's status if different from current
    /// @param _hatId The id of the Hat in quest
    /// @param _newStatus The status to potentially change to
    /// @return updated - Whether the status was updated
    function _processHatStatus(uint256 _hatId, bool _newStatus) internal returns (bool updated) {
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
    /// @return updated Whether the wearer standing was updated
    function _processHatWearerStatus(uint256 _hatId, address _wearer, bool _eligible, bool _standing)
        internal
        returns (bool updated)
    {
        // revoke/burn the hat if _wearer has a positive balance
        if (_staticBalanceOf(_wearer, _hatId) > 0) {
            // always ineligible if in bad standing
            if (!_eligible || !_standing) {
                _burnHat(_wearer, _hatId);
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

    /// @notice Internal function to set a hat's status in storage
    /// @dev Flips the 0th bit of _hat.config via bitwise operation
    /// @param _hat The hat object
    /// @param _status The status to set for the hat
    function _setHatStatus(Hat storage _hat, bool _status) internal {
        if (_status) {
            _hat.config |= uint96(1 << 95);
        } else {
            _hat.config &= ~uint96(1 << 95);
        }
    }

    /**
     * @notice Internal function to retrieve an account's internal "static" balance directly from internal storage,
     * @dev This function bypasses the dynamic `_isActive` and `_isEligible` checks
     * @param _account The account to check
     * @param _hatId The hat to check
     * @return staticBalance The account's static of the hat, from internal storage
     */
    function _staticBalanceOf(address _account, uint256 _hatId) internal view returns (uint256 staticBalance) {
        staticBalance = _balanceOf[_account][_hatId];
    }

    /*//////////////////////////////////////////////////////////////
                              HATS ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks whether msg.sender is an admin of a hat, and reverts if not
    function _checkAdmin(uint256 _hatId) internal view {
        if (!isAdminOfHat(msg.sender, _hatId)) {
            revert NotAdmin(msg.sender, _hatId);
        }
    }

    /// @notice checks whether the msg.sender is either an admin or wearer or a hat, and reverts the appropriate error if not
    function _checkAdminOrWearer(uint256 _hatId) internal view {
        if (!isAdminOfHat(msg.sender, _hatId) && !isWearerOfHat(msg.sender, _hatId)) {
            revert NotAdminOrWearer();
        }
    }

    /// @notice Transfers a hat from one wearer to another eligible wearer
    /// @dev The hat must be mutable, and the transfer must be initiated by an admin
    /// @param _hatId The hat in question
    /// @param _from The current wearer
    /// @param _to The new wearer
    function transferHat(uint256 _hatId, address _from, address _to) public {
        _checkAdmin(_hatId);
        // cannot transfer immutable hats, except for tophats, which can always transfer themselves
        if (!isTopHat(_hatId)) {
            if (!_isMutable(_hats[_hatId])) revert Immutable();
        }
        // Checks storage instead of `isWearerOfHat` since admins may want to transfer revoked Hats to new wearers
        if (_staticBalanceOf(_from, _hatId) < 1) revert NotHatWearer();
        // Check if recipient is already wearing hat; also checks storage to maintain balance == 1 invariant
        if (_staticBalanceOf(_to, _hatId) > 0) revert AlreadyWearingHat(_to, _hatId);
        // only eligible wearers can receive transferred hats
        if (!isEligible(_to, _hatId)) revert NotEligible();
        // only active hats can be transferred
        if (!_isActive(_hats[_hatId], _hatId)) revert HatNotActive();
        // we've made it passed all the checks, so adjust balances to execute the transfer
        _balanceOf[_from][_hatId] = 0;
        _balanceOf[_to][_hatId] = 1;
        // emit the ERC1155 standard transfer event
        emit TransferSingle(msg.sender, _from, _to, _hatId, 1);
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
    /// @dev Hat must be mutable, except for tophats.
    /// @param _hatId The id of the Hat to change
    /// @param _newDetails The new details. Must not be larger than 7000 bytes.
    function changeHatDetails(uint256 _hatId, string calldata _newDetails) external {
        if (bytes(_newDetails).length > 7000) revert StringTooLong();

        _checkAdmin(_hatId);

        Hat storage hat = _hats[_hatId];

        // a tophat can change its own details, but otherwise only mutable hat details can be changed
        if (!isTopHat(_hatId)) {
            if (!_isMutable(hat)) revert Immutable();
        }

        hat.details = _newDetails;

        emit HatDetailsChanged(_hatId, _newDetails);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable
    /// @param _hatId The id of the Hat to change
    /// @param _newEligibility The new eligibility module
    function changeHatEligibility(uint256 _hatId, address _newEligibility) external {
        if (_newEligibility == address(0)) revert ZeroAddress();

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
        if (_newToggle == address(0)) revert ZeroAddress();

        _checkAdmin(_hatId);
        Hat storage hat = _hats[_hatId];

        if (!_isMutable(hat)) {
            revert Immutable();
        }

        // record hat status from old toggle before changing; ensures smooth transition to new toggle,
        // especially in case of switching from mechanistic to humanistic toggle
        // a) attempt to retrieve hat status from old toggle
        (bool success, bool newStatus) = _pullHatStatus(hat, _hatId);
        // b) if succeeded, (ie if old toggle was mechanistic), store the retrieved status
        if (success) _processHatStatus(_hatId, newStatus);

        // set the new toggle
        hat.toggle = _newToggle;

        emit HatToggleChanged(_hatId, _newToggle);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable, except for tophats
    /// @param _hatId The id of the Hat to change
    /// @param _newImageURI The new imageURI. Must not be larger than 7000 bytes.
    function changeHatImageURI(uint256 _hatId, string calldata _newImageURI) external {
        if (bytes(_newImageURI).length > 7000) revert StringTooLong();

        _checkAdmin(_hatId);
        Hat storage hat = _hats[_hatId];

        // a tophat can change its own imageURI, but otherwise only mutable hat imageURIs can be changed
        if (!isTopHat(_hatId)) {
            if (!_isMutable(hat)) revert Immutable();
        }

        hat.imageURI = _newImageURI;

        emit HatImageURIChanged(_hatId, _newImageURI);
    }

    /// @notice Change a hat's details
    /// @dev Hat must be mutable; new max supply cannot be less than current supply
    /// @param _hatId The id of the Hat to change
    /// @param _newMaxSupply The new max supply
    function changeHatMaxSupply(uint256 _hatId, uint32 _newMaxSupply) external {
        _checkAdmin(_hatId);
        Hat storage hat = _hats[_hatId];

        if (!_isMutable(hat)) {
            revert Immutable();
        }

        if (_newMaxSupply < hat.supply) {
            revert NewMaxSupplyTooLow();
        }

        if (_newMaxSupply != hat.maxSupply) {
            hat.maxSupply = _newMaxSupply;
            emit HatMaxSupplyChanged(_hatId, _newMaxSupply);
        }
    }

    /// @notice Submits a request to link a Hat Tree under a parent tree. Requests can be
    /// submitted by either...
    ///     a) the wearer of a topHat, previous to any linkage, or
    ///     b) the admin(s) of an already-linked topHat (aka tree root), where such a
    ///        request is to move the tree root to another admin within the same parent
    ///        tree
    /// @dev A topHat can have at most 1 request at a time. Submitting a new request will
    ///      replace the existing request.
    /// @param _topHatDomain The domain of the topHat to link
    /// @param _requestedAdminHat The hat that will administer the linked tree
    function requestLinkTopHatToTree(uint32 _topHatDomain, uint256 _requestedAdminHat) external {
        uint256 fullTopHatId = uint256(_topHatDomain) << 224; // (256 - TOPHAT_ADDRESS_SPACE);

        // The wearer of an unlinked tophat is also the admin of same; once a tophat is linked, its wearer is no longer its admin
        _checkAdmin(fullTopHatId);

        linkedTreeRequests[_topHatDomain] = _requestedAdminHat;
        emit TopHatLinkRequested(_topHatDomain, _requestedAdminHat);
    }

    /// @notice Approve a request to link a Tree under a parent tree, with options to add eligibility or toggle modules and change its metadata
    /// @dev Requests can only be approved by wearer or an admin of the `_newAdminHat`, and there
    ///      can only be one link per tree root at a given time.
    /// @param _topHatDomain The 32 bit domain of the topHat to link
    /// @param _newAdminHat The hat that will administer the linked tree
    /// @param _eligibility Optional new eligibility module for the linked topHat
    /// @param _toggle Optional new toggle module for the linked topHat
    /// @param _details Optional new details for the linked topHat
    /// @param _imageURI Optional new imageURI for the linked topHat
    function approveLinkTopHatToTree(
        uint32 _topHatDomain,
        uint256 _newAdminHat,
        address _eligibility,
        address _toggle,
        string calldata _details,
        string calldata _imageURI
    ) external {
        // for everything but the last hat level, check the admin of `_newAdminHat`'s theoretical child hat, since either wearer or admin of `_newAdminHat` can approve
        if (getHatLevel(_newAdminHat) < MAX_LEVELS) {
            _checkAdmin(buildHatId(_newAdminHat, 1));
        } else {
            // the above buildHatId trick doesn't work for the last hat level, so we need to explicitly check both admin and wearer in this case
            _checkAdminOrWearer(_newAdminHat);
        }

        // Linkages must be initiated by a request
        if (_newAdminHat != linkedTreeRequests[_topHatDomain]) revert LinkageNotRequested();

        // remove the request -- ensures all linkages are initialized by unique requests,
        // except for relinks (see `relinkTopHatWithinTree`)
        delete linkedTreeRequests[_topHatDomain];

        // execute the link. Replaces existing link, if any.
        _linkTopHatToTree(_topHatDomain, _newAdminHat, _eligibility, _toggle, _details, _imageURI);
    }

    /**
     * @notice Unlink a Tree from the parent tree
     * @dev This can only be called by an admin of the tree root. Fails if the topHat to unlink has no non-zero wearer, which can occur if...
     *     - It's wearer is in badStanding
     *     - It has been revoked from its wearer (and possibly burned)˘
     *     - It is not active (ie toggled off)
     * @param _topHatDomain The 32 bit domain of the topHat to unlink
     * @param _wearer The current wearer of the topHat to unlink
     */
    function unlinkTopHatFromTree(uint32 _topHatDomain, address _wearer) external {
        uint256 fullTopHatId = uint256(_topHatDomain) << 224; // (256 - TOPHAT_ADDRESS_SPACE);
        _checkAdmin(fullTopHatId);

        // prevent unlinking if the topHat has no non-zero wearer
        // since we cannot search the entire address space for a wearer, we require the caller to provide the wearer
        if (_wearer == address(0) || !isWearerOfHat(_wearer, fullTopHatId)) revert HatsErrors.InvalidUnlink();

        // execute the unlink
        delete linkedTreeAdmins[_topHatDomain];
        // remove the request — ensures all linkages are initialized by unique requests
        delete linkedTreeRequests[_topHatDomain];

        // reset eligibility and storage to defaults for unlinked top hats
        Hat storage hat = _hats[fullTopHatId];
        delete hat.eligibility;
        delete hat.toggle;

        emit TopHatLinked(_topHatDomain, 0);
    }

    /// @notice Move a tree root to a different position within the same parent tree,
    ///         without a request. Valid destinations include within the same local tree as the origin,
    ///         or to the local tree of the tippyTopHat. TippyTopHat wearers can bypass this restriction
    ///         to relink to anywhere in its full tree.
    /// @dev Caller must be both an admin tree root and admin or wearer of `_newAdminHat`.
    /// @param _topHatDomain The 32 bit domain of the topHat to relink
    /// @param _newAdminHat The new admin for the linked tree
    /// @param _eligibility Optional new eligibility module for the linked topHat
    /// @param _toggle Optional new toggle module for the linked topHat
    /// @param _details Optional new details for the linked topHat
    /// @param _imageURI Optional new imageURI for the linked topHat
    function relinkTopHatWithinTree(
        uint32 _topHatDomain,
        uint256 _newAdminHat,
        address _eligibility,
        address _toggle,
        string calldata _details,
        string calldata _imageURI
    ) external {
        uint256 fullTopHatId = uint256(_topHatDomain) << 224; // (256 - TOPHAT_ADDRESS_SPACE);

        // msg.sender being capable of both requesting and approving allows us to skip the request step
        _checkAdmin(fullTopHatId); // "requester" must be admin

        // "approver" can be wearer or admin
        if (getHatLevel(_newAdminHat) < MAX_LEVELS) {
            _checkAdmin(buildHatId(_newAdminHat, 1));
        } else {
            // the above buildHatId trick doesn't work for the last hat level, so we need to explicitly check both admin and wearer in this case
            _checkAdminOrWearer(_newAdminHat);
        }

        // execute the new link, replacing the old link
        _linkTopHatToTree(_topHatDomain, _newAdminHat, _eligibility, _toggle, _details, _imageURI);
    }

    /// @notice Internal function to link a Tree under a parent Tree, with protection against circular linkages and relinking to a separate Tree,
    ///         with options to add eligibility or toggle modules and change its metadata
    /// @dev Linking `_topHatDomain` replaces any existing links
    /// @param _topHatDomain The 32 bit domain of the topHat to link
    /// @param _newAdminHat The new admin for the linked tree
    /// @param _eligibility Optional new eligibility module for the linked topHat
    /// @param _toggle Optional new toggle module for the linked topHat
    /// @param _details Optional new details for the linked topHat
    /// @param _imageURI Optional new imageURI for the linked topHat
    function _linkTopHatToTree(
        uint32 _topHatDomain,
        uint256 _newAdminHat,
        address _eligibility,
        address _toggle,
        string calldata _details,
        string calldata _imageURI
    ) internal {
        if (!noCircularLinkage(_topHatDomain, _newAdminHat)) revert CircularLinkage();
        {
            uint256 linkedAdmin = linkedTreeAdmins[_topHatDomain];

            // disallow relinking to separate tree
            if (linkedAdmin > 0) {
                uint256 tippyTopHat = uint256(getTippyTopHatDomain(_topHatDomain)) << 224;
                if (!isWearerOfHat(msg.sender, tippyTopHat)) {
                    uint256 destLocalTopHat = uint256(_newAdminHat >> 224 << 224); // (256 - TOPHAT_ADDRESS_SPACE);
                    // for non-tippyTopHat wearers: destination local tophat must be either...
                    // a) the same as origin local tophat, or
                    // b) within the tippy top hat's local tree
                    uint256 originLocalTopHat = linkedAdmin >> 224 << 224; // (256 - TOPHAT_ADDRESS_SPACE);
                    if (destLocalTopHat != originLocalTopHat && destLocalTopHat != tippyTopHat) {
                        revert CrossTreeLinkage();
                    }
                    // for tippyTopHat weerers: destination must be within the same super tree
                } else if (!sameTippyTopHatDomain(_topHatDomain, _newAdminHat)) {
                    revert CrossTreeLinkage();
                }
            }
        }

        // update and log the linked topHat's modules and metadata, if any changes
        uint256 topHatId = uint256(_topHatDomain) << 224;
        Hat storage hat = _hats[topHatId];

        if (_eligibility != address(0)) {
            hat.eligibility = _eligibility;
            emit HatEligibilityChanged(topHatId, _eligibility);
        }
        if (_toggle != address(0)) {
            hat.toggle = _toggle;
            emit HatToggleChanged(topHatId, _toggle);
        }

        uint256 length = bytes(_details).length;
        if (length > 0) {
            if (length > 7000) revert StringTooLong();
            hat.details = _details;
            emit HatDetailsChanged(topHatId, _details);
        }

        length = bytes(_imageURI).length;
        if (length > 0) {
            if (length > 7000) revert StringTooLong();
            hat.imageURI = _imageURI;
            emit HatImageURIChanged(topHatId, _imageURI);
        }

        // store the new linked admin
        linkedTreeAdmins[_topHatDomain] = _newAdminHat;
        emit TopHatLinked(_topHatDomain, _newAdminHat);
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
        Hat storage hat = _hats[_hatId];
        details = hat.details;
        maxSupply = hat.maxSupply;
        supply = hat.supply;
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
    /// @return isWearer Whether the `_user` wears the Hat.
    function isWearerOfHat(address _user, uint256 _hatId) public view returns (bool isWearer) {
        isWearer = (balanceOf(_user, _hatId) > 0);
    }

    /// @notice Checks whether a given address serves as the admin of a given Hat
    /// @dev Recursively checks if `_user` wears the admin Hat of the Hat in question. This is recursive since there may be a string of Hats as admins of Hats.
    /// @param _user The address in question
    /// @param _hatId The id of the Hat for which the `_user` might be the admin
    /// @return isAdmin Whether the `_user` has admin rights for the Hat
    function isAdminOfHat(address _user, uint256 _hatId) public view returns (bool isAdmin) {
        uint256 linkedTreeAdmin;
        uint32 adminLocalHatLevel;
        if (isLocalTopHat(_hatId)) {
            linkedTreeAdmin = linkedTreeAdmins[getTopHatDomain(_hatId)];
            if (linkedTreeAdmin == 0) {
                // tree is not linked
                return isAdmin = isWearerOfHat(_user, _hatId);
            } else {
                // tree is linked
                if (isWearerOfHat(_user, linkedTreeAdmin)) {
                    return isAdmin = true;
                } // user wears the treeAdmin
                else {
                    adminLocalHatLevel = getLocalHatLevel(linkedTreeAdmin);
                    _hatId = linkedTreeAdmin;
                }
            }
        } else {
            // if we get here, _hatId is not a tophat of any kind
            // get the local tree level of _hatId's admin
            adminLocalHatLevel = getLocalHatLevel(_hatId) - 1;
        }

        // search up _hatId's local address space for an admin hat that the _user wears
        while (adminLocalHatLevel > 0) {
            if (isWearerOfHat(_user, getAdminAtLocalLevel(_hatId, adminLocalHatLevel))) {
                return isAdmin = true;
            }
            // should not underflow given stopping condition > 0
            unchecked {
                --adminLocalHatLevel;
            }
        }

        // if we get here, we've reached the top of _hatId's local tree, ie the local tophat
        // check if the user wears the local tophat
        if (isWearerOfHat(_user, getAdminAtLocalLevel(_hatId, 0))) return isAdmin = true;

        // if not, we check if it's linked to another tree
        linkedTreeAdmin = linkedTreeAdmins[getTopHatDomain(_hatId)];
        if (linkedTreeAdmin == 0) {
            // tree is not linked
            // we've already learned that user doesn't wear the local tophat, so there's nothing else to check; we return false
            return isAdmin = false;
        } else {
            // tree is linked
            // check if user is wearer of linkedTreeAdmin
            if (isWearerOfHat(_user, linkedTreeAdmin)) return true;
            // if not, recurse to traverse the parent tree for a hat that the user wears
            isAdmin = isAdminOfHat(_user, linkedTreeAdmin);
        }
    }

    /// @notice Checks the active status of a hat
    /// @dev For internal use instead of `isActive` when passing Hat as param is preferable
    /// @param _hat The Hat struct
    /// @param _hatId The id of the hat
    /// @return active The active status of the hat
    function _isActive(Hat storage _hat, uint256 _hatId) internal view returns (bool active) {
        (bool success, bytes memory returndata) =
            _hat.toggle.staticcall(abi.encodeWithSignature("getHatStatus(uint256)", _hatId));

        /*
        * if function call succeeds with data of length == 32, then we know the contract exists
        * and has the getHatStatus function.
        * But — since function selectors don't include return types — we still can't assume that the return data is a boolean,
        * so we treat it as a uint so it will always safely decode without throwing.
        */
        if (success && returndata.length == 32) {
            // check the returndata manually
            uint256 uintReturndata = uint256(bytes32(returndata));
            // false condition
            if (uintReturndata == 0) {
                active = false;
                // true condition
            } else if (uintReturndata == 1) {
                active = true;
            }
            // invalid condition
            else {
                active = _getHatStatus(_hat);
            }
        } else {
            active = _getHatStatus(_hat);
        }
    }

    /// @notice Checks the active status of a hat
    /// @param _hatId The id of the hat
    /// @return active Whether the hat is active
    function isActive(uint256 _hatId) external view returns (bool active) {
        active = _isActive(_hats[_hatId], _hatId);
    }

    /// @notice Internal function to retrieve a hat's status from storage
    /// @dev reads the 0th bit of the hat's config
    /// @param _hat The hat object
    /// @return status Whether the hat is active
    function _getHatStatus(Hat storage _hat) internal view returns (bool status) {
        status = (_hat.config >> 95 != 0);
    }

    /// @notice Internal function to retrieve a hat's mutability setting
    /// @dev reads the 1st bit of the hat's config
    /// @param _hat The hat object
    /// @return _mutable Whether the hat is mutable
    function _isMutable(Hat storage _hat) internal view returns (bool _mutable) {
        _mutable = (_hat.config & uint96(1 << 94) != 0);
    }

    /// @notice Checks whether a wearer of a Hat is in good standing
    /// @param _wearer The address of the Hat wearer
    /// @param _hatId The id of the Hat
    /// @return standing Whether the wearer is in good standing
    function isInGoodStanding(address _wearer, uint256 _hatId) public view returns (bool standing) {
        (bool success, bytes memory returndata) = _hats[_hatId].eligibility.staticcall(
            abi.encodeWithSignature("getWearerStatus(address,uint256)", _wearer, _hatId)
        );

        /* 
        * if function call succeeds with data of length == 64, then we know the contract exists 
        * and has the getWearerStatus function (which returns two words).
        * But — since function selectors don't include return types — we still can't assume that the return data is two booleans, 
        * so we treat it as a uint so it will always safely decode without throwing.
        */
        if (success && returndata.length == 64) {
            // check the returndata manually
            (uint256 firstWord, uint256 secondWord) = abi.decode(returndata, (uint256, uint256));
            // returndata is valid
            if (firstWord < 2 && secondWord < 2) {
                standing = (secondWord == 1) ? true : false;
                // returndata is invalid
            } else {
                standing = !badStandings[_hatId][_wearer];
            }
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
    function _isEligible(address _wearer, Hat storage _hat, uint256 _hatId) internal view returns (bool eligible) {
        (bool success, bytes memory returndata) =
            _hat.eligibility.staticcall(abi.encodeWithSignature("getWearerStatus(address,uint256)", _wearer, _hatId));

        /* 
        * if function call succeeds with data of length == 64, then we know the contract exists 
        * and has the getWearerStatus function (which returns two words).
        * But — since function selectors don't include return types — we still can't assume that the return data is two booleans, 
        * so we treat it as a uint so it will always safely decode without throwing.
        */
        if (success && returndata.length == 64) {
            bool standing;
            // check the returndata manually
            (uint256 firstWord, uint256 secondWord) = abi.decode(returndata, (uint256, uint256));
            // returndata is valid
            if (firstWord < 2 && secondWord < 2) {
                standing = (secondWord == 1) ? true : false;
                // never eligible if in bad standing
                eligible = (standing && firstWord == 1) ? true : false;
            }
            // returndata is invalid
            else {
                eligible = !badStandings[_hatId][_wearer];
            }
        } else {
            eligible = !badStandings[_hatId][_wearer];
        }
    }

    /// @notice Checks whether an address is eligible for a given Hat
    /// @dev Public function for use when passing a Hat object is not possible or preferable
    /// @param _hatId The id of the Hat
    /// @param _wearer The address to check
    /// @return eligible Whether the wearer is eligible for the Hat
    function isEligible(address _wearer, uint256 _hatId) public view returns (bool eligible) {
        eligible = _isEligible(_wearer, _hats[_hatId], _hatId);
    }

    /// @notice Gets the current supply of a Hat
    /// @dev Only tracks explicit burns and mints, not dynamic revocations
    /// @param _hatId The id of the Hat
    /// @return supply The current supply of the Hat
    function hatSupply(uint256 _hatId) external view returns (uint32 supply) {
        supply = _hats[_hatId].supply;
    }

    /// @notice Gets the eligibility module for a hat
    /// @param _hatId The hat whose eligibility module we're looking for
    /// @return eligibility The eligibility module for this hat
    function getHatEligibilityModule(uint256 _hatId) external view returns (address eligibility) {
        eligibility = _hats[_hatId].eligibility;
    }

    /// @notice Gets the toggle module for a hat
    /// @param _hatId The hat whose toggle module we're looking for
    /// @return toggle The toggle module for this hat
    function getHatToggleModule(uint256 _hatId) external view returns (address toggle) {
        toggle = _hats[_hatId].toggle;
    }

    /// @notice Gets the max supply for a hat
    /// @param _hatId The hat whose max supply we're looking for
    /// @return maxSupply The maximum possible quantity of this hat that could be minted
    function getHatMaxSupply(uint256 _hatId) external view returns (uint32 maxSupply) {
        maxSupply = _hats[_hatId].maxSupply;
    }

    /// @notice Gets the imageURI for a given hat
    /// @dev If this hat does not have an imageURI set, recursively get the imageURI from
    ///      its admin
    /// @param _hatId The hat whose imageURI we're looking for
    /// @return _uri The imageURI of this hat or, if empty, its admin
    function getImageURIForHat(uint256 _hatId) public view returns (string memory _uri) {
        // check _hatId first to potentially avoid the `getHatLevel` call
        Hat storage hat = _hats[_hatId];

        string memory imageURI = hat.imageURI; // save 1 SLOAD

        // if _hatId has an imageURI, we return it
        if (bytes(imageURI).length > 0) {
            return imageURI;
        }

        // otherwise, we check its branch of admins
        uint256 level = getHatLevel(_hatId);

        // but first we check if _hatId is a tophat, in which case we fall back to the global image uri
        if (level == 0) return baseImageURI;

        // otherwise, we check each of its admins for a valid imageURI
        uint256 id;

        // already checked at `level` above, so we start the loop at `level - 1`
        for (uint256 i = level - 1; i > 0;) {
            id = getAdminAtLevel(_hatId, uint32(i));
            hat = _hats[id];
            imageURI = hat.imageURI;

            if (bytes(imageURI).length > 0) {
                return imageURI;
            }
            // should not underflow given stopping condition is > 0
            unchecked {
                --i;
            }
        }

        id = getAdminAtLevel(_hatId, 0);
        hat = _hats[id];
        imageURI = hat.imageURI;

        if (bytes(imageURI).length > 0) {
            return imageURI;
        }

        // if none of _hatId's admins has an imageURI of its own, we again fall back to the global image uri
        _uri = baseImageURI;
    }

    /// @notice Constructs the URI for a Hat, using data from the Hat struct
    /// @param _hatId The id of the Hat
    /// @return _uri An ERC1155-compatible JSON string
    function _constructURI(uint256 _hatId) internal view returns (string memory _uri) {
        Hat storage hat = _hats[_hatId];

        uint256 hatAdmin;

        if (isTopHat(_hatId)) {
            hatAdmin = _hatId;
        } else {
            hatAdmin = getAdminAtLevel(_hatId, getHatLevel(_hatId) - 1);
        }

        // split into two objects to avoid stack too deep error
        string memory idProperties = string.concat(
            '"domain": "',
            LibString.toString(getTopHatDomain(_hatId)),
            '", "id": "',
            LibString.toString(_hatId),
            '", "pretty id": "',
            LibString.toHexString(_hatId, 32),
            '",'
        );

        string memory otherProperties = string.concat(
            '"status": "',
            (_isActive(hat, _hatId) ? "active" : "inactive"),
            '", "current supply": "',
            LibString.toString(hat.supply),
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

        _uri = string(
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
    /// @dev Balance is dynamic based on the hat's status and wearer's eligibility, so off-chain balance data indexed from events may not be in sync
    /// @param _wearer The address whose balance is being checked
    /// @param _hatId The id of the Hat
    /// @return balance The `wearer`'s balance of the Hat tokens. Can never be > 1.
    function balanceOf(address _wearer, uint256 _hatId)
        public
        view
        override(ERC1155, IHats)
        returns (uint256 balance)
    {
        Hat storage hat = _hats[_hatId];

        balance = 0;

        if (_isActive(hat, _hatId) && _isEligible(_wearer, hat, _hatId)) {
            balance = super.balanceOf(_wearer, _hatId);
        }
    }

    /// @notice Internal call to mint a Hat token to a wearer
    /// @dev Unsafe if called when `_wearer` has a non-zero balance of `_hatId`
    /// @param _wearer The wearer of the Hat and the recipient of the newly minted token
    /// @param _hatId The id of the Hat to mint
    function _mintHat(address _wearer, uint256 _hatId) internal {
        unchecked {
            // should not overflow since `mintHat` enforces max balance of 1
            _balanceOf[_wearer][_hatId] = 1;

            // increment Hat supply counter
            // should not overflow given AllHatsWorn check in `mintHat`
            ++_hats[_hatId].supply;
        }

        emit TransferSingle(msg.sender, address(0), _wearer, _hatId, 1);
    }

    /// @notice Internal call to burn a wearer's Hat token
    /// @dev Unsafe if called when `_wearer` doesn't have a zero balance of `_hatId`
    /// @param _wearer The wearer from which to burn the Hat token
    /// @param _hatId The id of the Hat to burn
    function _burnHat(address _wearer, uint256 _hatId) internal {
        // neither should underflow since `_burnHat` is never called on non-positive balance
        unchecked {
            _balanceOf[_wearer][_hatId] = 0;

            // decrement Hat supply counter
            --_hats[_hatId].supply;
        }

        emit TransferSingle(msg.sender, _wearer, address(0), _hatId, 1);
    }

    /// @notice Approvals are not necessary for Hats since transfers are not handled by the wearer
    /// @dev Admins should use `transferHat()` to transfer
    function setApprovalForAll(address, bool) public pure override {
        revert();
    }

    /// @notice Safe transfers are not necessary for Hats since transfers are not handled by the wearer
    /// @dev Admins should use `transferHat()` to transfer
    function safeTransferFrom(address, address, uint256, uint256, bytes calldata) public pure override {
        revert();
    }

    /// @notice Safe transfers are not necessary for Hats since transfers are not handled by the wearer
    function safeBatchTransferFrom(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        public
        pure
        override
    {
        revert();
    }

    /**
     * @notice ERC165 interface detection
     *  @dev While Hats Protocol conforms to the ERC1155 *interface*, it does not fully conform to the ERC1155 *specification*
     *  since it does not implement the ERC1155Receiver functionality.
     *  For this reason, this function overrides the ERC1155 implementation to return false for ERC1155.
     *  @param interfaceId The interface identifier, as specified in ERC-165
     *  @return bool True if the contract implements `interfaceId` and false otherwise
     */
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            // interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
            || interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /// @notice Batch retrieval for wearer balances
    /// @dev Given the higher gas overhead of Hats balanceOf checks, large batches may be high cost or run into gas limits
    /// @param _wearers Array of addresses to check balances for
    /// @param _hatIds Array of Hat ids to check, using the same index as _wearers
    function balanceOfBatch(address[] calldata _wearers, uint256[] calldata _hatIds)
        public
        view
        override(ERC1155, IHats)
        returns (uint256[] memory balances)
    {
        if (_wearers.length != _hatIds.length) revert BatchArrayLengthMismatch();

        balances = new uint256[](_wearers.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i; i < _wearers.length; ++i) {
                balances[i] = balanceOf(_wearers[i], _hatIds[i]);
            }
        }
    }

    /// @notice View the uri for a Hat
    /// @param id The id of the Hat
    /// @return _uri An 1155-compatible JSON object
    function uri(uint256 id) public view override(ERC1155, IHats) returns (string memory _uri) {
        _uri = _constructURI(id);
    }
}
