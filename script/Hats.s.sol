// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hats.sol";

contract DeployHats is Script {
    function run() external {
        vm.startBroadcast();

        string memory name = "Hats Protocol - Beta 2"; // increment this each test deployment

        Hats hats = new Hats(name);

        vm.stopBroadcast();
    }
}
