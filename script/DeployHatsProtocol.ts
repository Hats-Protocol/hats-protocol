import { config as dotEnvConfig } from "dotenv";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { Wallet } from "zksync-ethers";
import * as hre from "hardhat";

// Before executing a real deployment, be sure to set these values as appropriate for the environment being deployed
// to. The values used in the script at the time of deployment can be checked in along with the deployment artifacts
// produced by running the scripts.
const contractName = "Hats";
async function main() {
  dotEnvConfig();

  const deployerPrivateKey = process.env.PRIVATE_KEY;
  if (!deployerPrivateKey) {
    throw "Please set PRIVATE_KEY in your .env file";
  }

  console.log("Deploying " + contractName + "...");

  const zkWallet = new Wallet(deployerPrivateKey);
  const deployer = new Deployer(hre, zkWallet);

  const contract = await deployer.loadArtifact(contractName);
  const constructorArgs = [
    "Hats Protocol v1",
    "ipfs://bafkreiflezpk3kjz6zsv23pbvowtatnd5hmqfkdro33x5mh2azlhne3ah4",
  ];
  const hatsProtocol = await deployer.deploy(
    contract,
    constructorArgs,
    "create2",
    {
      customData: {
        salt: "0x0000000000000000000000000000000000000000000000000000000000004a75",
      },
    }
  );
  console.log(
    "constructor args:" + hatsProtocol.interface.encodeDeploy(constructorArgs)
  );

  const contractAddress = await hatsProtocol.getAddress();
  console.log(`${contractName} was deployed to ${contractAddress}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
