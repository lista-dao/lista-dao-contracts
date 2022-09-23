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
  let fakeProvider;

  let dex;
  let pool;
  let abnbc;
  let wNative;

  let ceToken;
  let vault;
  let ceRouter;

  const minStake = ten.pow(10);
  const relayerFee = ten.pow(10);

  const inBeforeBlock = false;

  const networkSnapshotter = new NetworkSnapshotter();

  before("setup", async () => {
    [deployer, signer1, acc, feeder, fakeProvider] = await ethers.getSigners();
    const Dex = await ethers.getContractFactory("Dex");
    const Pool = await ethers.getContractFactory("Pool");
    const ABNBC = await ethers.getContractFactory("ABNBC");
    const WNative = await ethers.getContractFactory("WNative");

    const CeToken = await ethers.getContractFactory("CeToken");
    const CeVault = await ethers.getContractFactory("CeVault");
    const CerosRouter = await ethers.getContractFactory("CerosRouter");

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
    await ceRouter.changeProvider(fakeProvider.address);

    const amount = ethers.utils.parseEther("1000");

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

  it("initial parameters", async () => {
    expect(await ceRouter.getProvider()).eq(fakeProvider.address);
    expect(await ceRouter.getCeToken()).eq(ceToken.address);
    expect(await ceRouter.getWbnbAddress()).eq(wNative.address);
    expect(await ceRouter.getCertToken()).eq(abnbc.address);
    expect(await ceRouter.getPoolAddress()).eq(pool.address);
    expect(await ceRouter.getDexAddress()).eq(dex.address);
    expect(await ceRouter.getVaultAddress()).eq(vault.address);
    await ceRouter.getPendingWithdrawalOf(AddressZero);
  });

  it("only owner can call changeVault/changeDex/changePool/changeProvider functions", async () => {
    const errMessage = "Ownable: caller is not the owner";
    await expect(ceRouter.connect(signer1).changeVault(AddressZero)).revertedWith(errMessage);
    await expect(ceRouter.connect(signer1).changeDex(AddressZero)).revertedWith(errMessage);
    await expect(ceRouter.connect(signer1).changePool(AddressZero)).revertedWith(errMessage);
    await expect(ceRouter.connect(signer1).changeProvider(AddressZero)).revertedWith(errMessage);

    await ceRouter.connect(deployer).changeVault(acc.address);
    expect(await ceRouter.getVaultAddress()).eq(acc.address);
    await ceRouter.connect(deployer).changeDex(acc.address);
    expect(await ceRouter.getDexAddress()).eq(acc.address);
    await ceRouter.connect(deployer).changePool(acc.address);
    expect(await ceRouter.getPoolAddress()).eq(acc.address);
    await ceRouter.connect(deployer).changeProvider(acc.address);
    expect(await ceRouter.getProvider()).eq(acc.address);
  });

  it("only provider/owner can call withdrawFor/depositABNBcFrom functions", async () => {
    const errMessage = "Provider: not allowed";
    await expect(ceRouter.connect(signer1).withdrawFor(AddressZero, 0)).revertedWith(errMessage);
    await expect(ceRouter.connect(signer1).depositABNBcFrom(AddressZero, 0)).revertedWith(
      errMessage
    );
  });

  it("deposit works with pool", async () => {
    const amt = parseEther("100");
    await dex.setRate(tenPow18.div(2));
    await ceRouter.connect(signer1).deposit({ value: amt });
    expect(await ceRouter.getProfitFor(signer1.address)).eq(0);
  });

  it("deposit works with dex", async () => {
    const amt = BigNumber.from(parseEther("100"));
    await abnbc.setRatio(tenPow18.mul(9).div(10));
    await ceRouter.connect(signer1).deposit({ value: amt });

    const path = [];
    path[0] = wNative.address;
    path[1] = abnbc.address;
    const outAmounts = await dex.getAmountsOut(amt, path);
    // let's calculate returned amount of aBNBc from BinancePool
    const minimumStake = await pool.getMinimumStake();
    const relayerFee = await pool.getRelayerFee();
    const ratio = await abnbc.ratio();
    let poolABNBcAmount = BigNumber.from(0);
    if (amt.gte(minimumStake.add(relayerFee))) {
      poolABNBcAmount = amt.sub(relayerFee).mul(ratio).div(tenPow18);
    }

    const realAmount = outAmounts[1];
    let profit = BigNumber.from(0);
    if (realAmount.gt(poolABNBcAmount) && !poolABNBcAmount.isZero()) {
      profit = realAmount.sub(poolABNBcAmount);
    }
    expect(await ceRouter.getProfitFor(signer1.address)).eq(profit);
  });

  it("depositABNBc works", async () => {
    const amt = parseEther("100");
    await abnbc.mint(signer1.address, amt);
    await abnbc.connect(signer1).approve(ceRouter.address, MaxUint256);
    await expect(ceRouter.connect(signer1).depositABNBc(amt)).to.not.be.reverted;
    expect(await vault.getDepositOf(signer1.address)).eq(amt);
  });

  it("depositABNBcFrom works", async () => {
    const amt = parseEther("100");
    await abnbc.mint(signer1.address, amt);
    await abnbc.connect(signer1).approve(ceRouter.address, MaxUint256);
    await expect(ceRouter.connect(fakeProvider).depositABNBcFrom(signer1.address, amt)).to.not.be
      .reverted;
    expect(await vault.getDepositOf(fakeProvider.address)).eq(amt);
  });

  it("claim works", async () => {
    const amt = parseEther("100");
    await abnbc.mint(signer1.address, amt);
    await abnbc.connect(signer1).approve(ceRouter.address, MaxUint256);
    await expect(ceRouter.connect(signer1).depositABNBc(amt)).to.not.be.reverted;
    const signer1Bal = await abnbc.balanceOf(signer1.address);
    await abnbc.setRatio(tenPow18.mul(7).div(10));
    await ceRouter.connect(signer1).claim(signer1.address);
    expect(await abnbc.balanceOf(signer1.address)).eq(signer1Bal.add(parseEther("30")));
  });

  it("claimProfit works", async () => {
    await expect(ceRouter.connect(signer1).claimProfit(AddressZero)).revertedWith(
      "has not got a profit"
    );

    const amt = BigNumber.from(parseEther("100"));
    await abnbc.setRatio(tenPow18.mul(9).div(10));
    await ceRouter.connect(signer1).deposit({ value: amt });

    const path = [];
    path[0] = wNative.address;
    path[1] = abnbc.address;
    const outAmounts = await dex.getAmountsOut(amt, path);
    // let's calculate returned amount of aBNBc from BinancePool
    const minimumStake = await pool.getMinimumStake();
    const relayerFee = await pool.getRelayerFee();
    const ratio = await abnbc.ratio();
    let poolABNBcAmount = BigNumber.from(0);
    if (amt.gte(minimumStake.add(relayerFee))) {
      poolABNBcAmount = amt.sub(relayerFee).mul(ratio).div(tenPow18);
    }

    const realAmount = outAmounts[1];
    let profit = BigNumber.from(0);
    if (realAmount.gt(poolABNBcAmount) && !poolABNBcAmount.isZero()) {
      profit = realAmount.sub(poolABNBcAmount);
    }
    const signer1Bal = await abnbc.balanceOf(signer1.address);
    await ceRouter.connect(signer1).claimProfit(signer1.address);
    expect(await abnbc.balanceOf(signer1.address)).eq(signer1Bal.add(profit));
  });

  it("withdraw works", async () => {
    await expect(ceRouter.connect(signer1).withdraw(AddressZero, 0)).revertedWith(
      "value must be greater than min unstake amount"
    );

    // deposit cert token
    const depositAmt = parseEther("110");
    await abnbc.mint(signer1.address, depositAmt);
    await abnbc.connect(signer1).approve(ceRouter.address, MaxUint256);
    await expect(ceRouter.connect(signer1).depositABNBc(depositAmt)).to.not.be.reverted;

    // withdraw native
    const withdrawAmt = parseEther("100");
    const signer1Bal = await acc.getBalance();
    await ceRouter.connect(signer1).withdraw(acc.address, withdrawAmt);
    expect(await acc.getBalance()).eq(signer1Bal.add(withdrawAmt));
  });

  it("withdrawFor works", async () => {
    // deposit cert token
    const depositAmt = parseEther("110");
    await abnbc.mint(fakeProvider.address, depositAmt);
    await abnbc.connect(fakeProvider).approve(ceRouter.address, MaxUint256);
    await expect(ceRouter.connect(fakeProvider).depositABNBc(depositAmt)).to.not.be.reverted;

    // withdraw native
    const withdrawAmt = parseEther("100");
    const accBal = await acc.getBalance();
    await ceRouter.connect(fakeProvider).withdraw(acc.address, withdrawAmt);
    expect(await acc.getBalance()).eq(accBal.add(withdrawAmt));
  });

  it("withdrawABNBc works", async () => {
    // deposit cert token
    const depositAmt = parseEther("110");
    await abnbc.mint(signer1.address, depositAmt);
    await abnbc.connect(signer1).approve(ceRouter.address, MaxUint256);
    await expect(ceRouter.connect(signer1).depositABNBc(depositAmt)).to.not.be.reverted;

    // withdraw native
    const withdrawAmt = parseEther("100");
    const signer1Bal = await abnbc.balanceOf(signer1.address);
    await ceRouter.connect(signer1).withdrawABNBc(signer1.address, withdrawAmt);
    expect(await abnbc.balanceOf(signer1.address)).eq(signer1Bal.add(withdrawAmt));
  });

  it("withdrawWitSlippage works", async () => {
    // deposit cert token
    const depositAmt = parseEther("110");
    await abnbc.mint(signer1.address, depositAmt);
    await abnbc.connect(signer1).approve(ceRouter.address, MaxUint256);
    await expect(ceRouter.connect(signer1).depositABNBc(depositAmt)).to.not.be.reverted;

    // withdraw native
    const withdrawAmt = parseEther("100");
    const accBal = await acc.getBalance();
    await ceRouter.connect(signer1).withdrawWithSlippage(acc.address, withdrawAmt, 0);
    expect(await acc.getBalance()).eq(accBal.add(withdrawAmt));
  });
});
