const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

let INTERACTION = '0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4';
let lisUSD = '0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5';
let oracle = '0xf3afD82A4071f272F403dC176916141f44E6c750';
let priceDeviation = 200000;
let admin = '0x8d388136d578dCD791D081c6042284CED6d9B0c6';

async function main() {
   const DynamicDutyCalculator = await hre.ethers.getContractFactory('DynamicDutyCalculator');
   const dynamicDutyCalculator = await upgrades.deployProxy(DynamicDutyCalculator, [INTERACTION, lisUSD, oracle, priceDeviation, admin]);
   await dynamicDutyCalculator.waitForDeployment();

   console.log('DynamicDutyCalculator deployed to:', dynamicDutyCalculator.target);
   await run("verify:verify", {
    address: dynamicDutyCalculator.target,
    constructorArguments: [],
  });

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
