const hre = require("hardhat");
const {ethers, upgrades} = hre;
const { upgradeProxy , deployImplementation , verifyImpContract} = require("../upgrades/utils/upgrade_utils");

async function main() {
  // Deploy BoundValidator
  const BoundValidator = await ethers.getContractFactory("BoundValidator");
  const boundValidator = await upgrades.deployProxy(BoundValidator);
  await boundValidator.waitForDeployment();

  let boundValidatorImplementation = await upgrades.erc1967.getImplementationAddress(boundValidator.target, [], { initializer: "initialize" });
  console.log("Deployed: BoundValidator    : " + boundValidator.target);
  console.log("Imp                         : " + boundValidatorImplementation);

  // Deploy resilientOracle
  const ResilientOracle = await ethers.getContractFactory("ResilientOracle");
  const resilientOracle = await upgrades.deployProxy(ResilientOracle, [boundValidator.target], { initializer: "initialize" });
  await resilientOracle.waitForDeployment();

  let resilientOracleImplementation = await upgrades.erc1967.getImplementationAddress(resilientOracle.target);
  console.log("Deployed: ResilientOracle    : " + resilientOracle.target);
  console.log("Imp                         : " + resilientOracleImplementation);

  // verify contracts
  console.log('---------- verifying BoundValidator ----------')
  await hre.run("verify:verify", { address: boundValidator.target });
  console.log('\n\n---------- verifying ResilientOracle ----------')
  await hre.run("verify:verify", { address: resilientOracle.target });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
