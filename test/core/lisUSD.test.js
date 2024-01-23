const { ethers, network } = require('hardhat');
const { expect } = require("chai");

describe('===LisUSD===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("TEST");

    const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.LisUSD = await ethers.getContractFactory("LisUSD");

        // Contract deployment
        hay = await this.LisUSD.connect(deployer).deploy();
        await hay.deployed();
    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            expect(await hay.symbol()).to.be.equal("lisUSD");
        });
    });
    describe('--- rely()', function () {
        it('reverts: LisUSD/not-authorized', async function () {
            await expect(hay.rely(signer1.address)).to.be.revertedWith("LisUSD/not-authorized");
            expect(await hay.wards(signer1.address)).to.be.equal("0");
        });
        it('relies on address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.rely(signer1.address);
            expect(await hay.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: LisUSD/not-authorized', async function () {
            await expect(hay.deny(signer1.address)).to.be.revertedWith("LisUSD/not-authorized");
        });
        it('denies an address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.rely(signer1.address);
            expect(await hay.wards(signer1.address)).to.be.equal("1");
            await hay.deny(signer1.address);
            expect(await hay.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- mint()', function () {
        it('reverts: LisUSD/mint-to-zero-address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await expect(hay.mint(NULL_ADDRESS, "1" + wad)).to.be.revertedWith("LisUSD/mint-to-zero-address");
        });
        it('reverts: LisUSD/cap-reached', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await expect(hay.mint(deployer.address, "101" + wad)).to.be.revertedWith("LisUSD/cap-reached");
        });
        it('mints hay to an address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(deployer.address, "1" + wad);
            expect(await hay.balanceOf(deployer.address)).to.be.equal("1" + wad);
        });
    });
    describe('--- burn()', function () {
        it('reverts: LisUSD/burn-from-zero-address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await expect(hay.burn(NULL_ADDRESS, "1" + wad)).to.be.revertedWith("LisUSD/burn-from-zero-address");
        });
        it('reverts: LisUSD/insufficient-balance', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await expect(hay.burn(deployer.address, "1" + wad)).to.be.revertedWith("LisUSD/insufficient-balance");
        });
        it('reverts: LisUSD/insufficient-allowance', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(signer1.address, "1" + wad);
            await expect(hay.burn(signer1.address, "1" + wad)).to.be.revertedWith("LisUSD/insufficient-allowance");
        });
        it('burns with allowance', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(signer1.address, "1" + wad);
            await hay.connect(signer1).approve(deployer.address, "1" + wad);
            await hay.burn(signer1.address, "1" + wad);
            expect(await hay.balanceOf(signer1.address)).to.be.equal(0);
        });
        it('burns from address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(signer1.address, "1" + wad);
            await hay.connect(signer1).burn(signer1.address, "1" + wad);
            expect(await hay.balanceOf(signer1.address)).to.be.equal(0);
        });
    });
    describe('--- transferFrom()', function () {
        it('reverts: LisUSD/transfer-from-zero-address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await expect(hay.transferFrom(NULL_ADDRESS, deployer.address, "1" + wad)).to.be.revertedWith("LisUSD/transfer-from-zero-address");
        });
        it('reverts: LisUSD/transfer-to-zero-address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await expect(hay.transferFrom(deployer.address, NULL_ADDRESS, "1" + wad)).to.be.revertedWith("LisUSD/transfer-to-zero-address");
        });
        it('reverts: LisUSD/insufficient-balance', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await expect(hay.transferFrom(deployer.address, signer1.address, "1" + wad)).to.be.revertedWith("LisUSD/insufficient-balance");
        });
        it('reverts: LisUSD/insufficient-allowance', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(deployer.address, "1" + wad);
            await expect(hay.connect(signer1).transferFrom(deployer.address, signer1.address, "1" + wad)).to.be.revertedWith("LisUSD/insufficient-allowance");
        });
        it('transferFrom with allowance', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(deployer.address, "1" + wad);
            await hay.approve(signer1.address, "1" + wad);
            await hay.connect(signer1).transferFrom(deployer.address, signer1.address, "1" + wad);
            expect(await hay.balanceOf(signer1.address)).to.be.equal("1" + wad);
        });
        it('transferFrom an address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(deployer.address, "1" + wad);
            await hay.connect(deployer).transferFrom(deployer.address, signer1.address, "1" + wad);
            expect(await hay.balanceOf(signer1.address)).to.be.equal("1" + wad);
        });
    });
    describe('--- transfer()', function () {
        it('transfers to an address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(deployer.address, "1" + wad);
            await hay.transfer(signer1.address, "1" + wad);
            expect(await hay.balanceOf(signer1.address)).to.be.equal("1" + wad);
        });
    });
    describe('--- push()', function () {
        it('pushes to an address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(deployer.address, "1" + wad);
            await hay.push(signer1.address, "1" + wad);
            expect(await hay.balanceOf(signer1.address)).to.be.equal("1" + wad);
        });
    });
    describe('--- pull()', function () {
        it('pulls from an address', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(signer1.address, "1" + wad);
            await hay.connect(signer1).approve(deployer.address, "1" + wad);
            await hay.pull(signer1.address, "1" + wad);
            expect(await hay.balanceOf(deployer.address)).to.be.equal("1" + wad);
        });
    });
    describe('--- move()', function () {
        it('move between addresses', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(deployer.address, "1" + wad);
            await hay.move(deployer.address, signer1.address, "1" + wad);
            expect(await hay.balanceOf(signer1.address)).to.be.equal("1" + wad);
        });
    });
    describe('--- increaseAllowance()', function () {
        it('increases allowance', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.increaseAllowance(signer1.address, "1" + wad);
            expect(await hay.allowance(deployer.address, signer1.address)).to.be.equal("1" + wad);
        });
    });
    describe('--- decreaseAllowance()', function () {
        it('reverts: LisUSD/decreased-allowance-below-zero', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.increaseAllowance(signer1.address, "1" + wad);
            await expect(hay.decreaseAllowance(signer1.address, "2" + wad)).to.be.revertedWith("LisUSD/decreased-allowance-below-zero");
        });
        it('decreases allowance', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.increaseAllowance(signer1.address, "1" + wad);
            await hay.decreaseAllowance(signer1.address, "1" + wad);
            expect(await hay.allowance(deployer.address, signer1.address)).to.be.equal("0");
        });
    });
    describe('--- setSupplyCap()', function () {
        it('reverts: LisUSD/more-supply-than-cap', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.mint(deployer.address, "1" + wad);
            await expect(hay.setSupplyCap("0")).to.be.revertedWith("LisUSD/more-supply-than-cap");
        });
        it('sets the cap', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.setSupplyCap("5" + wad);
            expect(await hay.supplyCap()).to.be.equal("5" + wad);
        });
    });
    describe('--- updateDomainSeparator()', function () {
        it('sets domain separator', async function () {
            await hay.initialize(97, "lisUSD", "100" + wad);
            await hay.updateDomainSeparator(1);
            let DS1 = await hay.DOMAIN_SEPARATOR;
            let DS2 =await hay.updateDomainSeparator(2);
            expect(DS1).to.not.be.equal(DS2);
        });
    });
});
