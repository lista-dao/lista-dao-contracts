const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

const NetworkSnapshotter = require("../helpers/NetworkSnapshotter");

const ten = BigNumber.from(10);
const tenPow18 = ten.pow(18);

const { AddressZero } = ethers.constants;

describe("CeVault", () => {
  let deployer;
  let signer1;
  let signer2;
  let fakeRouter;

  let abnbc;
  let vault;
  let ceToken;

  let inBeforeBlock = false;

  const networkSnapshotter = new NetworkSnapshotter();

  before("setup", async () => {
    [deployer, signer1, signer2, fakeRouter] = await ethers.getSigners();
    const CeToken = await ethers.getContractFactory("CeToken");
    const ABNBC = await ethers.getContractFactory("ABNBC");
    const CeVault = await ethers.getContractFactory("CeVault");

    // deploy aBNBc
    abnbc = await ABNBC.deploy();
    await abnbc.deployed();
    // deploy ceToken
    ceToken = await CeToken.deploy();
    await ceToken.deployed();
    await ceToken.initialize("ceaBNBc", "CEBNB");
    // deploy ceVault
    vault = await CeVault.deploy();
    await vault.deployed();
    await vault.initialize("ceaBNBc", ceToken.address, abnbc.address);

    await ceToken.changeVault(vault.address);
    await vault.changeRouter(fakeRouter.address);

    await networkSnapshotter.firstSnapshot();
  });

  afterEach("revert", async () => {
    if (!inBeforeBlock) {
      await networkSnapshotter.revert();
    }
  });

  it("initial values", async () => {
    expect(await vault.getCeToken()).eq(ceToken.address);
    expect(await vault.getAbnbcAddress()).eq(abnbc.address);
    expect(await vault.getRouter()).eq(fakeRouter.address);
    expect(await vault.getName()).eq("ceaBNBc");
  });

  it("only Owner can change router address", async () => {
    await expect(vault.connect(signer1).changeRouter(signer1.address)).revertedWith(
      "Ownable: caller is not the owner"
    );
    await vault.connect(deployer).changeRouter(signer1.address);
    expect(await vault.getRouter()).eq(signer1.address);
  });

  it("only router can call depositFor/withdrawFor/claimYieldsFor functions", async () => {
    const errMessage = "Router: not allowed";
    await expect(vault.connect(signer1).depositFor(AddressZero, 0)).revertedWith(errMessage);
    await expect(vault.connect(signer1).withdrawFor(AddressZero, AddressZero, 0)).revertedWith(
      errMessage
    );
    await expect(vault.connect(signer1).claimYieldsFor(AddressZero, AddressZero)).revertedWith(
      errMessage
    );
  });

  describe("interactive test", () => {
    const userInitialBal = tenPow18.mul("10000");
    before("setup", async () => {
      await abnbc.mint(signer2.address, userInitialBal);
      await abnbc.connect(signer2).approve(vault.address, ethers.constants.MaxUint256);
      expect(await abnbc.balanceOf(signer2.address)).eq(userInitialBal);
      inBeforeBlock = true;
    });

    it("deposit - 1000, ratio - 1", async () => {
      const ratio = tenPow18;
      await abnbc.setRatio(ratio);
      const amt = to18Dec("1000");
      await vault.connect(signer2).deposit(amt);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(amt);
      expect(vaultInfo.ceTokenBalance).eq(amt);
      expect(vaultInfo.claimed).eq(0);
      expect(vaultInfo.contractBal).eq(amt);
      expect(vaultInfo.userBal).eq(to18Dec("9000"));
    });

    it("deposit - 950, ratio - 0.95", async () => {
      const ratio = tenPow18.mul(95).div(100);
      await abnbc.setRatio(ratio);
      const amt = to18Dec("950");
      await vault.connect(signer2).deposit(amt);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("1950"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("2000"));
      expect(vaultInfo.claimed).eq(0);
      expect(vaultInfo.contractBal).eq(to18Dec("1950"));
      expect(vaultInfo.userBal).eq(to18Dec("8050"));
    });

    it("claimYields, ratio - 0.95", async () => {
      const ratio = tenPow18.mul(95).div(100);
      await abnbc.setRatio(ratio);
      await vault.connect(signer2).claimYields(signer2.address);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("1950"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("2000"));
      expect(vaultInfo.claimed).eq(to18Dec("50"));
      expect(vaultInfo.contractBal).eq(to18Dec("1900"));
      expect(vaultInfo.userBal).eq(to18Dec("8100"));
    });

    it("claimYields, ratio - 0.9", async () => {
      const ratio = tenPow18.mul(90).div(100);
      await abnbc.setRatio(ratio);
      await vault.connect(signer2).claimYields(signer2.address);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("1950"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("2000"));
      expect(vaultInfo.claimed).eq(to18Dec("150"));
      expect(vaultInfo.contractBal).eq(to18Dec("1800"));
      expect(vaultInfo.userBal).eq(to18Dec("8200"));
    });

    it("claimYields, ratio - 0.85", async () => {
      const ratio = tenPow18.mul(85).div(100);
      await abnbc.setRatio(ratio);
      await vault.connect(signer2).claimYields(signer2.address);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("1950"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("2000"));
      expect(vaultInfo.claimed).eq(to18Dec("250"));
      expect(vaultInfo.contractBal).eq(to18Dec("1700"));
      expect(vaultInfo.userBal).eq(to18Dec("8300"));
    });

    it("withdraw - 500, ratio - 0.85", async () => {
      const ratio = tenPow18.mul(85).div(100);
      await abnbc.setRatio(ratio);
      const amt = to18Dec("500");
      await vault.connect(signer2).withdraw(signer2.address, amt);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("1525"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("1500"));
      expect(vaultInfo.claimed).eq(to18Dec("250"));
      expect(vaultInfo.contractBal).eq(to18Dec("1275"));
      expect(vaultInfo.userBal).eq(to18Dec("8725"));
    });

    it("deposit - 800, ratio - 0.8", async () => {
      const ratio = tenPow18.mul(80).div(100);
      await abnbc.setRatio(ratio);
      const amt = to18Dec("800");
      await vault.connect(signer2).deposit(amt);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("2325"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("2500"));
      expect(vaultInfo.claimed).eq(to18Dec("250"));
      expect(vaultInfo.contractBal).eq(to18Dec("2075"));
      expect(vaultInfo.userBal).eq(to18Dec("7925"));
    });

    it("withdraw - 300, ratio - 0.75", async () => {
      const ratio = tenPow18.mul(75).div(100);
      await abnbc.setRatio(ratio);
      const amt = to18Dec("300");
      await vault.connect(signer2).withdraw(signer2.address, amt);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("2100"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("2200"));
      expect(vaultInfo.claimed).eq(to18Dec("250"));
      expect(vaultInfo.contractBal).eq(to18Dec("1850"));
      expect(vaultInfo.userBal).eq(to18Dec("8150"));
    });

    it("claimYields, ratio - 0.75", async () => {
      const ratio = tenPow18.mul(75).div(100);
      await abnbc.setRatio(ratio);
      await vault.connect(signer2).claimYields(signer2.address);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("2100"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("2200"));
      expect(vaultInfo.claimed).eq(to18Dec("450"));
      expect(vaultInfo.contractBal).eq(to18Dec("1650"));
      expect(vaultInfo.userBal).eq(to18Dec("8350"));
    });

    it("deposit - 750, ratio - 0.75", async () => {
      const ratio = tenPow18.mul(75).div(100);
      await abnbc.setRatio(ratio);
      const amt = to18Dec("750");
      await vault.connect(signer2).deposit(amt);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("2850"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("3200"));
      expect(vaultInfo.claimed).eq(to18Dec("450"));
      expect(vaultInfo.contractBal).eq(to18Dec("2400"));
      expect(vaultInfo.userBal).eq(to18Dec("7600"));
    });

    it("claimYields, ratio - 0.7", async () => {
      const ratio = tenPow18.mul(70).div(100);
      await abnbc.setRatio(ratio);
      await vault.connect(signer2).claimYields(signer2.address);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("2850"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("3200"));
      expect(vaultInfo.claimed).eq(to18Dec("610"));
      expect(vaultInfo.contractBal).eq(to18Dec("2240"));
      expect(vaultInfo.userBal).eq(to18Dec("7760"));
    });

    it("withdraw - 3200, ratio - 0.7", async () => {
      const ratio = tenPow18.mul(70).div(100);
      await abnbc.setRatio(ratio);
      const amt = to18Dec("3200");
      await vault.connect(signer2).withdraw(signer2.address, amt);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("610"));
      expect(vaultInfo.ceTokenBalance).eq(0);
      expect(vaultInfo.claimed).eq(to18Dec("610"));
      expect(vaultInfo.contractBal).eq(0);
      expect(vaultInfo.userBal).eq(userInitialBal);
    });

    after("revert", async () => {
      inBeforeBlock = false;
      await networkSnapshotter.revert();
    });

    const getVaultInfo = async (userAddr) => {
      const depositOf = await vault.getDepositOf(userAddr);
      const ceTokenBalance = await vault.getCeTokenBalanceOf(userAddr);
      const claimed = await vault.getClaimedOf(userAddr);
      const contractBal = await vault.getTotalAmountInVault();
      const userBal = await abnbc.balanceOf(userAddr);
      return {
        depositOf,
        ceTokenBalance,
        claimed,
        contractBal,
        userBal,
      };
    };

    const to18Dec = (num) => {
      const ten = BigNumber.from(10);
      const tenPow18 = ten.pow(18);
      return tenPow18.mul(num);
    };
  });

  describe("interactive test with router", () => {
    const userInitialBal = tenPow18.mul("10000");
    before("setup", async () => {
      await abnbc.mint(signer2.address, userInitialBal);
      await abnbc.connect(signer2).approve(vault.address, ethers.constants.MaxUint256);
      await abnbc.mint(fakeRouter.address, userInitialBal);
      await abnbc.connect(fakeRouter).approve(vault.address, ethers.constants.MaxUint256);
      expect(await abnbc.balanceOf(signer2.address)).eq(userInitialBal);
      inBeforeBlock = true;
    });

    it("deposit - 1000, ratio - 1", async () => {
      const ratio = tenPow18;
      await abnbc.setRatio(ratio);
      const amt = to18Dec("1000");
      await vault.connect(fakeRouter).depositFor(signer2.address, amt);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(amt);
      expect(vaultInfo.ceTokenBalance).eq(amt);
      expect(vaultInfo.claimed).eq(0);
      expect(vaultInfo.contractBal).eq(amt);
    });

    it("claimYields, ratio - 0.7", async () => {
      const ratio = tenPow18.mul(70).div(100);
      await abnbc.setRatio(ratio);
      await vault.connect(fakeRouter).claimYieldsFor(signer2.address, signer2.address);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("1000"));
      expect(vaultInfo.ceTokenBalance).eq(to18Dec("1000"));
      expect(vaultInfo.claimed).eq(to18Dec("300"));
      expect(vaultInfo.contractBal).eq(to18Dec("700"));
      expect(vaultInfo.userBal).eq(userInitialBal.add(to18Dec("300")));
    });

    it("withdraw - 1000, ratio - 0.7", async () => {
      const ratio = tenPow18.mul(70).div(100);
      await abnbc.setRatio(ratio);
      const amt = to18Dec("1000");
      await vault.connect(fakeRouter).withdrawFor(signer2.address, signer2.address, amt);
      const vaultInfo = await getVaultInfo(signer2.address);
      expect(vaultInfo.depositOf).eq(to18Dec("300"));
      expect(vaultInfo.ceTokenBalance).eq(0);
      expect(vaultInfo.claimed).eq(to18Dec("300"));
      expect(vaultInfo.contractBal).eq(0);
      expect(vaultInfo.userBal).eq(userInitialBal.add(amt));
    });

    after("revert", async () => {
      inBeforeBlock = false;
      await networkSnapshotter.revert();
    });

    const getVaultInfo = async (userAddr) => {
      const depositOf = await vault.getDepositOf(userAddr);
      const ceTokenBalance = await vault.getCeTokenBalanceOf(userAddr);
      const claimed = await vault.getClaimedOf(userAddr);
      const contractBal = await vault.getTotalAmountInVault();
      const userBal = await abnbc.balanceOf(userAddr);
      return {
        depositOf,
        ceTokenBalance,
        claimed,
        contractBal,
        userBal,
      };
    };

    const to18Dec = (num) => {
      const ten = BigNumber.from(10);
      const tenPow18 = ten.pow(18);
      return tenPow18.mul(num);
    };
  });
});
