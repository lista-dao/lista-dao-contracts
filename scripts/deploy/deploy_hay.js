const {ethers, upgrades} = require("hardhat");

// Global Variables
let wad = "000000000000000000"; // 18 Decimals

async function main() {

  // Declare and load network variables from networkVars.json
  let chainId;

  if (hre.network.name === "bsc") {
    const { m_chainID } = require('./1_deploy_all.json'); // mainnet
    chainId = m_chainID;
  } else  {
    const {t_chainID} = require('./1_deploy_all.json'); // testnet
    chainId = t_chainID;
  }

  // Contracts Fetching
  this.Hay = await ethers.getContractFactory("Hay");

  const hay = await upgrades.deployProxy(this.Hay, [chainId, "HAY", "100000000" + wad]);
  await hay.waitForDeployment();
  let hayImplementation = await upgrades.erc1967.getImplementationAddress(hay.target);
  console.log("Deployed: hay        : " + hay.target);
  console.log("Imp                  : " + hayImplementation);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
