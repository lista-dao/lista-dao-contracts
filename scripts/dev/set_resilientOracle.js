const hre = require('hardhat')
const { ethers, upgrades } = hre;

async function main() {
  const ResilientOracle = await ethers.getContractFactory("ResilientOracle");
  const resilientOracle = await ResilientOracle.attach('0x2D9f861Fb030Fa2Bf9Ac64EBD11dF7f337bA7582')
  await resilientOracle.setTokenConfig([
    '0xE7bCB9e341D546b66a46298f4893f5650a56e99E', // ResilientOracle
    [
      '0x635780E5D02Ab29d7aE14d266936A38d3D5B0CC5',
      '0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7',
      '0x7ED1Fe4dA11931F17a1221C4cbC7AF0320858bEf'
    ],
    [true, true, true]
  ]);
  console.log('done')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
