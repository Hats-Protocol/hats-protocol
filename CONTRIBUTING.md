# Contributing to Hats Protocol

Thank you for considering contributing to Hats Protocol. We welcome any contributions that can help improve the project, including bug reports, feature requests, and code changes.

## Getting Started

1. Fork the Project
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
3. Compile the contracts, run `forge build`, and to test, run `forge test`
4. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
5. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
6. Push to the Branch (`git push origin feature/AmazingFeature`)
7. Open a Pull Request &mdash; see the [checklist below](#pull-request-readiness-checklist) for what your PR should include

Existing deployments of Hats Protocol can be found in [Releases](https://github.com/Hats-Protocol/hats-protocol/releases). To deploy Hats Protocol yourself (e.g., for testing):

- Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Compile the contracts, run `forge build`, and to test, run `forge test`
- Deploy using the [Hats.s.sol script](script/Hats.s.sol) and follow the [Foundry scripting instructions](https://book.getfoundry.sh/tutorials/solidity-scripting)

## Code and Style Conventions

Hats Protocol follows certain conventions, including:

- Use custom errors (rather than in-line require statement strings), added to [HatsErrors.sol](src/Interfaces/HatsErrors.sol)
- New events should be added to [HatsEvents.sol](src/Interfaces/HatsEvents.sol)
- All new public or external functions should be added to the appropriate interface file, such as [IHats.sol](src/Interfaces/IHats.sol) or [IHatsIdUtilities.sol](src/Interfaces/IHatsIdUtilities.sol)
- We format all markdown according to the settings in [.markdownlintrc](./.markdownlintrc)
- All Solidity is formatted using Foundry's native formatter [forge fmt](https://github.com/foundry-rs/foundry/tree/master/fmt), currently using the following settings (also viewable in [foundry.toml](./foundry.toml)):

| `forge fmt` setting              | our value   |
| -------------------------------- | ----------- |
| line_length                      | 120         |
| tab_width                        | 4           |
| bracket_spacing                  | true        |
| int_types                        | long        |
| multiline_func_header            | attributes_first |
| quote_style                      | double      |
| number_underscore                | thousands   |
| override_spacing                 | true        |
| wrap_comments                    | true        |

## Documentation

All code changes should be accompanied by updates to documentation:

- Document all new functions (external and internal), data models, and state variables with [Solidity NatSpec](https://docs.soliditylang.org/en/v0.8.17/natspec-format.html)
- The above will be produced in an mdBook via Foundry's [forge doc](https://github.com/foundry-rs/foundry/tree/master/doc) module
- Update the [README](./README.md) and/or developer docs as needed

We also welcome contributions to the project's documentation itself!

## Testing

We require that all new code changes are thoroughly tested to ensure that the project remains stable and reliable. When submitting a pull request, please make sure to:

- Write thorough unit tests for all new code
- Ensure that all tests (existing and new) are passing
- Track test coverage with Foundry's `forge coverage` module
- Verify that contract sizes are under the [EIP-170 limit](https://eips.ethereum.org/EIPS/eip-170) when compiled with the optimizer set to at least `10_000` runs

## Pull Request Readiness Checklist

In summary, before submitting a PR, please complete each of the following items. Items that are explicitly checked in our [CI workflow](./.github/workflows/ci.yml) are flagged with "**(ci)**".

1. Thorough unit tests are written for all new code
2. Update the [test coverage tracker](./lcov.info) &mdash; run `forge coverage --report lcov`
3. Update the [gas snapshot tracker](./.gas-snapshot) &mdash; run `forge snapshot`
4. Ensure contract sizes are small enough to deploy &mdash; run `forge build --sizes` **(ci)**
5. Ensure all existing and new tests are passing &mdash; run `forge test` **(ci)**
6. Document all new Solidity code with NatSpec, and generate updated docs &mdash; run `forge doc`
7. Update the [README](./README.md) with any new or changed functionality
8. Ensure all markdown is formatted correctly &mdash; run `forge fmt` **(ci)**

## Contact Information

If you have any questions or need assistance with contributing to the Hats Protocol, please feel free to reach out to the project maintainers. Contact information can be found in the [README](./README.md#contact) file.

Thank you for your contributions!
