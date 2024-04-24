const hre = require("hardhat");
const {ethers} = hre;

async function main() {
  const PRICE_IDS = {
    ETH: '0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace',
    BNB: '0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f',
  }
  const args = [
    hre.network.name === "bsc" ?
      '0x4d7e825f80bdf85e913e0dd2a2d54927e9de1594' : // pyth contract (BSC Mainnet)
      '0x5744Cbf430D99456a0A8771208b674F27f8EF0Fb', // pyth contract (BSC Testnet)
    PRICE_IDS.BNB // price id
  ];
  // Deploy pyth oracle
  const PythOracle = await ethers.getContractFactory("PythOracle");
  const pythOracle = await PythOracle.deploy(...args);
  await pythOracle.waitForDeployment();
  const pythOracleAddress = await pythOracle.getAddress();
  console.log("Deployed: PythOracle         : " + pythOracleAddress);
  // verify contract
  console.log('\n\n---------- verifying PythAgent ----------')
  await hre.run("verify:verify", {
    address: pythOracleAddress,
    constructorArguments: args
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
