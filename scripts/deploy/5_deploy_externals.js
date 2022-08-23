const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");
const {ether} = require("@openzeppelin/test-helpers");

// Global Variables
let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {

  // Declare and load network variables from networkVars.json
  let _aBNBc, _wBnb, _aBnbb, _dex, _pool;
  let ilkCE;
  let _multiSig;
  let chainId;
  let whitelistOperatorAddress;

  if (hre.network.name == "bsc") {
      const {m_aBNBc, m_wBnb, m_aBnbb, m_dex, m_pool, m_chainID, ilkString, multiSig, whiteListOperator} = require('./1_deploy_all.json'); // mainnet
      _aBNBc = m_aBNBc; _wBnb = m_wBnb; _aBnbb = m_aBnbb; _dex = m_dex; _pool = m_pool, _multiSig = multiSig;
      whitelistOperatorAddress = whiteListOperator;
      chainId = ethers.BigNumber.from(m_chainID);
      ilkCE = ethers.utils.formatBytes32String(ilkString);
  } else if (hre.network.name == "bsc_testnet") {
      const {t_aBNBc, t_wBnb, t_aBnbb, t_dex, t_pool, t_chainID, ilkString, multiSig, whiteListOperator} = require('./1_deploy_all.json'); // testnet
      _aBNBc = t_aBNBc; _wBnb = t_wBnb; _aBnbb = t_aBnbb; _dex = t_dex; _pool = t_pool, _multiSig = multiSig;
      whitelistOperatorAddress = whiteListOperator;
      chainId = ethers.BigNumber.from(t_chainID);
      ilkCE = ethers.utils.formatBytes32String(ilkString);
  }

  // Script variables
  let ceaBNBc, ceVault, hBNB, cerosRouter;

  // Contracts Fetching
  this.CeaBNBc = await hre.ethers.getContractFactory("CeToken");

  // Ceros Deployment
  console.log("Ceros...") 

  ceaBNBc = await upgrades.deployProxy(this.CeaBNBc, ["CEROS aBNBc Vault Token", "ceaBNBc"], {initializer: "initialize"});
  await ceaBNBc.deployed();
  let ceaBNBcImplementation = await upgrades.erc1967.getImplementationAddress(ceaBNBc.address);
  console.log("Deployed: ceaBNBc    : " + ceaBNBc.address);
  console.log("Imp                  : " + ceaBNBcImplementation);

  // Initialization
  console.log("Ceros init...");
  await hBNB.changeMinter(helioProvider.address);

  // Store deployed addresses
  const addresses = {
    ceaBNBc: ceaBNBc.address,
    ceaBNBcImplementation: ceaBNBcImplementation,
    ceVault: ceVault.address,
    ceVaultImplementation: ceVaultImplementation,
    hBNB: hBNB.address,
    hBnbImplementation: hBnbImplementation,
    cerosRouter: cerosRouter.address,
    cerosRouterImplementation: cerosRouterImplementation,
    abaci: abaci.address,
    abaciImplementation: abaciImplementation,
    oracle: oracle.address,
    oracleImplementation: oracleImplementation,
    vat: vat.address,
    vatImplementation: vatImplementation,
    spot: spot.address,
    spotImplementation: spotImplementation,
    hay: hay.address,
    hayImplementation: hayImplementation,
    hayJoin: hayJoin.address,
    hayJoinImplementation: hayJoinImplementation,
    bnbJoin: bnbJoin.address,
    bnbJoinImplementation: bnbJoinImplementation,
    jug: jug.address,
    jugImplementation: jugImplementation,
    vow: vow.address,
    vowImplementation: vowImplementation,
    dog: dog.address,
    dogImplementation: dogImplementation,
    clipCE: clipCE.address,
    clipCEImplementation: clipCEImplementation,
    rewards: rewards.address,
    rewardsImplementation: rewardsImplementation,
    interaction: interaction.address,
    interactionImplementation: interactionImplementation,
    AuctionLib: auctionProxy.address,
    helioProvider: helioProvider.address,
    helioProviderImplementation: helioProviderImplementation,
    // helioOracle: helioOracle.address,
    // helioToken: helioToken.address,
    ilk: ilkCE
  }

  const json_addresses = JSON.stringify(addresses);
  fs.writeFileSync(`./scripts/deploy/${network.name}_addresses.json`, json_addresses);
  console.log("Addresses Recorded to: " + `./scripts/deploy/${network.name}_addresses.json`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });