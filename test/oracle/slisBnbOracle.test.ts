import { ethers } from "hardhat";
import hre from "hardhat";
import { it, describe } from "mocha";

describe("SlisBnbOracle", function () {
  it("oracle return price data and bool as expected", async () => {
    hre.network.name = 'hardhat';
    const FeedAdapter = await ethers.getContractFactory("FeedAdaptorMock");
    const feedAdapter = await FeedAdapter.deploy();
    await feedAdapter.deployed();
    console.log("Deployed: FeedAdaptor         :", feedAdapter.address);

    const StakeManager = await ethers.getContractFactory("StakeManagerMock");
    const stakeManager = await StakeManager.deploy();
    await stakeManager.deployed();
    console.log("Deployed: StakeManager        :", stakeManager.address);

    const SlisBnbOracle = await ethers.getContractFactory("SlisBnbOracleHardhat");
    const slisBnbOracle = await SlisBnbOracle.deploy(feedAdapter.address, stakeManager.address);
    await slisBnbOracle.deployed();
    console.log("Deployed: SlisBnbOracleHardhat: " + slisBnbOracle.address);

    const peekResult = await slisBnbOracle.peek();
    console.log("Result: peek()                : ", peekResult);
    const [priceInBytes32, ] = peekResult;
    console.log("Reullt: price                 : ", priceInBytes32);
  });
});
