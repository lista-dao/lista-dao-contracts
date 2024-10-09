const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let lisUSDPool = '0xDA1cA1F0bc8fD75fB51315526403774f4BE25691';
let lisUSD = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af';

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;

    const EarnPool = await hre.ethers.getContractFactory('EarnPool');
    const earnPoll = await upgrades.deployProxy(EarnPool, [
        lisUSDPool,
        lisUSD,
    ]);
    await earnPoll.waitForDeployment();

    const proxyAddress = await earnPoll.getAddress();

    console.log('EarnPool deployed to:', proxyAddress);
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
