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

interface IHatsEligibility {
    /// @notice Returns the status of a wearer for a given hat
    /// @dev If standing is false, eligibility MUST also be false
    /// @param _wearer The address of the current or prospective Hat wearer
    /// @param _hatId The id of the hat in question
    /// @return eligible Whether the _wearer is eligible to wear the hat
    /// @return standing Whether the _wearer is in goog standing
    function getWearerStatus(address _wearer, uint256 _hatId) external view returns (bool eligible, bool standing);
}
