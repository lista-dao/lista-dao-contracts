const { ethers, network } = require('hardhat');
const { expect } = require("chai");

describe('===Flash===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.encodeBytes32String("TEST");

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.Vat = await ethers.getContractFactory("Vat");
        this.Vow = await ethers.getContractFactory("Vow");
        this.Hay = await ethers.getContractFactory("Hay");
        this.HayJoin = await ethers.getContractFactory("HayJoin");
        this.Flash = await ethers.getContractFactory("Flash");
        this.BorrowingContract = await ethers.getContractFactory("FlashBorrower");

        // Contract deployment
        vat = await this.Vat.connect(deployer).deploy();
        await vat.waitForDeployment();
        vow = await this.Vow.connect(deployer).deploy();
        await vow.waitForDeployment();
        hay = await this.Hay.connect(deployer).deploy();
        await hay.waitForDeployment();
        hayjoin = await this.HayJoin.connect(deployer).deploy();
        await hayjoin.waitForDeployment();
        flash = await this.Flash.connect(deployer).deploy();
        await flash.waitForDeployment();
        borrowingContract = await this.BorrowingContract.connect(deployer).deploy(flash.target);
        await borrowingContract.waitForDeployment();
    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            expect(await flash.wards(deployer.address)).to.be.equal("0");
            await hayjoin.initialize(vat.target, hay.target);
            await vow.initialize(vat.target, hayjoin.target, deployer.address);
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            expect(await flash.wards(deployer.address)).to.be.equal("1");
        });
    });
    describe('--- rely()', function () {
        it('reverts: Flash/not-authorized', async function () {
            await expect(flash.rely(signer1.address)).to.be.revertedWith("Flash/not-authorized");
            expect(await flash.wards(signer1.address)).to.be.equal("0");
        });
        it('relies on address', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await flash.rely(signer1.address);
            expect(await flash.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: Flash/not-authorized', async function () {
            await expect(flash.deny(signer1.address)).to.be.revertedWith("Flash/not-authorized");
        });
        it('denies an address', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await flash.rely(signer1.address);
            expect(await flash.wards(signer1.address)).to.be.equal("1");
            await flash.deny(signer1.address);
            expect(await flash.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- file(2)', function () {
        it('reverts: Flash/ceiling-too-high', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await expect(flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("max"), "100" + rad)).to.be.revertedWith("Flash/ceiling-too-high");
        });
        it('reverts: Flash/file-unrecognized-param', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await expect(flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("maxi"), "100" + rad)).to.be.revertedWith("Flash/file-unrecognized-param");
        });
        it('sets max', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("max"), "5" + wad);
            expect(await flash.max()).to.be.equal("5" + wad);
        });
        it('sets toll', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("toll"), "1" + wad);
            expect(await flash.toll()).to.be.equal("1" + wad);
        });
    });
    describe('--- maxFlashLoan()', function () {
        it('other token', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            expect(await flash.maxFlashLoan(deployer.address)).to.be.equal("0");
        });
        it('loan token', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("max"), "5" + wad);
            expect(await flash.maxFlashLoan(hay.target)).to.be.equal("5" + wad);
        });
    });
    describe('--- flashFee()', function () {
        it('reverts: Flash/token-unsupported', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await expect(flash.flashFee(deployer.address, "1" + wad)).to.be.revertedWith("Flash/token-unsupported");
        });
        it('calculates flashFee', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("toll"), "1" + wad);
            expect(await flash.flashFee(hay.target, "1" + wad)).to.be.equal("1" +  wad);
        });
    });
    describe('--- flashLoan()', function () {
        it('reverts: Flash/token-unsupported', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("max"), "10" + wad);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("toll"), "10000000000000000"); // 1%
            hay2 = await this.Hay.connect(deployer).deploy();
            await hay2.waitForDeployment();
            await expect(borrowingContract.flashBorrow(hay2.target, "1" + wad)).to.be.revertedWith("Flash/token-unsupported");
        });
        it('reverts: Flash/ceiling-exceeded', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("max"), "10" + wad);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("toll"), "10000000000000000"); // 1%
            await expect(borrowingContract.flashBorrow(hay.target, "11" + wad)).to.be.revertedWith("Flash/ceiling-exceeded");
        });
        it('reverts: Flash/vat-not-live', async function () {
            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("max"), "10" + wad);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("toll"), "10000000000000000"); // 1%
            await expect(borrowingContract.flashBorrow(hay.target, "9" + wad)).to.be.revertedWith("Flash/vat-not-live");
        });
        it('flash mints, burns and accrues with fee', async function () {
            await vat.initialize();
            await vat.init(collateral);
            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.encodeBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.encodeBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.encodeBytes32String("spot"), "100" + ray);
            await vat.slip(collateral, deployer.address, "1" + wad);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, hayjoin.target, 0, "20" + wad);
            await vat.rely(flash.target);
            await vat.rely(hayjoin.target);

            await hay.initialize(97, "HAY", "100" + wad);
            await hay.rely(hayjoin.target);

            await hayjoin.initialize(vat.target, hay.target);
            await hayjoin.rely(flash.target);

            await flash.initialize(vat.target, hay.target, hayjoin.target, vow.target);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("max"), "10" + wad);
            await flash.connect(deployer)["file(bytes32,uint256)"](await ethers.encodeBytes32String("toll"), "10000000000000000"); // 1%
            await hay.mint(borrowingContract.target, "1000000000000000000"); // Minting 1% fee that will be returned with 1 wad next
            await borrowingContract.flashBorrow(hay.target, "1" + wad);

            expect(await vat.hay(vow.target)).to.be.equal("0" + rad);
            await flash.accrue();
            expect(await vat.hay(vow.target)).to.be.equal("10000000000000000000000000000000000000000000"); // Surplus from Flash fee
        });
    });
});
