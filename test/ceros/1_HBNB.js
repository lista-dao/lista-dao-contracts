const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

const NetworkSnapshotter = require("../helpers/NetworkSnapshotter");

const ten = BigNumber.from(10);
const tenPow18 = ten.pow(18);

describe("HBNB", () => {
  let deployer;
  let signer1;
  let minter;

  let hBNB;

  const networkSnapshotter = new NetworkSnapshotter();

  before("setup", async () => {
    [deployer, signer1, minter] = await ethers.getSigners();
    // eslint-disable-next-line camelcase
    const HBNB = (await ethers.getContractFactory("hBNB"));
    hBNB = await HBNB.deploy();
    await hBNB.deployed();
    await hBNB.initialize();

    await hBNB.changeMinter(minter.address);

    await networkSnapshotter.firstSnapshot();
  });

  afterEach("revert", async () => await networkSnapshotter.revert());

  it("Only Minter can call burn/mint functions", async () => {
    await expect(hBNB.connect(signer1).mint(signer1.address, tenPow18)).to.be.revertedWith(
      "Minter: not allowed"
    );
    await expect(hBNB.connect(signer1).burn(signer1.address, tenPow18)).to.be.revertedWith(
      "Minter: not allowed"
    );
    await expect(hBNB.connect(minter).mint(signer1.address, tenPow18)).not.to.be.reverted;
    await expect(hBNB.connect(minter).burn(signer1.address, tenPow18)).not.to.be.reverted;
  });

  it("Only Owner can change a minter", async () => {
    await expect(hBNB.connect(signer1).changeMinter(signer1.address)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    );
    await expect(hBNB.connect(deployer).changeMinter(signer1.address)).not.to.be.reverted;
    expect(await hBNB.getMinter()).eq(signer1.address);
  });

  it("mint/burn works", async () => {
    let bal = await hBNB.balanceOf(signer1.address);
    await hBNB.connect(minter).mint(signer1.address, tenPow18);
    expect(await hBNB.balanceOf(signer1.address)).eq(bal.add(tenPow18));
    bal = await hBNB.balanceOf(signer1.address);
    await hBNB.connect(minter).burn(signer1.address, tenPow18);
    expect(await hBNB.balanceOf(signer1.address)).eq(bal.sub(tenPow18));
  });

  it("non-transferable part works well", async () => {
    await hBNB.connect(minter).mint(signer1.address, tenPow18);
    expect(await hBNB.allowance(deployer.address, signer1.address)).eq(0);
    const errMessage = "Not transferable";
    await expect(hBNB.connect(signer1).approve(deployer.address, tenPow18)).to.be.revertedWith(
      errMessage
    );
    await expect(hBNB.connect(signer1).transfer(deployer.address, tenPow18)).to.be.revertedWith(
      errMessage
    );
    await expect(
      hBNB.connect(signer1).transferFrom(signer1.address, deployer.address, tenPow18)
    ).to.be.revertedWith(errMessage);
  });
});
