// SPDX-License-Identifier: CC0
pragma solidity >=0.8.13;

interface HatsEvents {
    event HatCreated(
        uint256 id,
        string details,
        uint32 maxSupply,
        address eligibility,
        address toggle,
        bool mutable_,
        string imageURI
    );

    // event HatRenounced(uint256 hatId, address wearer);

    // event WearerStatus(
    //     uint256 hatId,
    //     address wearer,
    //     bool eligible,
    //     bool wearerStanding
    // );

    event HatStatusChanged(uint256 hatId, bool newStatus);

    event HatDetailsChanged(uint256 hatId, string newDetails);

    event HatEligibilityChanged(uint256 hatId, address newEligibility);

    event HatToggleChanged(uint256 hatId, address newToggle);

    event HatMutabilityChanged(uint256 hatId);

    event HatMaxSupplyChanged(uint256 hatId, uint32 newMaxSupply);

    event HatImageURIChanged(uint256 hatId, string newImageURI);
}