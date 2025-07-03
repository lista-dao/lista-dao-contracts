const hre = require("hardhat");
const {ethers} = hre;

const ORACLE_CONTRACT = 'xSolvBTCOracle';
const X_SOL_BTC_PRICE_FEED = "";

async function main() {
  if (!ORACLE_CONTRACT.length) {
    throw new Error('ORACLE_CONTRACT is required');
  }
  const Oracle = await ethers.getContractFactory(ORACLE_CONTRACT);
  const oracle = await Oracle.deploy(X_SOL_BTC_PRICE_FEED);
  await oracle.waitForDeployment();
  const oracleAddress = await oracle.getAddress();
  console.log('xSolvBTCOracle deployed at: ', oracleAddress);
  // waiting for ~5 blocks, in case scan doesn't sync in time
  await new Promise((resolve) => setTimeout(resolve, 3000 * 5));
  console.log('---------- verifying contract ----------')
  await hre.run("verify:verify", {
    address: oracleAddress,
    constructorArguments: [X_SOL_BTC_PRICE_FEED],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
