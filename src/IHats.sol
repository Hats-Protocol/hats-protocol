// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

interface IHats {
    function createHat(
        string memory details, // encode as bytes32 ??
        uint32 maxSupply,
        address oracle,
        address conditions
    ) external returns (uint256 hatId);

    // function recordOffer(
    //     uint256 hatId,
    //     address offeror,
    //     uint256 amount
    // ) external returns (uint256 offerId);

    // function acceptOffer(uint256 offerId) external returns (bool);

    function getHatStatus(uint256 hatId) external returns (bool);

    function setHatStatus(uint256 hatId, bool newStatus) external returns (bool);

    function getHatWearerStatus(uint256 hatId, address wearer) external returns (bool);

    function setHatWearerStatus(uint256 hatId, address wearer, bool revoke, bool wearerStanding) external returns (bool);
}
