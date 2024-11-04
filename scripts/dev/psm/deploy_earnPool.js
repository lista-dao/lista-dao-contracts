const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let lisUSDPool = '0xd3c66df615fe10E756019208515b86D98FA205E5';
let lisUSD = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af';
const USDC = '0xA528b0E61b72A0191515944cD8818a88d1D1D22b';
const zero = '0x0000000000000000000000000000000000000000';
const psm = "0x89F5e21Ed5d716FcD86dfF00fDAbf9Bbc9327AC5";

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

    await earnPoolContract.setPSM(USDC, psm);
    await lisUSDPoolContract.setEarnPool(proxyAddress);
    await lisUSDPoolContract.registerPool(USDC, USDC, zero);
    console.log("EarnPool deploy and setup done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
