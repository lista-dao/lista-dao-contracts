const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");

async function main() {

  let [deployer] = await ethers.getSigners();

  this.Dog = await hre.ethers.getContractFactory("Dog");
  this.AuctionProxy = await hre.ethers.getContractFactory("AuctionProxy");
  const auctionProxy = await this.AuctionProxy.deploy();
  await auctionProxy.deployed();
  this.Interaction = await hre.ethers.getContractFactory("Interaction", {
    unsafeAllow: ["external-library-linking"],
    libraries: {
      AuctionProxy: auctionProxy.address,
    },
  });

  const interaction = await this.Interaction.deploy();
  await interaction.deployed();
  const dog = await this.Dog.deploy();
  await dog.deployed();

  console.log("Interaction    : " + interaction.address);
  console.log("AucctionProxy  : " + auctionProxy.address);
  console.log("Dog            : " + dog.address);

  const addresses = {
    interaction: interaction.address,
    auctionProxy: auctionProxy.address,
    dog: dog.address
  };

  const jsonAddresses = JSON.stringify(addresses);
  fs.writeFileSync(`../${network.name}contractAddresses.json`, jsonAddresses);

  await hre.run("verify:verify", {address: dog.address});
  await hre.run("verify:verify", {address: interaction.address});
  await hre.run("verify:verify", {address: auctionProxy.address});
 }

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });