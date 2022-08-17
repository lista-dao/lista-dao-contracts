const hre = require("hardhat");
const {ethers, upgrades} = require("hardhat");
const {ether} = require("@openzeppelin/test-helpers");
const { withDefaults } = require("@openzeppelin/hardhat-upgrades/dist/utils");

///////////////////////////////////////////////////////////////////////////////////
// Note: This script is meant to be used before full release. Not for production.//
///////////////////////////////////////////////////////////////////////////////////

let dead_address = "0x000000000000000000000000000000000000dEaD";

async function main() {

  /*****OWNERSHIP TRANSFER*****/
  [deployer] = await ethers.getSigners();

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
  let auctionProxy = await this.AuctionProxy.deploy();
  await auctionProxy.deployed();
  this.Interaction = await hre.ethers.getContractFactory("Interaction", {
    unsafeAllow: ["external-library-linking"],
    libraries: {
      AuctionProxy: auctionProxy.address,
    },
  });

  let _multisig1, _multisig2, _multisig3, _multisig4;

  let _ceabnbc, 
   _cevault, 
   _hbnb, 
   _cerosrouter,
   _helioprovider,
   _vat,
   _spot,
   _hay,
   _gemjoin,
   _hayjoin,
   _oracle,
   _jug,
   _vow,
   _dog,
   _clip,
   _abaci,
//    _heliotoken,
   _heliorewards,
//    _heliooracle,
   _auctionproxy,
   _interaction;
  
  if (hre.network.name == "bsc") {
    const {m_ceaBNBc, m_ceVault, m_hBNB, m_cerosRouter, m_abaci, m_oracle, m_vat, m_spot, m_hay
    , m_hayJoin, m_bnbJoin, m_jug, m_vow, m_dog, m_clipCE, m_rewards, m_interaction, m_AuctionLib, m_helioProvider,
    multisig1, multisig2, multisig3, multisig4} = require('./4_transferOwnerships.json'); // mainnet
    _ceabnbc = m_ceaBNBc, _cevault = m_ceVault, _hbnb = m_hBNB, _cerosrouter = m_cerosRouter, _helioprovider = m_helioProvider, _vat = m_vat, _spot = m_spot, _hay = m_hay, _gemjoin = m_bnbJoin, 
    _hayjoin = m_hayJoin, _oracle = m_oracle, _jug = m_jug, _vow = m_vow, _dog = m_dog, _clip = m_clipCE, _abaci = m_abaci, _heliorewards = m_rewards, _auctionproxy = m_AuctionLib, _interaction = m_interaction,
    _multisig1 = multisig1, _multisig2 = multisig2, _multisig3 = multisig3, _multisig4 = multisig4;
  } else if (hre.network.name == "bsc_testnet") {
    const {t_ceaBNBc, t_ceVault, t_hBNB, t_cerosRouter, t_abaci, t_oracle, t_vat, t_spot, t_hay
    , t_hayJoin, t_bnbJoin, t_jug, t_vow, t_dog, t_clipCE, t_rewards, t_interaction, t_AuctionLib, t_helioProvider,
    multisig1, multisig2, multisig3, multisig4}  = require('./4_transferOwnerships.json'); // testnet
    _ceabnbc = t_ceaBNBc, _cevault = t_ceVault, _hbnb = t_hBNB, _cerosrouter = t_cerosRouter, _helioprovider = t_helioProvider, _vat = t_vat, _spot = t_spot, _hay = t_hay, _gemjoin = t_bnbJoin, 
    _hayjoin = t_hayJoin, _oracle = t_oracle, _jug = t_jug, _vow = t_vow, _dog = t_dog, _clip = t_clipCE, _abaci = t_abaci, _heliorewards = t_rewards, _auctionproxy = t_AuctionLib, _interaction = t_interaction,
    _multisig1 = multisig1, _multisig2 = multisig2, _multisig3 = multisig3, _multisig4 = multisig4;
  }

  let ceabnbc = await this.CeaBNBc.attach(_ceabnbc);
  let cevault = await this.CeVault.attach(_cevault);
  let hbnb = await this.HBnb.attach(_hbnb);
  let cerosrouter = await this.CerosRouter.attach(_cerosrouter);
  let helioprovider = await this.HelioProvider.attach(_helioprovider);
  let vat = await this.Vat.attach(_vat);
  let spot = await this.Spot.attach(_spot);
  let hay = await this.Hay.attach(_hay);
  let gemjoin = await this.GemJoin.attach(_gemjoin);
  let hayjoin = await this.HayJoin.attach(_hayjoin);
  let oracle = await this.Oracle.attach(_oracle);
  let jug = await this.Jug.attach(_jug);
  let vow = await this.Vow.attach(_vow);
  let dog = await this.Dog.attach(_dog);
  let clip = await this.Clip.attach(_clip);
  let abaci = await this.Abaci.attach(_abaci);
//   let heliotoken = await this.HelioToken.attach();
  let heliorewards = await this.HelioRewards.attach(_heliorewards);
//   let heliooracle = await this.HelioOracle.attach();
  let auctionproxy = await this.AuctionProxy.attach(_auctionproxy);
  let interaction = await this.Interaction.attach(_interaction);

  console.log("HOLD YOUR HORSES !");
  console.log("STARTING TRANSFER OF OWNERSHIPS !")

  // MULTISIG 4
  await ceabnbc.transferOwnership(_multisig4);
  console.log("ceabnbnc transfered to   : " + _multisig4);

  await cevault.transferOwnership(_multisig4);
  console.log("cevault transfered to    : " + _multisig4);

  await hbnb.transferOwnership(_multisig4);
  console.log("hbnb transfered to       : " + _multisig4);

  await cerosrouter.transferOwnership(_multisig4);
  console.log("cerosrouter transfered to: " + _multisig4);

  // MULTISIG 3
  await abaci.rely(_multisig3);
  console.log("abaci relied to          : " + _multisig3);
  await abaci.deny(deployer.address);
  console.log("abaci denied to          : " + deployer.address);

  await vat.rely(_multisig3);
  console.log("vat relied to            : " + _multisig3);
  await vat.deny(deployer.address);
  console.log("vat denied to            : " + deployer.address);
  await vat.transferOwnership(dead_address); // Dead Address
  console.log("vat transfered to        : " + dead_address);

  await spot.rely(_multisig3);
  console.log("spot relied to           : " + _multisig3);
  await spot.deny(deployer.address);
  console.log("spot denied to           : " + deployer.address);

  await hay.rely(_multisig3);
  console.log("hay relied to            : " + _multisig3);
  await hay.deny(deployer.address);
  console.log("hay denied to            : " + deployer.address);

  await hayjoin.rely(_multisig3);
  console.log("hayjoin relied to        : " + _multisig3);
  await hayjoin.deny(deployer.address);
  console.log("hayjoin denied to        : " + deployer.address);

  await gemjoin.rely(_multisig3);
  console.log("gemjoin relied to        : " + _multisig3);
  await gemjoin.deny(deployer.address);
  console.log("gemjoin denied to        : " + deployer.address);

  await jug.rely(_multisig3);
  console.log("jug relied to            : " + _multisig3);
  await jug.deny(deployer.address);
  console.log("jug denied to            : " + deployer.address);

  await vow.rely(_multisig3);
  console.log("vow relied to            : " + _multisig3);
  await vow.deny(deployer.address);
  console.log("vow denied to            : " + deployer.address);

  await dog.rely(_multisig3);
  console.log("dog relied to            : " + _multisig3);
  await dog.deny(deployer.address);
  console.log("dog denied to            : " + deployer.address);

  await clip.rely(_multisig3);
  console.log("clip relied to           : " + _multisig3);
  await clip.deny(deployer.address);
  console.log("clip denied to           : " + deployer.address);

  // MULTISIG 2
  await heliorewards.rely(_multisig2);
  console.log("heliorewards relied to   : " + _multisig2);
  await heliorewards.deny(deployer.address);
  console.log("heliorewards denied to   : " + deployer.address);
  await heliorewards.transferOwnership(dead_address); // Dead Address
  console.log("heliorewars transfered to: " + dead_address);

  await interaction.disableWhitelist(); // Whitelist DISABLED
  console.log("WHITELIST DISABLED !");
  await interaction.rely(_multisig2);
  console.log("interaction relied to     : " + _multisig2);
  await interaction.deny(deployer.address);
  console.log("interaction denied to     : " + deployer.address);
  await interaction.transferOwnership(dead_address); // Dead Address
  console.log("interaction transfer to   : " + dead_address);

  await helioprovider.transferOwnership(_multisig2)
  console.log("helioprovider transfer to : " + _multisig2);

  console.log("TRANSFER OF OWNERSHIPS COMPLETED !");
  console.log("DON'T FORGET PROXY ADMIN OWNERSHIP TRANDFER !");

  // MULTISIG 1
  // THE PROXY ADMIN OWNERSHIP WILL BE TRANSFERED FROM BSC-SCAN
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });