const { describe, it, before } = require("mocha");
const hre = require("hardhat");
const { ethers  } = hre;

describe("MultiOracles", function () {
  this.timeout(0); // never timeout

  // BNB Price Feed
  const CHAINLINK_ORACLE_ADDRESS = '0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526';
  const BINANCE_ORACLE_ADDRESS = '0x1A26d803C2e796601794f8C5609549643832702C';
  const BNB = '0x1A26d803C2e796601794f8C5609549643832702C';

  /** @NOTE:
   * priceFeed A: Main,
   * priceFeed B: Pivot,
   * priceFeed C: Fallback
   * */
  it("venus approach", async () => {

    // deploy bound validator
    const BoundValidator = await ethers.getContractFactory("BoundValidatorTestnet");
    const boundValidator = await BoundValidator.deploy();
    await boundValidator.waitForDeployment();
    const boundValidatorAddress = await boundValidator.getAddress();

    // deploy resilient oracle (that's how Venus called it)
    const ResilientOracle = await ethers.getContractFactory("ResilientOracleTestnet");
    const resilientOracle = await ResilientOracle.deploy(boundValidatorAddress);
    await resilientOracle.waitForDeployment();
    const resilientOracleAddress = await resilientOracle.getAddress();
    console.log('Venus resilientOracleAddress:', resilientOracleAddress);

    // set oracles
    await resilientOracle.setTokenConfig([
      BNB,
      [CHAINLINK_ORACLE_ADDRESS, BINANCE_ORACLE_ADDRESS, BINANCE_ORACLE_ADDRESS],
      [true, true, true]
    ]);

    // deploy consumer contract
    const ConsumerMock = await ethers.getContractFactory("ConsumerTestnetMock");
    const consumerMock = await ConsumerMock.deploy(resilientOracleAddress);
    await consumerMock.waitForDeployment();await consumerMock.waitForDeployment();
    const consumerMockAddress = await consumerMock.getAddress();

    console.log('Venus consumerMockAddress:', consumerMockAddress);
  });

  it("master-slave approach", async () => {

    // deploy master-slave oracle
    const MasterSlaveOracle = await ethers.getContractFactory("MasterSlaveOracleTestnet");
    const masterSlaveOracle = await MasterSlaveOracle.deploy();
    await masterSlaveOracle.waitForDeployment();
    const masterSlaveOracleAddress = await masterSlaveOracle.getAddress();
    console.log('master-slave oracle address:', masterSlaveOracleAddress);

    await masterSlaveOracle.setTokenConfig([
      BNB,
      [BINANCE_ORACLE_ADDRESS, CHAINLINK_ORACLE_ADDRESS],
      [true, true]
    ]);

    // deploy consumer contract
    const ConsumerMock = await ethers.getContractFactory("ConsumerTestnetMock");
    const consumerMock = await ConsumerMock.deploy(masterSlaveOracleAddress);
    await consumerMock.waitForDeployment();
    const consumerMockAddress = await consumerMock.getAddress();

    console.log('master-slave consumerMockAddress:', consumerMockAddress);
  });


})
