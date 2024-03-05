
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");

// Global Variables
let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners();
  // Ceros Deployment
  console.log("ETH Ceros...")

  this.CewBETH = await hre.ethers.getContractFactory("CeToken");
  this.CeVault = await hre.ethers.getContractFactory("CeETHVault");
  this.HEth = await hre.ethers.getContractFactory("hETH");
  this.CerosRouter = await hre.ethers.getContractFactory("CerosETHRouter");
  this.HelioProvider = await hre.ethers.getContractFactory("HelioETHProvider");

  let _wBETH, _ethToken, _withdrawalFee;
  let _referral;
  let _minStake;
  let _tokenRatio;
  let _minWithdrawal;

  if (hre.network.name == "bsc") {
    const {m_wBETH, m_ethToken, m_referral} = require('./7_deploy_eth.json'); // mainnet
    _wBETH = "";
    _ethToken = "";
  } else if (hre.network.name == "bsc_testnet") {
    const {t_wBETH, t_ethToken, t_referral, t_withdrawalFee, t_minStake, t_tokenRatio, t_minWithdrawal} = require('./7_deploy_eth.json');
    _wBETH = t_wBETH;
    _ethToken = t_ethToken;
    _referral = t_referral;
    _tokenRatio = t_tokenRatio;
    _withdrawalFee = ethers.BigNumber.from(t_withdrawalFee);
    _minStake = ethers.BigNumber.from(t_minStake);
    _minWithdrawal = ethers.BigNumber.from(t_minWithdrawal);
    // ilkCE = ethers.encodeBytes32String(ilkString);
  }
  cewBETH = await upgrades.deployProxy(this.CewBETH, ["CEROS wBETH Vault Token", "cewBETH"]);
  await cewBETH.waitForDeployment();
  let cewBETHImplementation = await upgrades.erc1967.getImplementationAddress(cewBETH.target);
  console.log("Deployed: cewBETH    : " + cewBETH.target);
  console.log("Imp                  : " + cewBETHImplementation);

  ceVault = await upgrades.deployProxy(this.CeVault, ["CEROS wBETH Vault", _ethToken, cewBETH.target, _wBETH, _withdrawalFee, deployer.address]);
  await ceVault.waitForDeployment();
  let ceVaultImplementation = await upgrades.erc1967.getImplementationAddress(ceVault.target);
  console.log("Deployed: ceVault    : " + ceVault.target);
  console.log("Imp                  : " + ceVaultImplementation);

  hETH = await upgrades.deployProxy(this.HEth, []);
  await hETH.waitForDeployment();
  let hEthImplementation = await upgrades.erc1967.getImplementationAddress(hETH.target);
  console.log("Deployed: hETH       : " + hETH.target);
  console.log("Imp                  : " + hEthImplementation);

  cerosRouter = await upgrades.deployProxy(this.CerosRouter, [_ethToken, cewBETH.target, _wBETH, ceVault.target, _minStake, _referral, _tokenRatio], {unsafeAllow: ['delegatecall']}, {gasLimit: 2000000});
  await cerosRouter.waitForDeployment();
  let cerosRouterImplementation = await upgrades.erc1967.getImplementationAddress(cerosRouter.target);
  console.log("Deployed: cerosRouter: " + cerosRouter.target);
  console.log("Imp                  : " + cerosRouterImplementation);

  await cewBETH.changeVault(ceVault.target);
  await ceVault.changeRouter(cerosRouter.target);

  let INTERACTION = "0x2cf64bCB720b91373Df1315ED15188FF5D8C06Ab";

  let helioProvider = await upgrades.deployProxy(this.HelioProvider, [hETH.target, _ethToken, cewBETH.target, cerosRouter.target, INTERACTION, _minWithdrawal], {unsafeAllow: ['delegatecall']});
  await helioProvider.waitForDeployment();
  let helioProviderImplementation = await upgrades.erc1967.getImplementationAddress(helioProvider.target);
  console.log("Deployed: Provider   : " + helioProvider.target);
  console.log("Imp                  : " + helioProviderImplementation);

  // Set addresses
  let ILK = ethers.encodeBytes32String("cewBETH");
  // let BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
  let VAT = "0xaAe55ecf3D89a129F2039628b3D2A575cD8D9863";
  let DOG = "0xEF46C1B018F448d128a287E136DF7c2e07114439";
  let SPOT = "0xca52b26945FB42BB7fC3bc7d9B8DAec0aa1E60aB";
  let VOW = "0x0659aef5fe538250f518cbf09b6066516b630e2e";
  let ABACI = "0x5039Cb7bD2E3C47A07fb15a9F3A83bF375d37D04";
  let AUCTION_PROXY = "0x9747BA58300EB18fD6Db2Cc956B933c64C245e16";
  let REWARDS = "0x730666F77855cD265de35A3768F1A02b7506440b";

  // Initialization
  console.log("Ceros init...");
  await hETH.changeMinter(helioProvider.target);
  await cerosRouter.changeProvider(helioProvider.target);
  await helioProvider.changeProxy(INTERACTION);

  console.log("1ST CHECKPOINT SUCCESS!");
  // Fetch factories
  this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
  this.Clipper = await hre.ethers.getContractFactory("Clipper");
  this.Oracle = await hre.ethers.getContractFactory("EthOracle");

  // Deploy contracts
  const gemJoin = await upgrades.deployProxy(this.GemJoin, [VAT, ILK, cewBETH.target]);
  await gemJoin.waitForDeployment();
  let gemJoinImplementation = await upgrades.erc1967.getImplementationAddress(gemJoin.target);
  console.log("Deployed: gemJoin    : " + gemJoin.target);
  console.log("Imp                  : " + gemJoinImplementation);

  const clipper = await upgrades.deployProxy(this.Clipper, [VAT, SPOT, DOG, ILK]);
  await clipper.waitForDeployment();
  let clipperImplementation = await upgrades.erc1967.getImplementationAddress(clipper.target);
  console.log("Deployed: clipCE     : " + clipper.target);
  console.log("Imp                  : " + clipperImplementation);

  let aggregatorAddress;
  if (hre.network.name == "bsc") {
    aggregatorAddress = "0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e";
  } else if (hre.network.name == "bsc_testnet") {
    aggregatorAddress = "0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7";
  }

  const oracle = await upgrades.deployProxy(this.Oracle, [aggregatorAddress]);
  await oracle.waitForDeployment();
  let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.target);
  console.log("Deployed: oracle     : " + oracle.target);
  console.log("Imp                  : " + oracleImplementation);

  // Initialize
  this.vatContract = await hre.ethers.getContractFactory("Vat");
  let vat = this.vatContract.attach(VAT);
  await vat.rely(gemJoin.target);
  await vat.rely(clipper.target);

  await vat["file(bytes32,bytes32,uint256)"](ILK, ethers.encodeBytes32String("line"), "5000000" + rad);
  await vat["file(bytes32,bytes32,uint256)"](ILK, ethers.encodeBytes32String("dust"), "100" + ray);

  this.spotContract = await hre.ethers.getContractFactory("Spotter");
  let spot = this.spotContract.attach(SPOT);
  await spot["file(bytes32,bytes32,address)"](ILK, ethers.encodeBytes32String("pip"), oracle.target);

  this.dogContract = await hre.ethers.getContractFactory("Dog");
  let dog = this.dogContract.attach(DOG);
  await dog.rely(clipper.target);

  await dog["file(bytes32,bytes32,uint256)"](ILK, ethers.encodeBytes32String("hole"), "50000000" + rad);
  await dog["file(bytes32,bytes32,uint256)"](ILK, ethers.encodeBytes32String("chop"), "1100000000000000000"); // 10%
  await dog["file(bytes32,bytes32,address)"](ILK, ethers.encodeBytes32String("clip"), clipper.target);

  await gemJoin.rely(INTERACTION);

  await clipper.rely(DOG);
  await clipper.rely(INTERACTION);
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("buf"), "1100000000000000000000000000"); // 10%
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("tail"), "10800"); // 3h reset time
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("chip"), "100000000000000"); // 0.01% from vow incentive
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("stopped"), "0");
  await clipper["file(bytes32,address)"](ethers.encodeBytes32String("spotter"), SPOT);
  await clipper["file(bytes32,address)"](ethers.encodeBytes32String("dog"), DOG);
  await clipper["file(bytes32,address)"](ethers.encodeBytes32String("vow"), VOW);
  await clipper["file(bytes32,address)"](ethers.encodeBytes32String("calc"), ABACI);

  console.log("Interaction init...");

  this.Interaction = await hre.ethers.getContractFactory("Interaction", {
    libraries: {
        AuctionProxy: AUCTION_PROXY
    }
  });
  let interaction = this.Interaction.attach(INTERACTION);
  await interaction.setHelioProvider(cewBETH.target, helioProvider.target);
  await interaction.setCollateralType(cewBETH.target, gemJoin.target, ILK, clipper.target, "1333333333333333333333333333", {gasLimit: 700000}); // 1.333.... <- 75% borrow ratio
  await interaction.poke(cewBETH.target, {gasLimit: 200000});
  await interaction.drip(cewBETH.target, {gasLimit: 200000});
  await interaction.setCollateralDuty(cewBETH.target, "1000000000627937192491029810");

  // TODO on mainnet, this can be ignored.
  ///////////////////////////////////////////////////////////////////////////////////////////////
  this.HelioRewards = await hre.ethers.getContractFactory("HelioRewards");
  let rewards = this.HelioRewards.attach(REWARDS);
  await rewards.initPool(cewBETH.target, ILK, "1000000001847694957439350500"); //6%
  //////////////////////////////////////////////////////////////////////////////////////////////

  // Transfer Ownerships
  // await gemJoin.rely(NEW_OWNER);
  // await gemJoin.deny(deployer.address);

  // await clipper.rely(NEW_OWNER);
  // await clipper.deny(deployer.address);

  console.log("cewBETH: " + cewBETH.target);
  console.log(ILK);

  console.log("2ND CHECKPOINT SUCCESS!");

  // Store deployed addresses
  const addresses = {
    cewBETH: cewBETH.target,
    ceETHVault: ceVault.target,
    hETH: hETH.target,
    cerosRouter: cerosRouter.target,
    helioProvider: helioProvider.target,
    gemJoin: gemJoin.target,
    gemJoinImplementation: gemJoinImplementation,
    clipper: clipper.target,
    clipperImplementation: clipperImplementation,
    oracle: oracle.target,
    oracleImplementation: oracleImplementation,
    ilk: ILK
  }

  const json_addresses = JSON.stringify(addresses);
  fs.writeFileSync(`../${network.name}_addresses_eth.json`, json_addresses);
  console.log("Addresses Recorded to: " + `../${network.name}_addresses_eth.json`);

  // Verify
  await hre.run("verify:verify", {address: gemJoinImplementation});
  await hre.run("verify:verify", {address: clipperImplementation});
  await hre.run("verify:verify", {address: cewBETHImplementation});
  await hre.run("verify:verify", {address: ceVaultImplementation});
  await hre.run("verify:verify", {address: hEthImplementation});
  await hre.run("verify:verify", {address: cerosRouterImplementation});
  await hre.run("verify:verify", {address: helioProviderImplementation});
  await hre.run("verify:verify", {address: oracleImplementation, contract: "contracts/oracle/EthOracle.sol:EthOracle"});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
