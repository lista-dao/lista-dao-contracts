const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

const NetworkSnapshotter = require("../helpers/NetworkSnapshotter");

const ten = BigNumber.from(10);
const tenPow18 = ten.pow(18);

describe("CeToken", () => {
  let deployer;
  let signer1;
  let vault;

  let ceToken;

  const networkSnapshotter = new NetworkSnapshotter();

  before("setup", async () => {
    [deployer, signer1, vault] = await ethers.getSigners();
    const CeToken = await ethers.getContractFactory("CeToken");
    ceToken = await CeToken.deploy();
    await ceToken.deployed();
    await ceToken.initialize("ceaBNBc", "CEBNB");

    await ceToken.changeVault(vault.address);

    await networkSnapshotter.firstSnapshot();
  });

  afterEach("revert", async () => await networkSnapshotter.revert());

  it("Only Minter can call burn/mint functions", async () => {
    await expect(
      ceToken.connect(signer1).mint(signer1.address, tenPow18)
    ).to.be.revertedWith("Minter: not allowed");
    await expect(
      ceToken.connect(signer1).burn(signer1.address, tenPow18)
    ).to.be.revertedWith("Minter: not allowed");
    await expect(ceToken.connect(vault).mint(signer1.address, tenPow18)).not.to
      .be.reverted;
    await expect(ceToken.connect(vault).burn(signer1.address, tenPow18)).not.to
      .be.reverted;
  });

  it("Only Owner can change a minter", async () => {
    await expect(
      ceToken.connect(signer1).changeVault(signer1.address)
    ).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(ceToken.connect(deployer).changeVault(signer1.address)).not.to
      .be.reverted;
    expect(await ceToken.getVaultAddress()).eq(signer1.address);
  });

  it("mint/burn works", async () => {
    let bal = await ceToken.balanceOf(signer1.address);
    await ceToken.connect(vault).mint(signer1.address, tenPow18);
    expect(await ceToken.balanceOf(signer1.address)).eq(bal.add(tenPow18));
    bal = await ceToken.balanceOf(signer1.address);
    await ceToken.connect(vault).burn(signer1.address, tenPow18);
    expect(await ceToken.balanceOf(signer1.address)).eq(bal.sub(tenPow18));
  });
});
