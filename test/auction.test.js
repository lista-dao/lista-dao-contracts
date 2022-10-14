const chai = require("chai");
const chaiAsPromised = require("chai-as-promised");
const { describe, it, before } = require("mocha");
const { ethers, network } = require("hardhat");
const { solidity } = require("ethereum-waffle");

const NetworkSnapshotter = require("./helpers/NetworkSnapshotter");
const {
  toWad,
  toRay,
  toRad,
  advanceTime,
  printSale,
} = require("./helpers/utils");
const hre = require("hardhat");
const {ether} = require("@openzeppelin/test-helpers");

chai.use(solidity);
chai.use(chaiAsPromised);

const { expect } = chai;
const BigNumber = ethers.BigNumber;
const toBytes32 = ethers.utils.formatBytes32String;

const ten = BigNumber.from(10);
const wad = ten.pow(18);
const ray = ten.pow(27);
const rad = ten.pow(45);

describe("Auction", () => {
  const networkSnapshotter = new NetworkSnapshotter();

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
    const Vat = await ethers.getContractFactory("Vat");
    const Spot = await ethers.getContractFactory("Spotter");
    const Hay = await ethers.getContractFactory("Hay");
    const ABNBC = await ethers.getContractFactory("aBNBc");
    const GemJoin = await ethers.getContractFactory("GemJoin");
    const HayJoin = await ethers.getContractFactory("HayJoin");
    const Jug = await ethers.getContractFactory("Jug");
    const Oracle = await ethers.getContractFactory("Oracle"); // Mock Oracle
    const Dog = await ethers.getContractFactory("Dog");
    const Clipper = await ethers.getContractFactory("Clipper");
    const LinearDecrease = await ethers.getContractFactory("LinearDecrease");
    const Vow = await ethers.getContractFactory("Vow");
    const HelioToken = await ethers.getContractFactory("HelioToken");
    const HelioRewards = await ethers.getContractFactory("HelioRewards");
    this.AuctionProxy = await ethers.getContractFactory("AuctionProxy");
    auctionProxy = await this.AuctionProxy.connect(deployer).deploy();
    await auctionProxy.deployed();

    const Interaction = await hre.ethers.getContractFactory("Interaction", {
      unsafeAllow: ['external-library-linking'],
      libraries: {
        AuctionProxy: auctionProxy.address
      },
    });

    // Abacus
    abacus = await LinearDecrease.connect(deployer).deploy();
    await abacus.deployed();

    // Core module
    vat = await Vat.connect(deployer).deploy();
    await vat.deployed();
    spot = await Spot.connect(deployer).deploy(vat.address);
    await spot.deployed();

    const rewards = await HelioRewards.connect(deployer).deploy(vat.address);
    await rewards.deployed();
    const helioToken = await HelioToken.connect(deployer).deploy(ether("100000000").toString(), rewards.address);
    await helioToken.deployed();

    await helioToken.rely(rewards.address);
    await rewards.setHelioToken(helioToken.address);
    await rewards.initPool(collateral, "1000000001847694957439350500"); //6%

    // Hay module
    hay = await Hay.connect(deployer).deploy(97);
    await hay.deployed(); // Stable Coin
    hayJoin = await HayJoin.connect(deployer).deploy(vat.address, hay.address);
    await hayJoin.deployed();

    // Collateral module
    abnbc = await ABNBC.connect(deployer).deploy();
    await abnbc.deployed(); // Collateral
    abnbcJoin = await GemJoin.connect(deployer).deploy(
      vat.address,
      collateral,
      abnbc.address
    );
    await abnbcJoin.deployed();

    // Rates module
    jug = await Jug.connect(deployer).deploy(vat.address);
    await jug.deployed();

    // External
    oracle = await Oracle.connect(deployer).deploy();
    await oracle.deployed();

    // Auction modules
    dog = await Dog.connect(deployer).deploy(vat.address);
    await dog.deployed();
    clip = await Clipper.connect(deployer).deploy(
      vat.address,
      spot.address,
      dog.address,
      collateral
    );
    await clip.deployed();

    // vow
    vow = await Vow.connect(deployer).deploy(
      vat.address,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero
    );
    await vow.deployed();

    interaction = await upgrades.deployProxy(
      Interaction,
      [
        vat.address,
        spot.address,
        hay.address,
        hayJoin.address,
        jug.address,
        dog.address,
        rewards.address,
      ],
      { deployer }
    );
  };

  const configureAbacus = async () => {
    await abacus.connect(deployer).file(toBytes32("tau"), "1800");
  };

  const configureOracles = async () => {
    const collateral1Price = toWad("400");
    await oracle.connect(deployer).setPrice(collateral1Price);
  };

  const configureVat = async () => {
    await vat.connect(deployer).rely(hayJoin.address);
    await vat.connect(deployer).rely(spot.address);
    await vat.connect(deployer).rely(jug.address);
    await vat.connect(deployer).rely(interaction.address);
    await vat.connect(deployer).rely(dog.address);
    await vat.connect(deployer).rely(clip.address);
    await vat
      .connect(deployer)
      ["file(bytes32,uint256)"](toBytes32("Line"), toRad("20000")); // Normalized HAY
    await vat
      .connect(deployer)
      ["file(bytes32,bytes32,uint256)"](
        collateral,
        toBytes32("line"),
        toRad("20000")
      );
    await vat
      .connect(deployer)
      ["file(bytes32,bytes32,uint256)"](
        collateral,
        toBytes32("dust"),
        toRad("1")
      );
  };

  const configureSpot = async () => {
    await spot
      .connect(deployer)
      ["file(bytes32,bytes32,address)"](
        collateral,
        toBytes32("pip"),
        oracle.address
      );
    await spot
      .connect(deployer)
      ["file(bytes32,bytes32,uint256)"](
        collateral,
        toBytes32("mat"),
        "1250000000000000000000000000"
      ); // Liquidation Ratio
    await spot
      .connect(deployer)
      ["file(bytes32,uint256)"](toBytes32("par"), toRay("1")); // It means pegged to 1$
    await spot.connect(deployer).poke(collateral);
  };

  const configureHAY = async () => {
    // Initialize HAY Module
    await hay.connect(deployer).rely(hayJoin.address);
  };

  const configureDog = async () => {
    await dog.connect(deployer).rely(clip.address);
    await dog
      .connect(deployer)
      ["file(bytes32,address)"](toBytes32("vow"), vow.address);
    await dog
      .connect(deployer)
      ["file(bytes32,uint256)"](toBytes32("Hole"), toRad("10000000"));
    await dog
      .connect(deployer)
      ["file(bytes32,bytes32,uint256)"](
        collateral,
        toBytes32("chop"),
        toWad("1.13")
      );
    await dog
      .connect(deployer)
      ["file(bytes32,bytes32,uint256)"](
        collateral,
        toBytes32("hole"),
        toRad("10000000")
      );
    await dog
      .connect(deployer)
      ["file(bytes32,bytes32,address)"](
        collateral,
        toBytes32("clip"),
        clip.address
      );
  };

  const configureClippers = async () => {
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
  };

  const configureVow = async () => {
    await vow.connect(deployer).rely(dog.address);
  };

  const configureJug = async () => {
    const BR = new BigNumber.from("1000000003022266000000000000");
    await jug.connect(deployer)["file(bytes32,uint256)"](toBytes32("base"), BR); // 1% Yearly

    const proxyLike = await (
      await (await ethers.getContractFactory("ProxyLike"))
        .connect(deployer)
        .deploy(jug.address, vat.address)
    ).deployed();
    await jug.connect(deployer).rely(proxyLike.address);
    await proxyLike
      .connect(deployer)
      .jugInitFile(collateral, toBytes32("duty"), "0");

    await jug
      .connect(deployer)
      ["file(bytes32,address)"](toBytes32("vow"), vow.address);
  };

  const configureInteraction = async () => {
    await interaction
      .connect(deployer)
      .setCollateralType(
        abnbc.address,
        abnbcJoin.address,
        collateral,
        clip.address
      );
  };

  before("setup", async () => {
    [deployer, signer1, signer2, signer3] = await ethers.getSigners();

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

  xit("example", async () => {
    await abnbc.connect(deployer).mint(signer1.address, toWad("10000"));
    // Approve and send some collateral inside. collateral value == 400 == `dink`
    let dink = toWad("1000");

    await abnbc.connect(signer1).approve(interaction.address, dink);
    // Deposit collateral(aBNBc) to the interaction contract
    await interaction.connect(signer1).deposit(abnbc.address, dink);

    let s1Balance = await abnbc.balanceOf(signer1.address);
    expect(s1Balance).to.equal(toWad("9000"));

    let s1HAYBalance = await hay.balanceOf(signer1.address);
    expect(s1HAYBalance).to.equal("0");

    let free = await interaction
      .connect(signer1)
      .free(abnbc.address, signer1.address);
    expect(free).to.equal("0");
    let locked = await interaction
      .connect(signer1)
      .locked(abnbc.address, signer1.address);
    expect(locked).to.equal(toWad("1000"));

    // Locking collateral and borrowing HAY
    // We want to draw 60 HAY == `dart`
    // Maximum available for borrow = (1000 * 400) * 0.8 = 320000
    let dart = toWad("70");
    await interaction.connect(signer1).borrow(abnbc.address, dart);

    free = await interaction
      .connect(signer1)
      .free(abnbc.address, signer1.address);
    expect(free).to.equal("0");
    locked = await interaction
      .connect(signer1)
      .locked(abnbc.address, signer1.address);
    expect(locked).to.equal(dink);
    s1HAYBalance = await hay.balanceOf(signer1.address);
    expect(s1HAYBalance).to.equal(dart);

    // User locked 1000 aBNBc with price 400 and rate 0.8 == 320000$ collateral worth
    // Borrowed 70$ => available should equal to 320000 - 70 = 319930.
    let available = await interaction
      .connect(signer1)
      .availableToBorrow(abnbc.address, signer1.address);
    expect(available).to.equal(toWad("319930"));

    // 1000 * 0.0875 * 0.8 == 70$
    let liquidationPrice = await interaction
      .connect(signer1)
      .currentLiquidationPrice(abnbc.address, signer1.address);
    expect(liquidationPrice).to.equal(toWad("0.0875"));

    // (1000 + 1000) * 0.04375 * 0.8 == 70$
    let estLiquidationPrice = await interaction
      .connect(signer1)
      .estimatedLiquidationPrice(abnbc.address, signer1.address, toWad("1000"));
    expect(estLiquidationPrice).to.equal(toWad("0.04375"));

    let availableYear = await interaction
      .connect(signer1)
      .availableToBorrow(abnbc.address, signer1.address);

    console.log(availableYear.toString());

    // Update Stability Fees
    await advanceTime(31536000);
    await interaction.connect(signer1).drip(abnbc.address);

    availableYear = await interaction
      .connect(signer1)
      .availableToBorrow(abnbc.address, signer1.address);
    console.log(availableYear.toString());
  });

  it("auction started as expected", async () => {
    await abnbc.connect(deployer).mint(signer1.address, toWad("10000"));
    // Approve and send some collateral inside. collateral value == 400 == `dink`
    const dink = toWad("10");

    await abnbc.connect(signer1).approve(interaction.address, dink);
    // Deposit collateral(aBNBc) to the interaction contract
    await interaction.connect(signer1).deposit(signer1.address, abnbc.address, dink);
    const dart = toWad("1000");
    await interaction.connect(signer1).borrow(signer1.address, abnbc.address, dart);

    // change collateral price
    await oracle.connect(deployer).setPrice(toWad("124"));
    await spot.connect(deployer).poke(collateral);
    await interaction
      .connect(deployer)
      .startAuction(abnbc.address, signer1.address, deployer.address);

    const sale = await clip.sales(1);
    expect(sale.usr).to.not.be.equal(ethers.utils.AddressZero);
  });

  it("auction works as expected", async () => {
    await abnbc.connect(deployer).mint(signer1.address, toWad("10000"));
    await abnbc.connect(deployer).mint(signer2.address, toWad("10000"));
    await abnbc.connect(deployer).mint(signer3.address, toWad("10000"));

    const dink1 = toWad("10");
    const dink2 = toWad("1000");
    const dink3 = toWad("1000");
    await abnbc.connect(signer1).approve(interaction.address, dink1);
    await abnbc.connect(signer2).approve(interaction.address, dink2);
    await abnbc.connect(signer3).approve(interaction.address, dink3);
    await interaction.connect(signer1).deposit(signer1.address, abnbc.address, dink1);
    await interaction.connect(signer2).deposit(signer2.address, abnbc.address, dink2);
    await interaction.connect(signer3).deposit(signer3.address, abnbc.address, dink3);

    const dart1 = toWad("1000");
    const dart2 = toWad("5000");
    const dart3 = toWad("5000");
    await interaction.connect(signer1).borrow(signer1.address, abnbc.address, dart1);
    await interaction.connect(signer2).borrow(signer2.address, abnbc.address, dart2);
    await interaction.connect(signer3).borrow(signer3.address, abnbc.address, dart3);

    await oracle.connect(deployer).setPrice(toWad("124"));
    await spot.connect(deployer).poke(collateral);

    const auctionId = BigNumber.from(1);

    let res = await interaction
      .connect(deployer)
      .startAuction(abnbc.address, signer1.address, deployer.address);
    expect(res).to.emit(clip, "Kick");

    await vat.connect(signer2).hope(clip.address);
    await vat.connect(signer3).hope(clip.address);

    await hay
      .connect(signer2)
      .approve(hayJoin.address, ethers.constants.MaxUint256);
    await hay
      .connect(signer3)
      .approve(hayJoin.address, ethers.constants.MaxUint256);
    await hayJoin.connect(signer2).join(signer2.address, toWad("5000"));
    await hayJoin.connect(signer3).join(signer3.address, toWad("5000"));

    await clip
      .connect(signer2)
      .take(auctionId, toWad("7"), toRay("500"), signer2.address, []);

    await clip
      .connect(signer3)
      .take(auctionId, toWad("7"), toRay("500"), signer2.address, []);

    const sale = await clip.sales(auctionId);
    expect(sale.pos).to.equal(0);
    expect(sale.tab).to.equal(0);
    expect(sale.lot).to.equal(0);
    expect(sale.tic).to.equal(0);
    expect(sale.top).to.equal(0);
    expect(sale.usr).to.equal(ethers.constants.AddressZero);
  });

  it("auction works as expected", async () => {
    await abnbc.connect(deployer).mint(signer1.address, toWad("10000"));
    await abnbc.connect(deployer).mint(signer2.address, toWad("10000"));
    await abnbc.connect(deployer).mint(signer3.address, toWad("10000"));

    const dink1 = toWad("10");
    const dink2 = toWad("1000");
    const dink3 = toWad("1000");
    await abnbc.connect(signer1).approve(interaction.address, dink1);
    await abnbc.connect(signer2).approve(interaction.address, dink2);
    await abnbc.connect(signer3).approve(interaction.address, dink3);
    await interaction.connect(signer1).deposit(signer1.address, abnbc.address, dink1);
    await interaction.connect(signer2).deposit(signer2.address, abnbc.address, dink2);
    await interaction.connect(signer3).deposit(signer3.address, abnbc.address, dink3);

    const dart1 = toWad("1000");
    const dart2 = toWad("5000");
    const dart3 = toWad("5000");
    await interaction.connect(signer1).borrow(signer1.address, abnbc.address, dart1);
    await interaction.connect(signer2).borrow(signer2.address, abnbc.address, dart2);
    await interaction.connect(signer3).borrow(signer3.address, abnbc.address, dart3);

    await oracle.connect(deployer).setPrice(toWad("124"));
    await spot.connect(deployer).poke(collateral);

    const auctionId = BigNumber.from(1);

    let res = await interaction
      .connect(deployer)
      .startAuction(abnbc.address, signer1.address, deployer.address);
    expect(res).to.emit(clip, "Kick");

    await vat.connect(signer2).hope(clip.address);
    await vat.connect(signer3).hope(clip.address);

    await hay.connect(signer2).approve(interaction.address, toWad("700"));
    await hay.connect(signer3).approve(interaction.address, toWad("700"));

    await advanceTime(1000);

    const abnbcSigner2BalanceBefore = await abnbc.balanceOf(signer2.address);
    const abnbcSigner3BalanceBefore = await abnbc.balanceOf(signer3.address);

    await interaction
      .connect(signer2)
      .buyFromAuction(
        abnbc.address,
        auctionId,
        toWad("7"),
        toRay("100"),
        signer2.address,
        []
      );

    await interaction
      .connect(signer3)
      .buyFromAuction(
        abnbc.address,
        auctionId,
        toWad("5"),
        toRay("100"),
        signer3.address,
        []
      );


    const abnbcSigner2BalanceAfter = await abnbc.balanceOf(signer2.address);
    const abnbcSigner3BalanceAfter = await abnbc.balanceOf(signer3.address);

    expect(abnbcSigner2BalanceAfter.sub(abnbcSigner2BalanceBefore)).to.be.equal(toWad("7"));
    expect(abnbcSigner3BalanceAfter.sub(abnbcSigner3BalanceBefore)).to.be.equal(toWad("3"));

    const sale = await clip.sales(auctionId);
    expect(sale.pos).to.equal(0);
    expect(sale.tab).to.equal(0);
    expect(sale.lot).to.equal(0);
    expect(sale.tic).to.equal(0);
    expect(sale.top).to.equal(0);
    expect(sale.usr).to.equal(ethers.constants.AddressZero);
  });
});
