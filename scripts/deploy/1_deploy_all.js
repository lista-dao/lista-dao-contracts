const fs = require("fs");
const {ethers, upgrades} = require("hardhat");

// Global Variables
let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {

  // Declare and load network variables from networkVars.json
  let _aBNBc, _wBnb, _aBnbb, _dex, _pool, _BnbStakingPool;
  let ilkCE;
  let _multiSig;
  let chainId;
  let whitelistOperatorAddress;

  if (hre.network.name == "bsc") {
      const {m_aBNBc, m_wBnb, m_aBnbb, m_dex, m_pool, m_BnbStakingPool, m_chainID, ilkString, multiSig, whiteListOperator} = require('./1_deploy_all.json'); // mainnet
      _aBNBc = m_aBNBc; _wBnb = m_wBnb; _aBnbb = m_aBnbb; _dex = m_dex; _pool = m_pool, _multiSig = multiSig;
      _BnbStakingPool = m_BnbStakingPool;
      whitelistOperatorAddress = whiteListOperator;
      chainId = ethers.BigNumber.from(m_chainID);
      ilkCE = ethers.encodeBytes32String(ilkString);
  } else if (hre.network.name == "bsc_testnet") {
      const {t_aBNBc, t_wBnb, t_aBnbb, t_dex, t_pool, t_BnbStakingPool, t_chainID, ilkString, multiSig, whiteListOperator} = require('./1_deploy_all.json'); // testnet
      _aBNBc = t_aBNBc; _wBnb = t_wBnb; _aBnbb = t_aBnbb; _dex = t_dex; _pool = t_pool, _multiSig = multiSig;
      _BnbStakingPool = t_BnbStakingPool;
      whitelistOperatorAddress = whiteListOperator;
      chainId = t_chainID;
      ilkCE = ethers.encodeBytes32String(ilkString);
  } else if (hre.network.name == "hardhat") {
    chainId = hre.network.config.chainId;
    ilkCE =ethers.encodeBytes32String('ceABNBc');
    _multiSig = (await ethers.getSigners())[0].address;
    whitelistOperatorAddress = (await ethers.getSigners())[0].address;
    const deployer = (await ethers.getSigners())[0];
    const BinancePool = await ethers.getContractFactory("BinancePool");
    const binancePool = await upgrades.deployProxy(BinancePool, [deployer.address, deployer.address, 10000]);
    _pool = binancePool.target;
    const ABNBb = await ethers.getContractFactory("aBNBb");
    const bondToken = await upgrades.deployProxy(ABNBb, [deployer.address]);
    _aBnbb = bondToken.target;
    const aBNBc = await ethers.deployContract("aBNBc", [_pool, _aBnbb]);
    await aBNBc.waitForDeployment();
    _aBNBc = aBNBc.target;
    const Wbnb = await ethers.getContractFactory("wBNB");
    const wbnb = await upgrades.deployProxy(Wbnb, []);
    _wBnb = wbnb.target;
    const factory = await ethers.deployContract("PancakeFactory", [deployer.address]);
    await factory.waitForDeployment();
    const dex = await ethers.deployContract("PancakeRouter", [factory.target, _wBnb]);
    await dex.waitForDeployment();
    _dex = dex.target;
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
  this.Flash = await hre.ethers.getContractFactory("Flash");
  this.FlashBuy = await hre.ethers.getContractFactory("FlashBuy");

  const auctionProxy = await this.AuctionProxy.deploy();
  await auctionProxy.waitForDeployment();
  this.Interaction = await hre.ethers.getContractFactory("Interaction", {
    unsafeAllow: ["external-library-linking"],
    libraries: {
      AuctionProxy: auctionProxy.target,
    },
  });

  // Ceros Deployment
  console.log("Ceros...")

  ceaBNBc = await upgrades.deployProxy(this.CeaBNBc, ["CEROS aBNBc Vault Token", "ceaBNBc"]);
  await ceaBNBc.waitForDeployment();
  let ceaBNBcImplementation = await upgrades.erc1967.getImplementationAddress(ceaBNBc.target);
  console.log("Deployed: ceaBNBc    : " + ceaBNBc.target);
  console.log("Imp                  : " + ceaBNBcImplementation);

  ceVault = await upgrades.deployProxy(this.CeVault, ["CEROS aBNBc Vault", ceaBNBc.target, _aBNBc]);
  await ceVault.waitForDeployment();
  let ceVaultImplementation = await upgrades.erc1967.getImplementationAddress(ceVault.target);
  console.log("Deployed: ceVault    : " + ceVault.target);
  console.log("Imp                  : " + ceVaultImplementation);

  hBNB = await upgrades.deployProxy(this.HBnb, []);
  await hBNB.waitForDeployment();
  let hBnbImplementation = await upgrades.erc1967.getImplementationAddress(hBNB.target);
  console.log("Deployed: hBNB       : " + hBNB.target);
  console.log("Imp                  : " + hBnbImplementation);

  cerosRouter = await upgrades.deployProxy(this.CerosRouter, [_aBNBc, _wBnb, ceaBNBc.target, _aBnbb, ceVault.target, _dex, _pool], {gasLimit: 2000000});
  await cerosRouter.waitForDeployment();
  let cerosRouterImplementation = await upgrades.erc1967.getImplementationAddress(cerosRouter.target);
  console.log("Deployed: cerosRouter: " + cerosRouter.target);
  console.log("Imp                  : " + cerosRouterImplementation);

  await ceaBNBc.changeVault(ceVault.target);
  await ceVault.changeRouter(cerosRouter.target);

  // Contracts Deployment
  console.log("Core...");

  const abaci = await upgrades.deployProxy(this.Abaci, []);
  await abaci.waitForDeployment();
  let abaciImplementation = await upgrades.erc1967.getImplementationAddress(abaci.target);
  console.log("Deployed: abaci      : " + abaci.target);
  console.log("Imp                  : " + abaciImplementation);

  let aggregatorAddress;
  if (hre.network.name == "bsc") {
    aggregatorAddress = "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE";
  } else if (hre.network.name == "bsc_testnet") {
    aggregatorAddress = "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526";
  }

  let oracle, oracleImplementation;
  if (hre.network.name !== "bsc") {
    oracle = await ethers.deployContract("Oracle");
    await oracle.waitForDeployment();
    oracleImplementation = oracle.target;
    console.log("Deployed: oracle     : " + oracle.target);
    await oracle.setPrice(300e18.toString());
  } else {
    oracle = await upgrades.deployProxy(this.Oracle, [aggregatorAddress]);
    await oracle.waitForDeployment();
    let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.target);
    console.log("Deployed: oracle     : " + oracle.target);
    console.log("Imp                  : " + oracleImplementation);
  }

  const vat = await upgrades.deployProxy(this.Vat, []);
  await vat.waitForDeployment();
  let vatImplementation = await upgrades.erc1967.getImplementationAddress(vat.target);
  console.log("Deployed: vat        : " + vat.target);
  console.log("Imp                  : " + vatImplementation);

  const spot = await upgrades.deployProxy(this.Spot, [vat.target]);
  await spot.waitForDeployment();
  let spotImplementation = await upgrades.erc1967.getImplementationAddress(spot.target);
  console.log("Deployed: spot       : " + spot.target);
  console.log("Imp                  : " + spotImplementation);

  const hay = await upgrades.deployProxy(this.Hay, [chainId, "HAY", "100000000" + wad]);
  await hay.waitForDeployment();
  let hayImplementation = await upgrades.erc1967.getImplementationAddress(hay.target);
  console.log("Deployed: hay        : " + hay.target);
  console.log("Imp                  : " + hayImplementation);

  const hayJoin = await upgrades.deployProxy(this.HayJoin, [vat.target, hay.target]);
  await hayJoin.waitForDeployment();
  let hayJoinImplementation = await upgrades.erc1967.getImplementationAddress(hayJoin.target);
  console.log("Deployed: hayJoin    : " + hayJoin.target);
  console.log("Imp                  : " + hayJoinImplementation);

  const bnbJoin = await upgrades.deployProxy(this.GemJoin, [vat.target, ilkCE, ceaBNBc.target]);
  await bnbJoin.waitForDeployment();
  let bnbJoinImplementation = await upgrades.erc1967.getImplementationAddress(bnbJoin.target);
  console.log("Deployed: bnbJoin    : " + bnbJoin.target);
  console.log("Imp                  : " + bnbJoinImplementation);

  const jug = await upgrades.deployProxy(this.Jug, [vat.target]);
  await jug.waitForDeployment();
  let jugImplementation = await upgrades.erc1967.getImplementationAddress(jug.target);
  console.log("Deployed: jug        : " + jug.target);
  console.log("Imp                  : " + jugImplementation);

  const vow = await upgrades.deployProxy(this.Vow, [vat.target, hayJoin.target, _multiSig]);
  await vow.waitForDeployment();
  let vowImplementation = await upgrades.erc1967.getImplementationAddress(vow.target);
  console.log("Deployed: vow        : " + vow.target);
  console.log("Imp                  : " + vowImplementation);

  const dog = await upgrades.deployProxy(this.Dog, [vat.target], {initializer: "initialize"});
  await dog.waitForDeployment();
  let dogImplementation = await upgrades.erc1967.getImplementationAddress(dog.target);
  console.log("Deployed: dog        : " + dog.target);
  console.log("Imp                  : " + dogImplementation);

  const clipCE = await upgrades.deployProxy(this.Clip, [vat.target, spot.target, dog.target, ilkCE], {initializer: "initialize"});
  await clipCE.waitForDeployment();
  let clipCEImplementation = await upgrades.erc1967.getImplementationAddress(clipCE.target);
  console.log("Deployed: clipCE     : " + clipCE.target);
  console.log("Imp                  : " + clipCEImplementation);

  const rewards = await upgrades.deployProxy(this.HelioRewards, [vat.target, 100000000n], {initializer: "initialize"}); // pool limit
  await rewards.waitForDeployment();
  let rewardsImplementation = await upgrades.erc1967.getImplementationAddress(rewards.target);
  console.log("Deployed: rewards    : " + rewards.target);
  console.log("Imp                  : " + rewardsImplementation);

  const flash = await upgrades.deployProxy(this.Flash, [vat.target, hay.target, hayJoin.target, vow.target]);
  await flash.waitForDeployment();
  let flashImplementation = await upgrades.erc1967.getImplementationAddress(flash.target);
  console.log("Deployed: Flash    : " + flash.target);
  console.log("Imp                  : " + flashImplementation);

  const flashBuy = await ethers.deployContract("FlashBuy", [flash.target, auctionProxy.target, _dex]);
  await flashBuy.waitForDeployment();
  console.log("Deployed: FlashBuy    : " + flashBuy.target);

    // // No Helio Token & Oracle at the moment
    // const helioOracle = await upgrades.deployProxy(this.HelioOracle, ["100000000000000000" ], {initializer: "initialize"}); // 0.1
    // await helioOracle.waitForDeployment();
    // let helioOracleImplementation = await upgrades.erc1967.getImplementationAddress(helioOracle.target);
    // console.log("Deployed: helioOracle: " + helioOracle.target);
    // console.log("Imp                  : " + helioOracleImplementation);

    // // initial helio token supply for rewards spending
    // const helioToken = await upgrades.deployProxy(this.HelioToken, [ether("100000000").toString(), rewards.target], {initializer: "initialize"});
    // await helioToken.waitForDeployment();
    // let helioTokenImplementation = await upgrades.erc1967.getImplementationAddress(helioToken.target);
    // console.log("Deployed: helioToken : " + helioToken.target);
    // console.log("Imp                  : " + helioTokenImplementation);

    // await rewards.setHelioToken(helioToken.target);
    // await rewards.setOracle(helioOracle.target);
    // await rewards.initPool(ceBNBc, ilkCE, "1000000001847694957439350500"); //6%

  const interaction = await upgrades.deployProxy(this.Interaction, [vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, rewards.target],
    {
      initializer: "initialize",
      unsafeAllowLinkedLibraries: true,
    }
  );
  await interaction.waitForDeployment();
  let interactionImplementation = await upgrades.erc1967.getImplementationAddress(interaction.target);
  console.log("Deployed: Interaction: " + interaction.target);
  console.log("Imp                  : " + interactionImplementation);
  console.log("Deployed: AuctionLib : " + auctionProxy.target);

  let helioProvider = await upgrades.deployProxy(this.HelioProvider, [hBNB.target, _aBNBc, ceaBNBc.target, cerosRouter.target, interaction.target, _pool], {initializer: "initialize"});
  await helioProvider.waitForDeployment();
  let helioProviderImplementation = await upgrades.erc1967.getImplementationAddress(helioProvider.target);
  console.log("Deployed: Provider   : " + helioProvider.target);
  console.log("Imp                  : " + helioProviderImplementation);

  // Initialization
  console.log("Ceros init...");
  await hBNB.changeMinter(helioProvider.target);
  await cerosRouter.changeProvider(helioProvider.target);
  await cerosRouter.changeBNBStakingPool(_BnbStakingPool);
  await helioProvider.changeProxy(interaction.target);

  console.log("Core init...");
  await vat.rely(bnbJoin.target);
  await vat.rely(spot.target);
  await vat.rely(hayJoin.target);
  await vat.rely(jug.target);
  await vat.rely(dog.target);
  await vat.rely(clipCE.target);
  await vat.rely(interaction.target);
  await vat["file(bytes32,uint256)"](ethers.encodeBytes32String("Line"), "5000000" + rad);
  await vat["file(bytes32,bytes32,uint256)"](ilkCE, ethers.encodeBytes32String("line"), "5000000" + rad);
  await vat["file(bytes32,bytes32,uint256)"](ilkCE, ethers.encodeBytes32String("dust"), "100" + ray);

  console.log("Hay init...");
  await hay.rely(hayJoin.target);

  console.log("Spot init...");
  await spot.rely(interaction.target);
  await spot["file(bytes32,bytes32,address)"](ilkCE, ethers.encodeBytes32String("pip"), oracle.target);
  await spot["file(bytes32,uint256)"](ethers.encodeBytes32String("par"), "1" + ray); // Pegged to 1$

  console.log("Rewards init...");
  await rewards.rely(interaction.target);

  console.log("Joins init...");
  await bnbJoin.rely(interaction.target);
  await hayJoin.rely(interaction.target);
  await hayJoin.rely(vow.target);

  console.log("Dog init...");
  await dog.rely(interaction.target);
  await dog.rely(clipCE.target);
  await dog["file(bytes32,address)"](ethers.encodeBytes32String("vow"), vow.target);
  await dog["file(bytes32,uint256)"](ethers.encodeBytes32String("Hole"), "50000000" + rad);
  await dog["file(bytes32,bytes32,uint256)"](ilkCE, ethers.encodeBytes32String("hole"), "50000000" + rad);
  await dog["file(bytes32,bytes32,uint256)"](ilkCE, ethers.encodeBytes32String("chop"), "1100000000000000000"); // 10%
  await dog["file(bytes32,bytes32,address)"](ilkCE, ethers.encodeBytes32String("clip"), clipCE.target);

  console.log("Clip init...");
  await clipCE.rely(interaction.target);
  await clipCE.rely(dog.target);
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("buf"), "1100000000000000000000000000"); // 10%
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("tail"), "10800"); // 3h reset time
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("chip"), "100000000000000"); // 0.01% from vow incentive
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("stopped"), "0");
  await clipCE["file(bytes32,address)"](ethers.encodeBytes32String("spotter"), spot.target);
  await clipCE["file(bytes32,address)"](ethers.encodeBytes32String("dog"), dog.target);
  await clipCE["file(bytes32,address)"](ethers.encodeBytes32String("vow"), vow.target);
  await clipCE["file(bytes32,address)"](ethers.encodeBytes32String("calc"), abaci.target);

  console.log("Jug init...");
  await jug.rely(interaction.target);
  // 1000000000315522921573372069 1% Borrow Rate
  // 1000000000627937192491029810 2% Borrow Rate
  // 1000000000937303470807876290 3% Borrow Rate
  // 1000000003022266000000000000 10% Borrow Rate
  // ***We don't set base rate. We set only duty rate via interaction***
  // await jug["file(bytes32,uint256)"](ethers.encodeBytes32String("base"), "1000000000627937192491029810");
  await jug["file(bytes32,address)"](ethers.encodeBytes32String("vow"), vow.target);

  console.log("Vow init...");
  await vow.rely(dog.target);
  await vow["file(bytes32,address)"](ethers.encodeBytes32String("hay"), hay.target);

  console.log("Interaction init...");
  await interaction.setHelioProvider(ceaBNBc.target, helioProvider.target);
  await interaction.setCollateralType(ceaBNBc.target, bnbJoin.target, ilkCE, clipCE.target, "1333333333333333333333333333", {gasLimit: 700000}); // 1.333.... <- 75% borrow ratio
  await interaction.poke(ceaBNBc.target, {gasLimit: 200000});
  await interaction.drip(ceaBNBc.target, {gasLimit: 200000});
  await interaction.enableWhitelist(); // Deposits are limited to whitelist
  await interaction.setWhitelistOperator(whitelistOperatorAddress); // Whitelist manager
  await interaction.setCollateralDuty(ceaBNBc.target, "1000000000627937192491029810");

  console.log("Abaci init...");
  await abaci.file(ethers.encodeBytes32String("tau"), "36000");

  // Store deployed addresses
  const addresses = {
    ceaBNBc: ceaBNBc.target,
    ceaBNBcImplementation: ceaBNBcImplementation,
    ceVault: ceVault.target,
    ceVaultImplementation: ceVaultImplementation,
    hBNB: hBNB.target,
    hBnbImplementation: hBnbImplementation,
    cerosRouter: cerosRouter.target,
    cerosRouterImplementation: cerosRouterImplementation,
    abaci: abaci.target,
    abaciImplementation: abaciImplementation,
    oracle: oracle.target,
    oracleImplementation: oracleImplementation,
    vat: vat.target,
    vatImplementation: vatImplementation,
    spot: spot.target,
    spotImplementation: spotImplementation,
    hay: hay.target,
    hayImplementation: hayImplementation,
    hayJoin: hayJoin.target,
    hayJoinImplementation: hayJoinImplementation,
    bnbJoin: bnbJoin.target,
    bnbJoinImplementation: bnbJoinImplementation,
    jug: jug.target,
    jugImplementation: jugImplementation,
    vow: vow.target,
    vowImplementation: vowImplementation,
    dog: dog.target,
    dogImplementation: dogImplementation,
    clipCE: clipCE.target,
    clipCEImplementation: clipCEImplementation,
    rewards: rewards.target,
    rewardsImplementation: rewardsImplementation,
    interaction: interaction.target,
    interactionImplementation: interactionImplementation,
    AuctionLib: auctionProxy.target,
    helioProvider: helioProvider.target,
    helioProviderImplementation: helioProviderImplementation,
    flash: flash.target,
    flashImplementation: flashImplementation,
    flashBuy: flashBuy.target,
    // helioOracle: helioOracle.target,
    // helioToken: helioToken.target,
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
