const hre = require('hardhat')
const { ethers } = hre;
const config = require('./config.json');

// --------- New owner address ------------
const NEW_OWNER = "0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37";
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
