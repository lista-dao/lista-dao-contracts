const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let lisUSD = '0x7adC9A28Fab850586dB99E7234EA2Eb7014950fA';
let maxDuty = '1000000034836767751273470154'; // 200%

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;

    const LisUSDPool = await hre.ethers.getContractFactory('LisUSDPool');
    const lisUSDPool = await upgrades.deployProxy(LisUSDPool, [
        lisUSD,
        maxDuty,
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

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
