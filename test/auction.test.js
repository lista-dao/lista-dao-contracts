"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = require("chai");
const hardhat_1 = require("hardhat");
const utils_1 = require("./helpers/utils");
const toBytes32 = hardhat_1.ethers.encodeBytes32String;
const ten = 10n;
const wad = 10 ** 18;
const ray = 10 ** 27;
const rad = 10 ** 45;
describe("Auction", () => {
    //  const networkSnapshotter = new NetworkSnapshotter();
    let deployer, signer1, signer2, signer3;
    let abacus;
    let vat;
    let spot;
    let hay;
    let abnbc;
    let abnbcJoin;
    let hayJoin;
    let jug;
    let oracle;
    let clip;
    let dog;
    let vow;
    let interaction;
    let collateral = toBytes32("aBNBc");
    const deployContracts = async () => {
        const AuctionProxy = await hardhat_1.ethers.deployContract("AuctionProxy");
        const auctionProxy = await AuctionProxy.waitForDeployment();
        console.log("AuctionProxy deployed to:", auctionProxy.target);
        // Abacus
        const LinearDecrease = await hardhat_1.ethers.getContractFactory("LinearDecrease");
        abacus = await hardhat_1.upgrades.deployProxy(LinearDecrease, []);
        await abacus.waitForDeployment();
        console.log("abacus deployed to:", abacus.target);
        // Core module
        const Vat = await hardhat_1.ethers.getContractFactory("Vat");
        vat = await hardhat_1.upgrades.deployProxy(Vat, []);
        await vat.waitForDeployment();
        console.log("vat deployed to:", vat.target);
        const Spotter = await hardhat_1.ethers.getContractFactory("Spotter");
        spot = await hardhat_1.upgrades.deployProxy(Spotter, [await vat.getAddress()]);
        console.log("spot deployed to:", spot.target);
        const HelioRewards = await hardhat_1.ethers.getContractFactory("HelioRewards");
        const rewards = await hardhat_1.upgrades.deployProxy(HelioRewards, [await vat.getAddress(), 1000000000000000000000000000000n]);
        console.log("rewards deployed to:", rewards.target);
        const HelioToken = await hardhat_1.ethers.getContractFactory("HelioToken");
        const helioToken = await hardhat_1.upgrades.deployProxy(HelioToken, [100000000n, await rewards.getAddress()]);
        console.log("helioToken deployed to:", helioToken.target);
        await helioToken.rely(await rewards.getAddress());
        await rewards.setHelioToken(await helioToken.getAddress());
        //    await rewards.initPool(await helioToken.getAddress(), collateral, "1000000001847694957439350500"); //6% FIXME
        // Hay module
        const Hay = await hardhat_1.ethers.getContractFactory("Hay");
        hay = await hardhat_1.upgrades.deployProxy(Hay, [97, "HAY", 100000000000000000000000000n]); // Stable Coin
        const HayJoin = await hardhat_1.ethers.getContractFactory("HayJoin");
        hayJoin = await hardhat_1.upgrades.deployProxy(HayJoin, [await vat.getAddress(), await hay.getAddress()]);
        console.log("hay deployed to:", hay.target);
        // Collateral module
        abnbc = await hardhat_1.ethers.deployContract("aBNBc");
        await abnbc.waitForDeployment(); // collateral
        const GemJoin = await hardhat_1.ethers.getContractFactory("GemJoin");
        abnbcJoin = await hardhat_1.upgrades.deployProxy(GemJoin, [await vat.getAddress(), collateral, await abnbc.getAddress()]);
        // Rates module
        const Jug = await hardhat_1.ethers.getContractFactory("Jug");
        jug = await hardhat_1.upgrades.deployProxy(Jug, [await vat.getAddress()]);
        console.log("jug deployed to:", jug.target);
        // External
        oracle = await hardhat_1.ethers.deployContract("Oracle");
        await oracle.waitForDeployment();
        console.log("oracle deployed to:", oracle.target);
        // Auction modules
        const Dog = await hardhat_1.ethers.getContractFactory("Dog");
        dog = await hardhat_1.upgrades.deployProxy(Dog, [await vat.getAddress()]);
        const Clipper = await hardhat_1.ethers.getContractFactory("Clipper");
        clip = await hardhat_1.upgrades.deployProxy(Clipper, [await vat.getAddress(), await spot.getAddress(), await dog.getAddress(), collateral]);
        console.log("clip deployed to:", clip.target);
        // vow
        const Vow = await hardhat_1.ethers.getContractFactory("Vow");
        vow = await hardhat_1.upgrades.deployProxy(Vow, [await vat.getAddress(), hardhat_1.ethers.ZeroAddress, hardhat_1.ethers.ZeroAddress]);
        console.log("vow deployed to:", vow.target);
        const Interaction = await hardhat_1.ethers.getContractFactory("Interaction", {
            libraries: {
                AuctionProxy: await auctionProxy.getAddress()
            }
        });
        interaction = await hardhat_1.upgrades.deployProxy(Interaction, [
            await vat.getAddress(),
            await spot.getAddress(),
            await hay.getAddress(),
            await hayJoin.getAddress(),
            await jug.getAddress(),
            await dog.getAddress(),
            await rewards.getAddress(),
        ], { unsafeAllow: ['external-library-linking'] });
        console.log("Interaction deployed to:", interaction.target);
    };
    const configureAbacus = async () => {
        await abacus.file(toBytes32("tau"), "1800");
    };
    const configureOracles = async () => {
        const collateral1Price = (0, utils_1.toWad)("400");
        await oracle.setPrice(collateral1Price);
        console.log("oracle price done");
    };
    const configureVat = async () => {
        await vat.rely(hayJoin.target);
        await vat.rely(spot.target);
        await vat.rely(jug.target);
        await vat.rely(interaction.target);
        await vat.rely(dog.target);
        await vat.rely(clip.target);
        await vat["file(bytes32,uint256)"](toBytes32("Line"), (0, utils_1.toRad)("20000")); // Normalized HAY
        await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("line"), (0, utils_1.toRad)("20000"));
        await vat["file(bytes32,bytes32,uint256)"](collateral, toBytes32("dust"), (0, utils_1.toRad)("1"));
        console.log("config vat done");
    };
    const configureSpot = async () => {
        await spot["file(bytes32,bytes32,address)"](collateral, toBytes32("pip"), oracle.target);
        await spot["file(bytes32,bytes32,uint256)"](collateral, toBytes32("mat"), "1250000000000000000000000000"); // Liquidation Ratio
        await spot["file(bytes32,uint256)"](toBytes32("par"), (0, utils_1.toRay)("1")); // It means pegged to 1$
        await spot.poke(collateral);
        console.log("config spot done");
    };
    const configureHAY = async () => {
        // Initialize HAY Module
        await hay.rely(hayJoin.target);
    };
    const configureDog = async () => {
        await dog.rely(clip.target);
        await dog["file(bytes32,address)"](toBytes32("vow"), vow.target);
        await dog["file(bytes32,uint256)"](toBytes32("Hole"), (0, utils_1.toRad)("10000000"));
        await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("chop"), (0, utils_1.toWad)("1.13"));
        await dog["file(bytes32,bytes32,uint256)"](collateral, toBytes32("hole"), (0, utils_1.toRad)("10000000"));
        await dog["file(bytes32,bytes32,address)"](collateral, toBytes32("clip"), clip.target);
        console.log("config dog done");
    };
    const configureClippers = async () => {
        await clip.rely(dog.target);
        await clip["file(bytes32,uint256)"](toBytes32("buf"), (0, utils_1.toRay)("1.2"));
        await clip["file(bytes32,uint256)"](toBytes32("tail"), "1800");
        await clip["file(bytes32,uint256)"](toBytes32("cusp"), (0, utils_1.toRay)("0.3"));
        await clip["file(bytes32,uint256)"](toBytes32("chip"), (0, utils_1.toWad)("0.02"));
        await clip["file(bytes32,uint256)"](toBytes32("tip"), (0, utils_1.toRad)("100"));
        await clip["file(bytes32,address)"](toBytes32("vow"), vow.target);
        await clip["file(bytes32,address)"](toBytes32("calc"), abacus.target);
        console.log("config clip done");
    };
    const configureVow = async () => {
        await vow.rely(dog.target);
        console.log("config vow done");
    };
    const configureJug = async () => {
        const BR = 1000000003022266000000000000n;
        await jug["file(bytes32,uint256)"](toBytes32("base"), BR); // 1% Yearly
        const proxyLike = await hardhat_1.ethers.deployContract("ProxyLike", [jug.target, vat.target]);
        await jug.rely(proxyLike.target);
        await proxyLike
            .jugInitFile(collateral, toBytes32("duty"), "0");
        await jug["file(bytes32,address)"](toBytes32("vow"), vow.target);
        console.log("config jug done");
    };
    const configureInteraction = async () => {
        await interaction
            .setCollateralType(abnbc.target, abnbcJoin.target, collateral, clip.target, toBytes32("mat"));
    };
    before("setup", async () => {
        [deployer, signer1, signer2, signer3] = await hardhat_1.ethers.getSigners();
        await deployContracts();
        await configureAbacus();
        await configureOracles();
        await configureVat();
        await configureSpot();
        await configureHAY();
        await configureDog();
        await configureClippers();
        await configureVow();
        await configureJug();
        await configureInteraction();
        await networkSnapshotter.snapshot();
    });
    afterEach("revert", async () => await networkSnapshotter.revert());
    it("example", async () => {
        await abnbc.connect(deployer).mint(signer1.address, (0, utils_1.toWad)("10000"));
        // Approve and send some collateral inside. collateral value == 400 == `dink`
        let dink = (0, utils_1.toWad)("1000");
        await abnbc.connect(signer1).approve(interaction.address, dink);
        // Deposit collateral(aBNBc) to the interaction contract
        await interaction.connect(signer1).deposit(abnbc.address, dink);
        let s1Balance = await abnbc.balanceOf(signer1.address);
        (0, chai_1.expect)(s1Balance).to.equal((0, utils_1.toWad)("9000"));
        let s1HAYBalance = await hay.balanceOf(signer1.address);
        (0, chai_1.expect)(s1HAYBalance).to.equal("0");
        let free = await interaction
            .connect(signer1)
            .free(abnbc.address, signer1.address);
        (0, chai_1.expect)(free).to.equal("0");
        let locked = await interaction
            .connect(signer1)
            .locked(abnbc.address, signer1.address);
        (0, chai_1.expect)(locked).to.equal((0, utils_1.toWad)("1000"));
        // Locking collateral and borrowing HAY
        // We want to draw 60 HAY == `dart`
        // Maximum available for borrow = (1000 * 400) * 0.8 = 320000
        let dart = (0, utils_1.toWad)("70");
        await interaction.connect(signer1).borrow(abnbc.address, dart);
        free = await interaction
            .connect(signer1)
            .free(abnbc.address, signer1.address);
        (0, chai_1.expect)(free).to.equal("0");
        locked = await interaction
            .connect(signer1)
            .locked(abnbc.address, signer1.address);
        (0, chai_1.expect)(locked).to.equal(dink);
        s1HAYBalance = await hay.balanceOf(signer1.address);
        (0, chai_1.expect)(s1HAYBalance).to.equal(dart);
        // User locked 1000 aBNBc with price 400 and rate 0.8 == 320000$ collateral worth
        // Borrowed 70$ => available should equal to 320000 - 70 = 319930.
        let available = await interaction
            .connect(signer1)
            .availableToBorrow(abnbc.address, signer1.address);
        (0, chai_1.expect)(available).to.equal((0, utils_1.toWad)("319930"));
        // 1000 * 0.0875 * 0.8 == 70$
        let liquidationPrice = await interaction
            .connect(signer1)
            .currentLiquidationPrice(abnbc.address, signer1.address);
        (0, chai_1.expect)(liquidationPrice).to.equal((0, utils_1.toWad)("0.0875"));
        // (1000 + 1000) * 0.04375 * 0.8 == 70$
        let estLiquidationPrice = await interaction
            .connect(signer1)
            .estimatedLiquidationPrice(abnbc.address, signer1.address, (0, utils_1.toWad)("1000"));
        (0, chai_1.expect)(estLiquidationPrice).to.equal((0, utils_1.toWad)("0.04375"));
        let availableYear = await interaction
            .connect(signer1)
            .availableToBorrow(abnbc.address, signer1.address);
        console.log(availableYear.toString());
        // Update Stability Fees
        await (0, utils_1.advanceTime)(31536000);
        await interaction.connect(signer1).drip(abnbc.address);
        availableYear = await interaction
            .connect(signer1)
            .availableToBorrow(abnbc.address, signer1.address);
        console.log(availableYear.toString());
    });
    it("auction started as expected", async () => {
        await abnbc.connect(deployer).mint(signer1.address, (0, utils_1.toWad)("10000"));
        // Approve and send some collateral inside. collateral value == 400 == `dink`
        const dink = (0, utils_1.toWad)("10");
        await abnbc.connect(signer1).approve(interaction.address, dink);
        // Deposit collateral(aBNBc) to the interaction contract
        await interaction.connect(signer1).deposit(signer1.address, abnbc.address, dink);
        const dart = (0, utils_1.toWad)("1000");
        await interaction.connect(signer1).borrow(signer1.address, abnbc.address, dart);
        // change collateral price
        await oracle.connect(deployer).setPrice((0, utils_1.toWad)("124"));
        await spot.connect(deployer).poke(collateral);
        await interaction
            .connect(deployer)
            .startAuction(abnbc.address, signer1.address, deployer.address);
        const sale = await clip.sales(1);
        (0, chai_1.expect)(sale.usr).to.not.be.equal(hardhat_1.ethers.utils.AddressZero);
    });
    it("auction works as expected", async () => {
        await abnbc.connect(deployer).mint(signer1.address, (0, utils_1.toWad)("10000"));
        await abnbc.connect(deployer).mint(signer2.address, (0, utils_1.toWad)("10000"));
        await abnbc.connect(deployer).mint(signer3.address, (0, utils_1.toWad)("10000"));
        const dink1 = (0, utils_1.toWad)("10");
        const dink2 = (0, utils_1.toWad)("1000");
        const dink3 = (0, utils_1.toWad)("1000");
        await abnbc.connect(signer1).approve(interaction.address, dink1);
        await abnbc.connect(signer2).approve(interaction.address, dink2);
        await abnbc.connect(signer3).approve(interaction.address, dink3);
        await interaction.connect(signer1).deposit(signer1.address, abnbc.address, dink1);
        await interaction.connect(signer2).deposit(signer2.address, abnbc.address, dink2);
        await interaction.connect(signer3).deposit(signer3.address, abnbc.address, dink3);
        const dart1 = (0, utils_1.toWad)("1000");
        const dart2 = (0, utils_1.toWad)("5000");
        const dart3 = (0, utils_1.toWad)("5000");
        await interaction.connect(signer1).borrow(signer1.address, abnbc.address, dart1);
        await interaction.connect(signer2).borrow(signer2.address, abnbc.address, dart2);
        await interaction.connect(signer3).borrow(signer3.address, abnbc.address, dart3);
        await oracle.connect(deployer).setPrice((0, utils_1.toWad)("124"));
        await spot.connect(deployer).poke(collateral);
        const auctionId = 1n;
        let res = await interaction
            .connect(deployer)
            .startAuction(abnbc.address, signer1.address, deployer.address);
        (0, chai_1.expect)(res).to.emit(clip, "Kick");
        await vat.connect(signer2).hope(clip.address);
        await vat.connect(signer3).hope(clip.address);
        await hay
            .connect(signer2)
            .approve(hayJoin.address, hardhat_1.ethers.constants.MaxUint256);
        await hay
            .connect(signer3)
            .approve(hayJoin.address, hardhat_1.ethers.constants.MaxUint256);
        await hayJoin.connect(signer2).join(signer2.address, (0, utils_1.toWad)("5000"));
        await hayJoin.connect(signer3).join(signer3.address, (0, utils_1.toWad)("5000"));
        await clip
            .connect(signer2)
            .take(auctionId, (0, utils_1.toWad)("7"), (0, utils_1.toRay)("500"), signer2.address, []);
        await clip
            .connect(signer3)
            .take(auctionId, (0, utils_1.toWad)("7"), (0, utils_1.toRay)("500"), signer2.address, []);
        const sale = await clip.sales(auctionId);
        (0, chai_1.expect)(sale.pos).to.equal(0);
        (0, chai_1.expect)(sale.tab).to.equal(0);
        (0, chai_1.expect)(sale.lot).to.equal(0);
        (0, chai_1.expect)(sale.tic).to.equal(0);
        (0, chai_1.expect)(sale.top).to.equal(0);
        (0, chai_1.expect)(sale.usr).to.equal(hardhat_1.ethers.constants.AddressZero);
    });
    it("auction works as expected", async () => {
        await abnbc.connect(deployer).mint(signer1.address, (0, utils_1.toWad)("10000"));
        await abnbc.connect(deployer).mint(signer2.address, (0, utils_1.toWad)("10000"));
        await abnbc.connect(deployer).mint(signer3.address, (0, utils_1.toWad)("10000"));
        const dink1 = (0, utils_1.toWad)("10");
        const dink2 = (0, utils_1.toWad)("1000");
        const dink3 = (0, utils_1.toWad)("1000");
        await abnbc.connect(signer1).approve(interaction.address, dink1);
        await abnbc.connect(signer2).approve(interaction.address, dink2);
        await abnbc.connect(signer3).approve(interaction.address, dink3);
        await interaction.connect(signer1).deposit(signer1.address, abnbc.address, dink1);
        await interaction.connect(signer2).deposit(signer2.address, abnbc.address, dink2);
        await interaction.connect(signer3).deposit(signer3.address, abnbc.address, dink3);
        const dart1 = (0, utils_1.toWad)("1000");
        const dart2 = (0, utils_1.toWad)("5000");
        const dart3 = (0, utils_1.toWad)("5000");
        await interaction.connect(signer1).borrow(signer1.address, abnbc.address, dart1);
        await interaction.connect(signer2).borrow(signer2.address, abnbc.address, dart2);
        await interaction.connect(signer3).borrow(signer3.address, abnbc.address, dart3);
        await oracle.connect(deployer).setPrice((0, utils_1.toWad)("124"));
        await spot.connect(deployer).poke(collateral);
        const auctionId = 1n;
        let res = await interaction
            .connect(deployer)
            .startAuction(abnbc.address, signer1.address, deployer.address);
        (0, chai_1.expect)(res).to.emit(clip, "Kick");
        await vat.connect(signer2).hope(clip.address);
        await vat.connect(signer3).hope(clip.address);
        await hay.connect(signer2).approve(interaction.address, (0, utils_1.toWad)("700"));
        await hay.connect(signer3).approve(interaction.address, (0, utils_1.toWad)("700"));
        await (0, utils_1.advanceTime)(1000);
        const abnbcSigner2BalanceBefore = await abnbc.balanceOf(signer2.address);
        const abnbcSigner3BalanceBefore = await abnbc.balanceOf(signer3.address);
        await interaction
            .connect(signer2)
            .buyFromAuction(abnbc.address, auctionId, (0, utils_1.toWad)("7"), (0, utils_1.toRay)("100"), signer2.address, []);
        await interaction
            .connect(signer3)
            .buyFromAuction(abnbc.address, auctionId, (0, utils_1.toWad)("5"), (0, utils_1.toRay)("100"), signer3.address, []);
        const abnbcSigner2BalanceAfter = await abnbc.balanceOf(signer2.address);
        const abnbcSigner3BalanceAfter = await abnbc.balanceOf(signer3.address);
        (0, chai_1.expect)(abnbcSigner2BalanceAfter.sub(abnbcSigner2BalanceBefore)).to.be.equal((0, utils_1.toWad)("7"));
        (0, chai_1.expect)(abnbcSigner3BalanceAfter.sub(abnbcSigner3BalanceBefore)).to.be.equal((0, utils_1.toWad)("3"));
        const sale = await clip.sales(auctionId);
        (0, chai_1.expect)(sale.pos).to.equal(0);
        (0, chai_1.expect)(sale.tab).to.equal(0);
        (0, chai_1.expect)(sale.lot).to.equal(0);
        (0, chai_1.expect)(sale.tic).to.equal(0);
        (0, chai_1.expect)(sale.top).to.equal(0);
        (0, chai_1.expect)(sale.usr).to.equal(hardhat_1.ethers.constants.AddressZero);
    });
});
