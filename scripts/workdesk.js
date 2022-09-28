const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");

async function main() {

  let [deployer] = await ethers.getSigners();

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

  const addresses = {
    interaction: interaction.address,
    auctionProxy: auctionProxy.address
  };

  const jsonAddresses = JSON.stringify(addresses);
  fs.writeFileSync(`../${network.name}contractAddresses.json`, jsonAddresses);

  console.log("Deployed: Interaction: " + interaction.address);
  console.log("Deployed: AuctionLib : " + auctionProxy.address);

  await hre.run("verify:verify", {address: interaction.address});
  await hre.run("verify:verify", {address: auctionProxy.address});
 }

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });