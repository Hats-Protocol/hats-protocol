// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

contract HatsIdUtilities {
    uint256 internal constant TOPHAT_BITS = 32;
    uint256 internal constant LEVEL_BITS = 8;
    uint256 internal constant HAT_TREE_DEPTH = 28;

    function getHatLevel(uint256 _hatId) public pure returns (uint8 level) {
        uint256 mask;
        uint256 i;
        for (i = 0; i < HAT_TREE_DEPTH; ++i) {
            mask = uint256(
                type(uint256).max >> (TOPHAT_BITS + (LEVEL_BITS * i))
            );

            if (_hatId & mask == 0) return uint8(i);
        }
    }

    function getAdminAtLevel(uint256 _hatId, uint8 _level)
        public
        pure
        returns (uint256)
    {
        uint256 mask = type(uint256).max <<
            (LEVEL_BITS * (HAT_TREE_DEPTH - _level));

        return _hatId & mask;
    }

    function buildHatId(uint256 _admin, uint8 _newChild)
        public
        pure
        returns (uint256)
    {
        uint256 mask;
        for (uint256 i = 0; i < HAT_TREE_DEPTH; ++i) {
            mask = uint256(
                type(uint256).max >> (TOPHAT_BITS + (LEVEL_BITS * i))
            );
            if (_admin & mask == 0) {
                return
                    _admin |
                    (uint256(_newChild) <<
                        (LEVEL_BITS * (HAT_TREE_DEPTH - 1 - i)));
            }
        }
    }
}
