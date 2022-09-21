const { ethers, network } = require('hardhat');
const { expect } = require("chai");

describe('===HelioToken===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("TEST");

    const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.HelioToken = await ethers.getContractFactory("HelioToken");

        // Contract deployment
        heliotoken = await this.HelioToken.connect(deployer).deploy();
        await heliotoken.deployed();
    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            await heliotoken.initialize("100" + wad, deployer.address);
            expect(await heliotoken.symbol()).to.be.equal("HELIO");
        });
    });
    describe('--- rely()', function () {
        it('reverts: HelioToken/not-authorized', async function () {
            await expect(heliotoken.rely(signer1.address)).to.be.revertedWith("HelioToken/not-authorized");
            expect(await heliotoken.wards(signer1.address)).to.be.equal("0");
        });
        it('reverts: HelioToken/invalid-address', async function () {
            await heliotoken.initialize("100" + wad, deployer.address);
            await expect(heliotoken.rely(NULL_ADDRESS)).to.be.revertedWith("HelioToken/invalid-address");
        });
        it('relies on address', async function () {
            await heliotoken.initialize("100" + wad, deployer.address);
            await heliotoken.rely(signer1.address);
            expect(await heliotoken.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: HelioToken/not-authorized', async function () {
            await expect(heliotoken.deny(signer1.address)).to.be.revertedWith("HelioToken/not-authorized");
        });
        it('reverts: HelioToken/invalid-address', async function () {
            await heliotoken.initialize("100" + wad, deployer.address);
            await expect(heliotoken.deny(NULL_ADDRESS)).to.be.revertedWith("HelioToken/invalid-address");
        });
        it('denies an address', async function () {
            await heliotoken.initialize("100" + wad, deployer.address);
            await heliotoken.rely(signer1.address);
            expect(await heliotoken.wards(signer1.address)).to.be.equal("1");
            await heliotoken.deny(signer1.address);
            expect(await heliotoken.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- mint()', function () {
        it('reverts: HelioToken/rewards-oversupply', async function () {
            await heliotoken.initialize("100" + wad, deployer.address);
            await expect(heliotoken.mint(deployer.address, "1000" + wad)).to.be.revertedWith("HelioToken/rewards-oversupply");
        });
        it('mints hay to an address', async function () {
            await heliotoken.initialize("100" + wad, deployer.address);
            await heliotoken.mint(signer1.address, "1" + wad);
            expect(await heliotoken.balanceOf(signer1.address)).to.be.equal("1" + wad);
        });
    });
    describe('--- burn()', function () {
        it('burns from address', async function () {
            await heliotoken.initialize("100" + wad, deployer.address);
            await heliotoken.mint(signer1.address, "1" + wad);
            await heliotoken.connect(signer1).burn("1" + wad);
            expect(await heliotoken.balanceOf(signer1.address)).to.be.equal(0);
        });
    });
    describe('--- pause()', function () {
        it('pauses transfers', async function () {
            await heliotoken.initialize("100" + wad, deployer.address);
            await heliotoken.pause();
            expect(await heliotoken.paused()).to.be.equal(true);
        });
    });
    describe('--- unpause()', function () {
        it('unpauses transfers', async function () {
            await heliotoken.initialize("100" + wad, deployer.address);
            await heliotoken.pause();
            expect(await heliotoken.paused()).to.be.equal(true);

            await heliotoken.unpause();
            expect(await heliotoken.paused()).to.be.equal(false);
        });
    });
});