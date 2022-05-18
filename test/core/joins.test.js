const { ethers, network } = require('hardhat');
const { expect } = require("chai");

describe('===GemJoin===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("TEST");

    const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.GemJoin = await ethers.getContractFactory("GemJoin");
        this.Vat = await ethers.getContractFactory("Vat");
        this.Hay = await ethers.getContractFactory("Hay");

        // Contract deployment
        gemjoin = await this.GemJoin.connect(deployer).deploy();
        await gemjoin.deployed();
        vat = await this.Vat.connect(deployer).deploy();
        await vat.deployed();
        gem = await this.Hay.connect(deployer).deploy();
        await gem.deployed();
    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            await gemjoin.initialize(vat.address, collateral, gem.address);
            expect(await gemjoin.vat()).to.be.equal(vat.address);
        });
    });
    describe('--- rely()', function () {
        it('reverts: GemJoin/not-authorized', async function () {
            await expect(gemjoin.rely(signer1.address)).to.be.revertedWith("GemJoin/not-authorized");
            expect(await gemjoin.wards(signer1.address)).to.be.equal("0");
        });
        it('relies on address', async function () {
            await gemjoin.initialize(vat.address, collateral, gem.address);
            await gemjoin.rely(signer1.address);
            expect(await gemjoin.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: GemJoin/not-authorized', async function () {
            await expect(gemjoin.deny(signer1.address)).to.be.revertedWith("GemJoin/not-authorized");
        });
        it('denies an address', async function () {
            await gemjoin.initialize(vat.address, collateral, gem.address);
            await gemjoin.rely(signer1.address);
            expect(await gemjoin.wards(signer1.address)).to.be.equal("1");
            await gemjoin.deny(signer1.address);
            expect(await gemjoin.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- cage()', function () {
        it('cages', async function () {
            await gemjoin.initialize(vat.address, collateral, gem.address);
            await gemjoin.cage();
            expect(await gemjoin.live()).to.be.equal("0");
        });
    });
    describe('--- join()', function () {
        it('reverts: GemJoin/not-live', async function () {
            await gemjoin.initialize(vat.address, collateral, gem.address);
            await gemjoin.cage();
            await expect(gemjoin.join(deployer.address, "1" + wad)).to.be.revertedWith("GemJoin/not-live");
        });
        it('reverts: GemJoin/overflow', async function () {
            await gemjoin.initialize(vat.address, collateral, gem.address);
            await expect(gemjoin.join(deployer.address, "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")).to.be.revertedWith("GemJoin/overflow");
        });
        it('joins hay erc20', async function () {
            await gemjoin.initialize(vat.address, collateral, gem.address);
            await gem.initialize(97, "GEM", "100" + wad);
            await vat.initialize();

            await gem.mint(deployer.address, "1" + wad);
            await gem.approve(gemjoin.address, "1" + wad);
            await vat.rely(gemjoin.address);
            await gem.rely(gemjoin.address);

            await gemjoin.join(deployer.address, "1" + wad);
            expect(await vat.gem(collateral, deployer.address)).to.be.equal("1" + wad);
        });
    });
    describe('--- exit()', function () {
        it('reverts: GemJoin/overflow', async function () {
            await gemjoin.initialize(vat.address, collateral, gem.address);
            await expect(gemjoin.exit(deployer.address, "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")).to.be.revertedWith("GemJoin/overflow");
        });
        it('exits hay erc20', async function () {
            await gemjoin.initialize(vat.address, collateral, gem.address);
            await gem.initialize(97, "GEM", "100" + wad);
            await vat.initialize();

            await gem.mint(deployer.address, "1" + wad);
            await gem.approve(gemjoin.address, "1" + wad);
            await vat.rely(gemjoin.address);
            await gem.rely(gemjoin.address);

            await gemjoin.join(deployer.address, "1" + wad);
            expect(await vat.gem(collateral, deployer.address)).to.be.equal("1" + wad);

            await gemjoin.exit(deployer.address, "1" + wad);
            expect(await vat.gem(collateral, deployer.address)).to.be.equal("0");
        });
    });
});
describe('===HayJoin===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("TEST");

    const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.HayJoin = await ethers.getContractFactory("HayJoin");
        this.Vat = await ethers.getContractFactory("Vat");
        this.Hay = await ethers.getContractFactory("Hay");

        // Contract deployment
        hayjoin = await this.HayJoin.connect(deployer).deploy();
        await hayjoin.deployed();
        vat = await this.Vat.connect(deployer).deploy();
        await vat.deployed();
        hay = await this.Hay.connect(deployer).deploy();
        await hay.deployed();
    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            await hayjoin.initialize(vat.address, hay.address);
            expect(await hayjoin.vat()).to.be.equal(vat.address);
        });
    });
    describe('--- rely()', function () {
        it('reverts: HayJoin/not-authorized', async function () {
            await expect(hayjoin.rely(signer1.address)).to.be.revertedWith("HayJoin/not-authorized");
            expect(await hayjoin.wards(signer1.address)).to.be.equal("0");
        });
        it('relies on address', async function () {
            await hayjoin.initialize(vat.address, hay.address);
            await hayjoin.rely(signer1.address);
            expect(await hayjoin.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: HayJoin/not-authorized', async function () {
            await expect(hayjoin.deny(signer1.address)).to.be.revertedWith("HayJoin/not-authorized");
        });
        it('denies an address', async function () {
            await hayjoin.initialize(vat.address, hay.address);
            await hayjoin.rely(signer1.address);
            expect(await hayjoin.wards(signer1.address)).to.be.equal("1");
            await hayjoin.deny(signer1.address);
            expect(await hayjoin.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- cage()', function () {
        it('cages', async function () {
            await hayjoin.initialize(vat.address, hay.address);
            await hayjoin.cage();
            expect(await hayjoin.live()).to.be.equal("0");
        });
    });
    describe('--- join()', function () {
        it('joins hay erc20', async function () {
            await hayjoin.initialize(vat.address, hay.address);
            await hay.initialize(97, "HAY", "100" + wad);
            
            await vat.initialize();
            await vat.init(collateral);
            await vat.rely(hayjoin.address);
            await hay.rely(hayjoin.address);
            await vat.hope(hayjoin.address);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);

            await vat.slip(collateral, deployer.address, "1" + wad);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, 0, "15" + wad);
            await hayjoin.exit(deployer.address, "1" + wad);

            await hay.approve(hayjoin.address, "1" + wad);
            
            await hayjoin.join(deployer.address, "1" + wad);
            expect(await vat.hay(deployer.address)).to.be.equal("15" + rad);
        });
    });
    describe('--- exit()', function () {
        it('reverts: HayJoin/not-live', async function () {
            await hayjoin.initialize(vat.address, hay.address);
            await hayjoin.cage();
            await expect(hayjoin.exit(deployer.address, "1" + wad)).to.be.revertedWith("HayJoin/not-live");
        });
        it('exits hay erc20', async function () {
            await hayjoin.initialize(vat.address, hay.address);
            await hay.initialize(97, "HAY", "100" + wad);
            
            await vat.initialize();
            await vat.init(collateral);
            await vat.rely(hayjoin.address);
            await hay.rely(hayjoin.address);
            await vat.hope(hayjoin.address);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);

            await vat.slip(collateral, deployer.address, "1" + wad);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, 0, "15" + wad);
            await hayjoin.exit(signer1.address, "1" + wad);

            expect(await hay.balanceOf(signer1.address)).to.be.equal("1" + wad);
        });
    });
});