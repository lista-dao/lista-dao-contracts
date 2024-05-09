const hre = require('hardhat')
const { ethers } = hre;
const config = require('./config.json');

async function main() {
  const boundValidator = await ethers.getContractAt(
    "BoundValidator",
    config.boundValidatorAddress
  );

  for (let assetName in config.assets) {
    const asset = config.assets[assetName];
    console.log(`[BoundValidator] setting ${assetName}...`);
    const tx = await boundValidator.setValidateConfig([
      asset.token,
      asset.upperBoundRatio,
      asset.lowerBoundRatio
    ]);
    await tx.wait(2);
  }
  console.log('[BoundValidator] config done')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
