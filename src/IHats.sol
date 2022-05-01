// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

interface IHats {
    function createHat(
        string memory name, // encode as bytes32 ??
        string memory details, // encode as bytes32 ??
        uint256 eligibilityThreshold,
        address owner,
        address oracle,
        address conditions
    ) external returns (uint256 hatId);

    function recordOffer(
        uint256 hatId,
        address offeror,
        uint256 amount
    ) external returns (uint256 offerId);

    function acceptOffer(uint256 offerId) external returns (bool);

    function checkHatConditions(uint256 hatId) external returns (bool);

    function deactivateHat(uint256 hatId) external returns (bool);

    function requestOracleRuling(uint256 hatId) external returns (bool);

    function rule(uint256 hatId, bool ruling) external returns (bool);

    function recordRelinquishment(uint256 hatId, address wearer)
        external
        returns (bool success, uint256 amount);
}
