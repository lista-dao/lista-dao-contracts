const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { parseEther } = ethers.utils;
const ten = BigNumber.from(10);
const tenPow18 = ten.pow(18);
const NetworkSnapshotter = require("../helpers/NetworkSnapshotter");

describe("MasterVault", function () {
  // Variables
  let CerosStrategy,
    dex,
    wNative,
    abnbc,
    deployer,
    signer1,
    signer2,
    masterVault,
    waitingPool;

  // External Addresses
  let _aBNBc,
    _aBnbb,
    _dex,
    _pool,
    _wBnb,
    _binancePool,
    _maxDepositFee = 500000, // 50%
    _maxWithdrawalFee = 500000,
    _maxStrategies = 10,
    _waitingPoolCap = 10;

  async function getTokenBalance(account, token) {
    if (token == _wBnb) {
      return await ethers.provider.getBalance(account);
    }
    const tokenContract = await ethers.getContractAt("ERC20Upgradeable", token);
    return await tokenContract.balanceOf(account);
  }

  async function depositAndAllocate(masterVault, signer, depositAmount) {
    tx = await masterVault.connect(signer).depositETH({ value: depositAmount });
    await masterVault.allocate();
  }

  const networkSnapshotter = new NetworkSnapshotter();

  // Deploy and Initialize contracts
  before(async function () {
    [deployer, signer1, signer2, signer3] = await ethers.getSigners();

    const Dex = await ethers.getContractFactory("Dex");
    const Pool = await ethers.getContractFactory("Pool");
    const ABNBC = await ethers.getContractFactory("ABNBC");
    const WNative = await ethers.getContractFactory("WNative");
    const CeaBNBc = await hre.ethers.getContractFactory("CeToken");
    const CeVault = await hre.ethers.getContractFactory("CeVault");
    const CerosRouter = await hre.ethers.getContractFactory("CerosRouter");
    const MasterVault = await hre.ethers.getContractFactory("MasterVault");
    const WaitingPool = await hre.ethers.getContractFactory("WaitingPool");

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

    _aBNBc = abnbc.address;
    _aBnbb = abnbc.address;
    _dex = dex.address;
    _pool = pool.address;
    _wBnb = wNative.address;
    _binancePool = pool.address;
    _wBnb = wNative.address;    

    ceaBNBc = await upgrades.deployProxy(
      CeaBNBc,
      ["CEROS aBNBc Vault Token", "ceaBNBc"],
      { initializer: "initialize" }
    );
    await ceaBNBc.deployed();

    masterVaultToken = await upgrades.deployProxy(
      CeaBNBc,
      ["CEROS aBNBc Vault Token", "ceaBNBc"],
      { initializer: "initialize" }
    );
    await masterVaultToken.deployed();

    ceVault = await upgrades.deployProxy(
      CeVault,
      ["CEROS aBNBc Vault", ceaBNBc.address, _aBNBc],
      { initializer: "initialize" }
    );
    await ceVault.deployed();

    cerosRouter = await upgrades.deployProxy(
      CerosRouter,
      [_aBNBc, _wBnb, ceaBNBc.address, _aBnbb, ceVault.address, _dex, _pool],
      { initializer: "initialize" },
      { gasLimit: 2000000 }
    );
    await cerosRouter.deployed();

    await ceaBNBc.changeVault(ceVault.address);
    await ceVault.changeRouter(cerosRouter.address);
    await abnbc.setRatio(tenPow18);

    masterVault = await upgrades.deployProxy(
      MasterVault,
      [
        // "CEROS BNB Vault Token",
        // "ceBNB",
        _maxDepositFee,
        _maxWithdrawalFee,
        _wBnb,
        _maxStrategies,
        masterVaultToken.address,
        pool.address
      ],
      { initializer: "initialize" }
    );
    await masterVault.deployed();
    await masterVaultToken.changeVault(masterVault.address);

    waitingPool = await upgrades.deployProxy(
      WaitingPool,
      [masterVault.address, _waitingPoolCap],
      { initializer: "initialize" }
    );
    await waitingPool.deployed();

    await masterVault.setWaitingPool(waitingPool.address);
    await masterVault.changeProvider(signer1.address);

    CerosStrategy = await hre.ethers.getContractFactory(
      "CerosYieldConverterStrategy"
    );
    cerosStrategy = await upgrades.deployProxy(
      CerosStrategy,
      [
        cerosRouter.address,
        deployer.address,
        // _wBnb,
        _aBNBc,
        masterVault.address,
        _binancePool,
      ],
      { initializer: "initialize" }
    );
    await cerosStrategy.deployed();

    await networkSnapshotter.firstSnapshot();
  });

  afterEach("revert", async () => await networkSnapshotter.revert());

  describe("Basic functionality", async () => {
    it("reverts:: Deposit 0 amount", async function () {
      await expect(
        masterVault.connect(signer1).depositETH()
      ).to.be.revertedWith("invalid amount");
    });

    it("Deposit: valid amount", async function () {
      depositAmount = parseEther("1");
      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      tx = await masterVault
        .connect(signer1)
        .depositETH({ value: depositAmount });
      receipt = await tx.wait(1);
      txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );
    });

    it("Deposit: valid amount", async function () {
      depositAmount = parseEther("1");
      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      tx = await masterVault
        .connect(signer1)
        .depositETH({ value: depositAmount });
      receipt = await tx.wait(1);
      txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );
    });

    it("Deposit: wBNB balance of master vault should increase by deposit amount", async function () {
      depositAmount = parseEther("1");
      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      wBNBTokenBalanceBefore = await getTokenBalance(
        masterVault.address,
        _wBnb
      );
      tx = await masterVault
        .connect(signer1)
        .depositETH({ value: depositAmount });
      receipt = await tx.wait(1);
      txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      wBNBTokenBalanceAfter = await getTokenBalance(masterVault.address, _wBnb);
      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );
      assert.equal(
        wBNBTokenBalanceAfter.toString(),
        Number(wBNBTokenBalanceBefore) + Number(depositAmount)
      );
    });

    it("Deposit: wBNB balance of master vault should increase by deposit amount(deposit fee: 0)", async function () {
      depositAmount = parseEther("1");
      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      wBNBTokenBalanceBefore = await getTokenBalance(
        masterVault.address,
        _wBnb
      );
      tx = await masterVault
        .connect(signer1)
        .depositETH({ value: depositAmount });
      receipt = await tx.wait(1);
      txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      wBNBTokenBalanceAfter = await getTokenBalance(masterVault.address, _wBnb);
      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );
      assert.equal(
        wBNBTokenBalanceAfter.toString(),
        Number(wBNBTokenBalanceBefore) + Number(depositAmount)
      );
    });

    it("Deposit: totalsupply of master vault should increase by amount(deposit fee: 0)", async function () {
      depositAmount = parseEther("1");
      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      wBNBTokenBalanceBefore = await getTokenBalance(
        masterVault.address,
        _wBnb
      );
      totalSupplyBefore = await masterVaultToken.totalSupply();
      tx = await masterVault
        .connect(signer1)
        .depositETH({ value: depositAmount });
      receipt = await tx.wait(1);
      txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      wBNBTokenBalanceAfter = await getTokenBalance(masterVault.address, _wBnb);
      totalSupplyAfter = await masterVaultToken.totalSupply();

      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );
      assert.equal(
        wBNBTokenBalanceAfter.toString(),
        Number(wBNBTokenBalanceBefore) + Number(depositAmount)
      );
      assert.equal(
        totalSupplyAfter.toString(),
        Number(totalSupplyBefore) + Number(depositAmount)
      );
    });

    it("Deposit: totalsupply of master vault should increase by amount(deposit fee: 0.1%)", async function () {
      let fee = 1000; // 0.1%
      depositAmount = parseEther("1");
      await masterVault.connect(deployer).setDepositFee(fee);
      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      wBNBTokenBalanceBefore = await getTokenBalance(
        masterVault.address,
        _wBnb
      );
      totalSupplyBefore = await masterVaultToken.totalSupply();
      tx = await masterVault
        .connect(signer1)
        .depositETH({ value: depositAmount });
      receipt = await tx.wait(1);
      txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      wBNBTokenBalanceAfter = await getTokenBalance(masterVault.address, _wBnb);
      totalSupplyAfter = await masterVaultToken.totalSupply();
      feeEarned = await masterVault.feeEarned();
      assert.equal(
        wBNBTokenBalanceAfter.toString(),
        Number(wBNBTokenBalanceBefore) + Number(depositAmount)
      );
      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) +
          Number(depositAmount) -
          Number((Number(depositAmount) * fee) / 1e6)
      );
      assert.equal(
        totalSupplyAfter.toString(),
        Number(totalSupplyBefore) +
          Number(depositAmount) -
          Number((Number(depositAmount) * fee) / 1e6)
      );
      assert.equal(feeEarned.toString(), Number((depositAmount * fee) / 1e6));
    });

    it("Allocate: wBNB balance should match allocation ratios", async function () {
      let depositAmount = parseEther("1");
      allocation = 80 * 10000; // 80%
      availableToWithdrawBefore = await masterVault.availableToWithdraw();
      tx = await masterVault
        .connect(signer1)
        .depositETH({ value: depositAmount });
      receipt = await tx.wait(1);

      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await masterVault.allocate();
      availableToWithdrawAfter = await masterVault.availableToWithdraw();
      strategyDebt = await masterVault.strategyParams(cerosStrategy.address);
      assert.equal(
        depositAmount.toString(),
        Number(availableToWithdrawAfter) + Number(strategyDebt.debt)
      );
    });

    it("Allocate: wBNB balance should match allocation ratios", async function () {
      depositAmount = parseEther("1");
      allocation = 80 * 10000; // 80%
      availableToWithdrawBefore = await masterVault.availableToWithdraw();
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await masterVault.connect(signer1).depositETH({ value: depositAmount });
      await depositAndAllocate(masterVault, signer1, depositAmount);
      availableToWithdrawAfter = await masterVault.availableToWithdraw();
      strategyDebt = await masterVault.strategyParams(cerosStrategy.address);
      assert.equal(
        Number(depositAmount) + Number(depositAmount),
        Number(availableToWithdrawAfter) + Number(strategyDebt.debt)
      );
    });

    it("Allocate: wBNB balance should match allocation ratios(deposit fee: 0.1%)", async function () {
      let fee = 1000; // 0.1%
      allocation = 80 * 10000; // 80%
      depositAmount = parseEther("1");
      await masterVault.connect(deployer).setDepositFee(fee);

      availableToWithdrawBefore = await masterVault.availableToWithdraw();

      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      availableToWithdrawAfter = await masterVault.availableToWithdraw();
      strategyDebt = await masterVault.strategyParams(cerosStrategy.address);

      totalSupplyAfter = await masterVaultToken.totalSupply();

      let depositFee = (Number(depositAmount) * fee) / 1e6;
      let depositedAmount = Number(depositAmount) - depositFee;
      assert.equal(Number(totalSupplyAfter), depositedAmount);

      assert.equal(
        Number(depositAmount),
        Number(availableToWithdrawAfter) +
          Number(strategyDebt.debt) +
          depositFee
      );
    });

    it("revert:: withdraw: should revert if withdrawal amount is more than vault-token balance(depositAmount)", async function () {
      depositAmount = parseEther("1");
      withdrawAmount = parseEther("1.1");
      await masterVault.connect(signer1).depositETH({ value: depositAmount });
      await expect(
        masterVault
          .connect(signer1)
          .withdrawETH(signer1.address, withdrawAmount)
      ).to.be.revertedWith("ERC20: burn amount exceeds balance");
    });

    it("withdraw: should let user withdraw (withdrawal fee: 0)", async function () {
      depositAmount = parseEther("1");

      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      tx = await masterVault
        .connect(signer1)
        .depositETH({ value: depositAmount });
      receipt = await tx.wait(1);
      txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );
      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);

      tx = await masterVault
        .connect(signer1)
        .withdrawETH(signer1.address, depositAmount.toString());
      receipt = await tx.wait(1);
      txFee = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      expect(vaultTokenBalanceAfter.toString()).to.be.equal("0");
      expect(bnbBalanceBefore.add(depositAmount).sub(txFee)).to.be.equal(bnbBalanceAfter);
    });

    it("withdrawFromStrategy(): should let owner withdraw from strategy", async function () {
      depositAmount = parseEther("1");
      allocation = 80 * 10000; // 80%
      availableToWithdrawBefore = await masterVault.availableToWithdraw();
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await masterVault.connect(signer1).depositETH({ value: depositAmount });
      await depositAndAllocate(masterVault, signer1, depositAmount);
      availableToWithdrawAfter = await masterVault.availableToWithdraw();
      strategyDebt = await masterVault.strategyParams(cerosStrategy.address);
      assert.equal(
        Number(depositAmount) + Number(depositAmount),
        Number(availableToWithdrawAfter) + Number(strategyDebt.debt)
      );

      await masterVault.withdrawFromStrategy(
        cerosStrategy.address,
        strategyDebt.debt
      );
      strategyDebt = await masterVault.strategyParams(cerosStrategy.address);
      assert.equal(Number(strategyDebt.debt), 0);
    });

    it("revert:: withdrawFromStrategy(): only owner can withdraw from strategy", async function () {
      depositAmount = parseEther("1");
      allocation = 80 * 10000; // 80%
      availableToWithdrawBefore = await masterVault.availableToWithdraw();
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await masterVault.connect(signer1).depositETH({ value: depositAmount });
      await depositAndAllocate(masterVault, signer1, depositAmount);
      availableToWithdrawAfter = await masterVault.availableToWithdraw();
      strategyDebt = await masterVault.strategyParams(cerosStrategy.address);
      assert.equal(
        Number(depositAmount) + Number(depositAmount),
        Number(availableToWithdrawAfter) + Number(strategyDebt.debt)
      );

      await expect(
        masterVault
          .connect(signer1)
          .withdrawFromStrategy(cerosStrategy.address, strategyDebt.debt)
      ).to.be.revertedWith("Manager: not allowed");
    });

    it("revert:: withdrawFromStrategy(): only owner can withdraw from strategy", async function () {
      depositAmount = parseEther("1");
      allocation = 80 * 10000; // 80%
      availableToWithdrawBefore = await masterVault.availableToWithdraw();
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await masterVault.connect(signer1).depositETH({ value: depositAmount });
      await depositAndAllocate(masterVault, signer1, depositAmount);
      availableToWithdrawAfter = await masterVault.availableToWithdraw();
      strategyDebt = await masterVault.strategyParams(cerosStrategy.address);
      assert.equal(
        Number(depositAmount) + Number(depositAmount),
        Number(availableToWithdrawAfter) + Number(strategyDebt.debt)
      );

      await expect(
        masterVault.withdrawFromStrategy(cerosStrategy.address, 0)
      ).to.be.revertedWith("invalid withdrawal amount");
    });

    it("revert:: withdrawFromStrategy(): only owner can withdraw from strategy", async function () {
      depositAmount = parseEther("1");
      allocation = 80 * 10000; // 80%
      availableToWithdrawBefore = await masterVault.availableToWithdraw();
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await masterVault.connect(signer1).depositETH({ value: depositAmount });
      await depositAndAllocate(masterVault, signer1, depositAmount);
      availableToWithdrawAfter = await masterVault.availableToWithdraw();
      strategyDebt = await masterVault.strategyParams(cerosStrategy.address);
      assert.equal(
        Number(depositAmount) + Number(depositAmount),
        Number(availableToWithdrawAfter) + Number(strategyDebt.debt)
      );

      await expect(
        masterVault.withdrawFromStrategy(
          cerosStrategy.address,
          strategyDebt.debt + 1000
        )
      ).to.be.revertedWith("insufficient assets in strategy");
    });

    it("withdrawAllFromStrategy(): should let owner withdraw all from strategy", async function () {
      depositAmount = parseEther("1");
      allocation = 80 * 10000; // 80%
      availableToWithdrawBefore = await masterVault.availableToWithdraw();
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await masterVault.connect(signer1).depositETH({ value: depositAmount });
      await depositAndAllocate(masterVault, signer1, depositAmount);
      availableToWithdrawAfter = await masterVault.availableToWithdraw();
      strategyDebt = await masterVault.strategyParams(cerosStrategy.address);
      assert.equal(
        Number(depositAmount) + Number(depositAmount),
        Number(availableToWithdrawAfter) + Number(strategyDebt.debt)
      );

      await masterVault.withdrawAllFromStrategy(cerosStrategy.address);
      strategyDebt = await masterVault.strategyParams(cerosStrategy.address);
      assert.equal(Number(strategyDebt.debt), 0);
    });

    it("withdraw: should let user withdraw (withdrawal fee: 0.1%)", async function () {
      let fee = 1000; // 0.1%
      depositAmount = parseEther("1");
      await masterVault.connect(deployer).setWithdrawalFee(fee);

      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      tx = await masterVault
        .connect(signer1)
        .depositETH({ value: depositAmount });
      receipt = await tx.wait(1);
      txFee1 = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );

      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      let withdrawAmount = depositAmount;
      tx = await masterVault
        .connect(signer1)
        .withdrawETH(signer1.address, withdrawAmount.toString());
      receipt = await tx.wait(1);
      txFee2 = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );

      let event = receipt.events?.filter((x) => {
        return x.event == "Withdraw";
      });
      assert.equal(
        event[0].args.shares,
        withdrawAmount - (Number(withdrawAmount) * fee) / 1e6
      );
      // assert.equal(Number(bnbBalanceAfter), Number(bnbBalanceBefore) + Number(event[0].args.shares) - txFee2);
      expect(
        bnbBalanceAfter.eq(
          bnbBalanceBefore.add(event[0].args.shares).sub(txFee2)
        )
      );
    });

    it("withdraw: should let user withdraw when funds are allocated to strategy (withdrawal fee: 0.1%)", async function () {
      let fee = 1000, // 0.1%
        allocation = 80 * 10000, // 80%
        depositAmount = parseEther("1");
      // withdrawalAmount = parseEther("1");
      await masterVault.connect(deployer).setWithdrawalFee(fee);

      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      // tx = await masterVault.connect(signer1).depositETH({value: depositAmount});
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      // receipt = await tx.wait(1);
      // txFee1 = receipt.gasUsed.mul(receipt.effectiveGasPrice)
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );

      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      let withdrawAmount = depositAmount;

      tx = await masterVault
        .connect(signer1)
        .withdrawETH(signer1.address, withdrawAmount.toString());
      let receipt = await tx.wait(1);
      txFee2 = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );

      let event = receipt.events?.filter((x) => {
        return x.event == "Withdraw";
      });
      assert.equal(
        Number(event[0].args.shares),
        withdrawAmount - (Number(withdrawAmount) * fee) / 1e6
      );
      assert.equal(Number(vaultTokenBalanceAfter), 0);
      // assert.equal(Number(bnbBalanceAfter), Number(bnbBalanceBefore) + Number(event[0].args.shares) - txFee2);
      expect(
        bnbBalanceAfter,
        bnbBalanceBefore.add(event[0].args.shares).sub(txFee2)
      );
    });

    it("withdrawFee: should let user withdraw when funds are allocated to strategy (withdrawal fee: 0.1%)", async function () {
      let fee = 1000, // 0.1%
        allocation = 80 * 10000, // 80%
        depositAmount = parseEther("1");
      // withdrawalAmount = parseEther("1");
      await masterVault.connect(deployer).setWithdrawalFee(fee);

      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      // tx = await masterVault.connect(signer1).depositETH({value: depositAmount});
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      // receipt = await tx.wait(1);
      // txFee1 = receipt.gasUsed.mul(receipt.effectiveGasPrice)
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );

      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      let withdrawAmount = depositAmount;

      tx = await masterVault
        .connect(signer1)
        .withdrawETH(signer1.address, withdrawAmount.toString());
      let receipt = await tx.wait(1);
      txFee2 = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );

      let event = receipt.events?.filter((x) => {
        return x.event == "Withdraw";
      });
      assert.equal(
        Number(event[0].args.shares),
        withdrawAmount - (Number(withdrawAmount) * fee) / 1e6
      );
      assert.equal(Number(vaultTokenBalanceAfter), 0);

      bnbBalanceBefore = await ethers.provider.getBalance(deployer.address);
      feeEarned = await masterVault.feeEarned();
      assert.equal(feeEarned, (Number(withdrawAmount) * fee) / 1e6);

      await masterVault.connect(signer1).depositETH({ value: depositAmount });

      wNativeBalance = await getTokenBalance(
        masterVault.address,
        wNative.address
      );
      tx = await masterVault.withdrawFee();
      receipt = await tx.wait(1);
      txFee3 = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      wNativeBalance = await getTokenBalance(
        masterVault.address,
        wNative.address
      );

      bnbBalanceAfter = await ethers.provider.getBalance(deployer.address);
      expect(bnbBalanceAfter).to.be.equal(
        bnbBalanceBefore.add(feeEarned).sub(txFee3)
      );
    });

    it("withdraw: should let user withdraw (withdrawal fee: 0.1%)", async function () {
      let fee = 1000, // 0.1%
        allocation = 80 * 10000, // 80%
        depositAmount = parseEther("1");
      await masterVault.connect(deployer).setWithdrawalFee(fee);

      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      // tx = await masterVault.connect(signer1).depositETH({value: depositAmount});
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      // receipt = await tx.wait(1);
      // txFee1 = receipt.gasUsed.mul(receipt.effectiveGasPrice)
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      let withdrawalAmount = depositAmount;
      assert.equal(
        vaultTokenBalanceAfter.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );

      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      tx = await masterVault
        .connect(signer1)
        .withdrawETH(signer1.address, withdrawalAmount.toString());
      receipt = await tx.wait(1);
      txFee2 = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );

      assert.equal(Number(vaultTokenBalanceAfter), 0);
      // assert.equal(Number(bnbBalanceAfter), Number(bnbBalanceBefore) + Number(depositAmount) - Number(swapFee) - (Number(depositAmount) * fee / 1e6) - txFee2);
      expect(
        bnbBalanceAfter.eq(
          bnbBalanceBefore
            .add(depositAmount)
            .sub(depositAmount.mul(fee).div(ethers.BigNumber.from("1000000")))
            .sub(txFee2)
        )
      );
    });

    it("withdraw: withdrawal request should go to the waiting pool(withdrawal fee: 0)", async function () {
      let allocation = 80 * 10000, // 80%
        depositAmount = parseEther("6");
      withdrawalAmount = parseEther("5");

      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      // tx = await masterVault.connect(signer1).depositETH({value: depositAmount});
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      // receipt = await tx.wait(1);
      // txFee1 = receipt.gasUsed.mul(receipt.effectiveGasPrice)
      vaultTokenBalanceAfterDeposit = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      assert.equal(
        vaultTokenBalanceAfterDeposit.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );

      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      await masterVault
        .connect(signer1)
        .withdrawETH(signer1.address, withdrawalAmount);
      // receipt = await tx.wait(1);
      // txFee2 = receipt.gasUsed.mul(receipt.effectiveGasPrice)

      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );

      waitingPoolBalance = await ethers.provider.getBalance(
        waitingPool.address
      );
      pendingWithdrawal = await waitingPool.people(0);

      assert.equal(
        Number(vaultTokenBalanceAfter),
        Number(depositAmount) - Number(withdrawalAmount)
      );
      assert.equal(Number(pendingWithdrawal[1]), Number(withdrawalAmount));
      assert.equal(Number(waitingPoolBalance), Number(depositAmount) / 5);
    });

    it("payDebt: should pay the pending withdrawal (withdrawal fee: 0)", async function () {
      let allocation = 80 * 10000, // 80%
        depositAmount = parseEther("6");
      withdrawalAmount = parseEther("5");

      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      vaultTokenBalanceAfterDeposit = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      assert.equal(
        vaultTokenBalanceAfterDeposit.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );

      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      await masterVault
        .connect(signer1)
        .withdrawETH(signer1.address, withdrawalAmount);

      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );

      pendingWithdrawal = await waitingPool.people(0);

      assert.equal(pendingWithdrawal[0], signer1.address);
      assert.equal(Number(pendingWithdrawal[1]), Number(withdrawalAmount));
      assert.equal(
        Number(vaultTokenBalanceAfter),
        Number(depositAmount) - Number(withdrawalAmount)
      );
      poolBalanceBefore = await waitingPool.getPoolBalance();
      await masterVault
        .connect(signer1)
        .depositETH({ value: withdrawalAmount });
      poolBalanceAfter = await waitingPool.getPoolBalance();
      expect(poolBalanceAfter.gt(poolBalanceBefore));
      balanceOfWithdrawerBefore = await ethers.provider.getBalance(
        signer1.address
      );
      await masterVault.connect(signer2).payDebt();
      balanceOfWithdrawerAfter = await ethers.provider.getBalance(
        signer1.address
      );

      assert(
        Number(balanceOfWithdrawerAfter) > Number(balanceOfWithdrawerBefore)
      );
    });

    it.skip("payDebt: should pay the pending withdrawal (withdrawal fee: 0)", async function () {
      let allocation = 80 * 10000, // 80%
        depositAmount = parseEther("6");
      withdrawalAmount = parseEther("5");

      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      vaultTokenBalanceAfterDeposit = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      assert.equal(
        vaultTokenBalanceAfterDeposit.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );

      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      await masterVault
        .connect(signer1)
        .withdrawETH(signer1.address, withdrawalAmount);

      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );

      pendingWithdrawal = await waitingPool.people(0);

      assert.equal(pendingWithdrawal[0], signer1.address);
      assert.equal(Number(pendingWithdrawal[1]), Number(withdrawalAmount));
      assert.equal(
        Number(vaultTokenBalanceAfter),
        Number(depositAmount) - Number(withdrawalAmount)
      );

      balanceOfWithdrawerBefore = await ethers.provider.getBalance(
        signer1.address
      );
      await expect(masterVault.connect(signer2).payDebt())
        .to.emit(waitingPool, "WithdrawCompleted")
        .withArgs(signer1.address, withdrawalAmount);

      balanceOfWithdrawerAfter = await ethers.provider.getBalance(
        signer1.address
      );

      expect(balanceOfWithdrawerAfter.gt(balanceOfWithdrawerBefore));
    });

    it("revert:: waitingPool: withdrawUnsettled(): cannot withdraw already settled debt", async function () {
      let allocation = 80 * 10000, // 80%
        depositAmount = parseEther("6");
      withdrawalAmount = parseEther("5");

      vaultTokenBalanceBefore = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      vaultTokenBalanceAfterDeposit = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );
      assert.equal(
        vaultTokenBalanceAfterDeposit.toString(),
        Number(vaultTokenBalanceBefore) + Number(depositAmount)
      );

      bnbBalanceBefore = await ethers.provider.getBalance(signer1.address);
      await masterVault
        .connect(signer1)
        .withdrawETH(signer1.address, withdrawalAmount);

      bnbBalanceAfter = await ethers.provider.getBalance(signer1.address);
      vaultTokenBalanceAfter = await getTokenBalance(
        signer1.address,
        masterVaultToken.address
      );

      pendingWithdrawal = await waitingPool.people(0);

      assert.equal(pendingWithdrawal[0], signer1.address);
      assert.equal(Number(pendingWithdrawal[1]), Number(withdrawalAmount));
      assert.equal(
        Number(vaultTokenBalanceAfter),
        Number(depositAmount) - Number(withdrawalAmount)
      );

      await masterVault
        .connect(signer1)
        .depositETH({ value: withdrawalAmount });
      balanceOfWithdrawerBefore = await ethers.provider.getBalance(
        signer1.address
      );
      await masterVault.connect(signer2).payDebt();
      balanceOfWithdrawerAfter = await ethers.provider.getBalance(
        signer1.address
      );

      assert(
        Number(balanceOfWithdrawerAfter) > Number(balanceOfWithdrawerBefore)
      );

      await expect(
        waitingPool.connect(signer1).withdrawUnsettled(0)
      ).to.be.revertedWith("already settled");
    });

    it("retireStrat(): should withdraw all the assets from given strategy", async function () {
      let depositAmount = parseEther("1"),
        allocation = 80 * 10000;
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      totalDebtBefore = await masterVault.totalDebt();
      await masterVault.retireStrat(cerosStrategy.address);
      totalDebtAfter = await masterVault.totalDebt();
      strategyParams = await masterVault.strategyParams(cerosStrategy.address);

      assert.equal(Number(totalDebtAfter), 0);
      assert.equal(strategyParams[0], false);
    });

    it("retireStrat(): should mark strategy inactive if debt is less than 10", async function () {
      let depositAmount = parseEther("1"),
        allocation = 80 * 10000;
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      await masterVault.withdrawAllFromStrategy(cerosStrategy.address);

      totalDebtBefore = await masterVault.totalDebt();
      assert.equal(Number(totalDebtBefore), 0);

      await masterVault.retireStrat(cerosStrategy.address);
      totalDebtAfter = await masterVault.totalDebt();
      strategyParams = await masterVault.strategyParams(cerosStrategy.address);

      assert.equal(Number(totalDebtAfter), 0);
      assert.equal(strategyParams[0], false);
    });

    it("migrateStrategy(): should withdraw all the assets from given strategy", async function () {
      let depositAmount = parseEther("1"),
        allocation = 80 * 10000,
        newAllocation = 50 * 10000;

      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await depositAndAllocate(masterVault, signer1, depositAmount);

      newStrategy = await upgrades.deployProxy(
        CerosStrategy,
        [
          cerosRouter.address,
          deployer.address,
          // _wBnb,
          _aBNBc,
          masterVault.address,
          _binancePool,
        ],
        { initializer: "initialize" }
      );
      await newStrategy.deployed();

      totalDebtBefore = await masterVault.totalDebt();
      await masterVault.migrateStrategy(
        cerosStrategy.address,
        newStrategy.address,
        newAllocation
      );
      totalDebtAfter = await masterVault.totalDebt();
      assert.equal(Number(totalDebtAfter), 0);
      let assetInVault = await masterVault.totalAssetInVault();
      await masterVault.allocate();
      totalDebtAfter = await masterVault.totalDebt();
      assert.equal(Number(totalDebtAfter), assetInVault / 2);
    });

    it("depositAllToStrategy(): should deposit all the assets to given strategy", async function () {
      let depositAmount = parseEther("1"),
        allocation = 80 * 10000;
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      await masterVault.connect(signer1).depositETH({ value: depositAmount });
      wBNBBalanceBefore = await getTokenBalance(masterVault.address, _wBnb);
      assert.equal(Number(wBNBBalanceBefore), Number(depositAmount));

      await masterVault.depositAllToStrategy(cerosStrategy.address);
      wBNBBalanceAfter = await getTokenBalance(masterVault.address, _wBnb);
      assert.equal(Number(wBNBBalanceAfter), 0);
    });

    it("depositToStrategy(): should deposit given amount of assets to given strategy", async function () {
      let depositAmount = parseEther("1");
      allocation = 80 * 10000;
      await masterVault.connect(signer1).depositETH({ value: depositAmount });
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      wBNBBalanceBefore = await getTokenBalance(masterVault.address, _wBnb);
      assert.equal(Number(wBNBBalanceBefore), Number(depositAmount));

      await masterVault.depositToStrategy(
        cerosStrategy.address,
        depositAmount.div(ethers.BigNumber.from("2"))
      );
      wBNBBalanceAfter = await getTokenBalance(masterVault.address, _wBnb);
      assert.equal(Number(wBNBBalanceAfter), Number(wBNBBalanceBefore) / 2);
    });

    it("depositAllToStrategy(): should deposit all the assets to given strategy", async function () {
      let depositAmount = parseEther("1");
      allocation = 80 * 10000;
      await masterVault.connect(signer1).depositETH({ value: depositAmount });
      await masterVault.setStrategy(cerosStrategy.address, allocation);
      wBNBBalanceBefore = await getTokenBalance(masterVault.address, _wBnb);
      assert.equal(Number(wBNBBalanceBefore), Number(depositAmount));

      await masterVault.depositAllToStrategy(cerosStrategy.address);
      wBNBBalanceAfter = await getTokenBalance(masterVault.address, _wBnb);
      assert.equal(Number(wBNBBalanceAfter), 0);
    });

    // it("revert:: deposit(): should revert", async function () {
    //   await expect(
    //     masterVault.connect(deployer).deposit(1, deployer.address)
    //   ).to.be.revertedWith("");
    // });

    // it("revert:: mint(): should revert", async function () {
    //   await expect(
    //     masterVault.connect(deployer).mint(1, deployer.address)
    //   ).to.be.revertedWith("");
    // });

    // it("revert:: withdraw(): should revert", async function () {
    //   await expect(
    //     masterVault
    //       .connect(deployer)
    //       .withdraw(1, deployer.address, deployer.address)
    //   ).to.be.revertedWith("");
    // });

    // it("revert:: redeem(): should revert", async function () {
    //   await expect(
    //     masterVault
    //       .connect(deployer)
    //       .redeem(1, deployer.address, deployer.address)
    //   ).to.be.revertedWith("");
    // });

    describe("setters", async () => {
      it("revert:: setDepositFee(): cannot set more than max", async function () {
        let fee = 51 * 10000;
        await expect(
          masterVault.connect(deployer).setDepositFee(fee)
        ).to.be.revertedWith("more than maxDepositFee");
      });

      it("setDepositFee(): should let owner set new fee", async function () {
        let fee = 20 * 10000;
        await masterVault.connect(deployer).setDepositFee(fee);
        assert.equal(fee, await masterVault.depositFee());
      });

      it("revert:: setWithdrawalFee(): cannot set more than max", async function () {
        let fee = 51 * 10000;
        await expect(
          masterVault.connect(deployer).setWithdrawalFee(fee)
        ).to.be.revertedWith("more than maxWithdrawalFee");
      });

      it("setWithdrawalFee(): should let owner set new fee", async function () {
        let fee = 40 * 10000;
        await masterVault.connect(deployer).setWithdrawalFee(fee);
        assert.equal(fee, await masterVault.withdrawalFee());
      });

      it("revert:: setWaitingPool(): cannot set zero address", async function () {
        await expect(
          masterVault
            .connect(deployer)
            .setWaitingPool(ethers.constants.AddressZero)
        ).to.be.revertedWith("");
      });

      it("revert:: setWaitingPool(): onlyOwner can call", async function () {
        await expect(
          masterVault
            .connect(signer1)
            .setWaitingPool(ethers.constants.AddressZero)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("setWaitingPool(): should let set new waiting pool", async function () {
        await masterVault.connect(deployer).setWaitingPool(signer2.address);
        assert.equal(signer2.address, await masterVault.waitingPool());
      });

      it("revert:: addManager(): onlyOwner can call", async function () {
        await expect(
          masterVault.connect(signer1).addManager(ethers.constants.AddressZero)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("revert:: addManager(): cannot set zero address", async function () {
        await expect(
          masterVault.connect(deployer).addManager(ethers.constants.AddressZero)
        ).to.be.revertedWith("");
      });

      it("addManager(): should let add new manager", async function () {
        await masterVault.connect(deployer).addManager(signer2.address);
        assert.equal(await masterVault.manager(signer2.address), true);
      });

      it("revert:: removeManager(): cannot set zero address", async function () {
        await expect(
          masterVault
            .connect(deployer)
            .removeManager(ethers.constants.AddressZero)
        ).to.be.revertedWith("");
      });

      it("removeManager(): should let owner remove manager", async function () {
        await masterVault.connect(deployer).removeManager(deployer.address);
        assert.equal(await masterVault.manager(deployer.address), false);
      });

      it("revert:: changeProvider(): cannot set zero address", async function () {
        await expect(
          masterVault
            .connect(deployer)
            .changeProvider(ethers.constants.AddressZero)
        ).to.be.revertedWith("");
      });

      it("changeProvider(): should let owner change provider address", async function () {
        await expect(masterVault.changeProvider(signer2.address))
          .to.emit(masterVault, "ProviderChanged")
          .withArgs(signer2.address);
      });

      it("revert:: changeStrategyAllocation(): cannot change allocation of zero address", async function () {
        await expect(
          masterVault
            .connect(deployer)
            .changeStrategyAllocation(ethers.constants.AddressZero, 0)
        ).to.be.revertedWith("");
      });

      it("changeStrategyAllocation(): should let owner change allocation", async function () {
        await masterVault
          .connect(deployer)
          .changeStrategyAllocation(cerosStrategy.address, 50 * 10000); // 50%
      });

      it("revert:: changeStrategyAllocation(): cannot change allocation to more than 100%", async function () {
        let allocation = 80 * 10000; // 80%
        await masterVault.setStrategy(cerosStrategy.address, allocation);
        await expect(
          masterVault
            .connect(deployer)
            .changeStrategyAllocation(cerosStrategy.address, 101 * 10000)
        ).to.be.revertedWith("allocations cannot be more than 100%");
      });

      it("revert:: setStrategy(): cannot set already existing strategy", async function () {
        let allocation = 80 * 10000; // 80%
        await masterVault.setStrategy(cerosStrategy.address, allocation);
        await expect(
          masterVault
            .connect(deployer)
            .setStrategy(cerosStrategy.address, allocation)
        ).to.be.revertedWith("strategy already exists");
      });

      it("revert:: setStrategy(): cannot set already existing strategy", async function () {
        let allocation = 80 * 10000; // 80%
        await masterVault.setStrategy(cerosStrategy.address, allocation);
        await expect(
          masterVault
            .connect(deployer)
            .setStrategy(signer1.address, 101 * 10000)
        ).to.be.revertedWith("allocations cannot be more than 100%");
      });

      it("revert:: setWaitingPoolCap(): onlyOwner can call", async function () {
        await expect(
          masterVault.connect(signer1).setWaitingPoolCap(12)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("revert:: setWaitingPoolCap(): should let owner set waiting pool cap limit", async function () {
        let capLimit = 12;
        await masterVault.connect(deployer).setWaitingPoolCap(capLimit);
        let waitingPoolCapLimit = await waitingPool.capLimit();
        assert.equal(waitingPoolCapLimit, capLimit);
      });

      it("revert:: setCapLimit(): onlyMasterVault can call", async function () {
        await expect(
          masterVault.connect(signer1).setWaitingPoolCap(12)
        ).to.be.revertedWith("");
      });

      it("revert:: setCapLimit(): cannot be zero", async function () {
        await expect(
          masterVault.connect(deployer).setWaitingPoolCap(0)
        ).to.be.revertedWith("invalid cap");
      });

      it("revert:: setCapLimit(): onlyMasterVault can call", async function () {
        await expect(
          waitingPool.connect(signer1).setCapLimit(12)
        ).to.be.revertedWith("");
      });

      it("revert:: changeFeeReceiver(): onlyOwner can call", async function () {
        await expect(
          masterVault.connect(signer1).changeFeeReceiver(signer2.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("changeFeeReceiver(): should let owner change fee receiver", async function () {
        expect(
          await masterVault.connect(deployer).changeFeeReceiver(signer2.address)
        )
          .to.emit(masterVault, "FeeReceiverChanged")
          .withArgs(signer2.address);
      });
    });

    describe("CerosStrategy: setters", async () => {
      it("revert:: changeCeRouter(): onlyOwner can call", async function () {
        await expect(
          cerosStrategy.connect(signer1).changeCeRouter(signer2.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("changeCeRouter(): should let owner change ceRouter", async function () {
        expect(
          await cerosStrategy.connect(deployer).changeCeRouter(signer2.address)
        )
          .to.emit(cerosStrategy, "CeRouterChanged")
          .withArgs(signer2.address);
      });

      it("revert:: setStrategist(): onlyOwner can call", async function () {
        await expect(
          cerosStrategy.connect(signer1).setStrategist(signer2.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("setStrategist(): should let owner change Strategist", async function () {
        expect(
          await cerosStrategy.connect(deployer).setStrategist(signer2.address)
        )
          .to.emit(cerosStrategy, "UpdatedStrategist")
          .withArgs(signer2.address);
      });

      it("revert:: setStrategist(): onlyOwner can call", async function () {
        await expect(
          cerosStrategy.connect(signer1).setStrategist(signer2.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("setRewards(): should let owner change rewards account", async function () {
        expect(
          await cerosStrategy.connect(deployer).setRewards(signer2.address)
        )
          .to.emit(cerosStrategy, "UpdatedRewards")
          .withArgs(signer2.address);
      });

      it("revert:: pause(): onlyStrategist can call", async function () {
        await expect(cerosStrategy.connect(signer1).pause()).to.be.revertedWith(
          ""
        );
      });

      it("pause(): should let Strategist pause deposits", async function () {
        await cerosStrategy.connect(deployer).pause();
        let depositPaused = await cerosStrategy.depositPaused();
        assert.equal(depositPaused, true);
      });

      it("unpause(): should let Strategist unpause deposits", async function () {
        await cerosStrategy.connect(deployer).unpause();
        let depositPaused = await cerosStrategy.depositPaused();
        assert.equal(depositPaused, false);
      });

      it("harvest(): should let strategiest harvest(claim yeild)", async function () {
        let depositAmount = parseEther("1"),
          allocation = 80 * 10000; // 80%
        availableToWithdrawBefore = await masterVault.availableToWithdraw();
        await masterVault.setStrategy(cerosStrategy.address, allocation);
        await masterVault.connect(signer1).depositETH({ value: depositAmount });
        await depositAndAllocate(masterVault, signer1, depositAmount);
        availableToWithdrawAfter = await masterVault.availableToWithdraw();
        strategyDebt = await masterVault.strategyParams(cerosStrategy.address);
        assert.equal(
          Number(depositAmount) + Number(depositAmount),
          Number(availableToWithdrawAfter) + Number(strategyDebt.debt)
        );

        await abnbc.setRatio(parseEther("0.5"));

        certTokenBalanceBefore = await abnbc.balanceOf(deployer.address);
        await cerosStrategy.connect(deployer).harvest();
        certTokenBalanceAfter = await abnbc.balanceOf(deployer.address);
        assert(certTokenBalanceBefore < certTokenBalanceAfter);
      });
    });
  });
});
