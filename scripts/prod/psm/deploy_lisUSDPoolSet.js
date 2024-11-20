const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')

let pauser = "0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8";
let lisUSD = '0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5';
let maxDuty = '1000000005781378656804590540'; // 20%
let maxAmount = "10000000000000000000000000"; // 10m
let withdrawDelay = 5;

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    const admin = deployer;
    const manager = deployer;
    const LisUSDPool = await hre.ethers.getContractFactory('LisUSDPoolSet');
    const lisUSDPool = await upgrades.deployProxy(LisUSDPool, [
        admin,
        manager,
        pauser,
        lisUSD,
        maxDuty,
        withdrawDelay
    ]);
    await lisUSDPool.waitForDeployment();

    const lisUSDPoolAddress = await lisUSDPool.getAddress();

    try {
        await run("verify:verify", {
            address: lisUSDPoolAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }

    const LisUSDPoolContract = await ethers.getContractAt('LisUSDPoolSet', lisUSDPoolAddress);

    await LisUSDPoolContract.setMaxAmount(maxAmount);

    console.log('LisUSDPool deployed to:', lisUSDPoolAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
