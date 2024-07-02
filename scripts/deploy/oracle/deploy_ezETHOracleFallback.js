const hre = require("hardhat");
const {ethers, upgrades} = hre;

async function main() {
  // Deploy EzETHOracle
  const EzETHOracle = await ethers.getContractFactory("EzETHOracleFallback");
  const ezETHOracle = await upgrades.deployProxy(
    EzETHOracle,
    [
      "0x98643CB1BDA4060d8BD2dc19bceB0acF6F03ae17",
      "0x45E287c45A151c027a41Be16ae6426D844da24c1"
    ],
    {
      initializer: "initialize"
    });
  await ezETHOracle.waitForDeployment();

  let ezETHOracleImplementation = await upgrades.erc1967.getImplementationAddress(ezETHOracle.target);
  console.log("Deployed: EzETHOraclePivot : " + ezETHOracle.target);
  console.log("Imp                        : " + ezETHOracleImplementation);

  // verify contracts
  console.log('\n\n---------- verifying EzETHOraclePivot ----------')
  await hre.run("verify:verify", { address: ezETHOracle.target });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
