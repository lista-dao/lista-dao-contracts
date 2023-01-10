const { expect } = require("chai");
const { parseEther, formatEther } = require("ethers/lib/utils");
const { ethers } = require("hardhat");

describe("BNBx Strategy", () => {
  let deployer,
    otherAddrs,
    user,
    rewardsAddr,
    strategy,
    bnbxStakeManager,
    bnbxToken,
    masterVault;

  beforeEach(async () => {
    [deployer, user, ...otherAddrs] = await ethers.getSigners();
    rewardsAddr = otherAddrs[1];

    bnbxStakeManager = await (
      await ethers.getContractFactory("BnbxStakeManagerMock")
    ).deploy();
    await bnbxStakeManager.deployed();

    masterVault = await (
      await ethers.getContractFactory("MasterVaultMock")
    ).deploy();
    await masterVault.deployed();

    bnbxToken = await (await ethers.getContractFactory("BnbxMock")).deploy();
    await bnbxToken.deployed();

    strategy = await upgrades.deployProxy(
      await ethers.getContractFactory("BnbxYieldConverterStrategy"),
      [
        bnbxStakeManager.address,
        rewardsAddr.address,
        bnbxToken.address,
        masterVault.address,
      ]
    );
    await strategy.deployed();

    await bnbxStakeManager.changeBnbx(bnbxToken.address);
    await bnbxStakeManager.changeER(parseEther("1"));
    await masterVault.changeStrategy(strategy.address);
  });

  it("deposit fails if invoked by anyone except masterVault", async () => {
    let oneEther = parseEther("1");

    // invoked by deployer
    await expect(strategy.deposit({ value: oneEther })).revertedWith("!vault");

    await expect(
      strategy.connect(user).deposit({ value: oneEther })
    ).revertedWith("!vault");
  });

  it("deposit via masterVault", async () => {
    let amount = parseEther("1.23");

    await masterVault.deposit({ value: amount });
    expect(await bnbxToken.balanceOf(strategy.address)).eq(amount);
    expect(await strategy.balanceOfPool()).eq(amount);
  });

  it("deposit fail: invalid amount", async () => {
    await expect(masterVault.deposit()).revertedWith("invalid amount");
    await expect(masterVault.deposit({ value: parseEther("0") })).revertedWith(
      "invalid amount"
    );
  });

  it("depositAll fails if invoked by anyone except strategist", async () => {
    await expect(strategy.connect(user).depositAll()).to.be.reverted;
    await expect(strategy.connect(rewardsAddr).depositAll()).to.be.reverted;
  });

  it("depositAll", async () => {
    // no bnb in strategy contract
    await expect(strategy.depositAll()).revertedWith("invalid amount");

    let amount = parseEther("1.23");
    await deployer.sendTransaction({
      to: strategy.address,
      value: amount,
    });
    await strategy.depositAll();
    expect(await bnbxToken.balanceOf(strategy.address)).eq(amount);

    // no bnb in strategy contract
    await expect(strategy.depositAll()).revertedWith("invalid amount");
  });

  it("withdraw fails if invoked by anyone except master vault", async () => {
    let amountInBnbx = parseEther("1");

    // invoked by deployer
    await expect(strategy.withdraw(user.address, amountInBnbx)).revertedWith(
      "!vault"
    );

    await expect(
      strategy.connect(user).withdraw(user.address, amountInBnbx)
    ).revertedWith("!vault");
  });

  it("withdraw via masterVault", async () => {
    const threeBNB = parseEther("3");
    const twoBNB = parseEther("2");
    const oneBNB = parseEther("1");

    expect(await strategy.bnbDepositBalance()).eq(0);

    // deployer deposits 3 BNB
    await masterVault.deposit({ value: threeBNB });
    expect(await strategy.bnbDepositBalance()).eq(threeBNB);

    // withdraw 1 BNB to deployer
    await masterVault.withdraw(deployer.address, oneBNB);
    expect(await strategy.bnbDepositBalance()).eq(twoBNB);
    expect(await bnbxToken.balanceOf(strategy.address)).eq(threeBNB);
    expect(await strategy.bnbxToUnstake()).eq(oneBNB);

    // withdraw 1 BNB to user
    await masterVault.withdraw(user.address, oneBNB);
    expect(await strategy.bnbDepositBalance()).eq(oneBNB);
    expect(await bnbxToken.balanceOf(strategy.address)).eq(threeBNB);
    expect(await strategy.bnbxToUnstake()).eq(twoBNB);
  });

  it("panic fails if invoked by anyone except strategist", async () => {
    await expect(strategy.connect(user).panic()).to.be.reverted;
    await expect(strategy.connect(rewardsAddr).panic()).to.be.reverted;
  });

  it("panic fails if debt is more than bnb deposited", async () => {
    const threeBNB = parseEther("3");
    const twoBNB = parseEther("2");
    const oneBNB = parseEther("1");

    // here debt is 3 BNB in all cases

    // case 1
    expect(await strategy.bnbDepositBalance()).be.eq(0);
    await expect(strategy.panic()).be.revertedWith("underflowed or overflowed");

    // case 2
    await masterVault.deposit({ value: twoBNB });
    expect(await strategy.bnbDepositBalance()).be.eq(twoBNB);
    await expect(strategy.panic()).be.revertedWith("underflowed or overflowed");

    // case 3
    await masterVault.deposit({ value: oneBNB });
    expect(await strategy.bnbDepositBalance()).be.eq(threeBNB);
    expect(await strategy.bnbxToUnstake()).be.eq(0);
    await masterVault.withdraw(deployer.address, oneBNB);
    expect(await strategy.bnbDepositBalance()).be.eq(twoBNB);
    expect(await strategy.bnbxToUnstake()).be.eq(oneBNB);
    await expect(strategy.panic()).be.revertedWith("underflowed or overflowed");
  });

  it("panic succeeds", async () => {
    const threeBNB = parseEther("3");
    await masterVault.deposit({ value: threeBNB });
    expect(await strategy.bnbDepositBalance()).be.eq(threeBNB);
    expect(await bnbxToken.balanceOf(strategy.address)).eq(threeBNB);
    expect(await strategy.bnbxToUnstake()).be.eq(0);
    await strategy.panic();
    expect(await strategy.bnbDepositBalance()).be.eq(0);
    expect(await strategy.bnbxToUnstake()).be.eq(threeBNB);
  });

  it("batchWithdraw fails if invoked before 24 hours", async () => {
    await expect(strategy.batchWithdraw()).be.revertedWith(
      "Allowed once daily"
    );

    // increase block time by 5 hours
    await ethers.provider.send("evm_increaseTime", [3600 * 5]);
    await expect(strategy.batchWithdraw()).be.revertedWith(
      "Allowed once daily"
    );

    // increase block time by 20 hours, so total 25 hours
    await ethers.provider.send("evm_increaseTime", [3600 * 20]);
    await expect(strategy.batchWithdraw()).be.revertedWith(
      "No BNBx to unstake"
    );
  });

  it("batchWithdraw succeeds", async () => {
    await expect(strategy.batchWithdraw()).be.revertedWith(
      "Allowed once daily"
    );

    // increase block time by 24 hours
    await ethers.provider.send("evm_increaseTime", [3600 * 24]);
    await expect(strategy.batchWithdraw()).be.revertedWith(
      "No BNBx to unstake"
    );

    const oneBNB = parseEther("1");
    const twoBNB = parseEther("2");
    const threeBNB = parseEther("3");

    await masterVault.deposit({ value: threeBNB });
    expect(await strategy.bnbDepositBalance()).be.eq(threeBNB);
    expect(await bnbxToken.balanceOf(strategy.address)).eq(threeBNB);
    expect(await strategy.bnbxToUnstake()).be.eq(0);

    await masterVault.withdraw(deployer.address, oneBNB);
    await masterVault.withdraw(user.address, oneBNB);
    expect(await strategy.bnbDepositBalance()).be.eq(oneBNB);
    expect(await bnbxToken.balanceOf(strategy.address)).eq(threeBNB);
    expect(await strategy.bnbxToUnstake()).be.eq(twoBNB);

    await strategy.batchWithdraw();
    expect(await strategy.bnbxToUnstake()).be.eq(0);
  });

  it("claimNextBatch", async () => {
    const twoBNB = parseEther("2");
    const threeBNB = parseEther("3");

    // send 3 BNB to bnbxStakeManager so that it has funds
    await deployer.sendTransaction({
      to: bnbxStakeManager.address,
      value: threeBNB,
    });

    expect(await ethers.provider.getBalance(strategy.address)).be.eq(0);
    expect(await strategy.bnbToDistribute()).be.eq(0);

    // always claims 2 BNB, as it is hardcoded in bnbx stakeManager mock
    await strategy.claimNextBatch();
    expect(await ethers.provider.getBalance(strategy.address)).be.eq(twoBNB);
    expect(await strategy.bnbToDistribute()).be.eq(twoBNB);
  });

  it("distributeFund", async () => {
    const oneBNB = parseEther("1");
    const twoBNB = parseEther("2");
    const threeBNB = parseEther("3");

    // send 3 BNB to bnbxStakeManager so that it has funds
    await deployer.sendTransaction({
      to: bnbxStakeManager.address,
      value: threeBNB,
    });

    await masterVault.deposit({ value: twoBNB });
    await masterVault.withdraw(deployer.address, oneBNB);
    await masterVault.withdraw(user.address, oneBNB);

    // increase time by 24 hours
    await ethers.provider.send("evm_increaseTime", [3600 * 24]);
    await strategy.batchWithdraw();

    expect(await strategy.bnbToDistribute()).be.eq(0);
    // always claims 2 BNB, as it is hardcoded in bnbx stakeManager mock
    await strategy.claimNextBatch();
    expect(await strategy.bnbToDistribute()).be.eq(twoBNB);

    const deployerPrevBalance = await ethers.provider.getBalance(
      deployer.address
    );
    const userPrevBalance = await ethers.provider.getBalance(user.address);

    await strategy.distributeFund(5);
    expect(await strategy.bnbToDistribute()).be.eq(0);
    expect(await ethers.provider.getBalance(deployer.address)).be.gt(
      deployerPrevBalance
    );
    expect(await ethers.provider.getBalance(user.address)).be.eq(
      userPrevBalance.add(oneBNB)
    );
  });

  it("claimNextBatchAndDistribute", async () => {
    const oneBNB = parseEther("1");
    const twoBNB = parseEther("2");
    const threeBNB = parseEther("3");

    // send 3 BNB to bnbxStakeManager so that it has funds
    await deployer.sendTransaction({
      to: bnbxStakeManager.address,
      value: threeBNB,
    });

    await masterVault.deposit({ value: twoBNB });
    await masterVault.withdraw(deployer.address, oneBNB);
    await masterVault.withdraw(user.address, oneBNB);

    // increase time by 24 hours
    await ethers.provider.send("evm_increaseTime", [3600 * 24]);
    await strategy.batchWithdraw();

    const deployerPrevBalance = await ethers.provider.getBalance(
      deployer.address
    );
    const userPrevBalance = await ethers.provider.getBalance(user.address);

    // always claims 2 BNB, as it is hardcoded in bnbx stakeManager mock
    await strategy.claimNextBatchAndDistribute(4);

    expect(await strategy.bnbToDistribute()).be.eq(0);
    expect(await ethers.provider.getBalance(deployer.address)).be.gt(
      deployerPrevBalance
    );
    expect(await ethers.provider.getBalance(user.address)).be.eq(
      userPrevBalance.add(oneBNB)
    );
  });

  it("Manual Distribute", async () => {
    const oneBNB = parseEther("1");
    const twoBNB = parseEther("2");
    const threeBNB = parseEther("3");

    mockReceiver = await (
      await ethers.getContractFactory("ReceiverMock")
    ).deploy();
    await mockReceiver.deployed();

    // send 3 BNB to bnbxStakeManager so that it has funds
    await deployer.sendTransaction({
      to: bnbxStakeManager.address,
      value: threeBNB,
    });

    await masterVault.deposit({ value: threeBNB });
    await masterVault.withdraw(mockReceiver.address, twoBNB);

    // increase time by 24 hours
    await ethers.provider.send("evm_increaseTime", [3600 * 24]);
    await strategy.batchWithdraw();

    const receiverPrevBalance = await ethers.provider.getBalance(
      mockReceiver.address
    );

    expect(await strategy.bnbToDistribute()).be.eq(0);
    // always claims 2 BNB, as it is hardcoded in bnbx stakeManager mock
    await strategy.claimNextBatch();
    expect(await strategy.bnbToDistribute()).be.eq(twoBNB);

    await strategy.distributeFund(5);
    expect(await strategy.bnbToDistribute()).be.eq(twoBNB); // bnbToDistribute still 2, means it was unable to distribute
    expect(await ethers.provider.getBalance(mockReceiver.address)).be.eq(
      receiverPrevBalance
    );

    // lets try manual distribute, which has no gas restriction
    await strategy.distributeManual(mockReceiver.address);
    expect(await strategy.bnbToDistribute()).be.eq(0);
    expect(await ethers.provider.getBalance(mockReceiver.address)).be.eq(
      receiverPrevBalance.add(twoBNB)
    );

    // lets try again, it should fail
    await expect(
      strategy.distributeManual(mockReceiver.address)
    ).be.revertedWith("!distributeManual");
  });

  it("harvest fails, when no yield", async () => {
    await expect(strategy.harvest()).be.revertedWith("no yield to harvest");

    await masterVault.deposit({ value: parseEther("2") });
    await expect(strategy.harvest()).be.revertedWith("no yield to harvest");
  });

  it("harvest succeeds, when bnbx/bnb exchange rate increases", async () => {
    await masterVault.deposit({ value: parseEther("2") });
    expect(await bnbxToken.balanceOf(strategy.address)).be.eq(parseEther("2"));
    await expect(strategy.harvest()).be.revertedWith("no yield to harvest");

    await bnbxStakeManager.changeER(parseEther("5"));
    await strategy.harvest();
    // bnbx left in strategy = 0.4 ( = bnbDepositBalance / ER)
    expect(await bnbxToken.balanceOf(strategy.address)).be.eq(
      parseEther("0.4")
    );
    expect(await bnbxToken.balanceOf(rewardsAddr.address)).be.eq(
      parseEther("1.6")
    );
  });

  it("change bnbxStakeManager", async () => {
    await expect(
      strategy.changeStakeManager(ethers.constants.AddressZero)
    ).be.revertedWith("zero address");

    await expect(
      strategy.changeStakeManager(bnbxStakeManager.address)
    ).be.revertedWith("old address provided");

    await expect(strategy.changeStakeManager(rewardsAddr.address))
      .emit(strategy, "StakeManagerChanged")
      .withArgs(rewardsAddr.address);
  });

  it("misc", async () => {
    const amount = parseEther("2.2");
    expect(await strategy.assessDepositFee(amount)).be.eq(amount);
  });
});
