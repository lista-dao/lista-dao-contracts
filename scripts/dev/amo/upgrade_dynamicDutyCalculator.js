const hre = require('hardhat')
const { ethers, upgrades } = hre;

let PROXY = '0x1a85d3530840111a662a8E5Ea611aC1089391c6E';
let MockResilientOracle = '0x79e9675cDe605Ef9965AbCE185C5FD08d0DE16B1';

async function main() {
    const DynamicDutyCalculatorImpl = await hre.ethers.getContractFactory("DynamicDutyCalculator");

    await upgrades.validateUpgrade(PROXY, DynamicDutyCalculatorImpl);
    console.log('Validate Upgrade Done');

    const dynamicDutyCalculator = await upgrades.upgradeProxy(PROXY, DynamicDutyCalculatorImpl);
    console.log('DynamicDutyCalculator upgraded at:', dynamicDutyCalculator.target);

    // update oracle address
    let what = ethers.encodeBytes32String('oracle');
    await dynamicDutyCalculator.file(what, MockResilientOracle);
}


main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error)
  process.exit(1)
})
