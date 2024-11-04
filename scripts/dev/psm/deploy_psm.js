const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let usdc = '0xA528b0E61b72A0191515944cD8818a88d1D1D22b';
let lisUSD = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af';
let sellFee = 0;
let buyFee = 500;
let sellLimit = '1000000000000000000000000000'; // 1e27
let buyLimit = '1000000000000000000000000000'; // 1e27
let dailyLimit = '10000000000000000000000000' // 1e25;
let minSell = '1000000000000000000'; // 1e18;
let minBuy = '1000000000000000000'; // 1e18;

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;

    const PSM = await hre.ethers.getContractFactory('PSM');
    const psm = await upgrades.deployProxy(PSM, [
        usdc,
        deployer,
        lisUSD,
        sellFee,
        buyFee,
        sellLimit,
        buyLimit,
        dailyLimit,
        minSell,
        minBuy
    ]);
    await psm.waitForDeployment();

    const proxyAddress = await psm.getAddress();

    console.log('PSM deployed to:', proxyAddress);
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
