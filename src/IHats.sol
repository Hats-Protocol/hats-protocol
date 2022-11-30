// SPDX-License-Identifier: AGPL v3
pragma solidity >=0.8.13;

interface IHats {
    function createHat(
        uint256 admin,
        string memory details, // encode as bytes32 ??
        uint32 maxSupply,
        address oracle,
        address conditions
    ) external returns (uint256 hatId);

    function mintHat(uint256 _hatId, address _wearer) external returns (bool);

    function batchMintHats(uint256[] memory _hatIds, address[] memory _wearers)
        external
        returns (bool);

    function getHatStatus(uint256 hatId) external returns (bool);

    function setHatStatus(uint256 hatId, bool newStatus)
        external
        returns (bool);

    function getHatWearerStatus(uint256 hatId, address wearer)
        external
        returns (bool);

    function setHatWearerStatus(
        uint256 hatId,
        address wearer,
        bool revoke,
        bool wearerStanding
    ) external returns (bool);

    function renounceHat(uint256 _hatId) external;

    function transferHat(
        uint256 _hatId,
        address _from,
        address _to
    ) external;

    function batchTransferHats(
        uint256[] memory _hatIds,
        address[] memory _froms,
        address[] memory _tos
    ) external;

    function viewHat(uint256 _hatId)
        external
        view
        returns (
            string memory details,
            uint32 maxSupply,
            uint32 supply,
            address oracle,
            address conditions,
            bool active
        );

    function isTopHat(uint256 _hatId) external pure returns (bool);

    function isWearerOfHat(address _user, uint256 _hatId)
        external
        view
        returns (bool);

    function isAdminOfHat(address _user, uint256 _hatId)
        external
        view
        returns (bool);

    function getHatLevel(uint256 _hatId) external pure returns (uint8 level);

    function isActive(uint256 _hatId) external view returns (bool);

    function isInGoodStanding(address _wearer, uint256 _hatId)
        external
        view
        returns (bool);

    function balanceOf(address wearer, uint256 hatId)
        external
        view
        returns (uint256 balance);
}
