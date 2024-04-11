const fs = require("fs");
const path = require("path");
const {ethers, upgrades} = require("hardhat");

// Global Variables
let rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

async function main() {

  [deployer] = await ethers.getSigners();
  let NEW_OWNER = "0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37";

  // Fetch factories
  this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
  this.Clipper = await hre.ethers.getContractFactory("Clipper");
  this.Oracle = await hre.ethers.getContractFactory("BtcOracle");

  // Set addresses
  let ILK = ethers.encodeBytes32String("BTCB");
  // btcb address
  let BTCB = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
  let VAT = "0x33A34eAB3ee892D40420507B820347b1cA2201c4";
  let DOG = "0xd57E7b53a1572d27A04d9c1De2c4D423f1926d0B";
  let SPOT = "0x49bc2c4E5B035341b7d92Da4e6B267F7426F3038";
  let INTERACTION = "0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4";
  let VOW = "0x2078A1969Ea581D618FDBEa2C0Dc13Fc15CB9fa7";
  let ABACI = "0xc1359eD77E6B0CBF9a8130a4C28FBbB87B9501b7";

  // Binance Oracle BTCB Aggregator Address
  let aggregatorAddress = "0x83968bCa5874D11e02fD80444cDDB431a1DbEc0f";

  if (hre.network.name === "bsc_testnet") {
    NEW_OWNER = deployer.address;
    console.log("Deploying on BSC Testnet", hre.network.name, "Network", deployer.address);

    // deploy BTCB
    const BtcbMock = await hre.ethers.getContractFactory("BtcbMock");
    const btcbMock = await BtcbMock.deploy();
    await btcbMock.waitForDeployment();
    BTCB = await btcbMock.getAddress();
    console.log("BTCB deployed to:", BTCB);
    // mint 1000 BTCB to deployer
    await btcbMock.mint(deployer.address, ethers.parseEther("1000"));
    VAT = "0xC9eeBDB18bD05dCF981F340b838E8CdD946D60ad";
    DOG = "0x77e4FcEbCDd30447f6e2E486B00a552A6493da0F";
    SPOT = "0x15493D9141481505f7CA3e591Cea2cBB03637B1d";
    INTERACTION = "0xb7A5999AEaE17C37d07ac4b34e56757c96387c84";
    VOW = "0x08b0e59E3AC9266738c6d14bAbAA414f3A989ccc";
    ABACI = "0x1f4F2aF5F8970654466d334208D1478eaabB28E3";
    aggregatorAddress = "0x491fD333937522e69D1c3FB944fbC5e95eEF9f59";
  }

  // Deploy contracts
  const gemJoin = await upgrades.deployProxy(this.GemJoin, [VAT, ILK, BTCB]);
  await gemJoin.waitForDeployment();
  let gemJoinImplementation = await upgrades.erc1967.getImplementationAddress(gemJoin.target);
  console.log("Deployed: gemJoin    : " + gemJoin.target);
  console.log("Imp                  : " + gemJoinImplementation);

  const clipper = await upgrades.deployProxy(this.Clipper, [VAT, SPOT, DOG, ILK]);
  await clipper.waitForDeployment();
  let clipperImplementation = await upgrades.erc1967.getImplementationAddress(clipper.target);
  console.log("Deployed: clipCE     : " + clipper.target);
  console.log("Imp                  : " + clipperImplementation);


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

  console.log("BTCB: " + BTCB);
  console.log(ILK);

  // Store deployed addresses
  const addresses = {
    gemJoin: gemJoin.target,
    gemJoinImplementation: gemJoinImplementation,
    clipper: clipper.target,
    clipperImplementation: clipperImplementation,
    oracle: oracle.target,
    oracleImplementation: oracleImplementation,
    BTCB: BTCB,
    ilk: ILK
  }

  const json_addresses = JSON.stringify(addresses);
  console.log('json addresses: ', json_addresses);
  const dir = path.join(__dirname, `./6_new_collateral_btcb_${hre.network.name}.json`);
  fs.writeFileSync(dir, json_addresses);
  console.log("Addresses Recorded to: " + dir);

  // Verify
  await hre.run("verify:verify", {address: gemJoinImplementation});
  await hre.run("verify:verify", {address: clipperImplementation});
  await hre.run("verify:verify", {address: oracleImplementation, contract: "contracts/oracle/BtcOracle.sol:BtcOracle"});
  if (hre.network.name === "bsc_testnet") {
    await hre.run("verify:verify", {address: BTCB, contract: "contracts/mock/BtcbMock.sol:BtcbMock"});
  }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
