// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hats.sol";

contract DeployHats is Script {
    string public imageURI = "mvp:";

    function run() external {
        vm.startBroadcast();

        Hats hats = new Hats(imageURI);

        vm.stopBroadcast();
    }
}
