// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

interface HatsErrors {
    error NotAdmin(address _user, uint256 _hatId);
    error AllHatsWorn(uint256 _hatId);
    error AlreadyWearingHat(address _wearer, uint256 _hatId);
    error HatDoesNotExist(uint256 _hatId);
    error NotEligible(address _wearer, uint256 _hatId);
    // error NoApprovalsNeeded();
    // error OnlyAdminsCanTransfer();
    error NotHatWearer();
    error NotHatsToggle();
    error NotHatsEligibility();
    // error NotIHatsToggleContract();
    // error NotIHatsEligibilityContract();
    error BatchArrayLengthMismatch();
    // error SafeTransfersNotNecessary();
    error MaxLevelsReached();
    error Immutable();
    error NewMaxSupplyTooLow();
}