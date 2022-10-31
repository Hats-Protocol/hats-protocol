// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hats.sol";

contract DeployHats is Script {
    string public imageURI = "";
    // string public name = "Hats Protocol - Beta 4"; // increment this each test deployment
    string public name = "Hats Protocol - uri test 5";

    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(privKey);
        vm.startBroadcast(deployer);

        Hats hats = new Hats(name, imageURI);

        vm.stopBroadcast();
    }

    // forge script script/Hats.s.sol -f goerli
    // forge script script/Hats.s.sol -f polygon --broadcast --verify
}
