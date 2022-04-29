pragma solidity >=0.8.0;

import "/IHats.sol";

abstract contract HatsEligibility{
    
    public immutable address hats;
    
    // records eligibility. Needs to be called by public or external function
    function submitEligibility() internal returns (bool);
    
    // records offer in Hats contract. Needs to be called by public or external function
    function submitOffer(uint256 hatId, uint256 amount) internal returns (bool) {
        IHats(hats).recordOffer(hatId, msg.sender, amount);
    }
    
    function relinquishHat(uint256 hatId) public returns (bool) {
        (success, amount) = recordRelinquishment(hatId, msg.sender);
        if (success) {
            _unlockEligibility(msg.sender, amount)
        }
    }
    
    function unlockEligibility(address user, uint256 amount) external onlyHats returns (bool) {
        _unlockEligibility(user, amount)
    }
    
    // unlocks the msg.sender's eligibility after no longer wearing a hat
    function _unlockEligibility(address user, uint256 amount) virtual internal returns (bool) {
        // eg return stake
    }
    
    function penalize(address user, uint256 amount) external virtual onlyHats returns (bool) {
        // eg slash stake
    }
    
    function checkEligibility(address user) public view returns (uint256);
    
    modifier onlyHats {
        require(msg.sender == hats);
        _;
    }
}