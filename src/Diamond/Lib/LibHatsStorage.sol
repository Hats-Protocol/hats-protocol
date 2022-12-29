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

library LibHatsStorage {
    /*//////////////////////////////////////////////////////////////
                                HATS EVENTS
    //////////////////////////////////////////////////////////////*/
    event HatCreated(
        uint256 id,
        string details,
        uint32 maxSupply,
        address eligibility,
        address toggle,
        bool mutable_,
        string imageURI
    );

    // event HatRenounced(uint256 hatId, address wearer);

    // event WearerStatus(
    //     uint256 hatId,
    //     address wearer,
    //     bool eligible,
    //     bool wearerStanding
    // );

    event HatStatusChanged(uint256 hatId, bool newStatus);

    event HatDetailsChanged(uint256 hatId, string newDetails);

    event HatEligibilityChanged(uint256 hatId, address newEligibility);

    event HatToggleChanged(uint256 hatId, address newToggle);

    event HatMutabilityChanged(uint256 hatId);

    event HatMaxSupplyChanged(uint256 hatId, uint32 newMaxSupply);

    event HatImageURIChanged(uint256 hatId, string newImageURI);

    /*//////////////////////////////////////////////////////////////
                                ERC1155 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
                                HATS DATA MODELS
    //////////////////////////////////////////////////////////////*/

    struct Hat {
        // 1st storage slot
        address eligibility; // ─┐ can revoke Hat based on ruling | 20
        uint32 maxSupply; //     │ the max number of identical hats that can exist | 4
        uint8 lastHatId; //     ─┘ indexes how many different hats an admin is holding | 1
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
                            DIAMOND DATA MODELS
    //////////////////////////////////////////////////////////////*/

    struct FacetAddressAndSelectorPosition {
        address facetAddress;
        uint16 selectorPosition;
    }

    /*//////////////////////////////////////////////////////////////
                                HATS STORAGE
    //////////////////////////////////////////////////////////////*/

    struct Storage {
        string name;
        uint32 lastTopHatId; // initialized at 0
        string baseImageURI;
        // see HatsIdUtilities.sol for more info on how Hat Ids work
        mapping(uint256 => Hat) _hats; // key: hatId => value: Hat struct
        mapping(uint256 => uint32) hatSupply; // key: hatId => value: supply
        // for external contracts to check if Hat was revoked because the wearer is in bad standing
        mapping(uint256 => mapping(address => bool)) badStandings; // key: hatId => value: (key: wearer => value: badStanding?)
        mapping(address => mapping(uint256 => uint256)) _balanceOf; // ERC1155 balanceOf
        // function selector => facet address and selector position in selectors array
        mapping(bytes4 => FacetAddressAndSelectorPosition) facetAddressAndSelectorPosition;
        bytes4[] selectors;
    }
}
