const hre = require("hardhat");
const {ethers, upgrades} = hre;

async function main() {
  // -------------------------------------
  // ----- 1. Deploy WEETHOracleMain -----
  // -------------------------------------
  const WEETHOracleMain = await ethers.getContractFactory("WeEthOracleMain");
  const weETHOracleMain = await upgrades.deployProxy(
    WEETHOracleMain,
    [
      "0x9b2C948dbA5952A1f5Ab6fA16101c1392b8da1ab",
      "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e"
    ],
    {
      initializer: "initialize"
    });
  await weETHOracleMain.waitForDeployment();

  let weETHOracleMainImplementation = await upgrades.erc1967.getImplementationAddress(weETHOracleMain.target);
  console.log("Deployed: weETHOracleMainMain : " + weETHOracleMain.target);
  console.log("Imp                        : " + weETHOracleMainImplementation);

  // verify contracts
  console.log('\n\n---------- verifying weETHOracleMainMain ----------')
  await hre.run("verify:verify", { address: weETHOracleMain.target });

  // --------------------------------------
  // ----- 2. Deploy WEETHOraclePivot -----
  // --------------------------------------
  const API3ProxyAddress = "0x3098c3217DFE5c7ECAD40Fa29BC5e57A097b3c54";
  const API3Oracle = await ethers.getContractFactory("API3Oracle");
  const api3Oracle = await API3Oracle.deploy(API3ProxyAddress);
  await api3Oracle.waitForDeployment();
  const api3OracleAddress = await api3Oracle.getAddress();
  console.log('contract deployed at: ', api3OracleAddress);
  console.log('---------- verifying contract ----------')
  await hre.run("verify:verify", {
    address: api3OracleAddress,
    constructorArguments: [API3ProxyAddress],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
