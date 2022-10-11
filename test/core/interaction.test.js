const { ethers, network } = require('hardhat');
const { expect } = require("chai");
const web3 = require('web3');

// To prevent duplicated function name warnings on console
ethers.utils.Logger.setLogLevel('off');

const {
    toWad,
    toRay,
    toRad,
    advanceTime,
    printSale,
  } = require("../helpers/utils");
const { constants } = require('@openzeppelin/test-helpers');
const BigNumber = ethers.BigNumber;
const toBN = web3.utils.toBN;
const toBytes32 = ethers.utils.formatBytes32String;

describe('===Interaction===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("ceABNBc");

    const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.Spot = await ethers.getContractFactory("Spotter");
        this.Vat = await ethers.getContractFactory("Vat");
        this.Oracle = await ethers.getContractFactory("Oracle");
        this.Hay = await ethers.getContractFactory("Hay");
        this.HayJoin = await ethers.getContractFactory("HayJoin");
        this.Vow = await ethers.getContractFactory("Vow");
        this.HelioRewards = await ethers.getContractFactory("HelioRewards");
        this.ABNBC = await ethers.getContractFactory("aBNBc");
        this.ABNBB = await ethers.getContractFactory("aBNBb");
        this.GemJoin = await ethers.getContractFactory("GemJoin");
        this.Clipper = await ethers.getContractFactory("Clipper");
        
        this.hBNB = await ethers.getContractFactory("hBNB");
        this.HelioProvider = await ethers.getContractFactory("HelioProvider");
        this.CeRouter = await ethers.getContractFactory("CerosRouter");
        this.CeToken = await ethers.getContractFactory("CeToken");
        this.BinancePool = await ethers.getContractFactory("BinancePool");
        this.Factory = await ethers.getContractFactory("PancakeFactory");
        this.wBNB = await ethers.getContractFactory("wBNB");
        wbnb = await this.wBNB.deploy();
        this.LinearDecrease = await ethers.getContractFactory("LinearDecrease");

        factory = await this.Factory.deploy(deployer.address);
        this.Router = await ethers.getContractFactory("PancakeRouter");
        dex = await this.Router.deploy(factory.address, wbnb.address);
        
        abacus = await this.LinearDecrease.connect(deployer).deploy();
        await abacus.deployed();
        await abacus.initialize();
        await abacus.connect(deployer).file(toBytes32("tau"), "1800");

        // Collateral module
        abnbc = await this.ABNBC.connect(deployer).deploy();
        await abnbc.deployed(); // Collateral
        ceabnbcJoin = await this.GemJoin.connect(deployer).deploy();
        await ceabnbcJoin.deployed();

        abnbb = await this.ABNBB.connect(deployer).deploy();
        await abnbb.deployed();
        await abnbb.initialize(deployer.address);

        await abnbc.initialize(constants.ZERO_ADDRESS, abnbb.address);
        await abnbb.changeABNBcToken(abnbc.address);
        // mint tokens
        await abnbc.mint(deployer.address, toBN(5e18).toString());
        await wbnb.mint(deployer.address, toBN(5e18).toString());
        // approve
        await abnbc.approve(dex.address, toBN(5e18).toString());
        await wbnb.approve(dex.address, toBN(5e18).toString());

        const reserve_0 = toBN('1000000000000000000');
        await dex.addLiquidityETH(
            abnbc.address, reserve_0.toString(), reserve_0.div(toBN(2)).toString(),
            reserve_0.toString(), deployer.address, 9999999999, { value: reserve_0.toString()});

        this.AuctionProxy = await ethers.getContractFactory("AuctionProxy");
        auctionProxy = await this.AuctionProxy.connect(deployer).deploy();
        await auctionProxy.deployed();

        this.Interaction = await ethers.getContractFactory("Interaction", {
            libraries: {
                AuctionProxy: auctionProxy.address
            }
        });
        this.Jug = await ethers.getContractFactory("Jug");
        this.Dog = await ethers.getContractFactory("Dog");

        // Contract deployment
        spot = await this.Spot.connect(deployer).deploy();
        await spot.deployed();
        vat = await this.Vat.connect(deployer).deploy();
        await vat.deployed();
        oracle = await this.Oracle.connect(deployer).deploy();
        await oracle.deployed();
        hay = await this.Hay.deploy();
        await hay.deployed();
        hayJoin = await this.HayJoin.deploy();
        await hayJoin.deployed();
        vow = await this.Vow.deploy();
        await vow.deployed();
        helioRewards = await this.HelioRewards.deploy();
        await helioRewards.deployed();
        interaction = await this.Interaction.deploy();
        await interaction.deployed();
        jug = await this.Jug.deploy();
        await jug.deployed();
        dog = await this.Dog.deploy();
        await dog.deployed();

        clip = await this.Clipper.connect(deployer).deploy();
        await clip.deployed();

        hbnb = await this.hBNB.connect(deployer).deploy();
        await hbnb.deployed();
        await hbnb.initialize();

        helioProvider = await this.HelioProvider.deploy();
        await helioProvider.deployed();
        ceRouter = await this.CeRouter.deploy();
        await ceRouter.deployed();
        

        ceToken = await this.CeToken.deploy();
        await ceToken.deployed();
        await ceToken.initialize('Ceros token', "ceAbnbc");
        
        binancePool = await this.BinancePool.deploy();
        await binancePool.deployed();
        
        await binancePool.initialize(deployer.address, signer1.address, 60 * 60);
        await binancePool.changeBondContract(abnbb.address);
        await abnbb.changeBinancePool(binancePool.address);
        await abnbb.changeABNBcToken(abnbc.address);
        await abnbb.changeSwapFeeParams(signer1.address, '10000000000000000');
        await binancePool.changeCertContract(abnbc.address);

        this.CeVault = await ethers.getContractFactory("CeVault");
        ceVault = await this.CeVault.deploy();
        await ceVault.initialize("CeVault", ceToken.address, abnbc.address);

        await ceToken.changeVault(ceVault.address);

        await ceRouter.initialize(abnbc.address, wbnb.address, ceToken.address, abnbb.address,
            ceVault.address, dex.address, binancePool.address);

        /* HProvider */
        await helioProvider.initialize(hbnb.address, abnbc.address, ceToken.address, ceRouter.address, interaction.address, binancePool.address);

        await ceRouter.changeProvider(helioProvider.address);
        await hbnb.changeMinter(helioProvider.address);
        await ceVault.changeRouter(ceRouter.address);
        // MINT aBNBc
        amount = toBN('10000000000020000000000');
        await abnbb.mintBonds(deployer.address, amount.mul(toBN(5)).toString());
        await abnbb.unlockSharesFor(deployer.address, amount.mul(toBN(2)).toString());

        await abnbb.mintBonds(signer1.address, amount.mul(toBN(5)).toString());
        await abnbb.unlockSharesFor(signer1.address, amount.mul(toBN(2)).toString());
        await abnbb.mintBonds(signer2.address, amount.mul(toBN(5)).toString());
        await abnbb.unlockSharesFor(signer2.address, amount.mul(toBN(2)).toString());

        await oracle.connect(deployer).setPrice(toWad("400"));
        
    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            expect(await interaction.vat()).to.be.equal(vat.address);
        });
    });
    describe('--- rely()', function () {
        it('reverts: Interaction/not-authorized', async function () {
            await expect(interaction.rely(signer1.address)).to.be.revertedWith("Interaction/not-authorized");
            expect(await interaction.wards(signer1.address)).to.be.equal("0");
        });
        it('relies on address', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await interaction.rely(signer1.address);
            expect(await interaction.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: Interaction/not-authorized', async function () {
            await expect(interaction.deny(signer1.address)).to.be.revertedWith("Interaction/not-authorized");
        });
        it('denies an address', async function () {

            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await interaction.rely(signer1.address);
            expect(await interaction.wards(signer1.address)).to.be.equal("1");
            await interaction.deny(signer1.address);
            expect(await interaction.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- enableWhitelist()', function() {
        it('reverts: Interaction/not-authorized', async function () {
            await expect(interaction.enableWhitelist()).to.be.revertedWith("Interaction/not-authorized");
        });
        it('enable whitelist mode', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await interaction.enableWhitelist();
            expect(await interaction.whitelistMode()).to.be.equal("1");
        })
    });
    describe('--- disableWhitelist()', function() {
        it('reverts: Interaction/not-authorized', async function () {
            await expect(interaction.disableWhitelist()).to.be.revertedWith("Interaction/not-authorized");
        });
        it('disable whitelist mode', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await interaction.disableWhitelist();
            expect(await interaction.whitelistMode()).to.be.equal("0");
        })
    });
    describe('--- setWhitelistOperator()', function() {
        it('reverts: Interaction/not-authorized', async function () {
            await expect(interaction.setWhitelistOperator(signer1.address)).to.be.revertedWith("Interaction/not-authorized");
        });
        it('set whitelist operator', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await interaction.setWhitelistOperator(signer1.address);
            expect(await interaction.whitelistOperator()).to.be.equal(signer1.address);
        })
    });
    describe('--- addToWhitelist()', function() {
        it('reverts: Interaction/not-operator-or-ward', async function () {
            await expect(interaction.addToWhitelist([signer1.address])).to.be.revertedWith("Interaction/not-operator-or-ward");
        });
        it('set whitelist operator', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await interaction.addToWhitelist([signer1.address]);
            expect(await interaction.whitelist(signer1.address)).to.be.equal("1");
        })
    });
    describe('--- removeFromWhitelist()', function() {
        it('reverts: Interaction/not-operator-or-ward', async function () {
            await expect(interaction.removeFromWhitelist([signer1.address])).to.be.revertedWith("Interaction/not-operator-or-ward");
        });
        it('set whitelist operator', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await interaction.addToWhitelist([signer1.address, signer2.address]);
            await interaction.removeFromWhitelist([signer1.address]);
            expect(await interaction.whitelist(signer1.address)).to.be.equal("0");
            expect(await interaction.whitelist(signer2.address)).to.be.equal("1");
        })
    });
    describe('--- setCores()', function() {
        it('set core addresses', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await interaction.setCores(vat.address, spot.address, hayJoin.address, jug.address);
            expect(await interaction.vat()).to.be.equal(vat.address);
        });
    });
    describe('--- setHayApprove()', function() {
        it('approve hayJoin to spend Hay', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await interaction.setHayApprove();
            expect(await hay.allowance(interaction.address, hayJoin.address)).to.be.equal(ethers.constants.MaxUint256);
        });
    });
    describe('--- setCollateralType()', function() {
        it('set collateral type', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await vat.rely(interaction.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));
        });
        it('reverts: Interaction/token-already-init', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await vat.rely(interaction.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            // await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));
            expect(interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"))).to.be.revertedWith("Interaction/token-already-init");
        });
    });
    describe('--- setCollateralDuty()', function() {
        it('reverts: Interaction/inactive collateral', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await vat.rely(interaction.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            // await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));
            expect(interaction.setCollateralDuty(ceToken.address, toRay("0.002"))).to.be.revertedWith("Interaction/inactive collateral");
        });
        it('set collateral duty', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));
            await interaction.setCollateralDuty(ceToken.address, toRay("2"));
            const [duty, ] = await jug.ilks(collateral);
            expect(duty).to.be.equal("2" + ray);
            // expect(interaction.setCollateralDuty(abnbc.address, toRay("0.002"))).to.be.revertedWith("Interaction/token-already-init");
        });
    });
    describe('--- removeCollateralType()', function() {
        it('remove collateral type', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));
            const res = await interaction.removeCollateralType(ceToken.address);
            const [gem, ilk, live, ] = await interaction.collaterals(ceToken.address);
            expect(live).to.be.equal(2);
            expect(await vat.wards(ceabnbcJoin.address)).to.be.equal(0);
            expect(res).to.emit(interaction, "CollateralDisabled");
        });
    });
    describe('--- removeBaseRate()', function() {
        it('remove base rate', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));
            const prevBase = await jug.base();
            await interaction.removeBaseRate(ceToken.address);
            expect(await jug.base()).to.be.equal(0);
            const [duty, rho] = await jug.ilks(collateral);
            expect(duty).to.be.equal(prevBase);
            // expect(rho).to.be.equal(Date.now());
        });
    });
    describe('--- setHelioProvider()', function() {
        it('set Helio provider for collateral', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await interaction.setHelioProvider(ceToken.address, helioRewards.address);
            expect(await interaction.helioProviders(ceToken.address)).to.be.equal(helioRewards.address);
        });
    });
    describe('--- deposit()', function() {
        it('deposit through HelioProvider with aBNBc', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));
            await interaction.setHelioProvider(ceToken.address, helioProvider.address);
            await abnbc.approve(ceRouter.address, "1" + wad);

            await helioProvider.provideInABNBc("1" + wad);
        });
    });
    describe('--- borrow()', function() {
        it('borrow HAY', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await hayJoin.rely(interaction.address);
            await hay.rely(hayJoin.address);
            await vat.rely(hayJoin.address);
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));

            await abnbc.approve(ceRouter.address, "10" + wad);
            await interaction.setHelioProvider(ceToken.address, helioProvider.address);
            await helioProvider.provideInABNBc("10" + wad);

            // set ceiling limit for collateral
            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            const borrowAmount = "1" + wad;
            await interaction.borrow(ceToken.address, borrowAmount);
            expect(await hay.balanceOf(deployer.address)).to.be.equal(borrowAmount);
        });
    });
    describe('--- payback()', function() {
        it('payback borrowed hay', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await hayJoin.rely(interaction.address);
            await hay.rely(hayJoin.address);
            await vat.rely(hayJoin.address);
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));

            await abnbc.approve(ceRouter.address, "10" + wad);
            await interaction.setHelioProvider(ceToken.address, helioProvider.address);
            await helioProvider.provideInABNBc("10" + wad);

            // set ceiling limit for collateral
            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            const borrowAmount = "7" + wad;
            await interaction.borrow(ceToken.address, borrowAmount);
            expect(await hay.balanceOf(deployer.address)).to.be.equal(borrowAmount);
            
            const paidBackAmount = "5" + wad;
            await hay.approve(interaction.address, paidBackAmount);
            await interaction.payback(ceToken.address, paidBackAmount);
            expect(await hay.balanceOf(deployer.address)).to.be.equal("2" + wad);
        });
    });
    describe('--- withdraw()', function() {
        it('withdraw collateral via HelioProvider', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));

            await abnbc.approve(ceRouter.address, "1" + wad);
            const beforeBalance = await abnbc.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.address, helioProvider.address);
            await helioProvider.provideInABNBc("1" + wad);
            expect(await abnbc.balanceOf(deployer.address)).to.be.equal(beforeBalance.sub(toWad("1")));
            const afterBalance = await abnbc.balanceOf(deployer.address);
            
            await helioProvider.releaseInABNBc(deployer.address, "1" + wad);
            expect(await abnbc.balanceOf(deployer.address)).to.be.equal(afterBalance.add(toWad("1")));
        });
    });
    describe('--- stringToBytes32()', function() {
        it('return bytes32 for string', async function() {
            const tempString = "aBNBc";
            expect(await interaction.stringToBytes32(tempString)).to.be.equal(toBytes32(tempString));
        });
    });
    describe('--- drip()', function() {
        it('update vow surplus', async function () {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await hayJoin.rely(interaction.address);
            await hay.rely(hayJoin.address);
            await vat.rely(hayJoin.address);
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));

            await abnbc.approve(ceRouter.address, "10" + wad);
            const beforeBalance = await abnbc.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.address, helioProvider.address);
            await helioProvider.provideInABNBc("10" + wad);

            // await interaction.drip(ceToken.address);
            // await jug["file(bytes32,bytes32,uint256)"](collateral, toBytes32("duty"), toRay("0.00002"));
            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.address);
            // expect(await abnbc.balanceOf(deployer.address)).to.be.equal(beforeBalance.sub(toWad("1")));
            // const afterBalance = await abnbc.balanceOf(deployer.address);
            
            // await helioProvider.releaseInABNBc(deployer.address, "1" + wad);
            // expect(await abnbc.balanceOf(deployer.address)).to.be.equal(afterBalance.add(toWad("1")));

            // set ceiling limit for collateral
            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            const borrowAmount = "7" + wad;
            await interaction.borrow(ceToken.address, borrowAmount);

            const beforeHayBalance = await vat.hay(vow.address);
            await advanceTime(60);
            await interaction.drip(ceToken.address);
            const afterHayBalance = await vat.hay(vow.address);

            expect(beforeHayBalance).to.be.equal(0);
            expect(afterHayBalance).to.be.gt(0);
        });
    });
    describe('--- poke()', function() {
        it('poke collateral price', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await hayJoin.rely(interaction.address);
            await hay.rely(hayJoin.address);
            await vat.rely(hayJoin.address);
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await vat.rely(spot.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));

            await abnbc.approve(ceRouter.address, "10" + wad);
            const beforeBalance = await abnbc.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.address, helioProvider.address);
            await helioProvider.provideInABNBc("10" + wad);

            await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, toBytes32("pip"), oracle.address);
            await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral,toBytes32("mat"),"1250000000000000000000000000");
            await spot["file(bytes32,uint256)"](toBytes32("par"), toRay("1")); // It means pegged to 1$

            const [,,beforeSpot,,] = await vat.ilks(collateral);

            const res = await interaction.poke(ceToken.address);
            expect(res).to.emit(interaction, "Poke");

            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.address);

            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            const borrowAmount = "1" + wad;
            await interaction.borrow(ceToken.address, borrowAmount);

            await advanceTime(60);
            await interaction.drip(ceToken.address);

            const [,,afterSpot,,] = await vat.ilks(collateral);
            expect(afterSpot).to.be.not.equal(beforeSpot);
        });
    });
    describe('--- read states via view functions', function() {
        it('read prices and collateral states', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await hayJoin.rely(interaction.address);
            await hay.rely(hayJoin.address);
            await vat.rely(hayJoin.address);
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await vat.rely(spot.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));

            await abnbc.approve(ceRouter.address, "10" + wad);
            const beforeBalance = await abnbc.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.address, helioProvider.address);
            await helioProvider.provideInABNBc("10" + wad);

            await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, toBytes32("pip"), oracle.address);
            await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral,toBytes32("mat"),"1250000000000000000000000000");
            await spot["file(bytes32,uint256)"](toBytes32("par"), toRay("1")); // It means pegged to 1$

            const res = await interaction.poke(ceToken.address);
            expect(res).to.emit(interaction, "Poke");

            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.address);

            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));

            const borrowAmount = "1" + wad;
            await interaction.borrow(ceToken.address, borrowAmount);

            await advanceTime(60);
            await interaction.drip(ceToken.address);

            // Read states via view functions
            expect(await interaction.collateralPrice(ceToken.address)).to.be.equal(toWad("400"));
            const [,rate,,,] = await vat.ilks(collateral);
            expect(await interaction.hayPrice(ceToken.address)).to.be.equal(rate.div(BigNumber.from(1000000000)));
            expect(await interaction.collateralRate(ceToken.address)).to.be.equal(toWad("0.8")); // 0.8 = 1 / 1.25
            expect(await interaction.depositTVL(ceToken.address)).to.be.equal(toWad("4000")); // 10 * 400 in $
            const collateralTVL = await interaction.collateralTVL(ceToken.address);
            expect(await interaction.free(ceToken.address, deployer.address)).to.be.equal(0);
            expect(await interaction.locked(ceToken.address, deployer.address)).to.be.equal(toWad("10"));
            expect(await interaction.borrowed(ceToken.address, deployer.address)).to.be.equal(collateralTVL);
            
            expect(await interaction.availableToBorrow(ceToken.address, deployer.address)).to.be.equal(BigNumber.from("6999999877999992679"));
            expect(await interaction.willBorrow(ceToken.address, deployer.address, toWad("1"))).to.be.equal(BigNumber.from("7799999877999992679"));
            expect(await interaction.currentLiquidationPrice(ceToken.address, deployer.address)).to.be.equal(BigNumber.from("125000015250000000"));
            expect(await interaction.estimatedLiquidationPrice(ceToken.address, deployer.address, toWad("1"))).to.be.equal(BigNumber.from("113636377500000000"));
            expect(await interaction.estimatedLiquidationPriceHAY(ceToken.address, deployer.address, toWad("1"))).to.be.equal(BigNumber.from("125000000125000015"));
            expect(await interaction.borrowApr(ceToken.address)).to.be.equal(BigNumber.from("6514815689033158807"));
        });
    });
    describe('--- Auction Scenario', function() {
        it('auction should be started and bought as expected', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100000" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await hayJoin.rely(interaction.address);
            await hay.rely(hayJoin.address);
            await vat.rely(hayJoin.address);
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await vat.rely(spot.address);
            await vat.rely(dog.address);
            await vat.rely(clip.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));

            await helioProvider.changeProxy(interaction.address);
            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.address);

            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("dust"), toRad("1"));

            await dog.rely(clip.address);
            await dog.rely(interaction.address);
            await dog["file(bytes32,address)"](toBytes32("vow"), vow.address);
            await dog["file(bytes32,uint256)"](toBytes32("Hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("chop"), toWad("1.13"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,address)"](collateral, toBytes32("clip"), clip.address);

            await clip.connect(deployer).rely(dog.address);
            await clip
                .connect(deployer)
                ["file(bytes32,uint256)"](toBytes32("buf"), toRay("1.2"));
            await clip
                .connect(deployer)
                ["file(bytes32,uint256)"](toBytes32("tail"), "1800");
            await clip
                .connect(deployer)
                ["file(bytes32,uint256)"](toBytes32("cusp"), toRay("0.3"));
            await clip
                .connect(deployer)
                ["file(bytes32,uint256)"](toBytes32("chip"), toWad("0.02"));
            await clip
                .connect(deployer)
                ["file(bytes32,uint256)"](toBytes32("tip"), toRad("100"));

            await clip
                .connect(deployer)
                ["file(bytes32,address)"](toBytes32("vow"), vow.address);
            await clip
                .connect(deployer)
                ["file(bytes32,address)"](toBytes32("calc"), abacus.address);

            clip.rely(interaction.address);

            await abnbc.approve(ceRouter.address, "10" + wad);
            const beforeBalance = await abnbc.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.address, helioProvider.address);
            await helioProvider.provideInABNBc("10" + wad);

            await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, toBytes32("pip"), oracle.address);
            await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral,toBytes32("mat"),"1250000000000000000000000000");
            await spot["file(bytes32,uint256)"](toBytes32("par"), toRay("1")); // It means pegged to 1$

            const res = await interaction.poke(ceToken.address);
            expect(res).to.emit(interaction, "Poke");

            const borrowAmount = "1000" + wad;
            await interaction.borrow(ceToken.address, borrowAmount);

            await oracle.connect(deployer).setPrice(toWad("120"));
            await interaction.poke(ceToken.address);

            await interaction.connect(deployer).startAuction(ceToken.address, deployer.address, signer1.address);

            const sale = await clip.sales(1);
            expect(sale.usr).to.not.be.equal(ethers.utils.AddressZero);

            const dink = toWad("1000");
            await abnbc.connect(signer1).approve(ceRouter.address, "1000" + wad);
            await abnbc.connect(signer2).approve(ceRouter.address, "1000" + wad);
            await helioProvider.connect(signer1).provideInABNBc(dink);
            await helioProvider.connect(signer2).provideInABNBc(dink);

            const dart = "5000" + wad;
            await interaction.connect(signer1).borrow(ceToken.address, dart);
            await interaction.connect(signer2).borrow(ceToken.address, dart);
            
            await vat.connect(signer1).hope(clip.address);
            await vat.connect(signer2).hope(clip.address);

            await hay.connect(signer1).approve(interaction.address, toWad("701"));
            await hay.connect(signer2).approve(interaction.address, toWad("1001"));

            // await advanceTime(2000); // If time spent too much, auction needs reset
            // await advanceTime(10); // Too expensive means your propased price is still not available for auction decrease price
            await advanceTime(1000);

            const abnbcSigner1BalanceBefore = await abnbc.balanceOf(signer1.address);
            const abnbcSigner2BalanceBefore = await abnbc.balanceOf(signer2.address);
            
            await interaction.connect(signer1).buyFromAuction(
                ceToken.address,
                1,
                toWad("7"),
                toRay("100"),
                signer1.address,
                []
            );

            await interaction.connect(signer2).buyFromAuction(
                ceToken.address,
                1,
                toWad("10"),
                toRay("100"),
                signer2.address,
                []
            );
            
            const abnbcSigner1BalanceAfter = await abnbc.balanceOf(signer1.address);
            const abnbcSigner2BalanceAfter = await abnbc.balanceOf(signer2.address);

            expect(abnbcSigner1BalanceAfter.sub(abnbcSigner1BalanceBefore)).to.be.equal(toWad("7"));
            expect(abnbcSigner2BalanceAfter.sub(abnbcSigner2BalanceBefore)).to.be.equal(toWad("3"));

            const saleAfter = await clip.sales(1);
            expect(saleAfter.pos).to.equal(0);
            expect(saleAfter.tab).to.equal(0);
            expect(saleAfter.lot).to.equal(0);
            expect(saleAfter.tic).to.equal(0);
            expect(saleAfter.top).to.equal(0);
            expect(saleAfter.usr).to.equal(ethers.constants.AddressZero);

            const [status,,,] = await interaction.getAuctionStatus(ceToken.address, 1);
            expect(status).to.be.equal(false);

            const allActiveAuctions = await interaction.getAllActiveAuctionsForToken(ceToken.address);
            expect(allActiveAuctions.length).to.be.equal(0);
        });
        it('--- resetAuction()', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100000" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await hayJoin.rely(interaction.address);
            await hay.rely(hayJoin.address);
            await vat.rely(hayJoin.address);
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await vat.rely(spot.address);
            await vat.rely(dog.address);
            await vat.rely(clip.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));

            await helioProvider.changeProxy(interaction.address);
            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.address);

            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("dust"), toRad("1"));

            await dog.rely(clip.address);
            await dog.rely(interaction.address);
            await dog["file(bytes32,address)"](toBytes32("vow"), vow.address);
            await dog["file(bytes32,uint256)"](toBytes32("Hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("chop"), toWad("1.13"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,address)"](collateral, toBytes32("clip"), clip.address);

            await clip.connect(deployer).rely(dog.address);
            await clip
                .connect(deployer)
                ["file(bytes32,uint256)"](toBytes32("buf"), toRay("1.2"));
            await clip
                .connect(deployer)
                ["file(bytes32,uint256)"](toBytes32("tail"), "1800");
            await clip
                .connect(deployer)
                ["file(bytes32,uint256)"](toBytes32("cusp"), toRay("0.3"));
            await clip
                .connect(deployer)
                ["file(bytes32,uint256)"](toBytes32("chip"), toWad("0.02"));
            await clip
                .connect(deployer)
                ["file(bytes32,uint256)"](toBytes32("tip"), toRad("100"));

            await clip
                .connect(deployer)
                ["file(bytes32,address)"](toBytes32("vow"), vow.address);
            await clip
                .connect(deployer)
                ["file(bytes32,address)"](toBytes32("calc"), abacus.address);

            clip.rely(interaction.address);

            await abnbc.approve(ceRouter.address, "10" + wad);
            const beforeBalance = await abnbc.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.address, helioProvider.address);
            await helioProvider.provideInABNBc("10" + wad);

            await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, toBytes32("pip"), oracle.address);
            await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral,toBytes32("mat"),"1250000000000000000000000000");
            await spot["file(bytes32,uint256)"](toBytes32("par"), toRay("1")); // It means pegged to 1$

            const res = await interaction.poke(ceToken.address);
            expect(res).to.emit(interaction, "Poke");

            const borrowAmount = "1000" + wad;
            await interaction.borrow(ceToken.address, borrowAmount);

            await oracle.connect(deployer).setPrice(toWad("120"));
            await interaction.poke(ceToken.address);

            await interaction.connect(deployer).startAuction(ceToken.address, deployer.address, signer1.address);

            const sale = await clip.sales(1);
            expect(sale.usr).to.not.be.equal(ethers.utils.AddressZero);

            const dink = toWad("1000");
            await abnbc.connect(signer1).approve(ceRouter.address, "1000" + wad);
            await abnbc.connect(signer2).approve(ceRouter.address, "1000" + wad);
            await helioProvider.connect(signer1).provideInABNBc(dink);
            await helioProvider.connect(signer2).provideInABNBc(dink);

            const dart = "5000" + wad;
            await interaction.connect(signer1).borrow(ceToken.address, dart);
            await interaction.connect(signer2).borrow(ceToken.address, dart);
            
            await vat.connect(signer1).hope(clip.address);
            await vat.connect(signer2).hope(clip.address);

            await hay.connect(signer1).approve(interaction.address, toWad("701"));
            await hay.connect(signer2).approve(interaction.address, toWad("1001"));

            // await advanceTime(2000); // If time spent too much, auction needs reset
            // await advanceTime(10); // Too expensive means your propased price is still not available for auction decrease price
            await advanceTime(2000);

            const reset = await interaction.resetAuction(ceToken.address, 1, deployer.address); 
            expect(reset).emit(interaction, "Redo");
        });
    });
    describe('--- upchostClipper()', function() {
        it('refresh chost for collateral', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100000" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await hayJoin.rely(interaction.address);
            await hay.rely(hayJoin.address);
            await vat.rely(hayJoin.address);
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await vat.rely(spot.address);
            await vat.rely(dog.address);
            await vat.rely(clip.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));

            // await helioProvider.changeProxy(interaction.address);

            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.address);

            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("dust"), toRad("1"));

            await dog.rely(clip.address);
            await dog.rely(interaction.address);
            await dog["file(bytes32,address)"](toBytes32("vow"), vow.address);
            await dog["file(bytes32,uint256)"](toBytes32("Hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("chop"), toWad("1.13"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,address)"](collateral, toBytes32("clip"), clip.address);
            
            const before = await clip.chost();
            await interaction.upchostClipper(ceToken.address);
            const after = await clip.chost();
            expect(after).be.not.equal(before);
        });
    });
    describe('--- totalPegLiquidity()', function() {
        it('read total supply of hay', async function() {
            await vat.initialize();
            await spot.initialize(vat.address);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.address, hay.address);
            await jug.initialize(vat.address);
            await dog.initialize(vat.address);
            await clip.initialize(vat.address, spot.address, dog.address, collateral);
            await ceabnbcJoin.initialize(vat.address, collateral, ceToken.address);
            await helioRewards.initialize(vat.address, "100" + wad);
            await interaction.initialize(vat.address, spot.address, hay.address, hayJoin.address, jug.address, dog.address, helioRewards.address);
            
            await hayJoin.rely(interaction.address);
            await hay.rely(hayJoin.address);
            await vat.rely(hayJoin.address);
            await vat.rely(interaction.address);
            await vat.rely(jug.address);
            await jug.rely(interaction.address);
            await spot.rely(interaction.address);
            await ceabnbcJoin.rely(interaction.address);
            await interaction.setCollateralType(ceToken.address, ceabnbcJoin.address, collateral, clip.address, toRay("0.75"));

            await abnbc.approve(ceRouter.address, "10" + wad);
            await interaction.setHelioProvider(ceToken.address, helioProvider.address);
            await helioProvider.provideInABNBc("10" + wad);

            // set ceiling limit for collateral
            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            const borrowAmount = "1" + wad;
            await interaction.borrow(ceToken.address, borrowAmount);

            const res = await interaction.totalPegLiquidity();
            expect(res).to.be.equal(borrowAmount);
        });
    });
});