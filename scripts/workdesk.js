const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");
const {ether} = require("@openzeppelin/test-helpers");

async function main() {

  let [deployer] = await ethers.getSigners();

  // Contracts Fetching
  this.Dog = await hre.ethers.getContractFactory("Dog");
  this.Vow = await hre.ethers.getContractFactory("Vow");
  this.Hay = await hre.ethers.getContractFactory("Hay");
  this.AuctionProxy = await hre.ethers.getContractFactory("AuctionProxy");

  const auctionProxy = await this.AuctionProxy.deploy();
  await auctionProxy.deployed();
  this.Interaction = await hre.ethers.getContractFactory("Interaction", {
    unsafeAllow: ["external-library-linking"],
    libraries: {
      AuctionProxy: auctionProxy.address,
    },
  });

  let dog = await this.Dog.deploy();
  await dog.deployed();
  let vow = await this.Vow.deploy();
  await vow.deployed();
  let hay = await this.Hay.deploy();
  await hay.deployed();
  let int = await this.Interaction.deploy();
  await int.deployed();

  console.log("Dog: " + dog.address);
  console.log("Vow: " + vow.address);
  console.log("Hay: " + hay.address);
  console.log("Int: " + int.address);
  console.log("Lib: " + auctionProxy.address);
  
  // Store deployed addresses
  const addresses = {
    Dog: dog.address,
    Vow: vow.address,
    Hay: hay.address,
    Int: int.address,
    Lib: auctionProxy.address
  }

  const json_addresses = JSON.stringify(addresses);
  fs.writeFileSync(`../${network.name}_addresses.json`, json_addresses);
  console.log("Addresses Recorded to: " + `../${network.name}_addresses.json`);

  // Verify
  await hre.run("verify:verify", {address: dog.address});
  await hre.run("verify:verify", {address: vow.address});
  await hre.run("verify:verify", {address: hay.address});
  await hre.run("verify:verify", {address: int.address});
  await hre.run("verify:verify", {address: auctionProxy.address});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });