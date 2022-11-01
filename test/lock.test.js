const { ethers, network } = require('hardhat');
const { expect } = require("chai");

describe('===Lock===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("TEST");

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.Vat = await ethers.getContractFactory("Vat");
        this.Dog = await ethers.getContractFactory("Dog");
        this.Vow = await ethers.getContractFactory("Vow");
        this.Spot = await ethers.getContractFactory("Spotter");
        this.HayJoin = await ethers.getContractFactory("HayJoin");
        this.HelioToken = await ethers.getContractFactory("HelioToken");
        this.Jar = await ethers.getContractFactory("Jar");
        this.Lock = await ethers.getContractFactory("Lock");

        // Contract deployment
        vat = await this.Vat.connect(deployer).deploy();
        await vat.deployed();
        dog = await this.Dog.connect(deployer).deploy();
        await dog.deployed();
        vow = await this.Vow.connect(deployer).deploy();
        await vow.deployed();
        spot = await this.Spot.connect(deployer).deploy();
        await spot.deployed();
        hayJoin = await this.HayJoin.connect(deployer).deploy();
        await hayJoin.deployed();
        helioToken = await this.HelioToken.connect(deployer).deploy();
        await helioToken.deployed();
        jar = await this.Jar.connect(deployer).deploy();
        await jar.deployed();
        lock = await this.Lock.connect(deployer).deploy();
        await lock.deployed();
    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            expect(await lock.wards(deployer.address)).to.be.equal("0");
            await lock.initialize();
            expect(await lock.wards(deployer.address)).to.be.equal("1");
        });
    });
    describe('--- rely()', function () {
        it('reverts: Lock/not-authorized', async function () {
            await expect(lock.rely(signer1.address)).to.be.revertedWith("Lock/not-authorized");
            expect(await lock.wards(signer1.address)).to.be.equal("0");
        });
        it('relies on address', async function () {
            await lock.initialize();
            await lock.rely(signer1.address);
            expect(await lock.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: Lock/not-authorized', async function () {
            await expect(lock.deny(signer1.address)).to.be.revertedWith("Lock/not-authorized");
        });
        it('denies an address', async function () {
            await lock.initialize();
            await lock.rely(signer1.address);
            expect(await lock.wards(signer1.address)).to.be.equal("1");
            await lock.deny(signer1.address);
            expect(await lock.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- file(2)', function () {
        it('reverts: Lock/not-live', async function () {
            await lock.initialize();
            await lock.cage();
            await expect(lock.connect(deployer).file(await ethers.utils.formatBytes32String("vat"), vat.address)).to.be.revertedWith("Lock/not-live");
        });
        it('reverts: Lock/file-unrecognized-param', async function () {
            await lock.initialize();
            await expect(lock.connect(deployer).file(await ethers.utils.formatBytes32String("vatt"), vat.address)).to.be.revertedWith("file-unrecognized-param");
        });
        it('sets vat', async function () {
            await lock.initialize();
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("vat"), vat.address);
            expect(await lock.vat()).to.be.equal(vat.address);
        });
        it('sets dog', async function () {
            await lock.initialize();
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("dog"), dog.address);
            expect(await lock.dog()).to.be.equal(dog.address);
        });
        it('sets vow', async function () {
            await lock.initialize();
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("vow"), vow.address);
            expect(await lock.vow()).to.be.equal(vow.address);
        });
        it('sets spot', async function () {
            await lock.initialize();
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("spot"), spot.address);
            expect(await lock.spot()).to.be.equal(spot.address);
        });
        it('sets hayjoin', async function () {
            await lock.initialize();
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("hayJoin"), hayJoin.address);
            expect(await lock.hayJoin()).to.be.equal(hayJoin.address);
        });
        it('sets helioToken', async function () {
            await lock.initialize();
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("helioToken"), helioToken.address);
            expect(await lock.helioToken()).to.be.equal(helioToken.address);
        });
        it('sets jar', async function () {
            await lock.initialize();
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("jar"), jar.address);
            expect(await lock.jar()).to.be.equal(jar.address);
        });
    });
    describe('--- lockDown()/unlockAll()', function () {
        it('reverts: Lock/not-live', async function () {
            await lock.initialize();
            await lock.cage();
            await expect(lock.connect(deployer).lockDown()).to.be.revertedWith("Lock/not-live");
        });
        it('locks down all and unlocks all', async function () {
            await lock.initialize();

            await vat.initialize();
            await vat.rely(lock.address);
            await dog.initialize(vat.address);
            await dog.rely(lock.address);
            await vow.initialize(vat.address, hayJoin.address, deployer.address);
            await vow.rely(lock.address);
            await spot.initialize(vat.address);
            await spot.rely(lock.address);
            this.Hay = await ethers.getContractFactory("Hay");
            hay = await this.Hay.connect(deployer).deploy();
            await hay.deployed();
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await hayJoin.rely(lock.address);
            await helioToken.initialize("100" + wad, deployer.address);
            await helioToken.rely(lock.address);
            await jar.initialize("Helio Hay", "hHAY", hay.address, 10, 0, 5);
            await jar.rely(lock.address);

            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("vat"), vat.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("dog"), dog.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("vow"), vow.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("spot"), spot.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("hayJoin"), hayJoin.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("helioToken"), helioToken.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("jar"), jar.address);

            await lock.connect(deployer).lockDown();

            expect(await vat.live()).to.be.equal("0");
            expect(await dog.live()).to.be.equal("0");
            expect(await vow.live()).to.be.equal("0");
            expect(await spot.live()).to.be.equal("0");
            expect(await hayJoin.live()).to.be.equal("0");
            expect(await jar.live()).to.be.equal("0");

            await lock.connect(deployer).uncage();
            await lock.connect(deployer).unlockAll();

            expect(await vat.live()).to.be.equal("1");
            expect(await dog.live()).to.be.equal("1");
            expect(await vow.live()).to.be.equal("1");
            expect(await spot.live()).to.be.equal("1");
            expect(await hayJoin.live()).to.be.equal("1");
            expect(await jar.live()).to.be.equal("1");
        });
    });
    describe('--- lock()/unlock()', function () {
        it('reverts: Lock/not-live', async function () {
            await lock.initialize();
            await lock.cage();
            await expect(lock.connect(deployer).lock(ethers.utils.formatBytes32String("vat"))).to.be.revertedWith("Lock/not-live");
        });
        it('locks down and unlocks vat', async function () {
            await lock.initialize();

            await vat.initialize();
            await vat.rely(lock.address);
            
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("vat"), vat.address);

            await lock.connect(deployer).lock(await ethers.utils.formatBytes32String("vat"));

            expect(await vat.live()).to.be.equal("0");

            await lock.connect(deployer).unlock(await ethers.utils.formatBytes32String("vat"));

            expect(await vat.live()).to.be.equal("1");
        });
        it('locks down and unlocks dog', async function () {
            await lock.initialize();

            await dog.initialize(vat.address);
            await dog.rely(lock.address);
            
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("dog"), dog.address);

            await lock.connect(deployer).lock(await ethers.utils.formatBytes32String("dog"));

            expect(await dog.live()).to.be.equal("0");

            await lock.connect(deployer).unlock(await ethers.utils.formatBytes32String("dog"));

            expect(await dog.live()).to.be.equal("1");
        });
        it('locks down and unlocks vow', async function () {
            await lock.initialize();

            await vow.initialize(vat.address, hayJoin.address, deployer.address);
            await vow.rely(lock.address);
            
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("vow"), vow.address);

            await lock.connect(deployer).lock(await ethers.utils.formatBytes32String("vow"));

            expect(await vow.live()).to.be.equal("0");

            await lock.connect(deployer).unlock(await ethers.utils.formatBytes32String("vow"));

            expect(await vow.live()).to.be.equal("1");
        });
        it('locks down and unlocks spot', async function () {
            await lock.initialize();

            await spot.initialize(vat.address);
            await spot.rely(lock.address);
            
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("spot"), spot.address);

            await lock.connect(deployer).lock(await ethers.utils.formatBytes32String("spot"));

            expect(await spot.live()).to.be.equal("0");

            await lock.connect(deployer).unlock(await ethers.utils.formatBytes32String("spot"));

            expect(await spot.live()).to.be.equal("1");
        });
        it('locks down and unlocks hayJoin', async function () {
            await lock.initialize();

            this.Hay = await ethers.getContractFactory("Hay");
            hay = await this.Hay.connect(deployer).deploy();
            await hay.deployed();
            await hay.initialize(97, "HAY", "100" + wad);

            await hayJoin.initialize(vat.address, hay.address);
            await hayJoin.rely(lock.address);
            
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("hayJoin"), hayJoin.address);

            await lock.connect(deployer).lock(await ethers.utils.formatBytes32String("hayJoin"));

            expect(await hayJoin.live()).to.be.equal("0");

            await lock.connect(deployer).unlock(await ethers.utils.formatBytes32String("hayJoin"));

            expect(await hayJoin.live()).to.be.equal("1");
        });
        it('locks down and unlocks helioToken', async function () {
            await lock.initialize();

            await helioToken.initialize("100" + wad, deployer.address);
            await helioToken.rely(lock.address);
            
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("helioToken"), helioToken.address);

            await lock.connect(deployer).lock(await ethers.utils.formatBytes32String("helioToken"));

            await lock.connect(deployer).unlock(await ethers.utils.formatBytes32String("helioToken"));
        });
        it('locks down and unlocks jar', async function () {
            await lock.initialize();

            this.Hay = await ethers.getContractFactory("Hay");
            hay = await this.Hay.connect(deployer).deploy();
            await hay.deployed();
            await hay.initialize(97, "HAY", "100" + wad);

            await jar.initialize("Helio Hay", "hHAY", hay.address, 10, 0, 5);
            await jar.rely(lock.address);
            
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("jar"), jar.address);

            await lock.connect(deployer).lock(await ethers.utils.formatBytes32String("jar"));

            expect(await jar.live()).to.be.equal("0");

            await lock.connect(deployer).unlock(await ethers.utils.formatBytes32String("jar"));

            expect(await jar.live()).to.be.equal("1");
        });
    });
    describe('--- lockExternals()/unlockExternals()', function () {
        it('reverts: Lock/not-live', async function () {
            await lock.initialize();
            await lock.cage();
            await expect(lock.connect(deployer).lockExternals()).to.be.revertedWith("Lock/not-live");
        });
        it('locks and unlocks all externals', async function () {
            await lock.initialize();

            await vat.initialize();
            await vat.rely(lock.address);
            await dog.initialize(vat.address);
            await dog.rely(lock.address);
            await vow.initialize(vat.address, hayJoin.address, deployer.address);
            await vow.rely(lock.address);
            await spot.initialize(vat.address);
            await spot.rely(lock.address);
            this.Hay = await ethers.getContractFactory("Hay");
            hay = await this.Hay.connect(deployer).deploy();
            await hay.deployed();
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await hayJoin.rely(lock.address);
            await helioToken.initialize("100" + wad, deployer.address);
            await helioToken.rely(lock.address);
            await jar.initialize("Helio Hay", "hHAY", hay.address, 10, 0, 5);
            await jar.rely(lock.address);

            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("vat"), vat.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("dog"), dog.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("vow"), vow.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("spot"), spot.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("hayJoin"), hayJoin.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("helioToken"), helioToken.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("jar"), jar.address);

            await lock.connect(deployer).lockExternals();

            expect(await vat.live()).to.be.equal("1");
            expect(await dog.live()).to.be.equal("1");
            expect(await vow.live()).to.be.equal("1");
            expect(await spot.live()).to.be.equal("1");
            expect(await hayJoin.live()).to.be.equal("1");
            expect(await jar.live()).to.be.equal("0");

            await lock.connect(deployer).unlockExternals();

            expect(await vat.live()).to.be.equal("1");
            expect(await dog.live()).to.be.equal("1");
            expect(await vow.live()).to.be.equal("1");
            expect(await spot.live()).to.be.equal("1");
            expect(await hayJoin.live()).to.be.equal("1");
            expect(await jar.live()).to.be.equal("1");
        });
    });
    describe('--- lockCore()', function () {
        it('reverts: Lock/not-live', async function () {
            await lock.initialize();
            await lock.cage();
            await expect(lock.connect(deployer).lockCore()).to.be.revertedWith("Lock/not-live");
        });
        it('locks and unlocks core', async function () {
            await lock.initialize();

            await vat.initialize();
            await vat.rely(lock.address);
            await dog.initialize(vat.address);
            await dog.rely(lock.address);
            await vow.initialize(vat.address, hayJoin.address, deployer.address);
            await vow.rely(lock.address);
            await spot.initialize(vat.address);
            await spot.rely(lock.address);
            this.Hay = await ethers.getContractFactory("Hay");
            hay = await this.Hay.connect(deployer).deploy();
            await hay.deployed();
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await hayJoin.rely(lock.address);
            await helioToken.initialize("100" + wad, deployer.address);
            await helioToken.rely(lock.address);
            await jar.initialize("Helio Hay", "hHAY", hay.address, 10, 0, 5);
            await jar.rely(lock.address);

            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("vat"), vat.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("dog"), dog.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("vow"), vow.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("spot"), spot.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("hayJoin"), hayJoin.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("helioToken"), helioToken.address);
            await lock.connect(deployer).file(await ethers.utils.formatBytes32String("jar"), jar.address);

            await lock.connect(deployer).lockCore();

            expect(await vat.live()).to.be.equal("0");
            expect(await dog.live()).to.be.equal("0");
            expect(await vow.live()).to.be.equal("0");
            expect(await spot.live()).to.be.equal("0");
            expect(await hayJoin.live()).to.be.equal("0");
            expect(await jar.live()).to.be.equal("1");

            await lock.connect(deployer).unlockCore();

            expect(await vat.live()).to.be.equal("1");
            expect(await dog.live()).to.be.equal("1");
            expect(await vow.live()).to.be.equal("1");
            expect(await spot.live()).to.be.equal("1");
            expect(await hayJoin.live()).to.be.equal("1");
            expect(await jar.live()).to.be.equal("1");
        });
    });
});