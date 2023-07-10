// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from "forge-std/Script.sol";
import { Hats } from "../src/Hats.sol";

contract DeployHats is Script {
    string public constant baseImageURI = "ipfs://bafkreiflezpk3kjz6zsv23pbvowtatnd5hmqfkdro33x5mh2azlhne3ah4";

    string public constant name = "Hats Protocol v1"; // increment this each deployment

    bytes32 internal constant SALT = bytes32(abi.encode(0x4a75)); // ~ H(4) A(a) T(7) S(5)

    function run() external {
        // set up deployer
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.rememberKey(privKey);
        // log deployer data
        console2.log("Deployer: ", deployer);
        console2.log("Deployer Nonce: ", vm.getNonce(deployer));

        vm.startBroadcast(deployer);

        // deploy Hats to a deterministic address via CREATE2
        Hats hats = new Hats{ salt: SALT }(name, baseImageURI);

        vm.stopBroadcast();
        // log deployment data
        console2.log("Salt: ", vm.toString(SALT));
        console2.log("Hats contract: ", address(hats));
    }

    // forge script script/Hats.s.sol:DeployHats -f goerli
    // forge script script/Hats.s.sol:DeployHats -f goerli --broadcast --verify

    // forge verify-contract --chain-id 5 --num-of-optimizations 10000 --watch --constructor-args $(cast abi-encode "constructor(string,string)" "Hats Protocol v1" "ipfs://bafkreiflezpk3kjz6zsv23pbvowtatnd5hmqfkdro33x5mh2azlhne3ah4") --compiler-version v0.8.17 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137 src/Hats.sol:Hats --etherscan-api-key $ETHERSCAN_KEY
}

contract DeployHatsAndMintTopHat is Script {
    string public imageURI = "";
    string public name = "Hats Protocol - Test XYZ";
    bytes32 internal constant SALT = bytes32(abi.encode(0x4a15)); // ~ hats

    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        address deployer = vm.rememberKey(privKey);
        vm.startBroadcast(deployer);

        Hats hats = new Hats{ salt: SALT }(name, imageURI);

        string memory image = "";
        string memory details = "";

        uint256 tophat = hats.mintTopHat(deployer, details, image);

        vm.stopBroadcast();

        console2.log("hats: ", address(hats));
        console2.log("tophat: ", tophat);
    }

    // forge script script/Hats.s.sol:DeployHatsAndMintTopHat -f goerli
    // forge script script/Hats.s.sol:DeployHatsAndMintTopHat -f polygon --broadcast --verify

    // forge script script/Hats.s.sol:DeployHatsAndMintTopHat --rpc-url http://localhost:8545 --broadcast

    // forge verify-contract --chain-id 5 --num-of-optimizations 1000000 --watch --constructor-args $(cast abi-encode "constructor(string,string)" "Hats Protocol - uri test 7" "") --compiler-version v0.8.16 "0x9b50ab91b3ffbcdd5d5ed49ed70bf299434c955c" src/Hats.sol:Hats $ETHERSCAN_API
}
