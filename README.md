# hats-protocol
Core contracts for Hats Protocol

## Overview

Hats Protocol is a protocol for DAO-native roles and credentials that support delegation of authorities. 

Hats are represented on-chain by ERC1155 tokens. An address with a balance of a given Hat token "wears" that hat, granting them the responsibilities and authorities that have been assigned to the Hat by the DAO.

### Hat Authorities
Hats Protocol does not define mechanisms for authorities and responsibilities to be associated with a Hat. All associations between a Hat and its authorities or responsibilities are created external to the protocol. 

You can think of a Hat's ERC1155 token as a credentialing primitive that creates a substrate onto which a DAO can attach authorities and responsibilities by using other tools.

Here are a few examples of how a DAO might confer authorities and responsibilities to a Hat:

| Authority or Responsibility | How is it attached to the Hat? |
| --- | ---- |
| Signer on a multisig | Using the Hat's ERC1155 token as a condition for membership in an Orca Protocol Pod | 
| Admin of the DAO's Github repo | Using the Hat's ERC1155 token as a condition for access via Lit Protocol | 
| Leadership of a working group | A social expectation |

In each case, the DAO uses a separate tool to attach the authority to the Hat.

Hats is designed this way in order to be highly composable -- it will work with any tool, application, or protocol that can interact with ERC1155. Further, it allows any number of such authorities or responsibilities to be attached to a single Hat, which greatly simplifies the process for DAOs of revoking those authorities as well as the process of role handoff.

#### Exception: Hat Admins
Hat admins are the one exception to the rule that authorities are external to the Hats Protocol. Refer to the Admins section below for more details.

## Hats Logic

Each Hat has several properties:

- `id` - the integer identifier for the Hat, which also serves as the ERC1155 token id (see three paragraphs below)
- `details` - metadata about the Hat; such as a name, description, and other properties like 
- `maxSupply` - the maximum number of addresses that can wear the Hat at once
- `admin` - the Hat that controls who can wear the Hat
- `oracle` - the address that controls whether a given wearer of the Hat is in good standing
- `conditions` - the address that controls whether the Hat is active

For more information on each property, refer to the detailed sections below.

#### Hat Struct Variable Packing
Within the contract, each Hat is represented by a struct. To minimize storage costs (gas) associated with creating a new Hat, variables in these structs are tightly packed into just three storage slots. This is accomplished by limiting the following variable types to less than 264 bits (32 bytes):
- `hatId` is typed as uint64 (8 bytes)
- `maxSupply` is typed as to uint32 (4 bytes)

This limits the total number of Hats that can exist to 2^64 (over 1 quintillion) and the max supply of any given Hat to 2^32 (over 2 billion). Both limits are plenty sufficient to support the use of Hats Protocol for many many years.

This also requires that the contract we do some casting of `hatId`s when working with ERC1155 functions, since ERC1155 token ids uint256 for 

### Wearing a Hat
The wearer of a given Hat is assigned the authorities and responsibilities associated with the Hat.

A wearer's standing relating to a given Hat is determined by three factors. All three must be true.
1. Whether their address has a balance (of 1) of the Hat's token
2. Whether the Hat is active (see the Conditions section for more detail)
3. Whether they are in good standing (see the Oracles section for more detail)

All of these factors are reflected in the `Hats.balanceOf` function, which will return `0` if any of the factors are false.

Any address can wear a Hat, including:
- Externally Owned Accounts (EOAs)
- Logic contracts (i.e., contracts with explicit logic codified within functions), or 
- Governance contracts (e.g., DAOs, multisigs, etc.)

### Hat Admins
The admin of every Hat is another Hat. This means that the authority to perform admin functions for a given Hat is assigned to the wearer of its admin Hat.

The scope of authority for a Hat's admin is to determine who can wear it. This is reflected in the ability create the Hat and to to mint or transfer the Hat's token.

#### Hatter Contracts
Logic contracts that serve as admins are informally known as "hatter" contracts. These are contracts that implement specific logic or rules. The admin of a hatter contract is the true admin, but has delegated said admin authority to the logic embedded in the hatter.

Hatter contract logic is a wide design space for DAOs. Here are some examples of hatter logic:
- **Wearer eligibility** - Enforce certain requirements that prospective wearers must meet in order to wear a given Hat, such as membership in a DAO or holding some token(s).
- **Wearer staking** - One particularly important type of eligibility requirement is staking tokens, DAO shares, or some other asset as a bond that could be slashed if the wearer is not a good steward of the accountabilities associated with the Hat, or does not follow through on its associated responsibilities.
- **Hat creation** - Allow certain addresses -- such as members of a DAO -- to create Hats that are then admin'd by the DAO.
- **Hat minting** - Allow certain addresses -- such as members of a DAO -- to mint Hat tokens. Together with the above, a DAO could in this way enable its members to create and wear a certain type of Hat permissionlessly. This would be esepcially if using Hats to facilitate role clarity and legibility.

#### Hat Trees
The ability of a Hat to be an admin of other Hats creates the possibility for a "tree" of Hats, a structure of Hats serving as admins of other Hats. This is useful because it enables a DAO to snip off, but not destroy, a rogue branch by revoking the offending Hat. It could then re-assign that admin Hat to another wearer.

Within a given branch of a hat tree, Hats closer to the root of the tree have admin authorities for Hats further down the branch. This is consistent with the direction of delegation of authority for DAOs, and combats the tendency for accountability to dilute as delegated authorities reach the edges of a network.

#### Tophats
Tophats are the one exception to the rule that a Hat's admin must be another hat. A Tophat is a Hat that serves as its own admin. 

The root of a Hat tree is always a Tophat. Typically, a DAO will wear the Tophat that serves as admin for the tree of Hats related to the DAO's operations.

### Oracles
Oracles have authority to rule on the good standing of wearers of a given Hat. This authority is reflected in an oracle's ability to trigger revocation of a Hat from a wearer, which burns the wearer's Hat token.

Revocations are stored on-chain to facilitate accountability. For example, a hatter contract implementing staking logic could slash a wearer's stake if their Hat were revoked.

Any address can serve as an oracle. There are two categories of oracles within Hats Protocol:
1. **Mechanistic oracles** are logic contracts that implement the `IHatsOracle` interface, which enables the Hats contract to *pull* wearer standing by calling `checkwearerStanding` from within the `Hats.balanceOf` function. Mechanistic oracles enable instantaneous revocation based on pre-defined triggers.
2. **Humanistic oracles** are either EOAs or governance contracts. To revoke a Hat, humanistic oracles must *push* updates to the Hats contract by calling `Hats.ruleOHatWearerStanding`.

Unlike admins, oracles are explicitly set as addresses, not Hats. This is to avoid long, potentially illegible, chains of revocation authority that can affect wearer penalties (such as slashed stake).

### Conditions
Conditions have authority to toggle the `hat.active` status of a Hat, such as from `active` to `inactive`. When a Hat is inactive, it does not have any wearers (i.e., the balance of its previous wearers' is changed to 0).

Any address can serve as a Hat's conditions. As with oracles, there are two categories of conditions within Hats Protocol:
1. **Mechanistic conditions** are logic contracts that implement the `IHatsConditions` interface, which enables the Hats contract to *pull* Hat active status by calling `checkConditions` from within the `Hats.balanceOf` function. Mechanistic conditions enable instantaneous deactivation (or reactivation) based on pre-defined conditions, such as timestamps ("this Hat expires at the end of the year").
2. **Humanistic conditions** are either EOAs or governance contracts. To deactivate (or reactivate) a Hat, humanistic conditions must *push* updates to the Hats contract by calling `Hats.toggleHatStatus`.

Unlike admins, conditions are explicitly set as addresses, not Hats.

### Creating a Hat
The creator of a Hat must be its admin. In other words, the admin of a Hat must be the `msg.sender` of the `Hats.createHat` function call. Though remember, by delegating its authority to a hatter contract, an admin can enable eligible others to create Hats based on whatever logic it desires.

Creating a Tophat (a Hat that serves as its own admin) requires a special function `createTophat(address _target_)`, which creates a new Hat, sets that Hat as its own admin, and then mints its token to `_target`. Any address that wants to create a Hat must first create a Tophat with itself as the wearer.

#### Creating a Hat Tree
In some scenarios, a DAO may want to create an entire tree of Hats at once. This is particularly useful when setting up an initial structure for a DAO or working group (e.g., from a Hats template) or when forking an existing Hats structure from a 

Enabling this latter forking/exit scenario is an important protection for Hat wearers against potentialy abuse of power by their DAO.

To create a Hat tree, a DAO can call the `Hats.createHatsTree()` function. This function takes arrays as its arguments, from which it constructs multiple Hats. As long as each of these Hats is part of the same tree of Hats &mdash; i.e., they either have the same existing Hat or any of the newly created Hats as admin(s) &mdash; they can all be created together.

### Minting a Hat
Only a Hat's admin can mint its token to a wearer. 

To mint a Hat, the Hat's max supply must not have already been reached, and the target wearer must not already wear the Hat.

A Hat's admin can mint its token individually by calling `Hats.mintHat`.

#### Batch Minting
Ad adminc can also mint multiple Hats by calling `Hats.batchMintHats`. This enables an admin to mint instances of the same hat to multiple wearers, to mint several Hat at once, or even to mint an entire Hats tree it just created.

### Transfers
Only a Hat's admin can transfer its token(s) to new wearer(s). 

Unlike typical tokens, the wearer of a Hat cannot transfer theirs. This is because the authorities and responsibilities associated with a Hat are delegated to, not owned by, the wearer.

As a result, there is no need for safe transfers (transfers which check whether the recipient supports ERC1155) or to pass data to recipient `on1155Received` or `onERC1155BatchReceived` hooks.

For these reasons, in Hats Protocol, the standard ERC1155 transfer functions &mdash; `safeTransferFrom` and `safeBatchTransferFrom` are disabled and will always revert. Similarly, token approvals are not required and `setApprovalForAll` will always revert.

As replacements, Hats can be transfered by admins via `Hats.transferHat`, which emits the ERC1155 standard event `TransferSingle`.

### Batch Transfers
As with minting, admins can also transfer Hats in a batch, via `Hats.batchTransferHats`. 

Since batch Hats transfers can be made from and to multiple wearers, batch transfers emit multiple `TransferSingle` events rather than a `TransferBatch` event.

### Renouncing a Hat
The wearer of a Hat can "take off" their Hat via `Hats.renounceHat`. This burns the token and revokes any associated authorities and responsibilities, but does not record a revocation.

## Latest Deployments
- Goerli (chain id #5) &mdash; `0xb7019c3670f5d4dd99166727a7d29f8a16f4f20a`

## How to Contribute

TODO