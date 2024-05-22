const hre = require('hardhat')
const { ethers } = hre;
const config = require('./config.json');

// --------- New owner address ------------
const NEW_OWNER = "0x8d388136d578dCD791D081c6042284CED6d9B0c6";
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
