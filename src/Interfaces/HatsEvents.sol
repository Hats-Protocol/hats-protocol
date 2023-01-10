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

interface HatsEvents {
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

    event TopHatLinked(uint32 domain, uint256 newAdmin);
}
