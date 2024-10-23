const hre = require("hardhat");
const {upgrades} = require("hardhat");


async function main() {
    let collateral = '0x16D9A837e0D1AAC45937425caC26CcB729388C9A'
    let beta = '1000000'
    let rate0 = '2293273137447729405' // duty - 1e27

    const dynamicCalc = '0x1a85d3530840111a662a8E5Ea611aC1089391c6E'

    console.log('DynamicDutyCalculator...')
    this.DynamicDutyCalculator = await hre.ethers.getContractFactory('DynamicDutyCalculator')
    const dynamicDutyCalculator = this.DynamicDutyCalculator.attach(dynamicCalc)

    const resp = await dynamicDutyCalculator.setCollateralParams(collateral, beta, rate0, 'true')
    console.log(resp)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
