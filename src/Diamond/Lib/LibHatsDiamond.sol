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

import {LibHatsStorage} from "../Lib/LibHatsStorage.sol";
import {HatsErrors} from "../../Interfaces/HatsErrors.sol";
import "forge-std/Test.sol"; // remove after testing

// import "../../HatsIdUtilities.sol";

library LibHatsDiamond {
    // bytes32 constant STORAGE_POSITION = keccak256("hats.app.storage");

    function hatsStorage()
        internal
        pure
        returns (LibHatsStorage.Storage storage s)
    {
        assembly {
            s.slot := 0
        }
    }

    /// @notice Mints a Hat token to `to`
    /// @dev Overrides ERC1155._mint: skips the typical 1155TokenReceiver hook since Hat wearers don't control their own Hat, and adds Hats-specific state changes
    /// @param to The wearer of the Hat and the recipient of the newly minted token
    /// @param id The id of the Hat to mint, cast to uint256
    function _mint(address to, uint256 id) internal {
        LibHatsStorage.Storage storage s = hatsStorage();
        ++s._balanceOf[to][id];

        // increment Hat supply counter
        ++s.hatSupply[uint256(id)];
        console2.log("_mint", s.hatSupply[id]);

        emit LibHatsStorage.TransferSingle(msg.sender, address(0), to, id, 1);
    }

    /// @notice Burns a wearer's (`from`'s) Hat token
    /// @dev Overrides ERC1155._burn: adds Hats-specific state change
    /// @param from The wearer from which to burn the Hat token
    /// @param id The id of the Hat to burn, cast to uint256
    function _burn(address from, uint256 id) internal {
        LibHatsStorage.Storage storage s = hatsStorage();
        --s._balanceOf[from][id];

        // decrement Hat supply counter
        --s.hatSupply[uint256(id)];

        emit LibHatsStorage.TransferSingle(msg.sender, from, address(0), id, 1);
    }

    /// @notice Gets the Hat token balance of a user for a given Hat
    /// @param wearer The address whose balance is being checked
    /// @param hatId The id of the Hat
    /// @return balance The `wearer`'s balance of the Hat tokens. Will typically not be greater than 1.
    function _dynamicBalanceOf(address wearer, uint256 hatId)
        internal
        view
        returns (uint256 balance)
    {
        LibHatsStorage.Storage storage s = hatsStorage();

        LibHatsStorage.Hat memory hat = s._hats[hatId];

        balance = 0;

        if (_isActive(hat, hatId) && _isEligible(wearer, hat, hatId)) {
            balance = s._balanceOf[wearer][hatId];
        }
    }

    /// @notice Gets the internal token balance of a user for a given hat id
    /// @param wearer The address whose balance is being checked
    /// @param hatId The id of the Hat
    /// @return balance The `wearer`'s balance of the Hat tokens. Will typically not be greater than 1.
    function _staticBalanceOf(address wearer, uint256 hatId)
        internal
        view
        returns (uint256 balance)
    {
        LibHatsStorage.Storage storage s = hatsStorage();
        balance = s._balanceOf[wearer][hatId];
    }

    /// @notice Checks whether a given address wears a given Hat
    /// @dev Convenience function that wraps `balanceOf`
    /// @param _user The address in question
    /// @param _hatId The id of the Hat that the `_user` might wear
    /// @return bool Whether the `_user` wears the Hat.
    function _isWearerOfHat(address _user, uint256 _hatId)
        internal
        view
        returns (bool)
    {
        return (_dynamicBalanceOf(_user, _hatId) > 0);
    }

    /// @notice Checks whether a given address serves as the admin of a given Hat
    /// @dev Recursively checks if `_user` wears the admin Hat of the Hat in question. This is recursive since there may be a string of Hats as admins of Hats.
    /// @param _user The address in question
    /// @param _hatId The id of the Hat for which the `_user` might be the admin
    /// @return bool Whether the `_user` has admin rights for the Hat
    function _isAdminOfHat(address _user, uint256 _hatId)
        internal
        view
        returns (bool)
    {
        if (isTopHat(_hatId)) {
            return (_isWearerOfHat(_user, _hatId));
        }

        uint8 adminHatLevel = getHatLevel(_hatId) - 1;

        while (adminHatLevel > 0) {
            if (_isWearerOfHat(_user, getAdminAtLevel(_hatId, adminHatLevel))) {
                return true;
            }

            adminHatLevel--;
        }

        return _isWearerOfHat(_user, getAdminAtLevel(_hatId, 0));
    }

    function _checkAdmin(uint256 _hatId) internal view {
        if (!_isAdminOfHat(msg.sender, _hatId)) {
            revert HatsErrors.NotAdmin(msg.sender, _hatId);
        }
    }

    /// @notice Checks the active status of a hat
    /// @dev For internal use instead of `isActive` when passing Hat as param is preferable
    /// @param _hat The Hat struct
    /// @param _hatId The id of the hat
    /// @return active The active status of the hat
    function _isActive(LibHatsStorage.Hat memory _hat, uint256 _hatId)
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

    function _getHatStatus(LibHatsStorage.Hat memory _hat)
        internal
        pure
        returns (bool)
    {
        return (_hat.config >> 95 != 0);
    }

    function _setHatStatus(LibHatsStorage.Hat storage _hat, bool _status)
        internal
    {
        if (_status) {
            _hat.config |= uint96(1 << 95);
        } else {
            _hat.config &= ~uint96(1 << 95);
        }
    }

    function _isMutable(LibHatsStorage.Hat memory _hat)
        internal
        pure
        returns (bool)
    {
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
    function _isInGoodStanding(address _wearer, uint256 _hatId)
        internal
        view
        returns (bool standing)
    {
        LibHatsStorage.Storage storage s = hatsStorage();

        (bool success, bytes memory returndata) = s
            ._hats[_hatId]
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
            standing = !s.badStandings[_hatId][_wearer];
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
        LibHatsStorage.Hat memory _hat,
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
            LibHatsStorage.Storage storage s = hatsStorage();
            eligible = !s.badStandings[_hatId][_wearer];
        }
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
    ) internal returns (LibHatsStorage.Hat memory hat) {
        LibHatsStorage.Storage storage s = hatsStorage();

        hat.details = _details;
        hat.maxSupply = _maxSupply;
        hat.eligibility = _eligibility;
        hat.toggle = _toggle;
        hat.imageURI = _imageURI;
        hat.config = _mutable ? uint96(3 << 94) : uint96(1 << 95);
        s._hats[_id] = hat;

        emit LibHatsStorage.HatCreated(
            _id,
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            _mutable,
            _imageURI
        );
    }

    /**
     * Hat Ids serve as addresses. A given Hat's Id represents its location in its
     * hat tree: its level, its admin, its admin's admin (etc, all the way up to the
     * tophat).
     *
     * The top level consists of 4 bytes and references all tophats.
     *
     * Each level below consists of 1 byte, and contains up to 255 child hats.
     *
     * A uint256 contains 4 bytes of space for tophat addresses and 28 additional bytes
     * of space, giving room for 28 levels of delegation, with the admin at each level
     * having space for 255 different child hats.
     *
     * A hat tree consists of a single tophat and has a max depth of 28 levels.
     */

    uint256 internal constant TOPHAT_ADDRESS_SPACE = 32; // 32 bits (4 bytes) of space for tophats, aka the "domain"
    uint256 internal constant LOWER_LEVEL_ADDRESS_SPACE = 8; // 8 bits (1 byte) of space for each of the levels below the tophat
    uint256 internal constant MAX_LEVELS = 28; // 28 levels below the tophat

    /// @notice Constructs a valid hat id for a new hat underneath a given admin
    /// @dev Check hats[_admin].lastHatId for the previous hat created underneath _admin
    /// @param _admin the id of the admin for the new hat
    /// @param _newHat the uint8 id of the new hat
    /// @return id The constructed hat id
    function buildHatId(uint256 _admin, uint8 _newHat)
        internal
        pure
        returns (uint256 id)
    {
        uint256 mask;
        // TODO: remove this loop
        for (uint256 i = 0; i < MAX_LEVELS; ++i) {
            mask = uint256(
                type(uint256).max >>
                    (TOPHAT_ADDRESS_SPACE + (LOWER_LEVEL_ADDRESS_SPACE * i))
            );
            if (_admin & mask == 0) {
                id =
                    _admin |
                    (uint256(_newHat) <<
                        (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - 1 - i)));
                return id;
            }
        }
    }

    /// @notice Identifies the level a given hat in its hat tree
    /// @param _hatId the id of the hat in question
    /// @return level (0 to 28)
    function getHatLevel(uint256 _hatId) internal pure returns (uint8) {
        uint256 mask;
        uint256 i;
        // TODO: get rid of this for loop and possibly use the YUL switch/case
        // syntax. Otherwise, return to the original syntax
        for (i = 0; i < MAX_LEVELS; ++i) {
            mask = uint256(
                type(uint256).max >>
                    (TOPHAT_ADDRESS_SPACE + (LOWER_LEVEL_ADDRESS_SPACE * i))
            );

            if (_hatId & mask == 0) return uint8(i);
        }

        return uint8(MAX_LEVELS);
    }

    /// @notice Checks whether a hat is a topHat
    /// @dev For use when passing a Hat object is not appropriate
    /// @param _hatId The hat in question
    /// @return bool Whether the hat is a topHat
    function isTopHat(uint256 _hatId) internal pure returns (bool) {
        return _hatId > 0 && uint224(_hatId) == 0;
    }

    /// @notice Gets the hat id of the admin at a given level of a given hat
    /// @param _hatId the id of the hat in question
    /// @param _level the admin level of interest
    /// @return uint256 The hat id of the resulting admin
    function getAdminAtLevel(uint256 _hatId, uint8 _level)
        internal
        pure
        returns (uint256)
    {
        uint256 mask = type(uint256).max <<
            (LOWER_LEVEL_ADDRESS_SPACE * (MAX_LEVELS - _level));

        return _hatId & mask;
    }

    /// @notice Gets the tophat domain of a given hat
    /// @dev A domain is the identifier for a given hat tree, stored in the first 4 bytes of a hat's id
    /// @param _hatId the id of the hat in question
    /// @return uint256 The domain
    function getTophatDomain(uint256 _hatId) internal pure returns (uint256) {
        return
            getAdminAtLevel(_hatId, 0) >>
            (LOWER_LEVEL_ADDRESS_SPACE * MAX_LEVELS);
    }

    /// @notice Gets the imageURI for a given hat
    /// @dev If this hat does not have an imageURI set, recursively get the imageURI from
    ///      its admin
    /// @param _hatId The hat whose imageURI we're looking for
    /// @return imageURI The imageURI of this hat or, if empty, its admin
    function _getImageURIForHat(uint256 _hatId)
        internal
        view
        returns (string memory)
    {
        LibHatsStorage.Storage storage s = hatsStorage();
        // check _hatId first to potentially avoid the `getHatLevel` call
        LibHatsStorage.Hat memory hat = s._hats[_hatId];

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
        if (level == 0) return s.baseImageURI;

        // otherwise, we check each of its admins for a valid imageURI
        uint256 id;

        // already checked at `level` above, so we start the loop at `level - 1`
        for (uint256 i = level - 1; i > 0; --i) {
            id = getAdminAtLevel(_hatId, uint8(i));
            hat = s._hats[id];
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
        return s.baseImageURI;

        /// TODO bring back the following in a way that actually works
        // return string.concat(baseImageURI, LibString.toString(_hatId));
    }

    /*//////////////////////////////////////////////////////////////
                            DIAMOND LOGIC
    //////////////////////////////////////////////////////////////*/
    /*//////////////////////////////////////////////////////////////
                            DIAMOND LOGIC
    //////////////////////////////////////////////////////////////*/

    // Internal function version of diamondCut
    function diamondCut(FacetCut[] memory _diamondCut) internal {
        for (
            uint256 facetIndex;
            facetIndex < _diamondCut.length;
            facetIndex++
        ) {
            bytes4[] memory functionSelectors = _diamondCut[facetIndex]
                .functionSelectors;
            address facetAddress = _diamondCut[facetIndex].facetAddress;
            // if (functionSelectors.length == 0) {
            //     revert NoSelectorsProvidedForFacetForCut(facetAddress);
            // }
            FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == FacetCutAction.Add) {
                addFunctions(facetAddress, functionSelectors);
            }
            // else if (action == IDiamond.FacetCutAction.Replace) {
            //     replaceFunctions(facetAddress, functionSelectors);
            // } else if (action == IDiamond.FacetCutAction.Remove) {
            //     removeFunctions(facetAddress, functionSelectors);
            // } else {
            //     revert IncorrectFacetCutAction(uint8(action));
            // }
        }
        // emit DiamondCut(_diamondCut, _init, _calldata);
        // initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        // if (_facetAddress == address(0)) {
        // revert CannotAddSelectorsToZeroAddress(_functionSelectors);
        // }
        LibHatsStorage.Storage storage s = hatsStorage();
        uint16 selectorCount = uint16(s.selectors.length);
        // enforceHasContractCode(
        //     _facetAddress,
        //     "LibDiamondCut: Add facet has no code"
        // );
        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            // address oldFacetAddress = s
            //     .facetAddressAndSelectorPosition[selector]
            //     .facetAddress;
            // if (oldFacetAddress != address(0)) {
            //     revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            // }

            s.facetAddressAndSelectorPosition[selector] = LibHatsStorage
                .FacetAddressAndSelectorPosition(_facetAddress, selectorCount);

            s.selectors.push(selector);
            selectorCount++;
        }
    }

    // function replaceFunctions(
    //     address _facetAddress,
    //     bytes4[] memory _functionSelectors
    // ) internal {
    //     DiamondStorage storage ds = diamondStorage();
    //     if (_facetAddress == address(0)) {
    //         revert CannotReplaceFunctionsFromFacetWithZeroAddress(
    //             _functionSelectors
    //         );
    //     }
    //     enforceHasContractCode(
    //         _facetAddress,
    //         "LibDiamondCut: Replace facet has no code"
    //     );
    //     for (
    //         uint256 selectorIndex;
    //         selectorIndex < _functionSelectors.length;
    //         selectorIndex++
    //     ) {
    //         bytes4 selector = _functionSelectors[selectorIndex];
    //         address oldFacetAddress = ds
    //             .facetAddressAndSelectorPosition[selector]
    //             .facetAddress;
    //         // can't replace immutable functions -- functions defined directly in the diamond in this case
    //         if (oldFacetAddress == address(this)) {
    //             revert CannotReplaceImmutableFunction(selector);
    //         }
    //         if (oldFacetAddress == _facetAddress) {
    //             revert CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(
    //                 selector
    //             );
    //         }
    //         if (oldFacetAddress == address(0)) {
    //             revert CannotReplaceFunctionThatDoesNotExists(selector);
    //         }
    //         // replace old facet address
    //         ds
    //             .facetAddressAndSelectorPosition[selector]
    //             .facetAddress = _facetAddress;
    //     }
    // }

    // function removeFunctions(
    //     address _facetAddress,
    //     bytes4[] memory _functionSelectors
    // ) internal {
    //     DiamondStorage storage ds = diamondStorage();
    //     uint256 selectorCount = ds.selectors.length;
    //     if (_facetAddress != address(0)) {
    //         revert RemoveFacetAddressMustBeZeroAddress(_facetAddress);
    //     }
    //     for (
    //         uint256 selectorIndex;
    //         selectorIndex < _functionSelectors.length;
    //         selectorIndex++
    //     ) {
    //         bytes4 selector = _functionSelectors[selectorIndex];
    //         FacetAddressAndSelectorPosition
    //             memory oldFacetAddressAndSelectorPosition = ds
    //                 .facetAddressAndSelectorPosition[selector];
    //         if (oldFacetAddressAndSelectorPosition.facetAddress == address(0)) {
    //             revert CannotRemoveFunctionThatDoesNotExist(selector);
    //         }

    //         // can't remove immutable functions -- functions defined directly in the diamond
    //         if (
    //             oldFacetAddressAndSelectorPosition.facetAddress == address(this)
    //         ) {
    //             revert CannotRemoveImmutableFunction(selector);
    //         }
    //         // replace selector with last selector
    //         selectorCount--;
    //         if (
    //             oldFacetAddressAndSelectorPosition.selectorPosition !=
    //             selectorCount
    //         ) {
    //             bytes4 lastSelector = ds.selectors[selectorCount];
    //             ds.selectors[
    //                 oldFacetAddressAndSelectorPosition.selectorPosition
    //             ] = lastSelector;
    //             ds
    //                 .facetAddressAndSelectorPosition[lastSelector]
    //                 .selectorPosition = oldFacetAddressAndSelectorPosition
    //                 .selectorPosition;
    //         }
    //         // delete last selector
    //         ds.selectors.pop();
    //         delete ds.facetAddressAndSelectorPosition[selector];
    //     }
    // }

    // function initializeDiamondCut(address _init, bytes memory _calldata)
    //     internal
    // {
    //     if (_init == address(0)) {
    //         return;
    //     }
    //     enforceHasContractCode(
    //         _init,
    //         "LibDiamondCut: _init address has no code"
    //     );
    //     (bool success, bytes memory error) = _init.delegatecall(_calldata);
    //     if (!success) {
    //         if (error.length > 0) {
    //             // bubble up error
    //             /// @solidity memory-safe-assembly
    //             assembly {
    //                 let returndata_size := mload(error)
    //                 revert(add(32, error), returndata_size)
    //             }
    //         } else {
    //             revert InitializationFunctionReverted(_init, _calldata);
    //         }
    //     }
    // }

    // function enforceHasContractCode(
    //     address _contract,
    //     string memory _errorMessage
    // ) internal view {
    //     uint256 contractSize;
    //     assembly {
    //         contractSize := extcodesize(_contract)
    //     }
    //     if (contractSize == 0) {
    //         revert NoBytecodeAtAddress(_contract, _errorMessage);
    //     }
    // }

    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }
    // Add=0, Replace=1, Remove=2

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}
