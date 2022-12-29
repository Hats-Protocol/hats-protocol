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

import {LibHatsDiamond} from "./Lib/LibHatsDiamond.sol";
import "./Lib/LibHatsStorage.sol";

contract HatsDiamond {
    // LibHatsStorage.Storage internal s;

    constructor(
        string memory _name,
        string memory _baseImageURI,
        LibHatsDiamond.FacetCut[] memory _diamondCut
    ) {
        LibHatsStorage.Storage storage s = LibHatsDiamond.hatsStorage();
        s.name = _name;
        s.baseImageURI = _baseImageURI;
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        LibHatsStorage.Storage storage s = LibHatsDiamond.hatsStorage();
        // get facet from function selector
        address facet = s.facetAddressAndSelectorPosition[msg.sig].facetAddress;
        if (facet == address(0)) {
            // revert FunctionNotFound(msg.sig);
        }
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
