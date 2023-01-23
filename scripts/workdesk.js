const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");

async function main() {

  let [deployer] = await ethers.getSigners();

  // this.Vat = await hre.ethers.getContractFactory("Vat");
  // this.Jug = await hre.ethers.getContractFactory("Jug");
  // this.Dog = await hre.ethers.getContractFactory("Dog");
  // this.CerosRouter = await hre.ethers.getContractFactory("CerosRouter");
  // this.CeVault = await hre.ethers.getContractFactory("CeVault");
  // this.HelioProvider = await hre.ethers.getContractFactory("HelioProvider");
  this.EmergencyShutdown = await hre.ethers.getContractFactory("EmergencyShutdown");

  // this.AuctionProxy = await hre.ethers.getContractFactory("AuctionProxy");
  // const auctionProxy = await this.AuctionProxy.deploy();
  // await auctionProxy.deployed();
  // this.Interaction = await hre.ethers.getContractFactory("Interaction", {
  //   unsafeAllow: ["external-library-linking"],
  //   libraries: {
  //     AuctionProxy: auctionProxy.address,
  //   },
  // });

  // vat = await this.Vat.deploy(); await vat.deployed();
  // jug = await this.Jug.deploy(); await jug.deployed();
  // dog = await this.Dog.deploy(); await dog.deployed();
  // cerosrouter = await this.CerosRouter.deploy(); await cerosrouter.deployed();
  // ceVault = await this.CeVault.deploy(); await ceVault.deployed();
  // helioProvider = await this.HelioProvider.deploy(); await helioProvider.deployed();
  // interaction = await this.Interaction.deploy(); await interaction.deployed();
  es = await this.EmergencyShutdown.deploy("0x33A34eAB3ee892D40420507B820347b1cA2201c4", "0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8");
  await es.deployed();
  await es.transferOwnership("0x8d388136d578dCD791D081c6042284CED6d9B0c6");
  console.log("Deployed:            : " + es.address);

  // console.log("Vat     : " + vat.address);
  // console.log("Jug     : " + jug.address);
  // console.log("Dog     : " + dog.address);
  // console.log("CeRouter: " + cerosrouter.address);
  // console.log("CeVault : " + ceVault.address);
  // console.log("HelioPro: " + helioProvider.address);
  // console.log("Interact: " + interaction.address);
  // console.log("proxy   : " + auctionProxy.address);

  // Store deployed addresses
  const addresses = {
    // vat: vat.address,
    // jug: jug.address,
    // dog: dog.address,
    // cerouter: cerosrouter.address,
    // cervault: ceVault.address,
    // helioProvider: helioProvider.address,
    // interaction: interaction.address,
    // auctionProxy: auctionProxy.address
    es: es.address
  }

  const json_addresses = JSON.stringify(addresses);
  fs.writeFileSync(`../${network.name}_addresses.json`, json_addresses);
  console.log("Addresses Recorded to: " + `../${network.name}_addresses.json`);
  // await hre.run("verify:verify", {address: vat.address});
  // await hre.run("verify:verify", {address: jug.address});
  // await hre.run("verify:verify", {address: dog.address});
  // await hre.run("verify:verify", {address: cerosrouter.address});
  // await hre.run("verify:verify", {address: ceVault.address});
  // await hre.run("verify:verify", {address: helioProvider.address});
  // await hre.run("verify:verify", {address: interaction.address});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });