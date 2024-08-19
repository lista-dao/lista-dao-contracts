const hre = require("hardhat");
const {ethers, upgrades} = hre;

// -------------------------------------------- //
const contractName = '';
const initializerArgs = [''];
// -------------------------------------------- //

async function main() {

  console.log(`---------- deploying ${contractName} ----------`);

  // Deploy resilientOracle
  const Contract = await ethers.getContractFactory(contractName);
  const proxyContract = await upgrades.deployProxy(Contract, initializerArgs, { initializer: "initialize" });
  await proxyContract.waitForDeployment();

  let proxyContractImpl = await upgrades.erc1967.getImplementationAddress(proxyContract.target);
  console.log(`Deployed: ${contractName}: ` + proxyContract.target);
  console.log("Imp                      : " + proxyContractImpl);

  // verify contracts
  console.log(`---------- verifying ${contractName} ----------`)
  await hre.run("verify:verify", { address: proxyContract.target });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
