// SPDX-License-Identifier: CC0

pragma solidity >=0.8.13;

interface IHatsStatusController {
    function getHatStatus(uint256 _hatId) external view returns (bool);
}
