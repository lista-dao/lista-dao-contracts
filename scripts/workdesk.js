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
  // await auctionProxy.waitForDeployment();
  // this.Interaction = await hre.ethers.getContractFactory("Interaction", {
  //   unsafeAllow: ["external-library-linking"],
  //   libraries: {
  //     AuctionProxy: auctionProxy.target,
  //   },
  // });

  // vat = await this.Vat.deploy(); await vat.waitForDeployment();
  // jug = await this.Jug.deploy(); await jug.waitForDeployment();
  // dog = await this.Dog.deploy(); await dog.waitForDeployment();
  // cerosrouter = await this.CerosRouter.deploy(); await cerosrouter.waitForDeployment();
  // ceVault = await this.CeVault.deploy(); await ceVault.waitForDeployment();
  // helioProvider = await this.HelioProvider.deploy(); await helioProvider.waitForDeployment();
  // interaction = await this.Interaction.deploy(); await interaction.waitForDeployment();
  es = await this.EmergencyShutdown.deploy("0x33A34eAB3ee892D40420507B820347b1cA2201c4", "0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8");
  await es.waitForDeployment();
  await es.transferOwnership("0x8d388136d578dCD791D081c6042284CED6d9B0c6");
  console.log("Deployed:            : " + es.target);

  // console.log("Vat     : " + vat.target);
  // console.log("Jug     : " + jug.target);
  // console.log("Dog     : " + dog.target);
  // console.log("CeRouter: " + cerosrouter.target);
  // console.log("CeVault : " + ceVault.target);
  // console.log("HelioPro: " + helioProvider.target);
  // console.log("Interact: " + interaction.target);
  // console.log("proxy   : " + auctionProxy.target);

  // Store deployed addresses
  const addresses = {
    // vat: vat.target,
    // jug: jug.target,
    // dog: dog.target,
    // cerouter: cerosrouter.target,
    // cervault: ceVault.target,
    // helioProvider: helioProvider.target,
    // interaction: interaction.target,
    // auctionProxy: auctionProxy.target
    es: es.target
  }

  const json_addresses = JSON.stringify(addresses);
  fs.writeFileSync(`../${network.name}_addresses.json`, json_addresses);
  console.log("Addresses Recorded to: " + `../${network.name}_addresses.json`);
  // await hre.run("verify:verify", {address: vat.target});
  // await hre.run("verify:verify", {address: jug.target});
  // await hre.run("verify:verify", {address: dog.target});
  // await hre.run("verify:verify", {address: cerosrouter.target});
  // await hre.run("verify:verify", {address: ceVault.target});
  // await hre.run("verify:verify", {address: helioProvider.target});
  // await hre.run("verify:verify", {address: interaction.target});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });