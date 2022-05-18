const { ethers, network } = require('hardhat');
const { expect } = require("chai");

describe('===Spot===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("TEST");

    const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.Spot = await ethers.getContractFactory("Spotter");
        this.Vat = await ethers.getContractFactory("Vat");
        this.Oracle = await ethers.getContractFactory("Oracle");

        // Contract deployment
        spot = await this.Spot.connect(deployer).deploy();
        await spot.deployed();
        vat = await this.Vat.connect(deployer).deploy();
        await vat.deployed();
        oracle = await this.Oracle.connect(deployer).deploy();
        await oracle.deployed();
    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            expect(await spot.vat()).to.be.equal(vat.address);
        });
    });
    describe('--- rely()', function () {
        it('reverts: Spot/not-authorized', async function () {
            await expect(spot.rely(signer1.address)).to.be.revertedWith("Spotter/not-authorized");
            expect(await spot.wards(signer1.address)).to.be.equal("0");
        });
        it('relies on address', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await spot.rely(signer1.address);
            expect(await spot.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: Spot/not-authorized', async function () {
            await expect(spot.deny(signer1.address)).to.be.revertedWith("Spotter/not-authorized");
        });
        it('denies an address', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await spot.rely(signer1.address);
            expect(await spot.wards(signer1.address)).to.be.equal("1");
            await spot.deny(signer1.address);
            expect(await spot.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- file(3a)', function () {
        it('reverts: Spotter/not-live', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await spot.cage();
            await expect(spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, await ethers.utils.formatBytes32String("pip"), signer2.address)).to.be.revertedWith("Spotter/not-live");
        });
        it('reverts: Spotter/file-unrecognized-param', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await expect(spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, await ethers.utils.formatBytes32String("pipa"), signer2.address)).to.be.revertedWith("Spotter/file-unrecognized-param");
        });
        it('sets pip', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, await ethers.utils.formatBytes32String("pip"), signer2.address);
            expect(await (await spot.ilks(collateral)).pip).to.be.equal(signer2.address);
        });
    });
    describe('--- file(2)', function () {
        it('reverts: Spotter/not-live', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await spot.cage();
            await expect(spot.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("par"), "1" + ray)).to.be.revertedWith("Spotter/not-live");
        });
        it('reverts: Spotter/file-unrecognized-param', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await expect(spot.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("para"), "1" + ray)).to.be.revertedWith("Spotter/file-unrecognized-param");
        });
        it('sets par', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await spot.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("par"), "1" + ray);
            expect(await spot.par()).to.be.equal("1" + ray);
        });
    });
    describe('--- file(3b)', function () {
        it('reverts: Spotter/not-live', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await spot.cage();
            await expect(spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("mat"), "1" + ray)).to.be.revertedWith("Spotter/not-live");
        });
        it('reverts: Spotter/file-unrecognized-param', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await expect(spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("mata"), "1" + ray)).to.be.revertedWith("Spotter/file-unrecognized-param");
        });
        it('sets mat', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("mat"), "1" + ray);
            expect(await (await spot.ilks(collateral)).mat).to.be.equal("1" + ray);
        });
    });
    describe('--- poke()', function () {
        it('pokes new price of an ilk', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);

            await oracle.setPrice("5" + wad);
            await spot.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("par"), "1" + ray);
            await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, await ethers.utils.formatBytes32String("pip"), oracle.address);
            await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("mat"), "1" + ray);

            await vat.rely(spot.address);

            await spot.poke(collateral);
        });
    });
});