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
    // check is configured
    const oracle = await resilientOracle.getTokenConfig(asset.token);
    // not configured
    if ((oracle.asset || "").toLowerCase() !== asset.token.toLowerCase()) {
      const tx = await resilientOracle.setTokenConfig([
        asset.token,
        [
          zeroIfEmpty(asset.mainOracle),
          zeroIfEmpty(asset.pivotOracle),
          zeroIfEmpty(asset.fallbackOracle)
        ],
        [
          notEmptyAddress(asset.mainOracle),
          notEmptyAddress(asset.pivotOracle),
          notEmptyAddress(asset.fallbackOracle)
        ],
        asset.timeDeltaTolerance
      ]);
      await tx.wait(2);
    } else {
      console.log("[ResilientOracle] configured already")
    }
  }
  console.log('[ResilientOracle] config done')
}

function zeroIfEmpty(address) {
  return address === "" ? "0x0000000000000000000000000000000000000000" : address;
}

function notEmptyAddress(address) {
  return address !== "";

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
