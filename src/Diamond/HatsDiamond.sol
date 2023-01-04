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
import "forge-std/Test.sol"; // remove after testing
import "solbase/utils/LibString.sol"; // remove after testing

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

        LibHatsDiamond.diamondCut(_diamondCut);
    }

    // function toHexDigit(uint8 d) internal pure returns (bytes1) {
    //     if (0 <= d && d <= 9) {
    //         return bytes1(uint8(bytes1("0")) + d);
    //     } else if (10 <= uint8(d) && uint8(d) <= 15) {
    //         return bytes1(uint8(bytes1("a")) + d - 10);
    //     }
    //     revert();
    // }

    // function fromCode(bytes4 code) public view returns (string memory) {
    //     bytes memory result = new bytes(10);
    //     result[0] = bytes1("0");
    //     result[1] = bytes1("x");
    //     for (uint256 i = 0; i < 4; ++i) {
    //         result[2 * i + 2] = toHexDigit(uint8(code[i]) / 16);
    //         result[2 * i + 3] = toHexDigit(uint8(code[i]) % 16);
    //     }
    //     return string(result);
    // }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external {
        // console2.log("B");
        LibHatsStorage.Storage storage s = LibHatsDiamond.hatsStorage();
        // get facet from function selector
        address facet = s.facetAddressAndSelectorPosition[msg.sig].facetAddress;
        // console2.log(facet);
        // console2.log(fromCode(msg.sig));
        // if (facet == address(0)) {
        // revert FunctionNotFound(msg.sig);
        // }
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
