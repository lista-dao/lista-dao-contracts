const { describe, it, before } = require("mocha");
const hre = require("hardhat");
const { ethers  } = hre;

describe("MultiOracles", function () {
  this.timeout(0); // never timeout

  let priceFeedA, priceFeedB, priceFeedC;
  let priceFeedAddressA, priceFeedAddressB, priceFeedAddressC;

  const BNB = '0x1A26d803C2e796601794f8C5609549643832702C';

  before(async () => {
    // deploy all price feeds
    const PriceFeed = await ethers.getContractFactory("PriceFeedMock");
    priceFeedA = await PriceFeed.deploy(10);
    await priceFeedA.waitForDeployment();
    priceFeedAddressA = await priceFeedA.getAddress();
    console.log("PriceFeed A deployed to:", priceFeedAddressA);

    priceFeedB = await PriceFeed.deploy(10);
    await priceFeedB.waitForDeployment();
    priceFeedAddressB = await priceFeedB.getAddress();
    console.log("PriceFeed B deployed to:", priceFeedAddressB);

    priceFeedC = await PriceFeed.deploy(10);
    await priceFeedC.waitForDeployment();
    priceFeedAddressC = await priceFeedC.getAddress();
    console.log("PriceFeed C deployed to:", priceFeedAddressC);
  });

  /** @NOTE:
   * priceFeed A: Main,
   * priceFeed B: Pivot,
   * priceFeed C: Fallback
   * */
  it("venus approach", async () => {

    // deploy bound validator
    const BoundValidator = await ethers.getContractFactory("BoundValidator");
    const boundValidator = await BoundValidator.deploy(10);
    await boundValidator.waitForDeployment();
    const boundValidatorAddress = await boundValidator.getAddress();
    // console.log("BoundValidator deployed to:", boundValidatorAddress);

    // deploy resilient oracle (that's how Venus called it)
    const ResilientOracle = await ethers.getContractFactory("ResilientOracleMock");
    const resilientOracle = await ResilientOracle.deploy(boundValidatorAddress);
    await resilientOracle.waitForDeployment();
    const resilientOracleAddress = await resilientOracle.getAddress();
    // console.log("ResilientOracle deployed to:", resilientOracleAddress);

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

    // deploy master-slave oracle
    const MasterSlaveOracle = await ethers.getContractFactory("MasterSlaveOracle");
    const masterSlaveOracle = await MasterSlaveOracle.deploy();
    await masterSlaveOracle.waitForDeployment();
    const masterSlaveOracleAddress = await masterSlaveOracle.getAddress();

    await masterSlaveOracle.setOracle(BNB, priceFeedAddressA, priceFeedAddressB);

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
