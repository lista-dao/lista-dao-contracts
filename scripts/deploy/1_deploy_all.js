const hre = require("hardhat");
const fs = require("fs");
const { ethers, upgrades } = require("hardhat");
const { ether } = require("@openzeppelin/test-helpers");

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
    const {
      m_aBNBc,
      m_wBnb,
      m_aBnbb,
      m_dex,
      m_pool,
      m_chainID,
      ilkString,
      multiSig,
      whiteListOperator,
    } = require("./1_deploy_all.json"); // mainnet
    _aBNBc = m_aBNBc;
    _wBnb = m_wBnb;
    _aBnbb = m_aBnbb;
    _dex = m_dex;
    (_pool = m_pool), (_multiSig = multiSig);
    whitelistOperatorAddress = whiteListOperator;
    chainId = ethers.BigNumber.from(m_chainID);
    ilkCE = ethers.utils.formatBytes32String(ilkString);
  } else if (hre.network.name == "bsc_testnet") {
    const {
      t_aBNBc,
      t_wBnb,
      t_aBnbb,
      t_dex,
      t_pool,
      t_chainID,
      ilkString,
      multiSig,
      whiteListOperator,
    } = require("./1_deploy_all.json"); // testnet
    _aBNBc = t_aBNBc;
    _wBnb = t_wBnb;
    _aBnbb = t_aBnbb;
    _dex = t_dex;
    (_pool = t_pool), (_multiSig = multiSig);
    whitelistOperatorAddress = whiteListOperator;
    chainId = ethers.BigNumber.from(t_chainID);
    ilkCE = ethers.utils.formatBytes32String(ilkString);
  }

  // Script variables
  let ceaBNBc, ceVault, hBNB, cerosRouter;

  // Contracts Fetching
  this.CeaBNBc = await hre.ethers.getContractFactory("CeToken");
  this.CeVault = await hre.ethers.getContractFactory("CeVault");
  this.HBnb = await hre.ethers.getContractFactory("hBNB");
  this.CerosRouter = await hre.ethers.getContractFactory("CerosRouter");
  this.HelioProvider = await hre.ethers.getContractFactory("HelioProvider");

  this.Vat = await hre.ethers.getContractFactory("Vat");
  this.Spot = await hre.ethers.getContractFactory("Spotter");
  this.Hay = await hre.ethers.getContractFactory("Hay");
  this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
  this.HayJoin = await hre.ethers.getContractFactory("HayJoin");
  this.Oracle = await hre.ethers.getContractFactory("BnbOracle");
  this.Jug = await hre.ethers.getContractFactory("Jug");
  this.Vow = await hre.ethers.getContractFactory("Vow");
  this.Dog = await hre.ethers.getContractFactory("Dog");
  this.Clip = await hre.ethers.getContractFactory("Clipper");
  this.Abaci = await ethers.getContractFactory("LinearDecrease");

  this.HelioToken = await hre.ethers.getContractFactory("HelioToken");
  this.HelioRewards = await hre.ethers.getContractFactory("HelioRewards");
  this.HelioOracle = await hre.ethers.getContractFactory("HelioOracle");

  this.AuctionProxy = await hre.ethers.getContractFactory("AuctionProxy");

  console.log("--> before deploying auction proxy");
  // const auctionProxy = await this.AuctionProxy.deploy();
  // await auctionProxy.deployed();
  const auctionProxy = { address: "0xfeCFFDb796fbE99757225c6fCE19f94CE6BB84E8" };
  console.log("--> after deploying auction proxy", auctionProxy.address);
  this.Interaction = await hre.ethers.getContractFactory("Interaction", {
    unsafeAllow: ["external-library-linking"],
    libraries: {
      AuctionProxy: auctionProxy.address,
    },
  });

  // Ceros Deployment
  console.log("Ceros...");

  // ceaBNBc = await upgrades.deployProxy(this.CeaBNBc, ["CEROS aBNBc Vault Token", "ceaBNBc"], {
  //   initializer: "initialize",
  // });
  // await ceaBNBc.deployed();
  ceaBNBc = await hre.ethers.getContractAt("CeToken", "0x9f44175274692876529D730d5c73A9432C1C7E03");
  let ceaBNBcImplementation = await upgrades.erc1967.getImplementationAddress(ceaBNBc.address);
  console.log("Deployed: ceaBNBc    : " + ceaBNBc.address);
  console.log("Imp                  : " + ceaBNBcImplementation);

  // ceVault = await upgrades.deployProxy(this.CeVault, ["CEROS aBNBc Vault", ceaBNBc.address, _aBNBc], {
  //   initializer: "initialize",
  //   unsafeAllow: ["delegatecall"],
  // });
  // await ceVault.deployed();
  ceVault = await hre.ethers.getContractAt("CeVault", "0xF126cbf6e7c0727a0f58ABb4AC3131785b94a757");
  let ceVaultImplementation = await upgrades.erc1967.getImplementationAddress(ceVault.address);
  console.log("Deployed: ceVault    : " + ceVault.address);
  console.log("Imp                  : " + ceVaultImplementation);

  // hBNB = await upgrades.deployProxy(this.HBnb, [], {
  //   initializer: "initialize",
  // });
  // await hBNB.deployed();
  hBNB = await hre.ethers.getContractAt("hBNB", "0x9De2A1C33032120D068447c974220d4b0EAc0C30");
  let hBnbImplementation = await upgrades.erc1967.getImplementationAddress(hBNB.address);
  console.log("Deployed: hBNB       : " + hBNB.address);
  console.log("Imp                  : " + hBnbImplementation);

  // cerosRouter = await upgrades.deployProxy(
  //   this.CerosRouter,
  //   [_aBNBc, _wBnb, ceaBNBc.address, _aBnbb, ceVault.address, _dex, _pool],
  //   { initializer: "initialize", unsafeAllow: ["delegatecall"], txOverrides: { maxFeePerGas: 10e9 } },
  //   { gasLimit: 2000000 }
  // );
  // await cerosRouter.deployed();
  cerosRouter = await hre.ethers.getContractAt("CerosRouter", "0xBAB62890D76696baF201F81423Ce3eF0Be10B494");
  let cerosRouterImplementation = await upgrades.erc1967.getImplementationAddress(cerosRouter.address);
  console.log("Deployed: cerosRouter: " + cerosRouter.address);
  console.log("Imp                  : " + cerosRouterImplementation);

  // await ceaBNBc.changeVault(ceVault.address, { maxFeePerGas: 10e9 });
  // await ceVault.changeRouter(cerosRouter.address, { maxFeePerGas: 10e9 });

  // Contracts Deployment
  console.log("Core...");

  // const abaci = await upgrades.deployProxy(this.Abaci, [], {
  //   initializer: "initialize",
  // });
  // await abaci.deployed();
  const abaci = await hre.ethers.getContractAt("LinearDecrease", "0x6616603965de3A008d99C411F791736f99564D54");
  let abaciImplementation = await upgrades.erc1967.getImplementationAddress(abaci.address);
  console.log("Deployed: abaci      : " + abaci.address);
  console.log("Imp                  : " + abaciImplementation);

  let aggregatorAddress;
  if (hre.network.name == "bsc") {
    aggregatorAddress = "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE";
  } else if (hre.network.name == "bsc_testnet") {
    aggregatorAddress = "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526";
  }

  // const oracle = await upgrades.deployProxy(this.Oracle, [aggregatorAddress], {
  //   initializer: "initialize",
  // });
  // await oracle.deployed();
  const oracle = await hre.ethers.getContractAt("BnbOracle", "0x8C8DF3710e944D9ebA9b5867828a52d9A8169B99");
  let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.address);
  console.log("Deployed: oracle     : " + oracle.address);
  console.log("Imp                  : " + oracleImplementation);

  // const vat = await upgrades.deployProxy(this.Vat, [], {
  //   initializer: "initialize",
  // });
  // await vat.deployed();
  const vat = await hre.ethers.getContractAt("Vat", "0xa2573f33dD7C687d01BED841D3311acae345A7c9");
  let vatImplementation = await upgrades.erc1967.getImplementationAddress(vat.address);
  console.log("Deployed: vat        : " + vat.address);
  console.log("Imp                  : " + vatImplementation);

  // const spot = await upgrades.deployProxy(this.Spot, [vat.address], {
  //   initializer: "initialize",
  // });
  // await spot.deployed();
  const spot = await hre.ethers.getContractAt("Spotter", "0xdBadc7C3f832B6020691cfA4391C6DF719d70ed9");
  let spotImplementation = await upgrades.erc1967.getImplementationAddress(spot.address);
  console.log("Deployed: spot       : " + spot.address);
  console.log("Imp                  : " + spotImplementation);

  // const hay = await upgrades.deployProxy(this.Hay, [chainId, "HAY", "100000000" + wad], { initializer: "initialize" });
  // await hay.deployed();
  const hay = await hre.ethers.getContractAt("Hay", "0xbBF1D282F54dfB84b30Da282108080e11378c9bC");
  let hayImplementation = await upgrades.erc1967.getImplementationAddress(hay.address);
  console.log("Deployed: hay        : " + hay.address);
  console.log("Imp                  : " + hayImplementation);

  // const hayJoin = await upgrades.deployProxy(this.HayJoin, [vat.address, hay.address], { initializer: "initialize" });
  // await hayJoin.deployed();
  const hayJoin = await hre.ethers.getContractAt("HayJoin", "0x0dd929Fd0E83EAdc374F7C45a2a2787E952E2d11");
  let hayJoinImplementation = await upgrades.erc1967.getImplementationAddress(hayJoin.address);
  console.log("Deployed: hayJoin    : " + hayJoin.address);
  console.log("Imp                  : " + hayJoinImplementation);

  // const bnbJoin = await upgrades.deployProxy(this.GemJoin, [vat.address, ilkCE, ceaBNBc.address], {
  //   initializer: "initialize",
  // });
  // await bnbJoin.deployed();
  const bnbJoin = await hre.ethers.getContractAt("GemJoin", "0x8BA78ACc69C51C473Ac3AADd65C126C7785cf035");
  let bnbJoinImplementation = await upgrades.erc1967.getImplementationAddress(bnbJoin.address);
  console.log("Deployed: bnbJoin    : " + bnbJoin.address);
  console.log("Imp                  : " + bnbJoinImplementation);

  // const jug = await upgrades.deployProxy(this.Jug, [vat.address], {
  //   initializer: "initialize",
  // });
  // await jug.deployed();
  const jug = await hre.ethers.getContractAt("Jug", "0x47870F73113c2dc555A0b6E7C4473Fd809751c7f");
  let jugImplementation = await upgrades.erc1967.getImplementationAddress(jug.address);
  console.log("Deployed: jug        : " + jug.address);
  console.log("Imp                  : " + jugImplementation);

  // const vow = await upgrades.deployProxy(this.Vow, [vat.address, hayJoin.address, _multiSig], {
  //   initializer: "initialize",
  // });
  // await vow.deployed();
  const vow = await hre.ethers.getContractAt("Vow", "0x4d56F1DAAF6ad2693Af68B7D22DA567e657F4598");
  let vowImplementation = await upgrades.erc1967.getImplementationAddress(vow.address);
  console.log("Deployed: vow        : " + vow.address);
  console.log("Imp                  : " + vowImplementation);

  // const dog = await upgrades.deployProxy(this.Dog, [vat.address], {
  //   initializer: "initialize",
  // });
  // await dog.deployed();
  const dog = await hre.ethers.getContractAt("Dog", "0x76F4b1F82C36776e49801c0E67c6b411bF1229e2");
  let dogImplementation = await upgrades.erc1967.getImplementationAddress(dog.address);
  console.log("Deployed: dog        : " + dog.address);
  console.log("Imp                  : " + dogImplementation);

  // const clipCE = await upgrades.deployProxy(this.Clip, [vat.address, spot.address, dog.address, ilkCE], {
  //   initializer: "initialize",
  // });
  // await clipCE.deployed();
  const clipCE = await hre.ethers.getContractAt("Clipper", "0x637e25b9C11B8bA1940CA420070A4a2DEDDCc0a3");
  let clipCEImplementation = await upgrades.erc1967.getImplementationAddress(clipCE.address);
  console.log("Deployed: clipCE     : " + clipCE.address);
  console.log("Imp                  : " + clipCEImplementation);

  // const rewards = await upgrades.deployProxy(this.HelioRewards, [vat.address, ether("100000000").toString()], {
  //   initializer: "initialize",
  // }); // pool limit
  // await rewards.deployed();
  const rewards = await hre.ethers.getContractAt("HelioRewards", "0xC37bf1b95840e5cc3034540eFE5BDD54feC34BbF");
  let rewardsImplementation = await upgrades.erc1967.getImplementationAddress(rewards.address);
  console.log("Deployed: rewards    : " + rewards.address);
  console.log("Imp                  : " + rewardsImplementation);

  // // No Helio Token & Oracle at the moment
  // const helioOracle = await upgrades.deployProxy(this.HelioOracle, ["100000000000000000" ], {initializer: "initialize"}); // 0.1
  // await helioOracle.deployed();
  // let helioOracleImplementation = await upgrades.erc1967.getImplementationAddress(helioOracle.address);
  // console.log("Deployed: helioOracle: " + helioOracle.address);
  // console.log("Imp                  : " + helioOracleImplementation);

  // // initial helio token supply for rewards spending
  // const helioToken = await upgrades.deployProxy(this.HelioToken, [ether("100000000").toString(), rewards.address], {initializer: "initialize"});
  // await helioToken.deployed();
  // let helioTokenImplementation = await upgrades.erc1967.getImplementationAddress(helioToken.address);
  // console.log("Deployed: helioToken : " + helioToken.address);
  // console.log("Imp                  : " + helioTokenImplementation);

  // await rewards.setHelioToken(helioToken.address);
  // await rewards.setOracle(helioOracle.address);
  // await rewards.initPool(ceBNBc, ilkCE, "1000000001847694957439350500"); //6%

  // const interaction = await upgrades.deployProxy(
  //   this.Interaction,
  //   [vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, rewards.address],
  //   {
  //     initializer: "initialize",
  //     unsafeAllowLinkedLibraries: true,
  //   }
  // );
  // await interaction.deployed();
  const interaction = await hre.ethers.getContractAt("Interaction", "0x2e92BE58c5D3f6AF6E1dcCbC867C4D1Cc2595238");
  let interactionImplementation = await upgrades.erc1967.getImplementationAddress(interaction.address);
  console.log("Deployed: Interaction: " + interaction.address);
  console.log("Imp                  : " + interactionImplementation);
  console.log("Deployed: AuctionLib : " + auctionProxy.address);

  // let helioProvider = await upgrades.deployProxy(
  //   this.HelioProvider,
  //   [hBNB.address, _aBNBc, ceaBNBc.address, cerosRouter.address, interaction.address, _pool],
  //   { initializer: "initialize", unsafeAllow: ["delegatecall"], txOverrides: { maxFeePerGas: 15e9 } }
  // );
  // await helioProvider.deployed();
  const helioProvider = await hre.ethers.getContractAt("HelioProvider", "0x00c060a850605dfB9A2205c12662e1Ee228211Ee");
  let helioProviderImplementation = await upgrades.erc1967.getImplementationAddress(helioProvider.address);
  console.log("Deployed: Provider   : " + helioProvider.address);
  console.log("Imp                  : " + helioProviderImplementation);

  // Initialization
  // console.log("Ceros init...");
  // await hBNB.changeMinter(helioProvider.address);
  // await cerosRouter.changeProvider(helioProvider.address);
  // await helioProvider.changeProxy(interaction.address);

  // console.log("Core init...");
  // await vat.rely(bnbJoin.address);
  // await vat.rely(spot.address);
  // await vat.rely(hayJoin.address);
  // await vat.rely(jug.address);
  // await vat.rely(dog.address);
  // await vat.rely(clipCE.address);
  // await vat.rely(interaction.address);
  // await vat["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Line"), "5000000" + rad);
  // await vat["file(bytes32,bytes32,uint256)"](ilkCE, ethers.utils.formatBytes32String("line"), "5000000" + rad);
  // await vat["file(bytes32,bytes32,uint256)"](ilkCE, ethers.utils.formatBytes32String("dust"), "100" + ray);

  // console.log("Hay init...");
  // await hay.rely(hayJoin.address);

  // console.log("Spot init...");
  // await spot.rely(interaction.address);
  // await spot["file(bytes32,bytes32,address)"](ilkCE, ethers.utils.formatBytes32String("pip"), oracle.address);
  // await spot["file(bytes32,uint256)"](ethers.utils.formatBytes32String("par"), "1" + ray); // Pegged to 1$

  // console.log("Rewards init...");
  // await rewards.rely(interaction.address);

  // console.log("Joins init...");
  // await bnbJoin.rely(interaction.address);
  // await hayJoin.rely(interaction.address);
  // await hayJoin.rely(vow.address);

  console.log("Dog init...");
  await dog.rely(interaction.address);
  await dog.rely(clipCE.address);
  await dog["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);
  await dog["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Hole"), "50000000" + rad);
  await dog["file(bytes32,bytes32,uint256)"](ilkCE, ethers.utils.formatBytes32String("hole"), "50000000" + rad);
  await dog["file(bytes32,bytes32,uint256)"](ilkCE, ethers.utils.formatBytes32String("chop"), "1100000000000000000"); // 10%
  await dog["file(bytes32,bytes32,address)"](ilkCE, ethers.utils.formatBytes32String("clip"), clipCE.address);

  console.log("Clip init...");
  await clipCE.rely(interaction.address);
  await clipCE.rely(dog.address);
  await clipCE["file(bytes32,uint256)"](ethers.utils.formatBytes32String("buf"), "1100000000000000000000000000"); // 10%
  await clipCE["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tail"), "10800"); // 3h reset time
  await clipCE["file(bytes32,uint256)"](ethers.utils.formatBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
  await clipCE["file(bytes32,uint256)"](ethers.utils.formatBytes32String("chip"), "100000000000000"); // 0.01% from vow incentive
  await clipCE["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
  await clipCE["file(bytes32,uint256)"](ethers.utils.formatBytes32String("stopped"), "0");
  await clipCE["file(bytes32,address)"](ethers.utils.formatBytes32String("spotter"), spot.address);
  await clipCE["file(bytes32,address)"](ethers.utils.formatBytes32String("dog"), dog.address);
  await clipCE["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);
  await clipCE["file(bytes32,address)"](ethers.utils.formatBytes32String("calc"), abaci.address);

  console.log("Jug init...");
  await jug.rely(interaction.address);
  // 1000000000315522921573372069 1% Borrow Rate
  // 1000000000627937192491029810 2% Borrow Rate
  // 1000000000937303470807876290 3% Borrow Rate
  // 1000000003022266000000000000 10% Borrow Rate
  // ***We don't set base rate. We set only duty rate via interaction***
  // await jug["file(bytes32,uint256)"](ethers.utils.formatBytes32String("base"), "1000000000627937192491029810");
  await jug["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);

  console.log("Vow init...");
  await vow.rely(dog.address);
  await vow["file(bytes32,address)"](ethers.utils.formatBytes32String("hay"), hay.address);

  console.log("Interaction init...");
  await interaction.setHelioProvider(ceaBNBc.address, helioProvider.address);
  await interaction.setCollateralType(
    ceaBNBc.address,
    bnbJoin.address,
    ilkCE,
    clipCE.address,
    "1333333333333333333333333333",
    { gasLimit: 700000 }
  ); // 1.333.... <- 75% borrow ratio
  await interaction.poke(ceaBNBc.address, { gasLimit: 200000 });
  await interaction.drip(ceaBNBc.address, { gasLimit: 200000 });
  await interaction.enableWhitelist(); // Deposits are limited to whitelist
  await interaction.setWhitelistOperator(whitelistOperatorAddress); // Whitelist manager
  await interaction.setCollateralDuty(ceaBNBc.address, "1000000000627937192491029810");

  console.log("Abaci init...");
  await abaci.file(ethers.utils.formatBytes32String("tau"), "36000");

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
    ilk: ilkCE,
  };

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
