// SPDX-License-Identifier: CC0

pragma solidity >=0.8.13;

import "./IHatsEligibility.sol";
import "../IHats.sol";
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";

abstract contract HatsERC20Eligibility is IHatsEligibility {
    event TokenCriterionAdded(
        uint256 _hatId,
        address _token,
        uint256 _threshold
    );

    // only hat admins can set a criterion
    error NotHatAdmin(address _user, uint256 _hatId);

    // criteria cannot be changed once established
    error CriterionAlreadyExists(uint256 _hatId);

    IHats public HATS;

    struct Criterion {
        IERC20 token;
        uint256 threshold;
    }

    mapping(uint256 => Criterion) public criteria; // key: hatId | value: Criterion

    constructor(address _hatsContract) {
        HATS = IHats(_hatsContract);
    }

    function addTokenCriterion(
        uint256 _hatId,
        address _token,
        uint256 _threshold
    ) public {
        if (criteria[_hatId].token != address(0))
            revert CriterionAlreadyExists(_hatId);

        if (!HATS.isAdminOfHat(msg.sender, _hatId))
            revert NotHatAdmin(msg.sender, _hatId);

        Criterion crit = new Criterion;
        crit.token = IERC20(_token);
        crit.threshold = _threshold;

        emit TokenCriterionAdded(_hatId, _token, _threshold);
    }

    // TODO add a way to change a criterion, perhaps with approval from both the hat admin and wearer(s)

    // to be called by Hats.sol when checking wearer eligibility for revocation, etc
    function getWearerStatus(address _wearer, uint256 _hatId)
        external
        view
        override
        returns (bool eligible, bool standing)
    {
        standing = true; // for simplicity, this example does not adjust standing

        Criterion crit = criteria[_hatId];

        uint256 balance = crit.token.balanceOf(_wearer);

        eligible = (balance >= crit.threshold);
    }
}
