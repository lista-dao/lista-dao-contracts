const hre = require('hardhat')
const { ethers } = hre;
const config = require('./config.json');

// --------- New owner address ------------
const NEW_OWNER = "0x08aE09467ff962aF105c23775B9Bc8EAa175D27F";
// ----------------------------------------


async function main() {
  const resilientOracle = await ethers.getContractAt(
    "ResilientOracle",
    config.resilientOracleAddress
  );
  const tx = await resilientOracle.transferOwnership(NEW_OWNER);
  await tx.wait(2);
  console.log(`New owner ${NEW_OWNER} proposed.`)
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
