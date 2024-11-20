const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')
const Promise = require("bluebird");

let pauser = "0xEEfebb1546d88EA0909435DF6f615084DD3c5Bd8";
let lisUSD = '0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5';
let usdt = "0x55d398326f99059fF775485246999027B3197955";
let zero = "0x0000000000000000000000000000000000000000";
let duty = '1000000003022265980097390211'; // 10%

async function main() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    const admin = deployer;
    const manager = deployer;
    //todo
    const lisUSDPoolAddress = "0xA23FC5Cd5a1bC0fa7BcC90A89bdd1487ac8e3970";
    const psmAddress = "0x7E88e1208C6c23891D84E740b9883B7bcD6e7293";
    const EarnPool = await hre.ethers.getContractFactory('EarnPool');
    const earnPoll = await upgrades.deployProxy(EarnPool, [
        admin,
        manager,
        pauser,
        lisUSDPoolAddress,
        lisUSD,
    ]);
    await earnPoll.waitForDeployment();

    const earnPollAddress = await earnPoll.getAddress();

    try {
        await run("verify:verify", {
            address: earnPollAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }
    console.log('EarnPool deployed to:', earnPollAddress);

    const earnPoolContract = await ethers.getContractAt('EarnPool', earnPollAddress);

    const LisUSDPoolContract = await ethers.getContractAt('LisUSDPoolSet', lisUSDPoolAddress);

    await LisUSDPoolContract.setEarnPool(earnPollAddress);
    await Promise.delay(3000);

    earnPoolContract.setPSM(usdt, psmAddress);
    await Promise.delay(3000);

    LisUSDPoolContract.registerPool(lisUSD, lisUSD, zero);
    await Promise.delay(3000);

    //setDuty
    LisUSDPoolContract.setDuty(duty);

    console.log("EarnPool deploy and setup done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
