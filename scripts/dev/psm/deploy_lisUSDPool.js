const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let lisUSD = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af';
let maxDuty = '1000000034836767751273470154'; // 200%
let zero = "0x0000000000000000000000000000000000000000";
let maxAmount = "10000000000000000000000000";

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;

    const LisUSDPool = await hre.ethers.getContractFactory('LisUSDPoolSet');
    const lisUSDPool = await upgrades.deployProxy(LisUSDPool, [
        deployer,
        deployer,
        lisUSD,
        maxDuty
    ]);
    await lisUSDPool.waitForDeployment();

    const proxyAddress = await lisUSDPool.getAddress();

    console.log('LisUSDPool deployed to:', proxyAddress);
    try {
        await run("verify:verify", {
            address: proxyAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }

    const LisUSDPoolContract = await ethers.getContractAt('LisUSDPoolSet', proxyAddress);

    await LisUSDPoolContract.registerPool(lisUSD, lisUSD, zero);
    await LisUSDPoolContract.setMaxAmount(maxAmount);

    console.log('LisUSDPoolSet deploy and setup done');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
