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

import "../Lib/LibHatsStorage.sol";
import {HatsErrors} from "../../Interfaces/HatsErrors.sol";
import {LibHatsDiamond} from "../Lib/LibHatsDiamond.sol";

contract HatsCoreFacet {
    LibHatsStorage.Storage internal s;

    /*//////////////////////////////////////////////////////////////
                              HATS CORE LOGIC
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

        topHatId = uint256(++s.lastTopHatId) << 224;

        LibHatsDiamond._createHat(
            topHatId,
            _details, // details
            1, // maxSupply = 1
            address(0), // there is no eligibility
            address(0), // it has no toggle
            false, // its immutable
            _imageURI
        );

        LibHatsDiamond._mint(_target, topHatId);
    }

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
            revert HatsErrors.MaxLevelsReached();
        }

        newHatId = getNextId(_admin);

        // to create a hat, you must be wearing one of its admin hats
        LibHatsDiamond._checkAdmin(newHatId);

        // create the new hat
        LibHatsDiamond._createHat(
            newHatId,
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            _mutable,
            _imageURI
        );

        // increment _admin.lastHatId
        ++s._hats[_admin].lastHatId;
    }

    function getNextId(uint256 _admin) public view returns (uint256) {
        uint8 nextHatId = s._hats[_admin].lastHatId + 1;
        return LibHatsDiamond.buildHatId(_admin, nextHatId);
    }

    /// @notice Mints an ERC1155 token of the Hat to a recipient, who then "wears" the hat
    /// @dev The msg.sender must wear the admin Hat of `_hatId`
    /// @param _hatId The id of the Hat to mint
    /// @param _wearer The address to which the Hat is minted
    /// @return bool Whether the mint succeeded
    function mintHat(uint256 _hatId, address _wearer) public returns (bool) {
        LibHatsStorage.Hat memory hat = s._hats[_hatId];
        if (hat.maxSupply == 0) revert HatsErrors.HatDoesNotExist(_hatId);

        // only the wearer of a hat's admin Hat can mint it
        LibHatsDiamond._checkAdmin(_hatId);

        if (s.hatSupply[_hatId] >= hat.maxSupply) {
            revert HatsErrors.AllHatsWorn(_hatId);
        }

        if (LibHatsDiamond._isWearerOfHat(_wearer, _hatId)) {
            revert HatsErrors.AlreadyWearingHat(_wearer, _hatId);
        }

        LibHatsDiamond._mint(_wearer, _hatId);

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
        LibHatsStorage.Hat storage hat = s._hats[_hatId];

        if (msg.sender != hat.toggle) {
            revert HatsErrors.NotHatsToggle();
        }

        return _processHatStatus(_hatId, newStatus);
    }

    /// @notice Checks a hat's toggle and, if new, toggle's the hat's status
    /// @dev // TODO
    /// @param _hatId The id of the Hat whose toggle we are checking
    /// @return bool Whether there was a new status
    function checkHatStatus(uint256 _hatId) external returns (bool) {
        LibHatsStorage.Hat memory hat = s._hats[_hatId];
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
            revert HatsErrors.NotHatsToggle();
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
        LibHatsStorage.Hat memory hat = s._hats[_hatId];

        if (msg.sender != hat.eligibility) {
            revert HatsErrors.NotHatsEligibility();
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
        LibHatsStorage.Hat memory hat = s._hats[_hatId];
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
            revert HatsErrors.NotHatsEligibility();
        }

        return _processHatWearerStatus(_hatId, _wearer, eligible, standing);
    }

    /// @notice Stop wearing a hat, aka "renounce" it
    /// @dev Burns the msg.sender's hat
    /// @param _hatId The id of the Hat being renounced
    function renounceHat(uint256 _hatId) external {
        if (!LibHatsDiamond._isWearerOfHat(msg.sender, _hatId)) {
            revert HatsErrors.NotHatWearer();
        }
        // remove the hat
        LibHatsDiamond._burn(msg.sender, _hatId);

        // emit HatRenounced(_hatId, msg.sender);
    }

    // TODO write comment
    function _processHatStatus(uint256 _hatId, bool _newStatus)
        internal
        returns (bool updated)
    {
        // optimize later
        LibHatsStorage.Hat storage hat = s._hats[_hatId];

        if (_newStatus != LibHatsDiamond._getHatStatus(hat)) {
            LibHatsDiamond._setHatStatus(hat, _newStatus);
            emit LibHatsStorage.HatStatusChanged(_hatId, _newStatus);
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
        // always ineligible if in bad standing
        if (!_eligible || !_standing) {
            // revoke the Hat by burning it
            LibHatsDiamond._burn(_wearer, _hatId);
        }

        // record standing for use by other contracts
        // note: here, standing and badStandings are opposite
        // i.e. if standing (true = good standing)
        // then badStandings[_hatId][wearer] will be false
        // if they are different, then something has changed, and we need to update
        // badStandings marker
        if (_standing == s.badStandings[_hatId][_wearer]) {
            s.badStandings[_hatId][_wearer] = !_standing;
            updated = true;
        }

        // emit WearerStatus(_hatId, _wearer, _eligible, _standing);
    }

    function transferHat(
        uint256 _hatId,
        address _from,
        address _to
    ) public {
        LibHatsDiamond._checkAdmin(_hatId);

        // Checks storage instead of `isWearerOfHat` since admins may want to transfer revoked Hats to new wearers
        if (LibHatsDiamond._staticBalanceOf(_from, _hatId) < 1) {
            revert HatsErrors.NotHatWearer();
        }

        // Check if recipient is already wearing hat; also checks storage to maintain balance == 1 invariant
        if (LibHatsDiamond._staticBalanceOf(_to, _hatId) > 0) {
            revert HatsErrors.AlreadyWearingHat(_to, _hatId);
        }

        //Adjust balances
        --s._balanceOf[_from][_hatId];
        ++s._balanceOf[_to][_hatId];

        emit LibHatsStorage.TransferSingle(msg.sender, _from, _to, _hatId, 1);
    }
}
