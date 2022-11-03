// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Hats.sol";

contract DeployHats is Script {
    string public imageURI = "";
    string public name = "Hats Protocol - Beta 4"; // increment this each beta deployment

    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        address deployer = vm.rememberKey(privKey);
        vm.startBroadcast(deployer);

        Hats hats = new Hats(name, imageURI);

        vm.stopBroadcast();
    }

    // forge script script/Hats.s.sol:DeployHats -f goerli
    // forge script script/Hats.s.sol:DeployHats -f polygon --broadcast --verify

    // forge script script/Hats.s.sol:DeployHats --rpc-url http://localhost:8545 --broadcast

    // forge verify-contract --chain-id 5 --num-of-optimizations 1000000 --watch --constructor-args $(cast abi-encode "constructor(string,string)" "Hats Protocol - beta XYZ" "") --compiler-version v0.8.16 <contract address> src/Hats.sol:Hats $ETHERSCAN_API
}

contract DeployHatsAndMintTopHat is Script {
    string public imageURI = "";
    string public name = "Hats Protocol - Test XYZ";

    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        // uint256 privKey = uint256(
        //     0x0
        // );

        address deployer = vm.rememberKey(privKey);
        vm.startBroadcast(deployer);

        Hats hats = new Hats(name, imageURI);

        string memory image = "";

        uint256 tophat = hats.mintTopHat(deployer, image);

        console2.log("hats: ", address(hats));
        console2.log("tophat: ", tophat);

        vm.stopBroadcast();
    }

    // forge script script/Hats.s.sol:DeployHatsAndMintTopHat -f goerli
    // forge script script/Hats.s.sol:DeployHatsAndMintTopHat -f polygon --broadcast --verify

    // forge script script/Hats.s.sol:DeployHatsAndMintTopHat --rpc-url http://localhost:8545 --broadcast

    // forge verify-contract --chain-id 5 --num-of-optimizations 1000000 --watch --constructor-args $(cast abi-encode "constructor(string,string)" "Hats Protocol - uri test 7" "") --compiler-version v0.8.16 "0x9b50ab91b3ffbcdd5d5ed49ed70bf299434c955c" src/Hats.sol:Hats $ETHERSCAN_API
}
