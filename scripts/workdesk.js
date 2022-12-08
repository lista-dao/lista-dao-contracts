const hre = require("hardhat");
const fs = require("fs");
const {ethers, upgrades} = require("hardhat");

async function main() {

  let [deployer] = await ethers.getSigners();

  this.Hay = await hre.ethers.getContractFactory("Hay");
  hay = await this.Hay.deploy(); await hay.deployed();

  console.log("Hay            : " + hay.address);

  const addresses = {
    hayimp: hay.address,
  };

  const jsonAddresses = JSON.stringify(addresses);
  fs.writeFileSync(`../${network.name}contractAddresses.json`, jsonAddresses);

  await hre.run("verify:verify", {address: hay.address});
 }

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });