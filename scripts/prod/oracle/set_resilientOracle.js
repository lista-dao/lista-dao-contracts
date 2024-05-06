const hre = require('hardhat')
const { ethers } = hre;
const config = require('./config.json');

async function main() {
  const resilientOracle = await ethers.getContractAt(
    "ResilientOracle",
    config.resilientOracleAddress
  );

  for (let assetName in config.assets) {
    const asset = config.assets[assetName];
    console.log(`[ResilientOracle] setting ${assetName}...`);
    console.log(asset);
    const tx = await resilientOracle.setTokenConfig([
      asset.token,
      [asset.mainOracle, asset.pivotOracle, asset.fallbackOracle],
      [true, true, true],
      asset.timeDeltaTolerance
    ]);
    await tx.wait(2);
  }
  console.log('[ResilientOracle] config done')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
