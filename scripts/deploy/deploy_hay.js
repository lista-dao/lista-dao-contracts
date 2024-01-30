const hre = require("hardhat");
const {ethers, upgrades} = require("hardhat");

// Global Variables
let wad = "000000000000000000"; // 18 Decimals

async function main() {

  // Declare and load network variables from networkVars.json
  let chainId;

  if (hre.network.name === "bsc") {
    const { m_chainID } = require('./1_deploy_all.json'); // mainnet
    chainId = ethers.BigNumber.from(m_chainID);
  } else  {
    const {t_chainID} = require('./1_deploy_all.json'); // testnet
    chainId = ethers.BigNumber.from(t_chainID);
  }

  // Contracts Fetching
  this.Hay = await hre.ethers.getContractFactory("Hay");

  const hay = await upgrades.deployProxy(this.Hay, [chainId, "HAY", "100000000" + wad], {initializer: "initialize"});
  await hay.deployed();
  let hayImplementation = await upgrades.erc1967.getImplementationAddress(hay.address);
  console.log("Deployed: hay        : " + hay.address);
  console.log("Imp                  : " + hayImplementation);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
