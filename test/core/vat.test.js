const { ethers, network } = require('hardhat');
const { expect } = require("chai");

describe('===Vat===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("TEST");

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.Vat = await ethers.getContractFactory("Vat");

        // Contract deployment
        vat = await this.Vat.connect(deployer).deploy();
        await vat.deployed();
    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            expect(await vat.live()).to.be.equal("0");
            await vat.initialize();
            expect(await vat.live()).to.be.equal("1");
        });
    });
    describe('--- rely()', function () {
        it('reverts: Vat/not-authorized', async function () {
            await expect(vat.rely(signer1.address)).to.be.revertedWith("Vat/not-authorized");
            expect(await vat.wards(signer1.address)).to.be.equal("0");
        });
        it('reverts: Vat/not-live', async function () {
            await vat.initialize();
            await vat.cage();
            await expect(vat.rely(signer1.address)).to.be.revertedWith("Vat/not-live");
            expect(await vat.wards(signer1.address)).to.be.equal("0");
        });
        it('relies on address', async function () {
            await vat.initialize();
            await vat.rely(signer1.address);
            expect(await vat.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: Vat/not-authorized', async function () {
            await expect(vat.deny(signer1.address)).to.be.revertedWith("Vat/not-authorized");
        });
        it('reverts: Vat/not-live', async function () {
            await vat.initialize();
            await vat.cage();
            await expect(vat.deny(signer1.address)).to.be.revertedWith("Vat/not-live");
        });
        it('denies an address', async function () {
            await vat.initialize();
            await vat.rely(signer1.address);
            expect(await vat.wards(signer1.address)).to.be.equal("1");
            await vat.deny(signer1.address);
            expect(await vat.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- behalf()', function () {
        it('reverts: Vat/not-authorized', async function () {
            await expect(vat.behalf(signer1.address, signer2.address)).to.be.revertedWith("Vat/not-authorized");
        });
        it('behalfs an address', async function () {
            await vat.initialize();
            expect(await vat.can(signer1.address, signer2.address)).to.be.equal("0");
            await vat.behalf(signer1.address, signer2.address);
            expect(await vat.can(signer1.address, signer2.address)).to.be.equal("1");
        });
    });
    describe('--- regard()', function () {
        it('reverts: Vat/not-authorized', async function () {
            await expect(vat.behalf(signer1.address, signer2.address)).to.be.revertedWith("Vat/not-authorized");
        });
        it('regards an address', async function () {
            await vat.initialize();
            await vat.behalf(signer1.address, signer2.address);
            expect(await vat.can(signer1.address, signer2.address)).to.be.equal("1");
            await vat.regard(signer1.address, signer2.address);
            expect(await vat.can(signer1.address, signer2.address)).to.be.equal("0");
        });
    });
    describe('--- hope()', function () {
        it('hopes on address', async function () {
            expect(await vat.can(deployer.address, signer1.address)).to.be.equal("0");
            await vat.hope(signer1.address);
            expect(await vat.can(deployer.address, signer1.address)).to.be.equal("1");
        });
    });
    describe('--- nope()', function () {
        it('nopes on address', async function () {
            await vat.hope(signer1.address);
            expect(await vat.can(deployer.address, signer1.address)).to.be.equal("1");
            await vat.nope(signer1.address);
            expect(await vat.can(deployer.address, signer1.address)).to.be.equal("0");
        });
    });
    describe('--- wish()', function () {
        it('bit == usr', async function () {
            await vat.hope(signer1.address);
            expect(await vat.can(deployer.address, signer1.address)).to.be.equal("1");
            await vat.nope(signer1.address);
            expect(await vat.can(deployer.address, signer1.address)).to.be.equal("0");
        });
        it('can[bit][usr] == 1', async function () {
            await vat.hope(signer1.address);
            expect(await vat.can(deployer.address, signer1.address)).to.be.equal("1");
            await vat.nope(signer1.address);
            expect(await vat.can(deployer.address, signer1.address)).to.be.equal("0");
        });
    });
    describe('--- init()', function () {
        it('reverts: Vat/ilk-already-init', async function () {
            await vat.initialize();
            await vat.init(collateral);
            await expect(vat.init(collateral)).to.be.revertedWith("Vat/ilk-already-init");
        });
        it('initialize a new ilk', async function () {
            await vat.initialize();
            await vat.init(collateral);
            expect(await vat.ilks(collateral)).to.not.be.equal("0");
        });
    });
    describe('--- file(2)', function () {
        it('reverts: Vat/not-live', async function () {
            await vat.initialize();
            await vat.cage();
            await expect(vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "100" + rad)).to.be.revertedWith("Vat/not-live");
        });
        it('reverts: Vat/file-unrecognized-param', async function () {
            await vat.initialize();
            await expect(vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Lined"), "100" + rad)).to.be.revertedWith("Vat/file-unrecognized-param");
        });
        it('sets Line', async function () {
            await vat.initialize();
            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "100" + rad);
            expect(await vat.Line()).to.be.equal("100" + rad);
        });
    });
    describe('--- file(3)', function () {
        it('reverts: Vat/not-live', async function () {
            await vat.initialize();
            await vat.cage();
            await expect(vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("Line"), "100" + rad)).to.be.revertedWith("Vat/not-live");
        });
        it('reverts: Vat/file-unrecognized-param', async function () {
            await vat.initialize();
            await expect(vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("Lined"), "100" + rad)).to.be.revertedWith("Vat/file-unrecognized-param");
        });
        it('sets spot', async function () {
            await vat.initialize();
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);
            expect(await (await vat.ilks(collateral)).spot).to.be.equal("100" + ray);
        });
        it('sets line', async function () {
            await vat.initialize();
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "100" + rad);        
            expect(await (await vat.ilks(collateral)).line).to.be.equal("100" + rad);
        });
        it('sets dust', async function () {
            await vat.initialize();
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "100" + rad);        
            expect(await (await vat.ilks(collateral)).dust).to.be.equal("100" + rad);
        });
    });
    describe('--- slip()', function () {
        it('slips an amount', async function () {
            await vat.initialize();
            await vat.slip(collateral, signer1.address, "10" + wad);
            expect(await vat.gem(collateral, signer1.address)).to.be.equal("10" + wad);
        });
    });
    describe('--- flux()', function () {
        it('reverts: Vat/not-allowed', async function () {
            await vat.initialize();
            await vat.slip(collateral, signer1.address, "10" + wad);
            await expect(vat.flux(collateral, signer1.address, signer2.address, "10" + wad)).to.be.revertedWith("Vat/not-allowed");
        });
        it('flux an amount', async function () {
            await vat.initialize();
            await vat.slip(collateral, deployer.address, "10" + wad);
            await vat.flux(collateral, deployer.address, signer1.address, "10" + wad);
            expect(await vat.gem(collateral, signer1.address)).to.be.equal("10" + wad);
        });
    });
    describe('--- move()', function () {
        it('reverts: Vat/not-allowed', async function () {
            await vat.initialize();
            await expect(vat.move(signer1.address, signer2.address, 0)).to.be.revertedWith("Vat/not-allowed");
        });
        it('flux an amount', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);

            await vat.slip(collateral, deployer.address, "1" + wad);

            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, 0, "15" + wad);

            await vat.move(deployer.address, signer1.address, "1" + rad);
            expect(await vat.hay(signer1.address)).to.be.equal("1" + rad);
        });
    });
    describe('--- frob()', function () {
        it('reverts: Vat/not-allowed', async function () {
            await vat.initialize();
            await vat.cage();
            await expect(vat.frob(collateral, deployer.address, deployer.address, deployer.address, 0, 0)).to.be.revertedWith("Vat/not-live");
        });
        it('reverts: Vat/ilk-not-init', async function () {
            await vat.initialize();
            await expect(vat.frob(collateral, deployer.address, deployer.address, deployer.address, 0, 0)).to.be.revertedWith("Vat/ilk-not-init");
        });
        it('reverts: Vat/ceiling-exceeded', async function () {
            await vat.initialize();
            await vat.init(collateral);
            await expect(vat.frob(collateral, deployer.address, deployer.address, deployer.address, 0, 1)).to.be.revertedWith("Vat/ceiling-exceeded");
        });
        it('reverts: Vat/not-safe', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);        

            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "1" + ray);
            await vat.slip(collateral, deployer.address, "1" + wad);
            await vat.frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            expect(await (await vat.urns(collateral, deployer.address)).ink).to.be.equal("1" + wad);

            await expect(vat.frob(collateral, deployer.address, deployer.address, deployer.address, 0, "199" + wad)).to.be.revertedWith("Vat/not-safe");
        });
        it('reverts: Vat/not-allowed-u', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);        

            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);
            await vat.slip(collateral, signer1.address, "1" + wad);
            await vat.rely(signer1.address);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, "1" + wad, 0);
            await expect(vat.frob(collateral, signer1.address, signer1.address, signer1.address, -1, 0)).to.be.revertedWith("Vat/not-allowed-u");
        });
        it('reverts: Vat/not-allowed-v', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);        

            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);
            await vat.slip(collateral, signer1.address, "1" + wad);
            await vat.rely(signer1.address);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, "1" + wad, 0);
            await expect(vat.frob(collateral, signer1.address, signer1.address, signer1.address, 10, 0)).to.be.revertedWith("Vat/not-allowed-v");
        });
        it('reverts: Vat/not-allowed-w', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);        

            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);
            await vat.slip(collateral, signer1.address, "1" + wad);
            await vat.rely(signer1.address);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, "1" + wad, 0);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, "10" + wad);
            await expect(vat.frob(collateral, signer1.address, signer1.address, signer1.address, 0, "-1000000000000000000")).to.be.revertedWith("Vat/not-allowed-w");
        });
        it('reverts: Vat/dust', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "100" + rad);              

            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);
            await vat.slip(collateral, signer1.address, "1" + wad);
            await vat.rely(signer1.address);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, "1" + wad, 0);
            await expect(vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, "10" + wad)).to.be.revertedWith("Vat/dust");
        });
        it('frobs collateral and frobs stablecoin', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);

            await vat.slip(collateral, signer1.address, "1" + wad);

            await vat.rely(signer1.address);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, "1" + wad, 0);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, "20" + wad);
            expect(await (await vat.urns(collateral, signer1.address)).ink).to.be.equal("1" + wad);
            expect(await vat.hay(signer1.address)).to.be.equal("20" + rad);
        });
    });
    describe('--- fork()', function () {
        it('reverts: Vat/not-allowed', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);

            await vat.slip(collateral, deployer.address, "1" + wad);
            await vat.slip(collateral, signer1.address, "1" + wad);

            await vat.rely(signer1.address);

            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, 0, "50" + wad);

            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, "1" + wad, 0);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, "50" + wad);

            await expect(vat.fork(collateral, deployer.address, signer1.address, 0, "10" + wad)).to.be.revertedWith("Vat/not-allowed");

        });
        it('reverts: Vat/not-safe-src Vat/not-safe-dst', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);

            await vat.slip(collateral, deployer.address, "1" + wad);
            await vat.slip(collateral, signer1.address, "1" + wad);

            await vat.rely(signer1.address);

            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, 0, "30" + wad);

            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, "1" + wad, 0);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, "80" + wad);
            
            await vat.connect(deployer).hope(signer1.address);
            await vat.connect(signer1).hope(deployer.address);

            await expect(vat.fork(collateral, deployer.address, signer1.address, "1" + wad, 0)).to.be.revertedWith("Vat/not-safe-src");
            await expect(vat.fork(collateral, deployer.address, signer1.address, 0, "30" + wad)).to.be.revertedWith("Vat/not-safe-dst");
        });
        it('reverts: Vat/dust-src Vat/dust-dst', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);

            await vat.slip(collateral, deployer.address, "1" + wad);
            await vat.slip(collateral, signer1.address, "1" + wad);

            await vat.rely(signer1.address);

            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, 0, "15" + wad);

            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, "1" + wad, 0);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, "15" + wad);
            
            await vat.connect(deployer).hope(signer1.address);
            await vat.connect(signer1).hope(deployer.address);

            await expect(vat.fork(collateral, deployer.address, signer1.address, 0, "10" + wad)).to.be.revertedWith("Vat/dust-src");
            await expect(vat.fork(collateral, deployer.address, signer1.address, 0, "-10" + wad)).to.be.revertedWith("Vat/dust-dst");
        });
        it('forks between two addresses', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);

            await vat.slip(collateral, deployer.address, "1" + wad);
            await vat.slip(collateral, signer1.address, "1" + wad);

            await vat.rely(signer1.address);

            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, 0, "15" + wad);

            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, "1" + wad, 0);
            await vat.connect(signer1).frob(collateral, signer1.address, signer1.address, signer1.address, 0, "15" + wad);
            
            await vat.connect(deployer).hope(signer1.address);
            await vat.connect(signer1).hope(deployer.address);

            await vat.fork(collateral, deployer.address, signer1.address, 0, "1" + wad);
            expect(await (await vat.urns(collateral, deployer.address)).art).to.be.equal("14" + wad);
        });
    });
    describe('--- grab()', function () {
        it('grabs ink and art of an address', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.connect(deployer)["file(bytes32,uint256)"](await ethers.utils.formatBytes32String("Line"), "200" + rad);
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("line"), "200" + rad);  
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("dust"), "10" + rad);              
            await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, await ethers.utils.formatBytes32String("spot"), "100" + ray);

            await vat.slip(collateral, deployer.address, "1" + wad);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, "1" + wad, 0);
            await vat.connect(deployer).frob(collateral, deployer.address, deployer.address, deployer.address, 0, "15" + wad);

            await vat.rely(signer1.address);

            await vat.connect(signer1).grab(collateral, deployer.address, deployer.address, deployer.address, "-1" + wad, "-15" + wad);
            expect(await (await vat.urns(collateral, deployer.address)).art).to.be.equal(0);
            expect(await vat.vice()).to.be.equal("15" + rad);
        });
    });
    describe('--- suck()', function () {
        it('sucks more hay for an address for sin on another', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.suck(deployer.address, signer1.address, "10" + rad);
            expect(await vat.hay(signer1.address)).to.be.equal("10" + rad);
            expect(await vat.vice()).to.be.equal("10" + rad);
        });
    });
    describe('--- heal()', function () {
        it('heals sin of a caller', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.suck(deployer.address, deployer.address, "10" + rad);
            expect(await vat.hay(deployer.address)).to.be.equal("10" + rad);
            expect(await vat.vice()).to.be.equal("10" + rad);

            await vat.heal("10" + rad);
            expect(await vat.hay(signer1.address)).to.be.equal(0);
            expect(await vat.vice()).to.be.equal(0);
        });
    });
    describe('--- fold()', function () {
        it('reverts: Vat/not-live', async function () {
            await vat.initialize();
            await vat.cage();

            await expect(vat.fold(collateral, deployer.address, "1" + ray)).to.be.revertedWith("Vat/not-live");;
        });
        it('reverts: Vat/not-live', async function () {
            await vat.initialize();
            await vat.init(collateral);

            await vat.fold(collateral, deployer.address, "1" + ray);
            expect(await (await vat.ilks(collateral)).rate).to.be.equal("2" + ray);
        });
    });
});