const {ethers, upgrades, run} = require('hardhat')
const hre = require('hardhat')
const string_decoder = require("node:string_decoder");
const Promise = require("bluebird");
const {verifyImpContract} = require("../../upgrades/utils/upgrade_utils");
const {atan2} = require("math.js/lib/trigonometric");

let usdc = '0xA528b0E61b72A0191515944cD8818a88d1D1D22b';
let usdt = '0x49b1401B4406Fe0B32481613bF1bC9Fe4B9378aC';
let fdusd = '0xadbccCa89eC498F8B9B7F6A4B05206b113676861';
let lisUSD = '0x785b5d1Bde70bD6042877cA08E4c73e0a40071af';
let sellFee = 0;
let buyFee = 500;
let dailyLimit = '10000000000000000000000000' // 1e25;
let minSell = '1000000000000000000'; // 1e18;
let minBuy = '1000000000000000000'; // 1e18;
let psms = {}
let maxDuty = '1000000034836767751273470154'; // 200%
let withdrawDelay = 5;
let maxAmount = "10000000000000000000000000";
let duty = '1000000003022265980097390211'; // 10%

const distributors = {
    'USDC': '0x9d9cfDc14D22a4eC4a31D6AfeD892Ac07913705d',
    'USDT': '0x08853f4Ae95a4a163c7Ecfb5aa251681c5FcDcB7',
    'FDUSD': '0xdB38311d06ff3B1764BF51bFb5B9Dbb6297e116a',
    'lisUSD': '0x0000000000000000000000000000000000000000',
}

async function main() {
    await deployPSMAll(usdc, 'USDC');
    await deployPSMAll(usdt, 'USDT');
    await deployPSMAll(fdusd, 'FDUSD');

    await deployPools();
}

async function verifyMockVenus(address, token) {
    await run("verify:verify", {
        address: address,
        constructorArguments: [token],
        contract: 'contracts/mock/psm/MockVenus.sol:MockVenus'
    });
}

async function deployPSMAll(token, name) {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    const admin = deployer;
    const manager = deployer;
    const pauser = deployer;
    const feeReceiver = deployer;
    console.log(`---------------------- ${name} ---------------------- `);
    // deploy PSM USDC
    const PSM = await hre.ethers.getContractFactory('PSM');
    const psm = await upgrades.deployProxy(PSM, [
        admin,
        manager,
        pauser,
        token,
        feeReceiver,
        lisUSD,
        sellFee,
        buyFee,
        dailyLimit,
        minSell,
        minBuy
    ]);
    await psm.waitForDeployment();

    const psmAddress = await psm.getAddress();

    try {
        await run("verify:verify", {
            address: psmAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }

    psms[name] = psmAddress;
    console.log(`PSM ${name} deployed to:`, psmAddress);

    const VaultManager = await hre.ethers.getContractFactory('VaultManager');
    const vaultManager = await upgrades.deployProxy(VaultManager, [
        admin,
        manager,
        psmAddress,
        token
    ]);
    await vaultManager.waitForDeployment();

    const vaultManagerAddress = await vaultManager.getAddress();

    try {
        await run("verify:verify", {
            address: vaultManagerAddress,
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }

    const psmContract = await ethers.getContractAt('PSM', psmAddress);

    await psmContract.setVaultManager(vaultManagerAddress);

    console.log(`VaultManager ${name} deployed to:`, vaultManagerAddress);

    const MokcVenus = await hre.ethers.getContractFactory('MockVenus');
    const mockVenus = await MokcVenus.deploy(token);
    await mockVenus.deploymentTransaction().wait(6);
    const mockVenusAddress = await mockVenus.getAddress();

    try {
        await run("verify:verify", {
            address: mockVenusAddress,
            constructorArguments: [token],
            contract: 'contracts/mock/psm/MockVenus.sol:MockVenus'
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }
    console.log(`MockVenus ${name} deployed to:`, mockVenusAddress);

    const VenusAdapter = await hre.ethers.getContractFactory('VenusAdapter');
    const venusAdapter = await upgrades.deployProxy(VenusAdapter, [
        admin,
        manager,
        vaultManagerAddress,
        mockVenusAddress,
        token,
        mockVenusAddress,
        feeReceiver
    ]);

    await venusAdapter.waitForDeployment();

    const venusAdapterAddress = await venusAdapter.getAddress();

    try {
        await run("verify:verify", {
            address: venusAdapterAddress,
            constructorArguments: [token],
            contract: 'contracts/mock/psm/MockVenus.sol:MockVenus'
        });
    } catch (error) {
        console.error('error verifying contract:', error);
    }
    console.log(`VenusAdapter ${name} deployed to:`, venusAdapterAddress);

    const vaultManagerContract = await ethers.getContractAt('VaultManager', vaultManagerAddress);

    await vaultManagerContract.addAdapter(venusAdapterAddress, 100);

    console.log('VenusAdapter deploy and setup done')
}

async function deployPools() {
    const signers = await hre.ethers.getSigners();
    const deployer = signers[0].address;
    const admin = deployer;
    const manager = deployer;
    const pauser = deployer;
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

    await LisUSDPoolContract.setEarnPool(earnPollAddress);
    await Promise.delay(3000);

    earnPoolContract.setPSM(usdc, psms['USDC']);
    await Promise.delay(3000);
    earnPoolContract.setPSM(usdt, psms['USDT']);
    await Promise.delay(3000);
    earnPoolContract.setPSM(fdusd, psms['FDUSD']);
    await Promise.delay(3000);

    LisUSDPoolContract.registerPool(usdc, usdc, distributors['USDC']);
    await Promise.delay(3000);
    LisUSDPoolContract.registerPool(usdt, usdt, distributors['USDT']);
    await Promise.delay(3000);
    LisUSDPoolContract.registerPool(fdusd, fdusd, distributors['FDUSD']);
    await Promise.delay(3000);
    LisUSDPoolContract.registerPool(lisUSD, lisUSD, distributors['lisUSD']);
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
