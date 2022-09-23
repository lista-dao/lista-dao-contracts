const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

const NetworkSnapshotter = require("../helpers/NetworkSnapshotter");

const ten = BigNumber.from(10);
const tenPow18 = ten.pow(18);
const { parseEther } = ethers.utils;
const { AddressZero, MaxUint256 } = ethers.constants;

describe("CerosRouter", () => {
  let deployer;
  let signer1;
  let acc;
  let feeder;
  let operator;
  let fakeProxy;

  let dao;
  let dex;
  let pool;
  let abnbc;
  let wNative;

  let hbnb;
  let ceToken;
  let vault;
  let ceRouter;
  let provider;

  const minStake = ten.pow(10);
  const relayerFee = ten.pow(10);

  const inBeforeBlock = false;

  const networkSnapshotter = new NetworkSnapshotter();

  before("setup", async () => {
    [deployer, signer1, acc, feeder, operator, fakeProxy] = await ethers.getSigners();
    const Dao = await ethers.getContractFactory("Dao");
    const Dex = await ethers.getContractFactory("Dex");
    const Pool = await ethers.getContractFactory("Pool");
    const ABNBC = await ethers.getContractFactory("ABNBC");
    const WNative = await ethers.getContractFactory("WNative");

    const CeToken = await ethers.getContractFactory("CeToken");
    const CeVault = await ethers.getContractFactory("CeVault");
    const CerosRouter = await ethers.getContractFactory("CerosRouter");
    const HelioProvider = await ethers.getContractFactory("HelioProvider");
    // eslint-disable-next-line camelcase
    const HBNB = (await ethers.getContractFactory("hBNB"));

    // deploy dao
    dao = await Dao.deploy();
    await dao.deployed();
    // deploy HBNB
    hbnb = await HBNB.deploy();
    await hbnb.deployed();
    await hbnb.initialize();
    // deploy wNative
    wNative = await WNative.deploy();
    await wNative.deployed();
    // deploy aBNBc
    abnbc = await ABNBC.deploy();
    await abnbc.deployed();
    // deploy dex
    dex = await Dex.deploy(wNative.address, abnbc.address);
    await dex.deployed();
    // deploy pool
    pool = await Pool.deploy(abnbc.address);
    await pool.deployed();
    // deploy ceToken
    ceToken = await CeToken.deploy();
    await ceToken.deployed();
    await ceToken.initialize("ceaBNBc", "CEBNB");
    // deploy ceVault
    vault = await CeVault.deploy();
    await vault.deployed();
    await vault.initialize("ceaBNBc", ceToken.address, abnbc.address);
    // deploy cerosRouter
    ceRouter = await CerosRouter.deploy();
    await ceRouter.deployed();
    await ceRouter.initialize(
      abnbc.address,
      wNative.address,
      ceToken.address,
      abnbc.address,
      vault.address,
      dex.address,
      pool.address
    );
    provider = await HelioProvider.deploy();
    await provider.deployed();
    // TODO: fix AddressZero
    await provider.initialize(
      hbnb.address,
      abnbc.address,
      ceToken.address,
      ceRouter.address,
      dao.address,
      pool.address
    );

    const amount = ethers.utils.parseEther("1000");

    // setup hbnb
    await hbnb.changeMinter(provider.address);
    // setup helio provider
    await provider.changeProxy(fakeProxy.address);
    await provider.changeOperator(operator.address);
    // setup ceros router
    await ceRouter.changeProvider(provider.address);
    // setup abnbc
    await abnbc.setRatio(tenPow18);
    // setup ceToken
    await ceToken.changeVault(vault.address);
    // setup vault
    await vault.changeRouter(ceRouter.address);
    // setup dex
    await dex.setRate(tenPow18);
    await abnbc.mint(feeder.address, amount);
    await abnbc.connect(feeder).approve(dex.address, ethers.constants.MaxUint256);
    await dex.connect(feeder).addLiquidity(amount, { value: amount });
    // setup pool
    await pool.setMinimumStake(minStake);
    await pool.setRelayerFee(relayerFee);
    await feeder.sendTransaction({
      to: pool.address,
      value: amount,
    });

    await networkSnapshotter.firstSnapshot();
  });

  afterEach("revert", async () => {
    if (!inBeforeBlock) {
      await networkSnapshotter.revert();
    }
  });

  it("only owner can call pause/unPause/changeDao/changeCeToken/changeProxy/changeCollateralToken/changeOperator functions", async () => {
    const errMessage = "Ownable: caller is not the owner";
    await expect(provider.connect(signer1).pause()).revertedWith(errMessage);
    await expect(provider.connect(signer1).unPause()).revertedWith(errMessage);
    await expect(provider.connect(signer1).changeDao(AddressZero)).revertedWith(errMessage);
    await expect(provider.connect(signer1).changeCeToken(AddressZero)).revertedWith(errMessage);
    await expect(provider.connect(signer1).changeProxy(AddressZero)).revertedWith(errMessage);
    await expect(provider.connect(signer1).changeCollateralToken(AddressZero)).revertedWith(
      errMessage
    );
    await expect(provider.connect(signer1).changeOperator(AddressZero)).revertedWith(errMessage);

    await expect(provider.connect(deployer).pause()).to.not.be.reverted;
    await expect(provider.connect(deployer).unPause()).to.not.be.reverted;
    await expect(provider.connect(deployer).changeDao(abnbc.address)).to.not.be.reverted;
    await expect(provider.connect(deployer).changeCeToken(abnbc.address)).to.not.be.reverted;
    await expect(provider.connect(deployer).changeProxy(abnbc.address)).to.not.be.reverted;
    await expect(provider.connect(deployer).changeCollateralToken(abnbc.address)).to.not.be
      .reverted;
  });

  it("only proxy/owner can call liquidation/daoBurn/daoMint functions", async () => {
    const errMessage = "AuctionProxy: not allowed";
    await expect(provider.connect(signer1).liquidation(AddressZero, 0)).revertedWith(errMessage);
    await expect(provider.connect(signer1).daoBurn(AddressZero, 0)).revertedWith(errMessage);
    await expect(provider.connect(signer1).daoMint(AddressZero, 0)).revertedWith(errMessage);

    await expect(provider.connect(fakeProxy).daoBurn(acc.address, 0)).to.not.be.reverted;
    await expect(provider.connect(fakeProxy).daoMint(acc.address, 0)).to.not.be.reverted;
  });

  it("only operator/owner can call this function", async () => {
    await expect(provider.connect(signer1).claimInABNBc(AddressZero)).revertedWith(
      "Operator: not allowed"
    );
  });

  it("provide works", async () => {
    const amt = parseEther("100");
    const signer1Bal = await hbnb.balanceOf(signer1.address);
    await expect(provider.connect(signer1).provide({ value: amt })).to.not.be.reverted;
    expect(await hbnb.balanceOf(signer1.address)).eq(signer1Bal.add(amt).sub(minStake));
  });

  it("provideInABNBc works", async () => {
    const amt = parseEther("100");
    await abnbc.mint(signer1.address, amt);
    await abnbc.connect(signer1).approve(ceRouter.address, MaxUint256);
    const signer1Bal = await hbnb.balanceOf(signer1.address);
    await expect(provider.connect(signer1).provideInABNBc(amt)).to.not.be.reverted;
    expect(await hbnb.balanceOf(signer1.address)).eq(signer1Bal.add(amt));
  });

  it("claimInABNBc works", async () => {
    const amt = parseEther("100");
    await abnbc.mint(signer1.address, amt);
    await abnbc.connect(signer1).approve(ceRouter.address, MaxUint256);
    await expect(provider.connect(signer1).provideInABNBc(amt)).to.not.be.reverted;
    await abnbc.setRatio(tenPow18.mul(7).div(10));
    const operatorBal = await abnbc.balanceOf(operator.address);
    await provider.connect(operator).claimInABNBc(operator.address);
    expect(await abnbc.balanceOf(operator.address)).eq(operatorBal.add(parseEther("30")));
  });

  it("release works", async () => {
    const amt = parseEther("100");
    let signer1Bal = await hbnb.balanceOf(signer1.address);
    await expect(provider.connect(signer1).provide({ value: amt })).to.not.be.reverted;
    expect(await hbnb.balanceOf(signer1.address)).eq(signer1Bal.add(amt).sub(minStake));
    signer1Bal = await hbnb.balanceOf(signer1.address);
    await expect(provider.connect(signer1).release(signer1.address, amt.div(2))).to.not.be.reverted;
    expect(await hbnb.balanceOf(signer1.address)).eq(signer1Bal.sub(amt.div(2)));
  });

  it("releaseInABNBc works", async () => {
    const amt = parseEther("100");
    await abnbc.mint(signer1.address, amt);
    await abnbc.connect(signer1).approve(ceRouter.address, MaxUint256);
    let signer1Bal = await hbnb.balanceOf(signer1.address);
    await expect(provider.connect(signer1).provideInABNBc(amt)).to.not.be.reverted;
    expect(await hbnb.balanceOf(signer1.address)).eq(signer1Bal.add(amt));
    signer1Bal = await hbnb.balanceOf(signer1.address);
    await expect(provider.connect(signer1).releaseInABNBc(signer1.address, amt)).to.not.be.reverted;
    expect(await hbnb.balanceOf(signer1.address)).eq(signer1Bal.sub(amt));
  });
});
