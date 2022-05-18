const { expect } = require('chai');
const { BigNumber } = require('ethers');
const { ethers, network } = require('hardhat');
const Web3 = require('web3');
const {ether, expectRevert, BN, expectEvent, constants} = require('@openzeppelin/test-helpers');
const hre = require("hardhat");

///////////////////////////////////////////
//Word of Notice: Commented means pending//
//The test will be updated on daily basis//
///////////////////////////////////////////

describe('===INTERACTION-Multicollateral===', function () {
    let deployer, signer1, signer2, mockVow;

    let vat,
        spot,
        hay,
        abnbc,
        abnbcJoin,
        abnbc2,
        abnbcJoin2,
        hayJoin,
        jug,
        dog,
        clipABNBC,
        rewards,
        helio,
        oracle,
        oracle2,
        helioOracle,
        auctionProxy;

    let interaction;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000", // 45 Decimals
        ONE = 10 ** 27;


    let collateral = ethers.utils.formatBytes32String("aBNBc");
    let collateral2 = ethers.utils.formatBytes32String("aBNBc2");

    beforeEach(async function () {

        ////////////////////////////////
        /** Deployments ------------ **/
        ////////////////////////////////

        [deployer, signer1, signer2, mockVow] = await ethers.getSigners();

        this.Vat = await ethers.getContractFactory("Vat");
        this.Spot = await ethers.getContractFactory("Spotter");
        this.Hay = await ethers.getContractFactory("Hay");
        this.ABNBC = await ethers.getContractFactory("aBNBc");
        this.GemJoin = await ethers.getContractFactory("GemJoin");
        this.HayJoin = await ethers.getContractFactory("HayJoin");
        this.Jug = await ethers.getContractFactory("Jug");
        this.Oracle = await ethers.getContractFactory("Oracle"); // Mock Oracle
        this.Dog = await ethers.getContractFactory("Dog");
        this.ClipABNBC = await ethers.getContractFactory("Clipper");
        this.Abaci = await ethers.getContractFactory("LinearDecrease");
        this.Vow = await ethers.getContractFactory("Vow");
        this.AuctionProxy = await ethers.getContractFactory("AuctionProxy");
        this.Helio = await ethers.getContractFactory("HelioToken");
        const HelioOracle = await ethers.getContractFactory('HelioOracle');
        const HelioRewards = await ethers.getContractFactory('HelioRewards');


        // Core module
        vat = await this.Vat.connect(deployer).deploy();
        await vat.initialize();

        spot = await this.Spot.connect(deployer).deploy(vat.address);
        await spot.deployed();

        // Hay module
        hay = await this.Hay.connect(deployer).deploy(97, "testHAY");
        await hay.deployed(); // Stable Coin
        hayJoin = await this.HayJoin.connect(deployer).deploy(vat.address, hay.address);
        await hayJoin.deployed();

        const aBNBb = artifacts.require("aBNBb");
        abnbb = await aBNBb.new();
        await abnbb.initialize(deployer.address);
        abnbb2 = await aBNBb.new();
        await abnbb2.initialize(deployer.address);
        // Collateral module
        abnbc = await this.ABNBC.connect(deployer).deploy();
        await abnbc.initialize(constants.ZERO_ADDRESS, abnbb.address);
        abnbcJoin = await this.GemJoin.connect(deployer).deploy(vat.address, collateral, abnbc.address);
        await abnbcJoin.deployed();
        // Collateral 2
        abnbc2 = await this.ABNBC.connect(deployer).deploy();
        await abnbc2.initialize(constants.ZERO_ADDRESS, abnbb.address);
        abnbcJoin2 = await this.GemJoin.connect(deployer).deploy(vat.address, collateral2, abnbc2.address);
        await abnbcJoin2.deployed();

        // Rates module
        jug = await this.Jug.connect(deployer).deploy(vat.address);
        await jug.deployed();

        // External
        oracle = await this.Oracle.connect(deployer).deploy();
        await oracle.deployed();
        oracle2 = await this.Oracle.connect(deployer).deploy();
        await oracle2.deployed();

        dog = await this.Dog.connect(deployer).deploy(vat.address);
        await dog.deployed();
        clipABNBC = await this.ClipABNBC.connect(deployer).deploy(vat.address, spot.address, dog.address, collateral);
        await clipABNBC.deployed();

        helioOracle = await HelioOracle.connect(deployer).deploy();
        await helioOracle.initialize("100000000000000000");
        rewards = await HelioRewards.connect(deployer).deploy();
        await rewards.initialize(vat.address, ether("100000000").toString());
        helio = await this.Helio.connect(deployer).deploy(ether("100000000").toString(), rewards.address);
        await helio.deployed();

        auctionProxy = await this.AuctionProxy.connect(deployer).deploy();
        await auctionProxy.deployed();

        const Interaction = await hre.ethers.getContractFactory("Interaction", {
            unsafeAllow: ['external-library-linking'],
            libraries: {
                AuctionProxy: auctionProxy.address
            },
        });
        interaction = await Interaction.deploy();
        await interaction.initialize(
            vat.address,
            spot.address,
            hay.address,
            hayJoin.address,
            jug.address,
            dog.address,
            rewards.address,
        );
        //////////////////////////////
        /** Initial Setup -------- **/
        //////////////////////////////

        await helio.connect(deployer).rely(rewards.address);
        await rewards.connect(deployer).setHelioToken(helio.address);
        await rewards.connect(deployer).setOracle(helioOracle.address);
        await rewards.connect(deployer).initPool(abnbc.address, collateral, "1000000001847694957439350500"); //6%
        await rewards.connect(deployer).rely(interaction.address);
        await jug.connect(deployer).rely(interaction.address);

        // Initialize External
        // 2.000000000000000000000000000 ($) * 0.8 (80%) = 1.600000000000000000000000000,
        // 2.000000000000000000000000000 / 1.600000000000000000000000000 = 1.250000000000000000000000000 = mat
        await oracle.connect(deployer).setPrice("400" + wad); // 400$, mat = 80%, 400$ * 80% = 320$ With Safety Margin
        await oracle2.connect(deployer).setPrice("300" + wad); // 400$, mat = 80%, 400$ * 80% = 320$ With Safety Margin

        // Initialize Core Module
        // await vat.connect(deployer).init(collateral);
        // await vat.connect(deployer).rely(abnbcJoin.address);
        await vat.connect(deployer).rely(hayJoin.address);
        await vat.connect(deployer).rely(spot.address);
        await vat.connect(deployer).rely(jug.address);
        await vat.connect(deployer).rely(interaction.address);
        await vat.connect(deployer).rely(dog.address);
        await vat.connect(deployer).rely(abnbcJoin.address);
        await vat.connect(deployer).rely(abnbcJoin2.address);

        // await vat.connect(deployer).rely(jug.address);
        await vat.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Line"), "20000" + rad); // Normalized HAY
        await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("line"), "2000" + rad);
        // await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("spot"), "500" + rad);
        await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("dust"), "100000000000000000" + ray); //0.1 rad

        await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("pip"), oracle.address);
        await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio
        await spot.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("par"), "1" + ray); // It means pegged to 1$
        await spot.connect(deployer).poke(collateral);

        //Collateral2
        await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("line"), "3000" + rad);
        await vat.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("dust"), "1" + rad);

        await spot.connect(deployer)["file(bytes32,bytes32,address)"](collateral2, ethers.utils.formatBytes32String("pip"), oracle2.address);
        await spot.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral2, ethers.utils.formatBytes32String("mat"), "1250000000000000000000000000"); // Liquidation Ratio
        await spot.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("par"), "1" + ray); // It means pegged to 1$
        await spot.connect(deployer).poke(collateral2);


        // Initialize HAY Module
        await hay.connect(deployer).rely(hayJoin.address);

        // Stability fees
        //calculate base rate
        const year_seconds = 31536000;
        const rate_percent = 0.1; //10%;
        let fractionBR = (1 + rate_percent)**(1/year_seconds);
        // let BR = new BN(fractionBR)*10**27;
        let BR = new BN("1000000003022266000000000000").toString();
        console.log(BR);
        // await jug.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("base"), "1000000000315529215730000000"); // 1% Yearly
        await jug.connect(deployer)["file(bytes32,uint256)"](ethers.utils.formatBytes32String("base"), BR); // 1% Yearly
        // Setting duty requires now == rho. So Drip then Set, or Init then Set.
        // await jug.connect(deployer).init(collateral); // Duty by default set here to 1 Ray which is 0%, but added to Base that makes its effect compound
        // await jug.connect(deployer)["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("duty"), "0000000000312410000000000000"); // 1% Yearly Factored

        // evm does not support stopping time for now == rho, so we create a mock contract which calls both functions to set duty
        let proxyLike = await (await (await ethers.getContractFactory("ProxyLike")).connect(deployer).deploy(jug.address, vat.address)).deployed();
        await jug.connect(deployer).rely(proxyLike.address);
        // await proxyLike.connect(deployer).jugInitFile(collateral, ethers.utils.formatBytes32String("duty"), "0");
        // await proxyLike.connect(deployer).jugInitFile(collateral2, ethers.utils.formatBytes32String("duty"), "0000000000312410000000000000"); // 1% Yearly Factored

        await jug.connect(deployer)["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), mockVow.address);

        await interaction.connect(deployer).setCollateralType(abnbc.address, abnbcJoin.address, collateral,
            clipABNBC.address, "1250000000000000000000000000");
        await interaction.connect(deployer).setCollateralType(abnbc2.address, abnbcJoin2.address, collateral2,
            clipABNBC.address, "1250000000000000000000000000");
        await abnbcJoin.connect(deployer).rely(interaction.address);
        await abnbcJoin2.connect(deployer).rely(interaction.address);
        await clipABNBC.connect(deployer).rely(interaction.address);
        await hayJoin.connect(deployer).rely(interaction.address);

        expect(await(await jug.base()).toString()).to.be.equal(BR);
        expect(await(await(await jug.ilks(collateral)).duty).toString()).to.be.equal("0");
        expect(await(await(await jug.ilks(collateral2)).duty).toString()).to.be.equal("0");

        let s1Balance = (await abnbc.balanceOf(signer1.address)).toString();
        expect(s1Balance).to.equal("0");
        //Mint some tokens for user
        await abnbc.connect(deployer).mint(signer1.address, ether("5000").toString());
        await abnbc.connect(deployer).mint(signer2.address, ether("5000").toString());
        s1Balance = (await abnbc.balanceOf(signer1.address)).toString();
        expect(s1Balance).to.equal(ether("5000").toString());

        await abnbc2.connect(deployer).mint(signer1.address, ether("400").toString());
    });

    it('defaults', async function () {

        // let ilk = await interaction.connect(deployer).ilk(abnbc.address);
        // console.log("Ilk: " + ilk);
        let abnbcPrice = await interaction.connect(signer1).collateralPrice(abnbc.address);
        expect(abnbcPrice.toString()).to.equal(ether("400").toString());
        let abnbcPrice2 = await interaction.connect(signer1).collateralPrice(abnbc2.address);
        expect(abnbcPrice2.toString()).to.equal(ether("300").toString());

        let rate1 = await interaction.connect(signer1).collateralRate(abnbc.address);
        expect(rate1.toString()).to.equal("800000000000000000"); //80%
        let rate2 = await interaction.connect(signer1).collateralRate(abnbc2.address);
        expect(rate2.toString()).to.equal("800000000000000000");

        // Check initial state
        let free = await interaction.connect(signer1).free(abnbc.address, signer1.address);
        expect(free.toString()).to.equal("0");
        let locked = await interaction.connect(signer1).locked(abnbc.address, signer1.address);
        expect(locked.toString()).to.equal("0");

        let borrowApr = await interaction.connect(signer1).borrowApr(abnbc.address);
        expect(borrowApr.toString()).to.equal("10006965766471151936");

        let rewardPool = await rewards.rewardsPool();
        expect(rewardPool.toString()).to.equal("0");
    });

    it('put collateral and borrow', async function () {
        // Approve and send some collateral inside. collateral value == 400 == `dink`
        let dink = ether("2").toString();

        await abnbc.connect(signer1).approve(interaction.address, dink);
        // Deposit collateral(aBNBc) to the interaction contract
        await interaction.connect(signer1).deposit(signer1.address, abnbc.address, dink);

        let s1Balance = (await abnbc.balanceOf(signer1.address)).toString();
        expect(s1Balance).to.equal(ether("4998").toString());

        let s1HAYBalance = (await hay.balanceOf(signer1.address)).toString();
        expect(s1HAYBalance).to.equal("0");

        let free = await interaction.connect(signer1).free(abnbc.address, signer1.address);
        expect(free.toString()).to.equal("0");
        let locked = await interaction.connect(signer1).locked(abnbc.address, signer1.address);
        expect(locked.toString()).to.equal(ether("2").toString());

        // Locking collateral and borrowing HAY
        // We want to draw 60 HAY == `dart`
        // Maximum available for borrow = (2 * 400 ) * 0.8 = 640
        let dart = ether("60").toString();
        await interaction.connect(signer1).borrow(abnbc.address, dart);

        s1HAYBalance = (await hay.balanceOf(signer1.address)).toString();
        expect(s1HAYBalance).to.equal(dart);

        free = await interaction.connect(signer1).free(abnbc.address, signer1.address);
        expect(free.toString()).to.equal("0");
        locked = await interaction.connect(signer1).locked(abnbc.address, signer1.address);
        expect(locked.toString()).to.equal(dink);
        s1HAYBalance = (await hay.balanceOf(signer1.address)).toString();
        expect(s1HAYBalance).to.equal(dart);

        // User locked 2 aBNBc with price 400 and rate 0.8 == 640$ collateral worth
        // Borrowed 60$ => available should equal to 640 - 60 = 580.
        let available = await interaction.connect(signer1).availableToBorrow(abnbc.address, signer1.address);
        expect(available.toString()).to.equal("579999999999999999999");

        // 2 * 37.5 * 0.8 == 60$
        let liquidationPrice = await interaction.connect(signer1).currentLiquidationPrice(abnbc.address, signer1.address);
        expect(liquidationPrice.toString()).to.equal(ether("37.5").toString());
        // console.log("Liq.price is: " + liquidationPrice.toString());

        // ( 2 + 1 ) * 25 * 0.8 == 60$
        let estLiquidationPrice = await interaction.connect(signer1).estimatedLiquidationPrice(
            abnbc.address, signer1.address, ether("1").toString()
        );
        expect(estLiquidationPrice.toString()).to.equal(ether("25").toString());
        console.log("Est.Liq.price is: " + estLiquidationPrice.toString());

        // Update Stability Fees
        await network.provider.send("evm_increaseTime", [31536000]); // Jump 1 Year
        await interaction.connect(signer1).drip(abnbc.address);

        availableYear = await interaction.connect(signer1).availableToBorrow(abnbc.address, signer1.address);
        expect(availableYear.toString()).to.equal("573999999759105624305"); //roughly 10 percents less.
    });

    // 100 BNB -> Ankr
    // 100 aBNBc <-- Ankr 7%
    // 100 aBNBc --> Helio
    // XXX DAI <-- Helio (mint)
    // DAI -> Jar contract (modified MakerDAO Pot) 10%
    // jar is similar to pot but pot has no rewards limit and the interest is based on the percentage of deposit
    // jar has rewards limit and interest is based on percentage share of deposits from fixed emission
    // DAI*(1 + fees%) --> Helio
    // MKR token <-- Helio (amount of MKR == stability fee)

    it('payback and withdraw', async function() {
        //deposit&borrow
        let dink = ether("2").toString();
        await abnbc.connect(signer1).approve(interaction.address, dink);
        await interaction.connect(signer1).deposit(signer1.address, abnbc.address, dink);
        let dart = ether("60").toString();
        await interaction.connect(signer1).borrow(abnbc.address, dart);

        let s1Balance = (await abnbc.balanceOf(signer1.address)).toString();
        expect(s1Balance).to.equal(ether("4998").toString());
        let s1HAYBalance = (await hay.balanceOf(signer1.address)).toString();
        expect(s1HAYBalance).to.equal(dart);

        await hay.connect(signer1).approve(interaction.address, dart);
        await interaction.connect(signer1).payback(abnbc.address, dart);

        s1HAYBalance = (await hay.balanceOf(signer1.address)).toString();
        expect(s1HAYBalance).to.equal("0");
        // let ilk = await vat.connect(signer1).ilks(collateral);
        // console.log(ilk);

        // vatState = await vat.connect(signer1).urns(collateral, signer1.address);
        // console.log(vatState);

        let available = await interaction.connect(signer1).availableToBorrow(abnbc.address, signer1.address);
        expect(available.toString()).to.equal(ether("640").toString());

        let willBeAvailable = await interaction.connect(signer1).willBorrow(
            abnbc.address, signer1.address, ether("1").toString()
        );
        expect(willBeAvailable.toString()).to.equal(ether("960").toString());

        // HAY are burned, now we have to withdraw collateral
        // We will always withdraw all available collateral
        s1Balance = (await abnbc.balanceOf(signer1.address)).toString();
        expect(s1Balance).to.equal(ether("4998").toString());

        let free = await interaction.connect(signer1).free(abnbc.address, signer1.address);
        expect(free.toString()).to.equal("0");

        expectRevert(interaction.connect(signer2).withdraw(signer1.address, abnbc.address, ether("1").toString()),
            "Interaction/Caller must be the same address as participant");

        await interaction.connect(signer1).withdraw(signer1.address, abnbc.address, ether("1").toString());

        s1Balance = (await abnbc.balanceOf(signer1.address)).toString();
        expect(s1Balance).to.equal(ether("4999").toString());
    });

    it('drip', async function() {
        //deposit&borrow
        let dink = ether("2").toString();
        await abnbc.connect(signer1).approve(interaction.address, dink);
        await interaction.connect(signer1).deposit(signer1.address, abnbc.address, dink);
        let dart = ether("60").toString();
        await interaction.connect(signer1).borrow(abnbc.address, dart);

        let borrowed = await interaction.connect(signer1).borrowed(abnbc.address, signer1.address);
        expect(borrowed.toString()).to.equal(dart);

        await network.provider.send("evm_increaseTime", [86400]); // Jump 1 Day
        await interaction.connect(signer1).drip(abnbc.address);

        await abnbc.connect(signer2).approve(interaction.address, dink);
        await interaction.connect(signer2).deposit(signer2.address, abnbc.address, dink);
        await interaction.connect(signer2).borrow(abnbc.address, dart);
        let borrowed2 = await interaction.connect(signer2).borrowed(abnbc.address, signer2.address);
        expect(borrowed2.toString()).to.equal(dart);

        // await network.provider.send("evm_increaseTime", [86400]); // Jump 1 Day
        // await interaction.drip(abnbc.address, {from: signer1.address});

        await hay.connect(signer2).approve(interaction.address, dart);
        await interaction.connect(signer2).payback(abnbc.address, dart);

        borrowed2 = await interaction.connect(signer2).borrowed(abnbc.address, signer2.address);
        expect(borrowed2.toString()).to.equal("0");

        await interaction.connect(signer2).borrowed(abnbc.address, signer1.address);
        expect(borrowed.toString()).to.equal(dart);
    });

    xit('rewards', async function() {
        //deposit&borrow
        let dink = ether("2").toString();
        await abnbc.connect(signer1).approve(interaction.address, dink);
        await interaction.connect(signer1).deposit(signer1.address, abnbc.address, dink);
        let dart = ether("200").toString();
        await interaction.connect(signer1).borrow(signer1.address, abnbc.address, dart);

        let claimable = await rewards.claimable(abnbc.address, signer1.address);
        expect(claimable.toString()).to.equal("0");

        let borrowed = await interaction.connect(signer1).borrowed(abnbc.address, signer1.address);
        expect(borrowed.toString()).to.equal(dart);

        await network.provider.send("evm_increaseTime", [31536000]); // Jump 1 Day
        await network.provider.send("evm_increaseTime", [60]); // Jump 1 minute
        await network.provider.send("evm_mine");

        claimable = await rewards.claimable(abnbc.address, signer1.address);
        expect(claimable.toString()).to.equal("120000235026811392660");

        let totalPending = await rewards.pendingRewards(signer1.address);
        expect(totalPending.toString()).to.equal("120000235026811392660");

        await rewards.connect(signer1).claim(ether("60").toString());
        let helioBalance = await helio.balanceOf(signer1.address);
        expect(helioBalance.toString()).to.equal(ether("60").toString());

        totalPending = await rewards.pendingRewards(signer1.address);
        expect(totalPending.toString()).to.equal("60000238943925136690");
    });
});
