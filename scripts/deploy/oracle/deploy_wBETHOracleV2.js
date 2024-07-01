const hre = require("hardhat");
const {ethers, upgrades} = hre;

async function main() {
  // Deploy resilientOracle
  const WBETHOracle = await ethers.getContractFactory("WBETHOracleV2");
  const wBETHOracle = await upgrades.deployProxy(
    WBETHOracle,
    [
      "0x98643CB1BDA4060d8BD2dc19bceB0acF6F03ae17",
      "0x6a844ed6a1C5fE5f4C05C531C7A0D67d4D8d9f70"
    ],
    {
      initializer: "initialize"
    });
  await wBETHOracle.waitForDeployment();

  let wBETHOracleImplementation = await upgrades.erc1967.getImplementationAddress(wBETHOracle.target);
  console.log("Deployed: WBETHOracleV2 : " + wBETHOracle.target);
  console.log("Imp                     : " + wBETHOracleImplementation);

  // verify contracts
  console.log('\n\n---------- verifying WBETHOracleV2 ----------')
  await hre.run("verify:verify", { address: wBETHOracle.target });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
