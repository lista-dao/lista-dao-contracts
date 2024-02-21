const {ethers, upgrades} = require("hardhat");

///////////////////////////////////////////////////////////////////////////////////
// Note: This script is meant to be used before full release. Not for production.//
///////////////////////////////////////////////////////////////////////////////////

// Global Variables
let wad = "000000000000000000", // 18 Decimals
    ray = "000000000000000000000000000", // 27 Decimals
    rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {

  // Declare and load network variables from networkVars.json
  let ilkCE = "";

  // Contracts Fetching
  this.Vat = await hre.ethers.getContractFactory("Vat");
  this.Dog = await hre.ethers.getContractFactory("Dog");
  this.Clip = await hre.ethers.getContractFactory("Clipper");
  this.Abaci = await hre.ethers.getContractFactory("LinearDecrease");
  // this.Vow = await hre.ethers.getContractFactory("Vow");

  let vat = await this.Vat.attach("");
  let dog = await this.Dog.attach("");
  let clipCE = await this.Clip.attach("");
  let abaci = await this.Abaci.attach("");
  // let vow = await this.Vow.attach("");

  // Variables Upadate
  console.log("Vat Update...");
  await vat["file(bytes32,uint256)"](ethers.encodeBytes32String("Line"), "5000000" + rad);
  await vat["file(bytes32,bytes32,uint256)"](ilkCE, ethers.encodeBytes32String("line"), "5000000" + rad);
  await vat["file(bytes32,bytes32,uint256)"](ilkCE, ethers.encodeBytes32String("dust"), "100" + ray);

  console.log("Dog Update...");
  await dog["file(bytes32,uint256)"](ethers.encodeBytes32String("Hole"), "50000000" + rad);
  await dog["file(bytes32,bytes32,uint256)"](ilkCE, ethers.encodeBytes32String("hole"), "50000000" + rad);
  await dog["file(bytes32,bytes32,uint256)"](ilkCE, ethers.encodeBytes32String("chop"), "1100000000000000000"); // 10%

  console.log("Clip Update...");
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("buf"), "1100000000000000000000000000"); // 10%
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("tail"), "10800"); // 3h reset time
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("chip"), "100000000000000"); // 0.01% from vow incentive
  await clipCE["file(bytes32,uint256)"](ethers.encodeBytes32String("tip"), "10" + rad); // 10$ flat fee incentive

  console.log("Abaci Update...");
  await abaci.file(ethers.encodeBytes32String("tau"), "36000");

  // console.log("Vow Update...");
  // await vow["file(bytes32,uint256)"](ethers.encodeBytes32String("hump"), "0" + rad);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });