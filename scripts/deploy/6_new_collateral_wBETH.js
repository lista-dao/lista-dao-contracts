const hre = require("hardhat");
const fs = require("fs");
const { ethers, upgrades } = require("hardhat");

// Global Variables
let rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {
  [deployer] = await ethers.getSigners();
  let NEW_OWNER = "0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37";

  // Fetch factories
  this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
  this.Clipper = await hre.ethers.getContractFactory("Clipper");
  this.Oracle = await hre.ethers.getContractFactory("wBETHOracle");

  // Set addresses
  let ILK = await ethers.utils.formatBytes32String("wBETH");
  let wBETH = "0x34f8f72e3f14Ede08bbdA1A19a90B35a80f3E789";
  let VAT = "0xa2573f33dD7C687d01BED841D3311acae345A7c9";
  let DOG = "0x76F4b1F82C36776e49801c0E67c6b411bF1229e2";
  let SPOT = "0xdBadc7C3f832B6020691cfA4391C6DF719d70ed9";
  let INTERACTION = "0x2e92BE58c5D3f6AF6E1dcCbC867C4D1Cc2595238";
  let VOW = "0x4d56F1DAAF6ad2693Af68B7D22DA567e657F4598";
  let ABACI = "0x6616603965de3A008d99C411F791736f99564D54";

  // Deploy contracts
  const gemJoin = await upgrades.deployProxy(this.GemJoin, [VAT, ILK, wBETH], { initializer: "initialize" });
  await gemJoin.deployed();
  let gemJoinImplementation = await upgrades.erc1967.getImplementationAddress(gemJoin.address);
  console.log("Deployed: gemJoin    : " + gemJoin.address);
  console.log("Imp                  : " + gemJoinImplementation);

  const clipper = await upgrades.deployProxy(this.Clipper, [VAT, SPOT, DOG, ILK], { initializer: "initialize" });
  await clipper.deployed();
  let clipperImplementation = await upgrades.erc1967.getImplementationAddress(clipper.address);
  console.log("Deployed: clipCE     : " + clipper.address);
  console.log("Imp                  : " + clipperImplementation);

  let aggregatorAddress;
  if (hre.network.name == "bsc") {
    aggregatorAddress = "0xcBb98864Ef56E9042e7d2efef76141f15731B82f";
  } else if (hre.network.name == "bsc_testnet") {
    aggregatorAddress = "0x3aed9b75c6d6c68a1f065e8f9c9313e8bf8e37e9";
  }

  const oracle = await upgrades.deployProxy(this.Oracle, [aggregatorAddress], { initializer: "initialize" });
  await oracle.deployed();
  let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.address);
  console.log("Deployed: oracle     : " + oracle.address);
  console.log("Imp                  : " + oracleImplementation);

  // Initialize
  await gemJoin.rely(INTERACTION);

  await clipper.rely(DOG);
  await clipper.rely(INTERACTION);
  await clipper["file(bytes32,uint256)"](ethers.utils.formatBytes32String("buf"), "1100000000000000000000000000"); // 10%
  await clipper["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tail"), "10800"); // 3h reset time
  await clipper["file(bytes32,uint256)"](ethers.utils.formatBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
  await clipper["file(bytes32,uint256)"](ethers.utils.formatBytes32String("chip"), "100000000000000"); // 0.01% from vow incentive
  await clipper["file(bytes32,uint256)"](ethers.utils.formatBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
  await clipper["file(bytes32,uint256)"](ethers.utils.formatBytes32String("stopped"), "0");
  await clipper["file(bytes32,address)"](ethers.utils.formatBytes32String("spotter"), SPOT);
  await clipper["file(bytes32,address)"](ethers.utils.formatBytes32String("dog"), DOG);
  await clipper["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), VOW);
  await clipper["file(bytes32,address)"](ethers.utils.formatBytes32String("calc"), ABACI);

  // Transfer Ownerships
  await gemJoin.rely(NEW_OWNER);
  await gemJoin.deny(deployer.address);

  await clipper.rely(NEW_OWNER);
  await clipper.deny(deployer.address);

  console.log("wBETH: " + wBETH);
  console.log(ILK);

  // Store deployed addresses
  const addresses = {
    gemJoin: gemJoin.address,
    gemJoinImplementation: gemJoinImplementation,
    clipper: clipper.address,
    clipperImplementation: clipperImplementation,
    oracle: oracle.address,
    oracleImplementation: oracleImplementation,
    wBETH: wBETH,
    ilk: ILK,
  };

  const json_addresses = JSON.stringify(addresses);
  fs.writeFileSync(`../${network.name}_addresses.json`, json_addresses);
  console.log("Addresses Recorded to: " + `../${network.name}_addresses.json`);

  // Verify
  await hre.run("verify:verify", { address: gemJoinImplementation });
  await hre.run("verify:verify", { address: clipperImplementation });
  await hre.run("verify:verify", {
    address: oracleImplementation,
    contract: "contracts/oracle/BusdOracle.sol:BusdOracle",
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
