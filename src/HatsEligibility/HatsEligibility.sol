// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

import "../IHats.sol";

abstract contract HatsEligibility {
    address public immutable hats;

    constructor(address _hats) {
        hats = _hats;
    }

    // records eligibility. Needs to be called by public or external function
    function submitEligibility() internal virtual returns (bool);

    // records offer in Hats contract. Needs to be called by public or external function
    function submitOffer(uint256 hatId, uint256 amount) external {
        IHats(hats).recordOffer(hatId, msg.sender, amount);
    }

    function relinquishHat(uint256 hatId) public returns (bool) {
        IHats HATS = IHats(hats);
        (bool success, uint256 amount) = HATS.recordRelinquishment(
            hatId,
            msg.sender
        );
        if (success) {
            _unlockEligibility(msg.sender, amount);
        }

        return true;
    }

    function unlockEligibility(address user, uint256 amount)
        external
        onlyHats
        returns (bool)
    {
        _unlockEligibility(user, amount);

        return true;
    }

    // unlocks the msg.sender's eligibility after no longer wearing a hat
    function _unlockEligibility(address user, uint256 amount)
        internal
        virtual
        returns (bool)
    {
        // eg return stake
    }

    function penalize(address user, uint256 amount)
        external
        virtual
        onlyHats
        returns (bool)
    {
        // eg slash stake
    }

    function checkEligibility(address _user, uint256 _hatId)
        public
        view
        virtual
        returns (uint256);

    modifier onlyHats() {
        require(msg.sender == hats);
        _;
    }
}
