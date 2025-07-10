import {ethers} from "hardhat";

const hre = require("hardhat");
const {upgrades} = require("hardhat");

async function main() {
  // Contracts Fetching
  let CDPLiquidator = await hre.ethers.getContractFactory("CDPLiquidator");
  const [deployer] = await ethers.getSigners();
  const admin = deployer.address;
  const manager = deployer.address;
  const bot = deployer.address;
  const lender = "0x64d94e715B6c03A5D8ebc6B2144fcef278EC6aAa";
  const interaction = "0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4";
  const lisUSD = "0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5";

  const cdpLiquidator = await upgrades.deployProxy(CDPLiquidator, [
    admin,
    manager,
    bot,
    lender,
    interaction,
    lisUSD
  ], {initializer: "initialize"})

  console.log("Deployed: CDPLiquidator: " + await cdpLiquidator.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
