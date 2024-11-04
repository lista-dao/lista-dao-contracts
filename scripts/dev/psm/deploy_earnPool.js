const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')
const Promise = require('bluebird');

let lisUSDPool = '0x371588eBFA6D6fA9E38637D9880CC3327b33f82F';
let lisUSD = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af';

const psms = [{
    psm: '0x89F5e21Ed5d716FcD86dfF00fDAbf9Bbc9327AC5',
    coin: '0xA528b0E61b72A0191515944cD8818a88d1D1D22b',
    name: 'USDC',
    distributor: '0x0000000000000000000000000000000000000000',
}, {
    psm: '0xF915BD8Db101ABA1253a17B2e359B4B9C0d50F84',
    coin: '0x49b1401B4406Fe0B32481613bF1bC9Fe4B9378aC',
    name: 'USDT',
    distributor: '0x0000000000000000000000000000000000000000',
}, {
    psm: '0x7616c413F29059D5002B0cCdFc2c82526EdA3E23',
    coin: '0xadbccCa89eC498F8B9B7F6A4B05206b113676861',
    name: 'FDUSD',
    distributor: '0x0000000000000000000000000000000000000000',
}]

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;

    const EarnPool = await hre.ethers.getContractFactory('EarnPool');
    const earnPoll = await upgrades.deployProxy(EarnPool, [
        deployer,
        deployer,
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

    const lisUSDPoolContract = await ethers.getContractAt('LisUSDPoolSet', lisUSDPool);
    const earnPoolContract = await ethers.getContractAt('EarnPool', proxyAddress);

    await lisUSDPoolContract.setEarnPool(proxyAddress);
    await Promise.delay(3000);
    for (let i = 0; i < psms.length; i++) {
        const psm = psms[i];
        await earnPoolContract.setPSM(psm.coin, psm.psm);
        await Promise.delay(3000);
        await lisUSDPoolContract.registerPool(psm.coin, psm.coin, psm.distributor);
        await Promise.delay(3000);
    }
    console.log("EarnPool deploy and setup done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
