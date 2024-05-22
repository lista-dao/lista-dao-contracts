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
  const tx1 = await resilientOracle.transferOwnership(NEW_OWNER);
  await tx1.wait(2);
  console.log(`New owner of Resilient Oracle ${NEW_OWNER} proposed.`);

  const boundValidator = await ethers.getContractAt(
    "BoundValidator",
    config.boundValidatorAddress
  );
  const tx2 = await boundValidator.transferOwnership(NEW_OWNER);
  await tx2.wait(2);
  console.log(`New owner of Bound Validator ${NEW_OWNER} proposed.`);

}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
