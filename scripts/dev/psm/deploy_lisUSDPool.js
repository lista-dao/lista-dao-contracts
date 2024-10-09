const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let lisUSD = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af';
let maxDuty = '1000000034836767751273470154'; // 200%
let vat = "0x382589e4dE7A061fcb9716c203983d8FE847AE0b";

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;

    const LisUSDPool = await hre.ethers.getContractFactory('LisUSDPool');
    const lisUSDPool = await upgrades.deployProxy(LisUSDPool, [
        lisUSD,
        vat,
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
