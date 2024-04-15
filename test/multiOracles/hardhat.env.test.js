const { describe, it, before } = require("mocha");
const hre = require("hardhat");
const { ethers  } = hre;

describe("MultiOracles", function () {
  this.timeout(0); // never timeout

  let priceFeedA, priceFeedB, priceFeedC;
  let priceFeedAddressA, priceFeedAddressB, priceFeedAddressC;

  const BNB = '0x1A26d803C2e796601794f8C5609549643832702C';

  // fl : failure interval, returns fail when block number % fl == 0
  async function deployPriceFeeds(flA = 0, flB = 0, flC = 0) {
    // deploy all price feeds
    const PriceFeed = await ethers.getContractFactory("PriceFeedMock");
    priceFeedA = await PriceFeed.deploy(flA);
    await priceFeedA.waitForDeployment();
    priceFeedAddressA = await priceFeedA.getAddress();
    console.log("PriceFeed A deployed to:", priceFeedAddressA);

    priceFeedB = await PriceFeed.deploy(flB);
    await priceFeedB.waitForDeployment();
    priceFeedAddressB = await priceFeedB.getAddress();
    console.log("PriceFeed B deployed to:", priceFeedAddressB);

    priceFeedC = await PriceFeed.deploy(flC);
    await priceFeedC.waitForDeployment();
    priceFeedAddressC = await priceFeedC.getAddress();
    console.log("PriceFeed C deployed to:", priceFeedAddressC);
  }

  /** @NOTE:
   * priceFeed A: Main,
   * priceFeed B: Pivot,
   * priceFeed C: Fallback
   * */
  it("venus approach", async () => {

    // deploy price feeds
    // deployPriceFeeds(10, 0, 0) means Main oracle fails every 10 blocks, pivot oracle and fallback oracle never fails
    await deployPriceFeeds(0, 10 , 0);

    // deploy bound validator
    const BoundValidator = await ethers.getContractFactory("BoundValidator");
    const boundValidator = await BoundValidator.deploy();
    await boundValidator.waitForDeployment();
    const boundValidatorAddress = await boundValidator.getAddress();

    // deploy resilient oracle (that's how Venus called it)
    const ResilientOracle = await ethers.getContractFactory("ResilientOracleMock");
    const resilientOracle = await ResilientOracle.deploy(boundValidatorAddress);
    await resilientOracle.waitForDeployment();
    const resilientOracleAddress = await resilientOracle.getAddress();

    // set oracles
    await resilientOracle.setTokenConfig([
      BNB,
      [priceFeedAddressA, priceFeedAddressB, priceFeedAddressC],
      [true, true, true]
    ]);

    // deploy consumer contract
    const ConsumerMock = await ethers.getContractFactory("ConsumerMock");
    const consumerMock = await ConsumerMock.deploy(resilientOracleAddress);

    let succeededTimes = 0, failureTimes = 0;

    for (let i = 0; i < 100; i++) {
      try {
        await consumerMock.storePrice(BNB);
        succeededTimes++;
      }
      catch (e) { failureTimes++; }
    }
    console.log('Price written with successful rate:', (succeededTimes / (succeededTimes + failureTimes))*100, '%');

  });

  it("master-slave approach", async () => {

    // deployPriceFeeds(10, 0) means Main oracle fails every 10 blocks, fallback oracle never fails
    await deployPriceFeeds(10, 0);

    // deploy master-slave oracle
    const MasterSlaveOracle = await ethers.getContractFactory("MasterSlaveOracle");
    const masterSlaveOracle = await MasterSlaveOracle.deploy();
    await masterSlaveOracle.waitForDeployment();
    const masterSlaveOracleAddress = await masterSlaveOracle.getAddress();

    await masterSlaveOracle.setTokenConfig([
      BNB,
      [priceFeedAddressA, priceFeedAddressB],
      [true, true]
    ]);

    // deploy consumer contract
    const ConsumerMock = await ethers.getContractFactory("ConsumerMock");
    const consumerMock = await ConsumerMock.deploy(masterSlaveOracleAddress);

    let succeededTimes = 0, failureTimes = 0;
    for (let i = 0; i < 100; i++) {
      try {
        await consumerMock.storePrice(BNB);
        succeededTimes++;
      }
      catch (e) { failureTimes++; }
    }
    console.log('Price written with successful rate:', (succeededTimes / (succeededTimes + failureTimes))*100, '%');

  });


})
