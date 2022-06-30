const hre = require("hardhat");
const fs = require("fs");

const {
    ceBNBc, DEPLOYER, COLLATERAL_CE_ABNBC,
    HELIO_PROVIDER, CHAIN_ID,
    VAT,
    SPOT,
    HayJoin,
    HAY,
    ceBNBcJoin,
    aBNBcJoin,
    aBNBc,
    JUG,
    VOW,
    DOG,
    CLIP1,
    CLIP3,
    REWARDS,
    AUCTION_PROXY,
    INTERACTION
} = require('../../addresses.json');
const {ethers, upgrades} = require("hardhat");
const {BN, ether} = require("@openzeppelin/test-helpers");

let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

const hoursToSeconds = (hours) => {
  return hours * 60 * 60;
};

async function main() {
  console.log("Running deploy script");

  let collateralCE = ethers.utils.formatBytes32String(COLLATERAL_CE_ABNBC);
  console.log("IlkCE: " + collateralCE);

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

  console.log("Deploying core contracts");
  let abaci = await this.Abaci.deploy();
  await abaci.deployed();
  console.log("abaci deployed to:", abaci.address);

  let aggregatorAddress;
  if (hre.network.name == "bsc") {
    aggregatorAddress = "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE";
  } else if (hre.network.name == "bsc_testnet") {
    aggregatorAddress = "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526";
  }

  const oracle = await this.Oracle.deploy(aggregatorAddress);
  await oracle.deployed();
  console.log("oracle deployed to:", oracle.address);

  const vat = await upgrades.deployProxy(this.Vat, []);
  await vat.deployed();
  console.log("Vat deployed to:", vat.address);

  const spot = await this.Spot.deploy(vat.address);
  await spot.deployed();
  await spot["file(bytes32,bytes32,address)"](
    collateralCE,
    ethers.utils.formatBytes32String("pip"),
    oracle.address
  );
  await spot["file(bytes32,uint256)"](
    ethers.utils.formatBytes32String("par"),
    "1" + ray
  ); // It means pegged to 1$
  console.log("Spot deployed to:", spot.address);

  const hay = await this.Hay.deploy(CHAIN_ID, "HAY");
  await hay.deployed();
  console.log("Hay deployed to:", hay.address);

  const hayJoin = await this.HayJoin.deploy(vat.address, hay.address);
  await hayJoin.deployed();
  console.log("hayJoin deployed to:", hayJoin.address);

  const bnbJoin = await this.GemJoin.deploy(vat.address, collateralCE, ceBNBc);
  await bnbJoin.deployed();
  console.log("bnbJoin deployed to:", bnbJoin.address);

  const jug = await this.Jug.deploy(vat.address);
  await jug.deployed();
  console.log("Jug deployed to:", jug.address);

  const vow = await this.Vow.deploy(vat.address, DEPLOYER);
  await vow.deployed();
  console.log("Vow deployed to:", vow.address);

  const dog = await this.Dog.deploy(vat.address);
  await dog.deployed();
  console.log("Dog deployed to:", dog.address);

  const clipCE = await this.Clip.deploy(
    vat.address,
    spot.address,
    dog.address,
    collateralCE
  );
  await clipCE.deployed();
  console.log("ClipCE deployed to:", clipCE.address);

  console.log("Core contracts auth");

  await vat.rely(bnbJoin.address);
  await vat.rely(spot.address);
  await vat.rely(hayJoin.address);
  await vat.rely(jug.address);
  await vat.rely(dog.address);
  await vat.rely(clipCE.address);

  // REWARDS
  console.log("Deploying rewards");

  const rewards = await upgrades.deployProxy(this.HelioRewards, [
    vat.address,
    ether("100000000").toString(), // pool limit
  ]);
  await rewards.deployed();
  console.log("Rewards deployed to:", rewards.address);

  const helioOracle = await upgrades.deployProxy(this.HelioOracle, [
    "100000000000000000", // 0.1
  ]);
  await helioOracle.deployed();
  console.log("helioOracle deployed to:", helioOracle.address);

  // initial helio token supply for rewards spending
  const helioToken = await this.HelioToken.deploy(
    ether("100000000").toString(),
    rewards.address
  );
  await helioToken.deployed();
  console.log("helioToken deployed to:", helioToken.address);

  await rewards.setHelioToken(helioToken.address);
  await rewards.setOracle(helioOracle.address);
  await rewards.initPool(ceBNBc, collateralCE, "1000000001847694957439350500", { gasLimit: 2000000 }); //6%

  // INTERACTION
  const auctionProxy = await this.AuctionProxy.deploy();
  await auctionProxy.deployed();
  console.log("AuctionProxy lib deployed to: ", auctionProxy.address);

  this.Interaction = await hre.ethers.getContractFactory("Interaction", {
    unsafeAllow: ["external-library-linking"],
    libraries: {
      AuctionProxy: auctionProxy.address,
    },
  });
  const interaction = await upgrades.deployProxy(
    this.Interaction,
    [
      vat.address,
      spot.address,
      hay.address,
      hayJoin.address,
      jug.address,
      dog.address,
      rewards.address,
    ],
    {
      initializer: "initialize",
      unsafeAllowLinkedLibraries: true,
    }
  );
  await interaction.deployed();
  console.log("interaction deployed to:", interaction.address);

  await vat.rely(interaction.address);
  await rewards.rely(interaction.address);
  await bnbJoin.rely(interaction.address);
  await hayJoin.rely(interaction.address);
  await dog.rely(interaction.address);
  await jug.rely(interaction.address);
  await vow.rely(dog.address);
  await interaction.setHelioProvider(ceBNBc, HELIO_PROVIDER);
  // 1.333.... <- 75% borrow ratio
  await interaction.setCollateralType(
    ceBNBc,
    bnbJoin.address,
    collateralCE,
    clipCE.address,
    "1333333333333333333333333333"
  );

  console.log("Vat config...");
  await vat["file(bytes32,uint256)"](
    ethers.utils.formatBytes32String("Line"),
    "500000000" + rad
  );
  await vat["file(bytes32,bytes32,uint256)"](
    collateralCE,
    ethers.utils.formatBytes32String("line"),
    "50000000" + rad
  );
  await vat["file(bytes32,bytes32,uint256)"](
    collateralCE,
    ethers.utils.formatBytes32String("dust"),
    "1" + ray
  );

  console.log("Jug...");
  let BR = new BN("1000000003022266000000000000").toString(); //10% APY
  await jug["file(bytes32,uint256)"](
    ethers.utils.formatBytes32String("base"),
    BR
  ); // 10% Yearly
  await jug["file(bytes32,address)"](
    ethers.utils.formatBytes32String("vow"),
    vow.address
  );

  console.log("Hay...");
  await hay.rely(hayJoin.address);

  // Initialize Liquidation Module
  console.log("Dog...");
  await dog.rely(clipCE.address);
  await dog["file(bytes32,address)"](
    ethers.utils.formatBytes32String("vow"),
    vow.address
  );
  await dog["file(bytes32,uint256)"](
    ethers.utils.formatBytes32String("Hole"),
    "500" + rad
  );
  await dog["file(bytes32,bytes32,uint256)"](
    collateralCE,
    ethers.utils.formatBytes32String("hole"),
    "250" + rad
  );
  await dog["file(bytes32,bytes32,uint256)"](
    collateralCE,
    ethers.utils.formatBytes32String("chop"),
    "1100000000000000000"
  ); // 10%
  await dog["file(bytes32,bytes32,address)"](
    collateralCE,
    ethers.utils.formatBytes32String("clip"),
    clipCE.address
  );

  console.log("CLIP");
  await clipCE.rely(dog.address);

  await clipCE["file(bytes32,uint256)"](
    ethers.utils.formatBytes32String("buf"),
    "1100000000000000000000000000"
  ); // 10%
  await clipCE["file(bytes32,uint256)"](
    ethers.utils.formatBytes32String("tail"),
    "1800"
  ); // 30mins reset time
  await clipCE["file(bytes32,uint256)"](
    ethers.utils.formatBytes32String("cusp"),
    "600000000000000000000000000"
  ); // 60% reset ratio
  await clipCE["file(bytes32,uint256)"](
    ethers.utils.formatBytes32String("chip"),
    "10000000000000000"
  ); // 1% from vow incentive
  await clipCE["file(bytes32,uint256)"](
    ethers.utils.formatBytes32String("tip"),
    "10" + rad
  ); // 10$ flat fee incentive
  await clipCE["file(bytes32,uint256)"](
    ethers.utils.formatBytes32String("stopped"),
    "0"
  );
  await clipCE["file(bytes32,address)"](
    ethers.utils.formatBytes32String("spotter"),
    spot.address
  );
  await clipCE["file(bytes32,address)"](
    ethers.utils.formatBytes32String("dog"),
    dog.address
  );
  await clipCE["file(bytes32,address)"](
    ethers.utils.formatBytes32String("vow"),
    vow.address
  );
  await clipCE["file(bytes32,address)"](
    ethers.utils.formatBytes32String("calc"),
    abaci.address
  );

  await interaction.poke(ceBNBc);
  await interaction.drip(ceBNBc);

  console.log("Validating code");
  let vatImplAddress = await upgrades.erc1967.getImplementationAddress(
    vat.address
  );
  console.log("vatImplAddress implementation: ", vatImplAddress);

  const addresses = {
    abaci: abaci.address,
    oracle: oracle.address,
    vat: vat.address,
    spot: spot.address,
    hay: hay.address,
    hayJoin: hayJoin.address,
    bnbJoin: bnbJoin.address,
    jug: jug.address,
    vow: vow.address,
    dog: dog.address,
    clipCE: clipCE.address,
    rewards: rewards.address,
    helioOracle: helioOracle.address,
    helioToken: helioToken.address,
    auctionProxy: auctionProxy.address,
    interaction: interaction.address,
    vatImp: vatImplAddress,
  };
  const jsonAddresses = JSON.stringify(addresses);
  fs.writeFileSync(`./addresses/${network.name}Addresses.json`, jsonAddresses);
  console.log("Addresses saved!");

  await hre.run("verify:verify", {
    address: vatImplAddress,
  });
  await hre.run("verify:verify", {
    address: spot.address,
    constructorArguments: [vat.address],
  });
  await hre.run("verify:verify", {
    address: oracle.address,
  });
  await hre.run("verify:verify", {
    address: abaci.address,
  });
  await hre.run("verify:verify", {
    address: hay.address,
    constructorArguments: [CHAIN_ID, "HAY"],
  });
  await hre.run("verify:verify", {
    address: hayJoin.address,
    constructorArguments: [vat.address, hay.address],
  });
  await hre.run("verify:verify", {
    address: bnbJoin.address,
    constructorArguments: [vat.address, collateralCE, ceBNBc],
  });
  await hre.run("verify:verify", {
    address: jug.address,
    constructorArguments: [vat.address],
  });
  await hre.run("verify:verify", {
    address: vow.address,
    constructorArguments: [vat.address, DEPLOYER],
  });
  await hre.run("verify:verify", {
    address: dog.address,
    constructorArguments: [vat.address],
  });
  await hre.run("verify:verify", {
    address: clipCE.address,
    constructorArguments: [
      vat.address,
      spot.address,
      dog.address,
      collateralCE,
    ],
  });
  // Rewards
  let rewardsImplAddress = await upgrades.erc1967.getImplementationAddress(
    rewards.address
  );
  console.log("rewardsImplAddress implementation: ", rewardsImplAddress);
  await hre.run("verify:verify", {
    address: rewardsImplAddress,
  });

  await hre.run("verify:verify", {
    address: helioToken.address,
    constructorArguments: ["100000000", rewards.address],
  });

  // Interaction
  await hre.run("verify:verify", {
    address: auctionProxy.address,
  });

  let interactionImplAddress = await upgrades.erc1967.getImplementationAddress(
    interaction.address
  );
  console.log("Interaction implementation: ", interactionImplAddress);

  await hre.run("verify:verify", {
    address: interactionImplAddress,
  });

  console.log("Finished");
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
