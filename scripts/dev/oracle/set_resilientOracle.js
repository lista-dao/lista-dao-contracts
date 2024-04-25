const hre = require('hardhat')
const { ethers, upgrades } = hre;

const constants = {
  resilientOracle: '0x2D9f861Fb030Fa2Bf9Ac64EBD11dF7f337bA7582',
  mainOracle: '0x1A26d803C2e796601794f8C5609549643832702C',
  pivotOracle: '0x806B5D50b4bf790853a3595BEC0767d1a002aD82',
  fallbackOracle: '0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526',
  token: '0xae13d989dac2f0debff460ac112a837c89baa7cd',
  timeDeltaTolerance: 300,
}

async function main() {
  const ResilientOracle = await ethers.getContractFactory("ResilientOracle");
  const resilientOracle = await ResilientOracle.attach(constants.resilientOracle)
  const tx = await resilientOracle.setTokenConfig([
    constants.token,
    [
      constants.mainOracle,
      constants.pivotOracle,
      constants.fallbackOracle,
    ],
    [true, true, true],
    constants.timeDeltaTolerance
  ]);
  await tx.wait();
  console.log('done')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
