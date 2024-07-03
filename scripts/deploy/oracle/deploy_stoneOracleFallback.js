const hre = require("hardhat");
const {ethers, upgrades} = hre;

async function main() {
  // Deploy StoneETHOracle
  const StoneETHOracle = await ethers.getContractFactory("StoneOracleFallback");
  const stoneETHOracle = await upgrades.deployProxy(
    StoneETHOracle,
    [
      "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e", // ETH/USD
      "0xADCc15cE3900A2Fc8544e26fD89897C0484e98Fc", // Stone/ETH
    ],
    {
      initializer: "initialize"
    });
  await stoneETHOracle.waitForDeployment();

  let stoneETHOracleImplementation = await upgrades.erc1967.getImplementationAddress(stoneETHOracle.target);
  console.log("Deployed: StoneETHOraclePivot : " + stoneETHOracle.target);
  console.log("Imp                           : " + stoneETHOracleImplementation);

  // verify contracts
  console.log('\n\n---------- verifying StoneETHOracleFallback ----------')
  await hre.run("verify:verify", { address: stoneETHOracle.target });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
