pragma solidity >=0.8.0;

import "/ERC721.sol";
import "HatsEligibility/IHatsEligibility.sol";

interface IHats is ERC721{
    
    public immutable address eligibility;

    // Hats Functiopn -----

    function createHat(string name, // encode as bytes32 ??
                       string details,  // encode as bytes32 ??
                       uint256 eligibilityThreshold, 
                       address owner, 
                       address oracle, 
                       address conditions) public returns (uint256 hatId);

    function recordOffer(uint256 hatId, 
                         address offeror, 
                         uint256 amount) onlyHatsEligibility returns (uint256 offerId);

    function acceptOffer(uint256 offerId) onlyHatOwner returns (bool);

    function mintHat(uint256 hatId, address wearer) internal returns (bool);

    function burnHat(uint256 hatId) internal returns (bool);

    function checkHatConditions(uint256 hatId) public returns (bool);

    function deactivateHat(uint256 hatId) onlyConditions returns (bool);

    function requestOracleRuling(uint256 hatId) public returns (bool);

    function rule(uint256 hatId, bool ruling) onlyOracle returns (bool);

    function recordRelinquishment(uint256 hatId, address wearer) onlyHatsEligibility returns (bool success, uint256 amount);

    function unlockEligibility(uint256 hatId, address wearer) internal returns (bool);
    
    modifier onlyHatsEligibility;
    
    modifier onlyHatOwner;
    
    modifier onlyConditions;
    
    modifier onlyOracle;

}