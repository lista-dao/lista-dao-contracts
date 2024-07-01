const hre = require("hardhat");
const {ethers, upgrades} = hre;
const { upgradeProxy , deployImplementation , verifyImpContract} = require("../upgrades/utils/upgrade_utils");

const ORACLE_CONTRACT = "WBETHOracleV2";

async function main() {
  // Deploy resilientOracle
  const NewOracle = await ethers.getContractFactory(ORACLE_CONTRACT);
  const newOracle = await upgrades.deployProxy(
    NewOracle,
    [
      "0x98643CB1BDA4060d8BD2dc19bceB0acF6F03ae17",
      "0x6a844ed6a1C5fE5f4C05C531C7A0D67d4D8d9f70"
    ],
    {
      initializer: "initialize"
    });
  await newOracle.waitForDeployment();

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
