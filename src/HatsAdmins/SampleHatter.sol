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

import "../HatsEligibility/IHatsEligibility.sol";
import "../Interfaces/IHats.sol";
import "utils/Auth.sol";

/// @notice designed to serve as the admin for multiple hats
abstract contract SampleMultiHatter is Auth {
    IHats public HATS;

    constructor(address _hatsContract) {
        HATS = IHats(_hatsContract);
    }

    // DAO governance mint function (auth)
    function mint(uint256 _hatId, address _wearer) public virtual requiresAuth {
        _mint(_hatId, _wearer);
    }

    function _mint(uint256 _hatId, address _wearer) internal virtual {
        require(HATS.isInGoodStanding(_wearer, _hatId), "not eligible");
        HATS.mintHat(_hatId, _wearer);
    }

    function createAndMint(
        uint256 _admin,
        string memory _details,
        uint32 _maxSupply,
        address _eligibility,
        address _toggle,
        address _wearer,
        bool _mutable,
        string memory _imageURI
    ) public virtual requiresAuth {
        uint256 id = HATS.createHat(
            _admin,
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            _mutable,
            _imageURI
        );
        _mint(id, _wearer);
    }

    // DAO governance transfer function (auth)
    function transfer(
        uint256 _hatId,
        address _wearer,
        address _newWearer
    ) public virtual requiresAuth {
        HATS.transferHat(_hatId, _wearer, _newWearer);
    }
}
