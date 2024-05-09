const { describe, it, before } = require("mocha");
const hre = require("hardhat");
const {expect} = require("chai");
const { ethers, upgrades  } = hre;

describe("MultiOracles", function () {
  this.timeout(0); // never timeout

  // BNB Price Feed
  const CHAINLINK_ORACLE_ADDRESS = '0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526';
  const BINANCE_ORACLE_ADDRESS = '0x1A26d803C2e796601794f8C5609549643832702C';
  const TOKEN = '0x1A26d803C2e796601794f8C5609549643832702C';

  let boundValidator, resilientOracle, mainOracle, pivotOracle, fallbackOracle,
    mainOracleAddress = BINANCE_ORACLE_ADDRESS,
    pivotOracleAddress = CHAINLINK_ORACLE_ADDRESS,
    fallbackOracleAddress = BINANCE_ORACLE_ADDRESS;

  /** @NOTE:
   * priceFeed A: Main,
   * priceFeed B: Pivot,
   * priceFeed C: Fallback
   * */
  beforeEach(async () => {
    // Deploy BoundValidator
    const BoundValidator = await ethers.getContractFactory("BoundValidator");
    boundValidator = await upgrades.deployProxy(BoundValidator);
    await boundValidator.waitForDeployment();

    let boundValidatorImplementation = await upgrades.erc1967.getImplementationAddress(boundValidator.target, [], { initializer: "initialize" });
    console.log("Deployed: BoundValidator    : " + boundValidator.target);
    console.log("Imp                         : " + boundValidatorImplementation);

    // Deploy resilientOracle
    const ResilientOracle = await ethers.getContractFactory("ResilientOracle");
    resilientOracle = await upgrades.deployProxy(ResilientOracle, [boundValidator.target], { initializer: "initialize" });
    await resilientOracle.waitForDeployment();

    let resilientOracleImplementation = await upgrades.erc1967.getImplementationAddress(resilientOracle.target);
    console.log("Deployed: ResilientOracle    : " + resilientOracle.target);
    console.log("Imp                          : " + resilientOracleImplementation);

    if (hre.network.name === 'hardhat') {
      // deploy main oracle
      const MockSourceOracle = await ethers.getContractFactory('MockSourceOracle');
      mainOracle = await MockSourceOracle.deploy();
      await mainOracle.waitForDeployment();
      mainOracleAddress = await mainOracle.getAddress();
      console.log("Deployed: MainOracle         : " + mainOracleAddress);

      pivotOracle = await MockSourceOracle.deploy();
      await pivotOracle.waitForDeployment();
      pivotOracleAddress = await pivotOracle.getAddress();
      console.log("Deployed: pivotOracle        : " + pivotOracleAddress);

      fallbackOracle = await MockSourceOracle.deploy();
      await fallbackOracle.waitForDeployment();
      fallbackOracleAddress = await fallbackOracle.getAddress();
      console.log("Deployed: fallbackOracle     : " + fallbackOracleAddress);
    }
    // set token config
    await resilientOracle.setTokenConfig([
      TOKEN,
      [mainOracleAddress, pivotOracleAddress, fallbackOracleAddress],
      [true, true, true],
      300 // 300 seconds
    ]);
    console.log('Token config set.');

    // set bound validator config
    await boundValidator.setValidateConfig([
      TOKEN,
      '1010000000000000000',
      '990000000000000000'
    ]);
    console.log('Validation config set.');
  })

  it("get main price", async () => {
    const updateTimestamp = parseInt(Date.now()/1000);

    await mainOracle.setPrice(1000000000006789);
    await pivotOracle.setPrice(1000000000000010);
    await fallbackOracle.setPrice(1000000000000000);
    await mainOracle.setUpdateTimestamp(updateTimestamp);
    await pivotOracle.setUpdateTimestamp(updateTimestamp);
    await fallbackOracle.setUpdateTimestamp(updateTimestamp);
    const price = await resilientOracle.peek(TOKEN);
    console.log("Price: " + price.toString());
    expect(price.toString()).to.be.equal('1000000000006789');
  });

  it("get fallback price", async () => {
    const updateTimestamp = parseInt(Date.now()/1000);

    await mainOracle.setPrice(2000000000000010);
    await pivotOracle.setPrice(1000000000000010);
    await fallbackOracle.setPrice(1000000000001234);

    await mainOracle.setUpdateTimestamp(updateTimestamp - 500);
    await pivotOracle.setUpdateTimestamp(updateTimestamp);
    await fallbackOracle.setUpdateTimestamp(updateTimestamp);

    const price = await resilientOracle.peek(TOKEN);
    console.log("Price: " + price.toString());
    expect(price.toString()).to.be.equal('1000000000001234');
  });

  it("main zero", async () => {
    const updateTimestamp = parseInt(Date.now()/1000);

    await mainOracle.setPrice(0);
    await pivotOracle.setPrice(1000000000000010);
    await fallbackOracle.setPrice(1000000000001122);

    await mainOracle.setUpdateTimestamp(updateTimestamp);
    await pivotOracle.setUpdateTimestamp(updateTimestamp);
    await fallbackOracle.setUpdateTimestamp(updateTimestamp);

    const price = await resilientOracle.peek(TOKEN);
    console.log("Price: " + price.toString());
    expect(price.toString()).to.be.equal('1000000000001122');
  });

  it("main negative", async () => {
    const updateTimestamp = parseInt(Date.now()/1000);

    await mainOracle.setPrice(-10000000000000);
    await pivotOracle.setPrice(1000000000000010);
    await fallbackOracle.setPrice(1000000000001122);

    await mainOracle.setUpdateTimestamp(updateTimestamp - 500);
    await pivotOracle.setUpdateTimestamp(updateTimestamp);
    await fallbackOracle.setUpdateTimestamp(updateTimestamp);

    const price = await resilientOracle.peek(TOKEN);
    console.log("Price: " + price.toString());
    expect(price.toString()).to.be.equal('1000000000001122');
  })

  it("pivot failed", async () => {
    const updateTimestamp = parseInt(Date.now()/1000);

    await mainOracle.setPrice(1000000000003344);
    await pivotOracle.setPrice(0);
    await fallbackOracle.setPrice(1000000000000000);

    await mainOracle.setUpdateTimestamp(updateTimestamp - 500);
    await pivotOracle.setUpdateTimestamp(updateTimestamp);
    await fallbackOracle.setUpdateTimestamp(updateTimestamp);

    const price =  await resilientOracle.peek(TOKEN);
    console.log("Price: " + price.toString());
    expect(price.toString()).to.be.equal('1000000000003344');
  });

  it("toasted", async () => {
    const updateTimestamp = parseInt(Date.now()/1000);

    await mainOracle.setPrice(2000000000003344);
    await pivotOracle.setPrice(0);
    await fallbackOracle.setPrice(1000000000000000);

    await mainOracle.setUpdateTimestamp(updateTimestamp - 500);
    await pivotOracle.setUpdateTimestamp(updateTimestamp);
    await fallbackOracle.setUpdateTimestamp(updateTimestamp);

    try {
      const price = await resilientOracle.peek(TOKEN);
      console.log("Price: " + price.toString());
    } catch(e) {
      // e.message: VM Exception while processing transaction: reverted with reason string 'invalid resilient oracle price'
      expect(/invalid resilient oracle price/.test(e.message)).to.be.true;
    }
  });
})
