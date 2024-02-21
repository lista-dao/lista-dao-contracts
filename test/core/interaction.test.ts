import { ethers, network } from 'hardhat';
import { expect } from "chai";
//import { smock } from '@defi-wonderland/smock';

// To prevent duplicated function name warnings on console
//ethers.utils.Logger.setLogLevel('off');

import {
    toWad,
    toRay,
    toRad,
    advanceTime,
    printSale,
  } from "../helpers/utils";
const toBytes32 = ethers.encodeBytes32String;

describe('===Interaction===', function () {
    let deployer, signer1, signer2;
    let wbnb, factory, dex, abacus, abnbc, ceabnbcJoin, abnbb, auctionProxy, spot, vat, vow, oracle, hay, hayJoin, jug, dog, clip, helioRewards, interaction, hbnb, helioProvider, ceRouter, ceToken, binancePool, ceVault, stakingPool;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = toBytes32("ceABNBc");

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
        this.StakingPool = await ethers.getContractFactory("StakingPool");
        this.Factory = await ethers.getContractFactory("PancakeFactory");
        this.wBNB = await ethers.getContractFactory("wBNB");
        wbnb = await this.wBNB.deploy();
        this.LinearDecrease = await ethers.getContractFactory("LinearDecrease");

        factory = await this.Factory.deploy(deployer.address);
        this.Router = await ethers.getContractFactory("PancakeRouter");
        dex = await this.Router.deploy(factory.target, wbnb.target);

        abacus = await this.LinearDecrease.connect(deployer).deploy();
        await abacus.waitForDeployment();
        await abacus.initialize();
        await abacus.connect(deployer).file(toBytes32("tau"), "1800");

        // Collateral module
        abnbc = await this.ABNBC.connect(deployer).deploy();
        await abnbc.waitForDeployment(); // Collateral
        ceabnbcJoin = await this.GemJoin.connect(deployer).deploy();
        await ceabnbcJoin.waitForDeployment();

        abnbb = await this.ABNBB.connect(deployer).deploy();
        await abnbb.waitForDeployment();
        await abnbb.initialize(deployer.address);

        await abnbc.initialize(ethers.ZeroAddress, abnbb.target);
        await abnbb.changeABNBcToken(abnbc.target);
        // mint tokens
        await abnbc.mint(deployer.address, 5e18.toString());
        await wbnb.mint(deployer.address, 5e18.toString());
        // approve
        await abnbc.approve(dex.target, 5e18.toString());
        await wbnb.approve(dex.target, 5e18.toString());

        const reserve_0 = 1000000000000000000n;
        await dex.addLiquidityETH(
            abnbc.target, reserve_0, reserve_0 / 2n,
            reserve_0, deployer.address, 9999999999, { value: reserve_0});

        this.AuctionProxy = await ethers.getContractFactory("AuctionProxy");
        auctionProxy = await this.AuctionProxy.connect(deployer).deploy();
        await auctionProxy.waitForDeployment();

        this.Interaction = await ethers.getContractFactory("Interaction", {
            libraries: {
                AuctionProxy: auctionProxy.target
            }
        });
        this.Jug = await ethers.getContractFactory("Jug");
        this.Dog = await ethers.getContractFactory("Dog");

        // Contract deployment
        spot = await this.Spot.connect(deployer).deploy();
        await spot.waitForDeployment();
        vat = await this.Vat.connect(deployer).deploy();
        await vat.waitForDeployment();
        oracle = await this.Oracle.connect(deployer).deploy();
        await oracle.waitForDeployment();
        hay = await this.Hay.deploy();
        await hay.waitForDeployment();
        hayJoin = await this.HayJoin.deploy();
        await hayJoin.waitForDeployment();
        vow = await this.Vow.deploy();
        await vow.waitForDeployment();
        helioRewards = await this.HelioRewards.deploy();
        await helioRewards.waitForDeployment();
        interaction = await this.Interaction.deploy();
        await interaction.waitForDeployment();
        jug = await this.Jug.deploy();
        await jug.waitForDeployment();
        dog = await this.Dog.deploy();
        await dog.waitForDeployment();

        clip = await this.Clipper.connect(deployer).deploy();
        await clip.waitForDeployment();

        hbnb = await this.hBNB.connect(deployer).deploy();
        await hbnb.waitForDeployment();
        await hbnb.initialize();

        helioProvider = await this.HelioProvider.deploy();
        await helioProvider.waitForDeployment();
        ceRouter = await this.CeRouter.deploy();
        await ceRouter.waitForDeployment();

        await abnbb.mint(ceRouter.target, 50e19.toString());
        await abnbb.mint(ceRouter.target, 50e19.toString());


        ceToken = await this.CeToken.deploy();
        await ceToken.waitForDeployment();
        await ceToken.initialize('Ceros token', "ceAbnbc");

        binancePool = await this.BinancePool.deploy();
        await binancePool.waitForDeployment();

        await binancePool.initialize(deployer.address, signer1.address, 60 * 60);
        await binancePool.changeBondContract(abnbb.target);
        await abnbb.changeBinancePool(binancePool.target);
        await abnbb.changeABNBcToken(abnbc.target);
        await abnbb.changeSwapFeeParams(signer1.address, '10000000000000000');
        await binancePool.changeCertContract(abnbc.target);

        this.CeVault = await ethers.getContractFactory("CeVault");
        ceVault = await this.CeVault.deploy();
        await ceVault.initialize("CeVault", ceToken.target, abnbb.target);

        await ceToken.changeVault(ceVault.target);

        stakingPool = await this.StakingPool.deploy(abnbc.target);
        await stakingPool.waitForDeployment();

        await ceRouter.initialize(abnbb.target, wbnb.target, ceToken.target, abnbb.target,
            ceVault.target, dex.target, binancePool.target);
        await ceRouter.changeBNBStakingPool(stakingPool.target);

        /* HProvider */
        await helioProvider.initialize(hbnb.target, abnbc.target, ceToken.target, ceRouter.target, interaction.target, binancePool.target);

        await ceRouter.changeProvider(helioProvider.target);
        await hbnb.changeMinter(helioProvider.target);
        await ceVault.changeRouter(ceRouter.target);
        // MINT aBNBc
        const amount = 10000000000020000000000n;
        await abnbb.mintBonds(deployer.address, amount * 5n);
        await abnbb.unlockSharesFor(deployer.address, amount * 2n);

        await abnbb.mintBonds(signer1.address, amount * 5n);
        await abnbb.unlockSharesFor(signer1.address, amount * 2n);
        await abnbb.mintBonds(signer2.address, amount * 5n);
        await abnbb.unlockSharesFor(signer2.address, amount * 2n);

        await oracle.connect(deployer).setPrice(toWad("400"));

    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);
            expect(await interaction.vat()).to.be.equal(vat.target);
        });
    });
    describe('--- rely()', function () {
        it('reverts: Interaction/not-authorized', async function () {
            await expect(interaction.rely(signer1.address)).to.be.revertedWith("Interaction/not-authorized");
            expect(await interaction.wards(signer1.address)).to.be.equal("0");
        });
        it('relies on address', async function () {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

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
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

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
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

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
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

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
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

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
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

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
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await interaction.addToWhitelist([signer1.address, signer2.address]);
            await interaction.removeFromWhitelist([signer1.address]);
            expect(await interaction.whitelist(signer1.address)).to.be.equal("0");
            expect(await interaction.whitelist(signer2.address)).to.be.equal("1");
        })
    });
    describe('--- setCores()', function() {
        it('set core addresses', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await interaction.setCores(vat.target, spot.target, hayJoin.target, jug.target);
            expect(await interaction.vat()).to.be.equal(vat.target);
        });
    });
    describe('--- setCollateralType()', function() {
        it('set collateral type', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await vat.rely(interaction.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));
        });
        it('reverts: Interaction/token-already-init', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await vat.rely(interaction.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            // await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));
            expect(interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"))).to.be.revertedWith("Interaction/token-already-init");
        });
    });
    describe('--- setCollateralDuty()', function() {
        it('reverts: Interaction/inactive collateral', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await vat.rely(interaction.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            // await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));
            expect(interaction.setCollateralDuty(ceToken.target, toRay("0.002"))).to.be.revertedWith("Interaction/inactive collateral");
        });
        it('set collateral duty', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));
            await interaction.setCollateralDuty(ceToken.target, toRay("2"));
            const [duty, ] = await jug.ilks(collateral);
            expect(duty).to.be.equal("2" + ray);
            // expect(interaction.setCollateralDuty(abnbc.target, toRay("0.002"))).to.be.revertedWith("Interaction/token-already-init");
        });
    });
    describe('--- removeCollateralType()', function() {
        it('remove collateral type', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));
            const res = await interaction.removeCollateralType(ceToken.target);
            const [gem, ilk, live, ] = await interaction.collaterals(ceToken.target);
            expect(live).to.be.equal(2);
            expect(await vat.wards(ceabnbcJoin.target)).to.be.equal(0);
            expect(res).to.emit(interaction, "CollateralDisabled");
        });
    });
    describe('--- setHelioProvider()', function() {
        it('set Helio provider for collateral', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await interaction.setHelioProvider(ceToken.target, helioRewards.target);
            expect(await interaction.helioProviders(ceToken.target)).to.be.equal(helioRewards.target);
        });
    });
    describe('--- deposit()', function() {
        it('deposit through HelioProvider with aBNBc should revert', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));
            await interaction.setHelioProvider(ceToken.target, helioProvider.target);

            await expect(helioProvider.provideInABNBc("1" + wad)).to.be.revertedWith("HelioProvider/Disabled");

            await expect(helioProvider.provide({value: 1000})).to.emit(helioProvider, "Deposit").withArgs(deployer.address, "1000");
        });
    });
    describe('--- borrow()', function() {
        it('borrow HAY', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await hayJoin.rely(interaction.target);
            await hay.rely(hayJoin.target);
            await vat.rely(hayJoin.target);
            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));

            await interaction.setHelioProvider(ceToken.target, helioProvider.target);
            await helioProvider.provide({value: "10" + wad});

            // set ceiling limit for collateral
            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            const borrowAmount = "1" + wad;
            await interaction.borrow(ceToken.target, borrowAmount);
            expect(await hay.balanceOf(deployer.address)).to.be.equal(borrowAmount);
        });
    });
    describe('--- payback()', function() {
        it('payback borrowed hay', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await hayJoin.rely(interaction.target);
            await hay.rely(hayJoin.target);
            await vat.rely(hayJoin.target);
            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));

            await interaction.setHelioProvider(ceToken.target, helioProvider.target);
            await helioProvider.provide({value: "10" + wad });

            // set ceiling limit for collateral
            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            const borrowAmount = "7" + wad;
            await interaction.borrow(ceToken.target, borrowAmount);
            expect(await hay.balanceOf(deployer.address)).to.be.equal(borrowAmount);

            const paidBackAmount = "5" + wad;
            await hay.approve(interaction.target, paidBackAmount);
            await interaction.payback(ceToken.target, paidBackAmount);
            expect(await hay.balanceOf(deployer.address)).to.be.equal("2" + wad);
        });
    });
    describe('--- withdraw()', function() {
        it('withdraw collateral via HelioProvider', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));

            await interaction.setHelioProvider(ceToken.target, helioProvider.target);
            await helioProvider.provide({ value: "1" + wad });
            const beforeReleaseBalance = await abnbb.balanceOf(deployer.address);
            await expect(helioProvider.releaseInABNBc(deployer.address, "1" + wad)).to.emit(helioProvider, "Withdrawal").withArgs(deployer.address, deployer.address, "1" + wad);
            expect(await abnbb.balanceOf(deployer.address)).to.be.equal(beforeReleaseBalance + toWad("1"));
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
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await hayJoin.rely(interaction.target);
            await hay.rely(hayJoin.target);
            await vat.rely(hayJoin.target);
            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));

            const beforeBalance = await abnbc.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.target, helioProvider.target);
            await helioProvider.provide({ value: "10" + wad });

            // await interaction.drip(ceToken.target);
            // await jug["file(bytes32,bytes32,uint256)"](collateral, toBytes32("duty"), toRay("0.00002"));
            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.target);
            // expect(await abnbc.balanceOf(deployer.address)).to.be.equal(beforeBalance.sub(toWad("1")));
            // const afterBalance = await abnbc.balanceOf(deployer.address);

            // await helioProvider.releaseInABNBc(deployer.address, "1" + wad);
            // expect(await abnbc.balanceOf(deployer.address)).to.be.equal(afterBalance.add(toWad("1")));

            // set ceiling limit for collateral
            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            const borrowAmount = "7" + wad;
            await interaction.borrow(ceToken.target, borrowAmount);

            const beforeHayBalance = await vat.hay(vow.target);
            await advanceTime(60);
            await interaction.drip(ceToken.target);
            const afterHayBalance = await vat.hay(vow.target);

            expect(beforeHayBalance).to.be.equal(0);
            expect(afterHayBalance).to.be.gt(0);
        });
    });
    describe('--- poke()', function() {
        it('poke collateral price', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await hayJoin.rely(interaction.target);
            await hay.rely(hayJoin.target);
            await vat.rely(hayJoin.target);
            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await vat.rely(spot.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));

            await abnbc.approve(ceRouter.target, "10" + wad);
            const beforeBalance = await abnbc.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.target, helioProvider.target);
            await helioProvider.provide({ value: "10" + wad });

            await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, toBytes32("pip"), oracle.target);
            await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral,toBytes32("mat"),"1250000000000000000000000000");
            await spot["file(bytes32,uint256)"](toBytes32("par"), toRay("1")); // It means pegged to 1$

            const [,,beforeSpot,,] = await vat.ilks(collateral);

            const res = await interaction.poke(ceToken.target);
            expect(res).to.emit(interaction, "Poke");

            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.target);

            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            const borrowAmount = "1" + wad;
            await interaction.borrow(ceToken.target, borrowAmount);

            await advanceTime(60);
            await interaction.drip(ceToken.target);

            const [,,afterSpot,,] = await vat.ilks(collateral);
            expect(afterSpot).to.be.not.equal(beforeSpot);
        });
    });
    describe('--- read states via view functions', function() {
        it('read prices and collateral states', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await hayJoin.rely(interaction.target);
            await hay.rely(hayJoin.target);
            await vat.rely(hayJoin.target);
            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await vat.rely(spot.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));

            await abnbc.approve(ceRouter.target, "10" + wad);
            const beforeBalance = await abnbc.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.target, helioProvider.target);
            await helioProvider.provide({ value: "10" + wad });

            await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, toBytes32("pip"), oracle.target);
            await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral,toBytes32("mat"),"1250000000000000000000000000");
            await spot["file(bytes32,uint256)"](toBytes32("par"), toRay("1")); // It means pegged to 1$

            const res = await interaction.poke(ceToken.target);
            expect(res).to.emit(interaction, "Poke");

            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.target);

            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));

            const borrowAmount = "1" + wad;
            await interaction.borrow(ceToken.target, borrowAmount);

            await advanceTime(60);
            await interaction.drip(ceToken.target);

            // Read states via view functions
            expect(await interaction.collateralPrice(ceToken.target)).to.be.equal(toWad("400"));
            const [,rate,,,] = await vat.ilks(collateral);
            expect(await interaction.hayPrice(ceToken.target)).to.be.equal(rate / 1000000000n);
            expect(await interaction.collateralRate(ceToken.target)).to.be.equal(toWad("0.8")); // 0.8 = 1 / 1.25
            expect(await interaction.depositTVL(ceToken.target)).to.be.equal(toWad("4000")); // 10 * 400 in $
            const collateralTVL = await interaction.collateralTVL(ceToken.target);
            expect(await interaction.free(ceToken.target, deployer.address)).to.be.equal(0);
            expect(await interaction.locked(ceToken.target, deployer.address)).to.be.equal(toWad("10"));
            expect(await interaction.borrowed(ceToken.target, deployer.address)).to.be.equal(collateralTVL + 100n); // 100 Wei is added as a ceiling to help close CDP in repay()

            expect(await interaction.availableToBorrow(ceToken.target, deployer.address)).to.be.equal(6999999877999992679n);
            expect(await interaction.willBorrow(ceToken.target, deployer.address, toWad("1"))).to.be.equal(7799999877999992679n);
            expect(await interaction.currentLiquidationPrice(ceToken.target, deployer.address)).to.be.equal(125000015250000000n);
            expect(await interaction.estimatedLiquidationPrice(ceToken.target, deployer.address, toWad("1"))).to.be.equal(113636377500000000n);
            expect(await interaction.estimatedLiquidationPriceHAY(ceToken.target, deployer.address, toWad("1"))).to.be.equal(125000000125000015n);
            expect(await interaction.borrowApr(ceToken.target)).to.be.equal(6514815689033158807n);
        });
    });
    describe('--- Auction Scenario', function() {
        it('auction should be started and bought as expected', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100000" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await hayJoin.rely(interaction.target);
            await hay.rely(hayJoin.target);
            await vat.rely(hayJoin.target);
            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await vat.rely(spot.target);
            await vat.rely(dog.target);
            await vat.rely(clip.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));

            await helioProvider.changeProxy(interaction.target);
            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.target);

            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("dust"), toRad("1"));

            await dog.rely(clip.target);
            await dog.rely(interaction.target);
            await dog["file(bytes32,address)"](toBytes32("vow"), vow.target);
            await dog["file(bytes32,uint256)"](toBytes32("Hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("chop"), toWad("1.13"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,address)"](collateral, toBytes32("clip"), clip.target);

            await clip.rely(dog.target);
            await clip
                ["file(bytes32,uint256)"](toBytes32("buf"), toRay("1.2"));
            await clip
                ["file(bytes32,uint256)"](toBytes32("tail"), "1800");
            await clip
                ["file(bytes32,uint256)"](toBytes32("cusp"), toRay("0.3"));
            await clip
                ["file(bytes32,uint256)"](toBytes32("chip"), toWad("0.02"));
            await clip
                ["file(bytes32,uint256)"](toBytes32("tip"), toRad("100"));

            await clip
                ["file(bytes32,address)"](toBytes32("vow"), vow.target);
            await clip
                ["file(bytes32,address)"](toBytes32("calc"), abacus.target);

            clip.rely(interaction.target);

            const beforeBalance = await abnbc.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.target, helioProvider.target);
            await helioProvider.provide({ value: "10" + wad });

            await spot["file(bytes32,bytes32,address)"](collateral, toBytes32("pip"), oracle.target);
            await spot["file(bytes32,bytes32,uint256)"](collateral,toBytes32("mat"),"1250000000000000000000000000");
            await spot["file(bytes32,uint256)"](toBytes32("par"), toRay("1")); // It means pegged to 1$

            const res = await interaction.poke(ceToken.target);
            expect(res).to.emit(interaction, "Poke");

            const borrowAmount = "1000" + wad;
            await interaction.borrow(ceToken.target, borrowAmount);

            await oracle.connect(deployer).setPrice(toWad("120"));
            await interaction.poke(ceToken.target);

            await interaction.connect(deployer).startAuction(ceToken.target, deployer.address, signer1.address);

            const sale = await clip.sales(1);
            expect(sale.usr).to.not.be.equal(ethers.ZeroAddress);

            const dink = toWad("100");
            await helioProvider.connect(signer1).provide({ value: dink });
            await helioProvider.connect(signer2).provide({ value: dink });

            const dart = "5000" + wad;
            await interaction.connect(signer1).borrow(ceToken.target, dart);
            await interaction.connect(signer2).borrow(ceToken.target, dart);

            await vat.connect(signer1).hope(clip.target);
            await vat.connect(signer2).hope(clip.target);

            await hay.connect(signer1).approve(interaction.target, toWad("701"));
            await hay.connect(signer2).approve(interaction.target, toWad("1001"));

            // await advanceTime(2000); // If time spent too much, auction needs reset
            // await advanceTime(10); // Too expensive means your propased price is still not available for auction decrease price
            await advanceTime(1000);

            const abnbbSigner1BalanceBefore = await abnbb.balanceOf(signer1.address);
            const abnbbSigner2BalanceBefore = await abnbb.balanceOf(signer2.address);

            await interaction.connect(signer1).buyFromAuction(
                ceToken.target,
                1,
                toWad("7"),
                toRay("100"),
                signer1.address,
            );

            await interaction.connect(signer2).buyFromAuction(
                ceToken.target,
                1,
                toWad("3"),
                toRay("100"),
                signer2.address,
            );

            const abnbbSigner1BalanceAfter = await abnbb.balanceOf(signer1.address);
            const abnbbSigner2BalanceAfter = await abnbb.balanceOf(signer2.address);


            expect(abnbbSigner1BalanceAfter - abnbbSigner1BalanceBefore).to.be.equal(toWad("7"));
            expect(abnbbSigner2BalanceAfter - abnbbSigner2BalanceBefore).to.be.equal(toWad("3"));

            const saleAfter = await clip.sales(1);
            expect(saleAfter.pos).to.equal(0);
            expect(saleAfter.tab).to.equal(0);
            expect(saleAfter.lot).to.equal(0);
            expect(saleAfter.tic).to.equal(0);
            expect(saleAfter.top).to.equal(0);
            expect(saleAfter.usr).to.equal(ethers.ZeroAddress);

            const [status,,,] = await interaction.getAuctionStatus(ceToken.target, 1);
            expect(status).to.be.equal(false);

            const allActiveAuctions = await interaction.getAllActiveAuctionsForToken(ceToken.target);
            expect(allActiveAuctions.length).to.be.equal(0);
        });
        it('--- resetAuction()', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100000" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await hayJoin.rely(interaction.target);
            await hay.rely(hayJoin.target);
            await vat.rely(hayJoin.target);
            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await vat.rely(spot.target);
            await vat.rely(dog.target);
            await vat.rely(clip.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));

            await helioProvider.changeProxy(interaction.target);
            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.target);

            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("dust"), toRad("1"));

            await dog.rely(clip.target);
            await dog.rely(interaction.target);
            await dog["file(bytes32,address)"](toBytes32("vow"), vow.target);
            await dog["file(bytes32,uint256)"](toBytes32("Hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("chop"), toWad("1.13"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,address)"](collateral, toBytes32("clip"), clip.target);

            await clip.rely(dog.target);
            await clip
                ["file(bytes32,uint256)"](toBytes32("buf"), toRay("1.2"));
            await clip
                ["file(bytes32,uint256)"](toBytes32("tail"), "1800");
            await clip
                ["file(bytes32,uint256)"](toBytes32("cusp"), toRay("0.3"));
            await clip
                ["file(bytes32,uint256)"](toBytes32("chip"), toWad("0.02"));
            await clip
                ["file(bytes32,uint256)"](toBytes32("tip"), toRad("100"));

            await clip
                ["file(bytes32,address)"](toBytes32("vow"), vow.target);
            await clip
                ["file(bytes32,address)"](toBytes32("calc"), abacus.target);

            clip.rely(interaction.target);

            const beforeBalance = await abnbb.balanceOf(deployer.address);
            await interaction.setHelioProvider(ceToken.target, helioProvider.target);
            await helioProvider.provide({ value: "10" + wad });

            await spot["file(bytes32,bytes32,address)"](collateral, toBytes32("pip"), oracle.target);
            await spot["file(bytes32,bytes32,uint256)"](collateral,toBytes32("mat"),"1250000000000000000000000000");
            await spot["file(bytes32,uint256)"](toBytes32("par"), toRay("1")); // It means pegged to 1$

            const res = await interaction.poke(ceToken.target);
            expect(res).to.emit(interaction, "Poke");

            const borrowAmount = "1000" + wad;
            await interaction.borrow(ceToken.target, borrowAmount);

            await oracle.setPrice(toWad("120"));
            await interaction.poke(ceToken.target);

            await interaction.startAuction(ceToken.target, deployer.address, signer1.address);

            const sale = await clip.sales(1);
            expect(sale.usr).to.not.be.equal(ethers.ZeroAddress);

            const dink = toWad("100");
            await helioProvider.connect(signer1).provide({ value: dink });
            await helioProvider.connect(signer2).provide({ value: dink });

            const dart = "5000" + wad;
            await interaction.connect(signer1).borrow(ceToken.target, dart);
            await interaction.connect(signer2).borrow(ceToken.target, dart);

            await vat.connect(signer1).hope(clip.target);
            await vat.connect(signer2).hope(clip.target);

            await hay.connect(signer1).approve(interaction.target, toWad("701"));
            await hay.connect(signer2).approve(interaction.target, toWad("1001"));

            // await advanceTime(2000); // If time spent too much, auction needs reset
            // await advanceTime(10); // Too expensive means your propased price is still not available for auction decrease price
            await advanceTime(2000);

            const reset = await interaction.resetAuction(ceToken.target, 1, deployer.address);
            expect(reset).emit(interaction, "Redo");
        });
    });
    describe('--- upchostClipper()', function() {
        it('refresh chost for collateral', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100000" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await hayJoin.rely(interaction.target);
            await hay.rely(hayJoin.target);
            await vat.rely(hayJoin.target);
            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await vat.rely(spot.target);
            await vat.rely(dog.target);
            await vat.rely(clip.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));

            // await helioProvider.changeProxy(interaction.target);

            await jug["file(bytes32,uint256)"](toBytes32("base"), toRay("0.000000002"));
            await jug["file(bytes32,address)"](toBytes32("vow"), vow.target);

            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("dust"), toRad("1"));

            await dog.rely(clip.target);
            await dog.rely(interaction.target);
            await dog["file(bytes32,address)"](toBytes32("vow"), vow.target);
            await dog["file(bytes32,uint256)"](toBytes32("Hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("chop"), toWad("1.13"));
            await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("hole"), toRad("10000000"));
            await dog["file(bytes32,bytes32,address)"](collateral, toBytes32("clip"), clip.target);

            const before = await clip.chost();
            await interaction.upchostClipper(ceToken.target);
            const after = await clip.chost();
            expect(after).be.not.equal(before);
        });
    });
    describe('--- totalPegLiquidity()', function() {
        it('read total supply of hay', async function() {
            await vat.initialize();
            await spot.initialize(vat.target);
            await hay.initialize(97, "HAY", "100" + wad);
            await hayJoin.initialize(vat.target, hay.target);
            await jug.initialize(vat.target);
            await dog.initialize(vat.target);
            await clip.initialize(vat.target, spot.target, dog.target, collateral);
            await ceabnbcJoin.initialize(vat.target, collateral, ceToken.target);
            await helioRewards.initialize(vat.target, "100" + wad);
            await interaction.initialize(vat.target, spot.target, hay.target, hayJoin.target, jug.target, dog.target, helioRewards.target);

            await hayJoin.rely(interaction.target);
            await hay.rely(hayJoin.target);
            await vat.rely(hayJoin.target);
            await vat.rely(interaction.target);
            await vat.rely(jug.target);
            await jug.rely(interaction.target);
            await spot.rely(interaction.target);
            await ceabnbcJoin.rely(interaction.target);
            await interaction.setCollateralType(ceToken.target, ceabnbcJoin.target, collateral, clip.target, toRay("0.75"));

            await abnbc.approve(ceRouter.target, "10" + wad);
            await interaction.setHelioProvider(ceToken.target, helioProvider.target);
            await helioProvider.provide({ value: "10" + wad });

            // set ceiling limit for collateral
            await vat["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), toRad("20000"));
            await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("spot"), toRay("0.8"));
            const borrowAmount = "1" + wad;
            await interaction.borrow(ceToken.target, borrowAmount);

            const res = await interaction.totalPegLiquidity();
            expect(res).to.be.equal(borrowAmount);
        });
    });
});
