const { ethers, network } = require('hardhat');
const { expect } = require("chai");

describe('===HelioRewards===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("TEST");

    const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.HelioRewards = await ethers.getContractFactory("HelioRewards");
        this.HelioToken = await ethers.getContractFactory("HelioToken");
        this.Vat = await ethers.getContractFactory("Vat");
        this.HelioOracle = await ethers.getContractFactory("HelioOracle");

        // Contract deployment
        heliorewards = await this.HelioRewards.connect(deployer).deploy();
        await heliorewards.deployed();
        heliotoken = await this.HelioToken.connect(deployer).deploy();
        await heliotoken.deployed();
        vat = await this.Vat.connect(deployer).deploy();
        await vat.deployed();
        heliooracle = await this.HelioOracle.connect(deployer).deploy();
        await heliooracle.deployed();
    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            expect(await heliorewards.poolLimit()).to.be.equal("100" + wad);
        });
    });
    describe('--- rely()', function () {
        it('reverts: Rewards/not-authorized', async function () {
            await expect(heliorewards.rely(signer1.address)).to.be.revertedWith("Rewards/not-authorized");
            expect(await heliorewards.wards(signer1.address)).to.be.equal("0");
        });
        it('reverts: Rewards/not-live', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.stop();
            await expect(heliorewards.rely(signer1.address)).to.be.revertedWith("Rewards/not-live");
        });
        it('relies on address', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.rely(signer1.address);
            expect(await heliorewards.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: Rewards/not-authorized', async function () {
            await expect(heliorewards.deny(signer1.address)).to.be.revertedWith("Rewards/not-authorized");
        });
        it('reverts: Rewards/not-live', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.stop();
            await expect(heliorewards.deny(NULL_ADDRESS)).to.be.revertedWith("Rewards/not-live");
        });
        it('denies an address', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.rely(signer1.address);
            expect(await heliorewards.wards(signer1.address)).to.be.equal("1");
            await heliorewards.deny(signer1.address);
            expect(await heliorewards.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- stop()', function () {
        it('disables the live flag', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.stop();
            expect(await heliorewards.live()).to.be.equal("0");
        });
    });
    describe('--- start()', function () {
        it('enables the live flag', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.stop();
            expect(await heliorewards.live()).to.be.equal("0");

            await heliorewards.start();
            expect(await heliorewards.live()).to.be.equal("1");
        });
    });
    describe('--- initPool()', function () {
        it('reverts: Reward/not-enough-reward-token', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await expect(heliorewards.initPool(heliotoken.address, collateral, "1" + ray)).to.be.revertedWith("Reward/not-enough-reward-token");
        });
        it('reverts: Reward/pool-existed', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(heliotoken.address, collateral, "1" + ray)

            await expect(heliorewards.initPool(heliotoken.address, collateral, "1" + ray)).to.be.revertedWith("Reward/pool-existed");
        });
        it('reverts: Reward/invalid-token', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await expect(heliorewards.initPool(NULL_ADDRESS, collateral, "1" + ray)).to.be.revertedWith("Reward/invalid-token");
        });
        it('inits a pool', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(heliotoken.address, collateral, "1" + ray);
            expect(await (await heliorewards.pools(heliotoken.address)).rewardRate).to.be.equal("1" + ray);
        });
    });
    describe('--- setHelioToken()', function () {
        it('reverts: Reward/invalid-token', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await expect(heliorewards.setHelioToken(NULL_ADDRESS)).to.be.revertedWith("Reward/invalid-token");
        });
        it('sets helio token address', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);

            expect(await heliorewards.helioToken()).to.be.equal(heliotoken.address);
        });
    });
    describe('--- setRewardsMaxLimit()', function () {
        it('reverts: Reward/not-enough-reward-token', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await expect(heliorewards.setRewardsMaxLimit("110" + wad)).to.be.revertedWith("Reward/not-enough-reward-token");
        });
        it('sets rewards max limit', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.setRewardsMaxLimit("100" + wad);
            expect(await heliorewards.poolLimit()).to.be.equal("100" + wad);
        });
    });
    describe('--- setOracle()', function () {
        it('reverts: Reward/invalid-oracle', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await expect(heliorewards.setOracle(NULL_ADDRESS)).to.be.revertedWith("Reward/invalid-oracle");
        });
        it('sets oracle', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliooracle.initialize("1" + wad);
            await heliorewards.setOracle(heliooracle.address);
            expect(await heliorewards.oracle()).to.be.equal(heliooracle.address);
        });
    });
    describe('--- setRate()', function () {
        it('reverts: Reward/pool-existed', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(heliotoken.address, collateral, "1" + ray);
            await expect(heliorewards.setRate(heliotoken.address, "1" + ray)).to.be.revertedWith("Reward/pool-existed");
        });
        it('reverts: Reward/invalid-token', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(heliotoken.address, collateral, "1" + ray);
            await expect(heliorewards.setRate(NULL_ADDRESS, "1" + ray)).to.be.revertedWith("Reward/invalid-token");
        });
        it('reverts: Reward/negative-rate', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await expect(heliorewards.setRate(heliotoken.address, "1" + wad)).to.be.revertedWith("Reward/negative-rate");
        });
        it('reverts: Reward/high-rate', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await expect(heliorewards.setRate(heliotoken.address, "3" + ray)).to.be.revertedWith("Reward/high-rate");
        });
        it('sets rate', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.setRate(heliotoken.address, "1" + ray);
            expect(await (await heliorewards.pools(heliotoken.address)).rewardRate).to.be.equal("1" + ray);
        });
    });
    describe('--- helioPrice()', function () {
        it('returns helio price', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliorewards.setOracle(heliooracle.address);
            await heliooracle.initialize("2" + wad);
            expect(await heliorewards.helioPrice()).to.be.equal("2" + wad);
        });
    });
    describe('--- rewardsRate()', function () {
        it('returns token  rate', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(heliotoken.address, collateral, "1" + ray);
            expect(await heliorewards.rewardsRate(heliotoken.address)).to.be.equal("1" + ray);
        });
    });
    describe('--- drop()', function () {
        it('returns if rho is 0', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.drop(heliotoken.address, deployer.address);
            expect(await (await heliorewards.pools(heliotoken.address)).rewardRate).to.be.equal("0");
        });
        it('drops rewards', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);

            await vat.slip(collateral, deployer.address, "1" + wad);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, 0, "15" + wad);

            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(heliotoken.address, collateral, "1000000001847694957439350500");
            await heliooracle.initialize("1" + wad);
            await heliorewards.setOracle(heliooracle.address);

            expect(await (await heliorewards.piles(deployer.address, heliotoken.address)).amount).to.be.equal("0");

            await heliorewards.drop(heliotoken.address, deployer.address);

            tau = (await ethers.provider.getBlock()).timestamp;
            await network.provider.send("evm_setNextBlockTimestamp", [tau + 100]);
            await network.provider.send("evm_mine");
            await heliorewards.drop(heliotoken.address, deployer.address);
            expect(await (await heliorewards.piles(deployer.address, heliotoken.address)).amount).to.be.equal("2799258119129");

            await heliorewards.claim("2799258119129");
        });
    });
    describe('--- distributionApy()', function () {
        it('returns token APY', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(heliotoken.address, collateral, "1" + ray);
            expect(await heliorewards.distributionApy(heliotoken.address)).to.be.equal("0");
        });
    });
});