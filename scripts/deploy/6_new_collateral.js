const fs = require("fs");
const {ethers, upgrades} = require("hardhat");

// Global Variables
let rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners();
  let NEW_OWNER = "0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37";

  // Fetch factories
  this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
  this.Clipper = await hre.ethers.getContractFactory("Clipper");
  this.Oracle = await hre.ethers.getContractFactory("BusdOracle");

  // Set addresses
  let ILK = ethers.encodeBytes32String("BUSD");
  let BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56";
  let VAT = "0x33A34eAB3ee892D40420507B820347b1cA2201c4";
  let DOG = "0xd57E7b53a1572d27A04d9c1De2c4D423f1926d0B";
  let SPOT = "0x49bc2c4E5B035341b7d92Da4e6B267F7426F3038";
  let INTERACTION = "0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4";
  let VOW = "0x2078A1969Ea581D618FDBEa2C0Dc13Fc15CB9fa7";
  let ABACI = "0xc1359eD77E6B0CBF9a8130a4C28FBbB87B9501b7";

  // Deploy contracts
  const gemJoin = await upgrades.deployProxy(this.GemJoin, [VAT, ILK, BUSD]);
  await gemJoin.waitForDeployment();
  let gemJoinImplementation = await upgrades.erc1967.getImplementationAddress(gemJoin.target);
  console.log("Deployed: gemJoin    : " + gemJoin.target);
  console.log("Imp                  : " + gemJoinImplementation);

  const clipper = await upgrades.deployProxy(this.Clipper, [VAT, SPOT, DOG, ILK]);
  await clipper.waitForDeployment();
  let clipperImplementation = await upgrades.erc1967.getImplementationAddress(clipper.target);
  console.log("Deployed: clipCE     : " + clipper.target);
  console.log("Imp                  : " + clipperImplementation);

  let aggregatorAddress;
  if (hre.network.name == "bsc") {
    aggregatorAddress = "0xcBb98864Ef56E9042e7d2efef76141f15731B82f";
  } else if (hre.network.name == "bsc_testnet") {
    aggregatorAddress = "0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa";
  }

  const oracle = await upgrades.deployProxy(this.Oracle, [aggregatorAddress]);
  await oracle.waitForDeployment();
  let oracleImplementation = await upgrades.erc1967.getImplementationAddress(oracle.target);
  console.log("Deployed: oracle     : " + oracle.target);
  console.log("Imp                  : " + oracleImplementation);

  // Initialize
  await gemJoin.rely(INTERACTION);

  await clipper.rely(DOG);
  await clipper.rely(INTERACTION);
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("buf"), "1100000000000000000000000000"); // 10%
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("tail"), "10800"); // 3h reset time
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("cusp"), "600000000000000000000000000"); // 60% reset ratio
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("chip"), "100000000000000"); // 0.01% from vow incentive
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("tip"), "10" + rad); // 10$ flat fee incentive
  await clipper["file(bytes32,uint256)"](ethers.encodeBytes32String("stopped"), "0");
  await clipper["file(bytes32,address)"](ethers.encodeBytes32String("spotter"), SPOT);
  await clipper["file(bytes32,address)"](ethers.encodeBytes32String("dog"), DOG);
  await clipper["file(bytes32,address)"](ethers.encodeBytes32String("vow"), VOW);
  await clipper["file(bytes32,address)"](ethers.encodeBytes32String("calc"), ABACI);

  // Transfer Ownerships
  await gemJoin.rely(NEW_OWNER);
  await gemJoin.deny(deployer.address);

  await clipper.rely(NEW_OWNER);
  await clipper.deny(deployer.address);

  console.log("BUSD: " + BUSD);
  console.log(ILK);

  // Store deployed addresses
  const addresses = {
    gemJoin: gemJoin.target,
    gemJoinImplementation: gemJoinImplementation,
    clipper: clipper.target,
    clipperImplementation: clipperImplementation,
    oracle: oracle.target,
    oracleImplementation: oracleImplementation,
    BUSD: BUSD,
    ilk: ILK
  }

  const json_addresses = JSON.stringify(addresses);
  fs.writeFileSync(`../${network.name}_addresses.json`, json_addresses);
  console.log("Addresses Recorded to: " + `../${network.name}_addresses.json`);

  // Verify
  await hre.run("verify:verify", {address: gemJoinImplementation});
  await hre.run("verify:verify", {address: clipperImplementation});
  await hre.run("verify:verify", {address: oracleImplementation, contract: "contracts/oracle/BusdOracle.sol:BusdOracle"});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });