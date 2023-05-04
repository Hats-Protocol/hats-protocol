<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->

# <a name="readme-top"></a>

<!--
*** Attribution: thanks to @othneildrew for the Readme template!)
-->

<!-- SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
[![Contributors][contributors-shield]][contributors-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![Twitter][twitter-shield]][twitter-url]

<!-- LOGO -->
<br />
<div align="center">
  <a href="https://github.com/Hats-Protocol/hats-protocol">
    <img src="https://ipfs.io/ipfs/QmbQy4vsu4aAHuQwpHoHUsEURtiYKEbhv7ouumBXiierp9" alt="Hats Hat" width="300" height="300">
  </a>

  <h2 align="center">Hats Protocol</h3>

  <p align="center">
    How DAOs get things done
    <br />
    <br />
    <a href="https://hatsprotocol.xyz">Hats Protocol Website</a>
    ·
    <a href="https://github.com/Hats-Protocol/hats-protocol/issues">Report Bug</a>
    ·
    <a href="https://github.com/Hats-Protocol/hats-protocol/issues">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#latest-deployments">Deployments</a></li>
        <li><a href="#security-audits">Security Audits</a></li>
      </ul>
    </li>
    <!-- <li><a href="#getting-started">Getting Started</a></li>
    <li><a href="#use-cases">Use Cases</a></li> -->
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#hats-protocol-docs">Hats Protocol Docs</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project

Hats Protocol is a protocol for DAO-native roles and credentials that supports revocable delegation of authority and responsibility.

Hats are represented on-chain by non-transferable tokens that conform to the ERC1155 interface. An address with a balance of a given Hat token "wears" that hat, granting them the responsibilities and authorities that have been assigned to the Hat by the DAO.

### Deployments

For information on Hats Protocol versions and deployments, see [Releases](https://github.com/Hats-Protocol/hats-protocol/releases).

### Security Audits

This project has received two security audits, listed below. See the [audits](https://github.com/Hats-Protocol/hats-protocol/tree/main/audits) directory for the detailed reports.

| Auditor | Report Date | Review Commit Hash | Notes |
| --- | --- | --- | --- |
| Trust Security | Feb 23, 2023 | [60f07df](https://github.com/Hats-Protocol/hats-protocol/commit/60f07df0679ba52d4ad818b1bb3700d2f4f5a63a) | Report also includes findings from [Hats Protocol](https://github.com/Hats-Protocol/hats-protocol) audit |
| Sherlock | May 3, 2023 | [fafcfd](https://github.com/Hats-Protocol/hats-protocol/commit/fafcfdf046c0369c1f9e077eacd94a328f9d7af0) | Report also includes findings from [Hats Protocol](https://github.com/Hats-Protocol/hats-protocol) audit |

<!-- CONTRIBUTING -->
## Contributing

See [CONTRIBUTING.md](https://github.com/Hats-Protocol/hats-protocol/blob/main/CONTRIBUTING.md) for details on how to contribute.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- DOCUMENTATION -->
<a name="documentation-top"></a>

## Hats Protocol Docs

<!-- TABLE OF CONTENTS -->
### Table of Contents

<ol>
  <li><a href="#authorities-in-hats-protocol">Authorities in Hats Protocol</a></li>
  <li><a href="#hats-logic">Hats Logic</a></li>
  <li><a href="#erc1155-compatibility">ERC1155 Compatibility</a></li>
  <li><a href="#wearing-a-hat">Wearing a Hat</a></li>
  <li><a href="#hat-admins">Hat Admins</a></li>
  <li><a href="#addressable-hat-ids">Addressable Hat Ids</a></li>
  <li><a href="#eligibility">Eligibility</a></li>
  <li><a href="#toggle">Toggle</a></li>
  <li><a href="#hat-mutability">Hat Mutability</a></li>
  <li><a href="#hat-image-uris">Hat Image URIs</a></li>
  <li><a href="#creating-a-hat">Creating a Hat</a></li>
  <li><a href="#minting-a-hat">Minting a Hat</a> </li>
  <li><a href="#transferring-a-hat">Transferring a Hat</a></li>
  <li><a href="#hat-tree-grafting">Hat Tree Grafting</a></li>
  <li><a href="#renouncing-a-hat">Renouncing a Hat</a></li>
</ol>

### Authorities in Hats Protocol

One way to think about a Hat is as a primitive that creates a substrate onto which a DAO can attach authorities (e.g., access rights) and responsibilities via other tools (e.g., token-gating platforms).

Hats Protocol itself does not define mechanisms for how such authorities and responsibilities are associated with a Hat. All such associations are created external to the protocol.

Here are a few examples of how a DAO might confer authorities and responsibilities to a Hat:

| Authority | How is it attached to the Hat? |
| --- | ---- |
| Signer on a multisig | Using the Hat's ERC1155-similar token as a condition for membership in a Metropolis Pod |
| Admin of the DAO's Github repo | Using the Hat's ERC1155-similar token as a condition for access via Lit Protocol |
| Leadership of a working group | A social expectation |

In each case, the DAO uses a separate tool to attach the authority to the Hat.

Hats is designed to be highly composable -- it will work with any tool, application, or protocol that can interact with the ERC1155 interface. Further, it allows any number of such authorities or responsibilities to be attached to a single Hat, which greatly simplifies the process for DAOs of revoking those authorities as well as the process of role handoff.

#### Exception: Hat Admins

Hat admins are the one (very important!) exception to the rule that authorities are external to the Hats Protocol. Refer to the Admins section below for more details.

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### ERC1155 Compatibility

Hats Protocol conforms fully to the ERC1155 interface. All external functions required by the [ERC1155 standard](https://eips.ethereum.org/EIPS/eip-1155) are exposed by Hats Protocol. This is how Hats can work out of the box with existing token-gating applications.

However, Hats Protocol is not fully compliant with the ERC1155 standard. Since Hats are not transferable by their owners (aka "wearers"), there is little need for safe transfers and the `ERC1155TokenReceiver` logic. Developers building on top of Hats Protocol should note that mints and transfers of Hats will not, for example, include calls to `onERC1155Received`.

To avoid confusion, Hats Protocol does not claim to be ERC1155-compliant. Instead, we say that Hats Protocol has "ERC1155-similar" tokens. When referring specifically to the ERC1155 interface, however, we do say that Hats Protocol conforms fully.

### Hats Logic

Each Hat has several properties:

* `id` - the integer identifier for the Hat, which also serves as the ERC1155-similar token id (see three paragraphs below)
* `details` - metadata about the Hat; such as a name, description, and other properties like roles and responsibilities associated with the Hat. Should not exceed 7,000 characters.
* `maxSupply` - the maximum number of addresses that can wear the Hat at once
* `admin` - the Hat that controls who can wear the Hat
* `eligibility` - the address that controls eligibility criteria and whether a given wearer of the Hat is in good standing
* `toggle` - the address that controls whether the Hat is active
* `mutable` - whether the hat's properties can be changed by the admin
* `imageURI` - the URI for the image used in the Hat's ERC1155-similar token. Should not exceed 7,000 characters.

For more information on each property, refer to the detailed sections below.

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### Wearing a Hat

The wearer of a given Hat is assigned the authorities and responsibilities associated with the Hat.

A wearer's status relating to a given Hat is determined by three factors. All three must be true.

1. Whether their address has a balance (of 1) of the Hat's token
2. Whether the Hat is active (see the Toggle section for more detail)
3. Whether they are eligible (see the Eligibility section for more detail)

All of these factors are reflected in the `Hats.balanceOf` function, which will return `0` if any of the factors are false.

Any address can wear a Hat, including:

* Externally Owned Accounts (EOAs)
* Logic contracts (i.e., contracts with explicit logic codified within functions), or
* Governance contracts (e.g., DAOs, multisigs, etc.)

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### Hat Admins

The admin of every Hat is another Hat. This means that the authority to perform admin functions for a given Hat is assigned to the wearer of its admin Hat.

The scope of authority for a Hat's admin is to determine who can wear it. This is reflected in the ability to create the Hat and to mint or (for mutable Hats) transfer the Hat's token.

#### Hatter Contracts

Logic contracts that serve as admins are informally known as "hatter" contracts. These are contracts that implement specific logic or rules. The admin of a hatter contract is the true admin, but has delegated said admin authority to the logic embedded in the hatter.

Hatter contract logic is a wide design space for DAOs. Here are some examples of hatter logic:

* **Wearer eligibility** - Enforce certain requirements that prospective wearers must meet in order to wear a given Hat, such as membership in a DAO or holding some token(s).
* **Wearer staking** - One particularly important type of eligibility requirement is staking tokens, DAO shares, or some other asset as a bond that could be slashed if the wearer is not a good steward of the accountabilities associated with the Hat, or does not follow through on its associated responsibilities.
* **Hat creation** - Allow certain addresses -- such as members of a DAO -- to create Hats that are then admin'd by the DAO.
* **Hat minting** - Allow certain addresses -- such as members of a DAO -- to mint Hat tokens. Together with the above, a DAO could in this way enable its members to create and wear a certain type of Hat permissionlessly. This would be especially if using Hats to facilitate role clarity and legibility.

#### Hat Trees

The ability of a Hat to be an admin of other Hats creates the possibility for a "tree" of Hats, a structure of Hats serving as admins of other Hats. This is useful because it enables a DAO to snip off, but not destroy, a rogue branch by revoking the offending Hat. It could then re-assign that admin Hat to another wearer.

Within a given branch of a hat tree, Hats closer to the root of the tree have admin authorities for Hats further down the branch. This is consistent with the direction of delegation of authority for DAOs, and combats the tendency for accountability to dilute as delegated authorities reach the edges of a network.

#### Tophats

Tophats are the one exception to the rule that a Hat's admin must be another hat. A Tophat is a Hat that serves as its own admin.

The root of a Hat tree is always a Tophat. Typically, a DAO will wear the Tophat that serves as admin for the tree of Hats related to the DAO's operations.

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### Addressable Hat Ids

Hat ids are uint256 bitmaps that create an "address" &mdash; more like an web or IP address than an Ethereum address &mdash; that includes information about the entire branch of admins for a given hat.

The 32 bytes of a hat's id are structured as follows:

* The first 4 bytes are reserved for the top hat id. Since top hat ids are unique across a given deployment of Hats Protocol, we can also think of them as the top level "domain" for a hat tree.
* Each of the next chunks of 16 bits refers to a single "Hat Level".

This means there are 15 total hat levels, beginning with the top hat at level 0 and going up to level 14. A hat at level 6 will have 6 admins in its branch of the tree, and therefore its id will have non-zero values at levels 0-5 as well as its own level. Since these values correspond to its admins, all that is needed to know which hats have admin authorities over a given hat is to know that given hat's id.

#### Hat Tree Space

A hat tree can have up to 14 levels, plus the top hat (tree root). Within those 14 levels are 224 bits of address space (remember, one level contains 16 bits of space), so the maximum number of hats in a single hat tree is $2^{224} + 1 \approx ~2.696 * 10^{67}$, or well beyond the number of stars in the universe.

#### Displaying Hat Ids

It is recommended for front ends to instead convert hat ids to hexadecimal, revealing the values of the bytes &mdash; and therefore the hat levels &mdash; directly.

For example, instead of a hat id looking like this under base 10: `26960769438260605603848134863118277618512635038780455604427388092416`

...under hexadecimal it would look like this: `0x0000000100020003000000000000000000000000000000000000000000000000`

In this second version, you can see that this hat is...

* a level 2 hat
* is in the first hat tree (top hat id = 1)
* is the third hat created at level 2 within this tree
* admin'd by the second hat created at level 1 within this tree

We can also prettify this even further by separating hat levels with periods, a la IP addresses:

`0x00000001.0002.0003.0000.0000.0000.0000.0000.0000.0000.0000.0000.0000.0000.0000`

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### Eligibility

Eligibility modules have authority to rule on the a) eligibility and b) good standing of wearer(s) of a given Hat.

**Wearer Eligibility** (A) determines whether a given address is eligible to wear the Hat. This applies both before and while the address wears the Hat. Consider the following scenarios for a given address:

|  | Eligible | Not Eligible |
| --- | --- | --- |
| **Doesn't wear the Hat** | Hat can be minted to the address | Hat cannot be minted to the address |
| **Currently wears the Hat** | Keeps wearing the Hat | The Hat is revoked |

When a Hat is revoked, its token is burned.

**Wearer Standing** (B) determines whether a given address is in good or bad standing. Standing is stored on-chain in `Hats.sol` to facilitate accountability.

For example, a hatter contract implementing staking logic could slash a wearer's stake if they are placed in bad standing by the eligibility module.

An address placed in bad standing by a Hat's eligibility module automatically loses eligibility for that Hat. Note, though, that ineligibility does necessarily imply bad standing; it is possible for an address may be ineligible but in good standing.

Any address can serve as an eligibility module for a given Hat. Hats Protocol supports two categories of eligibility modules:

1. **Mechanistic eligibility** are logic contracts that implement the `IHatsEligibility` interface, which enables the Hats contract to _pull_ wearer standing by calling `checkWearerStanding` from within the `Hats.balanceOf` function. Mechanistic eligibility enables instantaneous revocation based on pre-defined triggers.
2. **Humanistic eligibility** are either EOAs or governance contracts. To revoke a Hat, humanistic eligibility must _push_ updates to the Hats contract by calling `Hats.ruleOHatWearerStanding`.

Unlike admins, eligibility modules are explicitly set as addresses, not Hats. This is to avoid long, potentially illegible, chains of revocation authority that can affect wearer penalties (such as slashed stake).

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### Toggle

Toggle contracts have authority to switch the `hat.active` status of a Hat, such as from `active` to `inactive`. When a Hat is inactive, it does not have any wearers (i.e., the balance of its previous wearers' is changed to 0).

Any address can serve as a Hat's toggle. As with eligibility modules, Hats Protocol supports two categories of toggle modules:

1. **Mechanistic toggles** are logic contracts that implement the `IHatsToggle` interface, which enables the Hats contract to _pull_ a Hat's active status by calling `checkToggle` from within the `Hats.balanceOf` function. Mechanistic toggle enable instantaneous deactivation (or reactivation) based on pre-defined logic, such as timestamps ("this Hat expires at the end of the year").
2. **Humanistic toggles** are either EOAs or governance contracts. To deactivate (or reactivate) a Hat, humanistic toggles must _push_ updates to the Hats contract by calling `Hats.toggleHatStatus`.

Unlike admins, toggle modules are explicitly set as addresses, not Hats.

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### Hat Mutability

In some cases, a Hat's properties should be immutable to give everybody (particularly the wearer(s)) maximal confidence in what they are signing up for. But this certainty comes at the expense of flexibility, which is often valuable for DAOs as they evolve and learn more about what their various roles are all about. With this trade-off in mind, Hats can be created as either mutable or immutable.

An **immutable** Hat cannot be changed at all once it has been created. A **mutable** Hat can be changed after it has been created. Only its admin(s) can make the change.

Changes are allowed to the following Hat properties:

* `details`
* `maxSupply` - as long as the new maxSupply is not less than the current supply
* `eligibility`
* `toggle`
* `mutable` - this is a one-way change
* `imageURI`

Additionally, mutable hats can be transferred by their admins to a different wearer. Immutable hats cannot be transferred.

#### TopHat Exception

The only exception to the above mutability rules is for tophats, which despite being immutable are allowed to change their own `details` and `imageURI` (but not other properties).

Note that this only includes non-linked tophats; a tophat that has been linked (aka grafted) onto another hat tree is no longer considered a tophat, and therefore is subject to the same mutability rules as other hats.

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### Hat Image URIs

Like any other NFT, Hats have images. The image for a given Hat is determined by the following logic:

1. If the Hat's `imageURI` property is set, use that
2. If the Hat's `imageURI` property is _not_ set, then use the `imageURI` of the Hat's admin Hat
3. If the admin Hat's `imageURI` property is _not_ set, then use the `imageURI` of _that_ Hat's admin
4. Repeat (3) until you find an `imageURI` that is set
5. If no set `imageURI` is found within the original Hat's hat tree (including the Tophat), then use the `globalImageURI` set in the Hats Protocol contract

This logic creates flexibility for DAOs to efficiently customize images for their Hats, while keeping images as optional.

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### Creating a Hat

The creator of a Hat must be its admin. In other words, the admin of a Hat must be the `msg.sender` of the `Hats.createHat` function call. Though remember, by delegating its authority to a hatter contract, an admin can enable eligible others to create Hats based on whatever logic it desires.

Creating a Tophat (a Hat that serves as its own admin) requires a special function `mintTophat`, which creates a new Hat, sets that Hat as its own admin, and then mints its token to a `_target`. Any address wanting to create a Hat that is not already wearing an admin Hat of some kind must first create a Tophat with itself as the wearer.

#### Batch Creation

In some scenarios, a DAO may want to create many Hats at once -- including an entire hat tree -- at once. This is particularly useful when setting up an initial structure for a DAO or working group (e.g., from a Hats template) or when forking an existing Hats structure from a template.

Enabling this latter forking/exit scenario is an important protection for Hat wearers against potential abuse of power by their DAO.

To create a batch of Hats, a DAO can call the `Hats.batchCreateHats()` function. This function takes arrays as its arguments, from which it constructs multiple Hats.  As long as each of these Hats is part of the same tree of Hats &mdash; i.e., they either have the same existing Hat or any of the newly created Hats as admin(s) &mdash; they can all be created together.

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### Minting a Hat

Only a Hat's admin can mint its token to a wearer.

To mint a Hat, the Hat must be active, its max supply must not have already been reached, the target wearer must not already wear the Hat, and the target wearer must be eligible for the Hat.

A Hat's admin can mint its token individually by calling `Hats.mintHat`.

#### Batch Minting

An admin can also mint multiple Hats by calling `Hats.batchMintHats`. This enables an admin to mint instances of the same hat to multiple wearers, to mint several Hats at once, or even to mint an entire Hats tree it just created.

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

### Transferring a Hat

Only a Hat's admin can transfer its token(s) to new wearer(s).

Unlike typical tokens, the wearer of a Hat cannot transfer the Hat to another wallet. This is because the authorities and responsibilities associated with a Hat are delegated to, not owned by, the wearer.

As a result, there is no need for safe transfers (transfers which check whether the recipient supports ERC1155) or to pass data to recipient `on1155Received` or `onERC1155BatchReceived` hooks.

For these reasons, in Hats Protocol, the standard ERC1155 transfer functions &mdash; `safeTransferFrom` and `safeBatchTransferFrom` are disabled and will always revert. Similarly, token approvals are not required and `setApprovalForAll` will always revert.

As a replacement, Hats can be transferred by admins via `Hats.transferHat`, which emits the ERC1155 standard event `TransferSingle`. Transfer recipients must not already be wearing the hat, and must be eligible to wear the hat.

With the exception of tophats — which can always transfer themselves — only mutable Hats can be transferred. Inactive Hats cannot be transferred.

### Hat Tree Grafting

Not all Hats trees will unfurl from top down or inside out. Sometimes, new branches will form independently from the main tree, or multiple trees will form before a main tree even exists.

In these cases, Hat trees can be grafted onto other trees. This is done via a request-approve process where the wearer of one tree's topHat requests to link their topHat to a hat in another tree, whose admin can approve if desired. This has three main effects:

1. The linked tophat loses its topHat status (i.e., `Hats.isTopHat` will return `false`) and turns into what we call a "tree root" or "linked topHat", and
2. The hat to which it is linked becomes its new admin; it is no longer its own admin
3. On linking, the linked topHat can be assigned eligibility and/or toggle modules like any other hat

Linked Hat trees can also be unlinked by the tree root from its linked admin, via `Hats.unlinkTopHatFromTree`. This causes the tree root to regain its status as a top hat and to once again become its own admin. Any eligibility or toggle modules added on linking are cleared. Note that unlinking is only allowed if the tree root is active and has an eligible wearer.

⚠️ **CAUTION**: Be careful when nesting multiple Hat trees. If the nested linkages become too long, the higher level admins may lose control of the lowest level Hats because admin actions at that distance may cost-prohibitive or even exceed the gas limit. Best practice is to not attach external authorities (e.g. via token gating) to Hats in trees that are more than ~10 nested trees deep (varies by network).

#### Relinking

Linked topHats can be relinked to a different Hat within the same tree. This is useful for DAOs that want to reorganize their subtrees without having to go through the request and approve steps. Valid relinks must meet the following criteria in order to ensure security:

1. The Hat wearer executing the relink is an admin of both the linked topHat and the new admin (destination)
2. The new admin (destination) is within the same local tree as the existing admin (origin), or within the tippy top hat's local tree. Tippy top hats executing a relink are not subject to these restrictions.
3. The new link does not create a circular linkage.

### Renouncing a Hat

The wearer of a Hat can "take off" their Hat via `Hats.renounceHat`. This burns the token and revokes any associated authorities and responsibilities from the now-former wearer, but does not put the wearer in bad standing.

<p align="right">(<a href="#table-of-contents">back to contents</a>)</p>

## License

Distributed under the AGPLv3 License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

Spencer Graham - [@spengrah](https://twitter.com/spengrah)

nintynick - [@nintynick_](https://twitter.com/nintynick_)

David Ehrlichman - [@davehrlichman](https://twitter.com/davehrlichman)

Project Website: [https://hatsprotocol.xyz/](https://hatsprotocol.xyz)

Project Link: [https://github.com/Hats-Protocol/hats-protocol/](https://github.com/Hats-Protocol/hats-protocol/)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/Hats-Protocol/hats-protocol.svg?style=flat
[contributors-url]: https://github.com/Hats-Protocol/hats-protocol/graphs/contributors
[stars-shield]: https://img.shields.io/github/stars/Hats-Protocol/hats-protocol.svg?style=flat
[stars-url]: https://github.com/Hats-Protocol/hats-protocol/stargazers
[issues-shield]: https://img.shields.io/github/issues/Hats-Protocol/hats-protocol.svg?style=flat
[issues-url]: https://github.com/Hats-Protocol/hats-protocol/issues
[twitter-shield]: https://img.shields.io/twitter/url?label=%40HatsProtocol&style=social&url=https%3A%2F%2Ftwitter.com%2FHatsProtocol
[twitter-url]: https://twitter.com/hatsprotocol
