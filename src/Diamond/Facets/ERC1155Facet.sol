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
import {LibHatsDiamond} from "../Lib/LibHatsDiamond.sol";
import "solbase/utils/Base64.sol";
import "solbase/utils/LibString.sol";

contract ERC1155Facet {
    LibHatsStorage.Storage internal s;

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = s._balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /// @notice Gets the Hat token balance of a user for a given Hat
    /// @param wearer The address whose balance is being checked
    /// @param hatId The id of the Hat
    /// @return balance The `_user`'s balance of the Hat tokens. Will typically not be greater than 1.
    function balanceOf(address wearer, uint256 hatId)
        public
        view
        returns (uint256 balance)
    {
        balance = LibHatsDiamond._dynamicBalanceOf(wearer, hatId);
    }

    function setApprovalForAll(address operator, bool approved) public pure {
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
    ) public pure {
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
    ) public pure {
        revert();
    }

    /// @notice View the uri for a Hat
    /// @param id The id of the Hat
    /// @return string An 1155-compatible JSON object
    function uri(uint256 id) public view returns (string memory) {
        return _constructURI(uint256(id));
    }

    /// @notice Constructs the URI for a Hat, using data from the Hat struct
    /// @param _hatId The id of the Hat
    /// @return An ERC1155-compatible JSON string
    function _constructURI(uint256 _hatId)
        internal
        view
        returns (string memory)
    {
        LibHatsStorage.Hat memory hat = s._hats[_hatId];

        uint256 hatAdmin;

        if (LibHatsDiamond.isTopHat(_hatId)) {
            hatAdmin = _hatId;
        } else {
            hatAdmin = LibHatsDiamond.getAdminAtLevel(
                _hatId,
                LibHatsDiamond.getHatLevel(_hatId) - 1
            );
        }

        // split into two objects to avoid stack too deep error
        string memory idProperties = string.concat(
            '"domain": "',
            LibString.toString(LibHatsDiamond.getTophatDomain(_hatId)),
            '", "id": "',
            LibString.toString(_hatId),
            '", "pretty id": "',
            "{id}",
            '",'
        );

        string memory otherProperties = string.concat(
            '"status": "',
            (LibHatsDiamond._isActive(hat, _hatId) ? "active" : "inactive"),
            '", "current supply": "',
            LibString.toString(s.hatSupply[_hatId]),
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
            LibHatsDiamond._isMutable(hat) ? "true" : "false",
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
                                LibHatsDiamond._getImageURIForHat(_hatId),
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
}
