// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hats.sol";

contract DeployHats is Script {
    string public imageURI = "hats-beta1:";

    function run() external {
        vm.startBroadcast();

        string memory name = "Hats Protocol - Beta 1"; // increment this each test deployment

        Hats hats = new Hats(name, imageURI);

        vm.stopBroadcast();
    }

    // forge script script/Hats.s.sol:DeployHats--rpc-url $GC_RPC --private-key $PRIVATE_KEY --verify --etherscan-api-key $GNOSISSCAN_KEY --broadcast
}
