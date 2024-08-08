const {ethers, upgrades} = require('hardhat')
const hre = require('hardhat')

let INTERACTION = '0x70C4880A3f022b32810a4E9B9F26218Ec026f279';
let lisUSD = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af';
let oracle = '0x9CCf790F691925fa61b8cB777Cb35a64F5555e53';
let priceDeviation = 200000;
let admin = '0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06';

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
