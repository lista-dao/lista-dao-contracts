// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "../libraries/FullMath.sol";

/**
  * @title sUSD1PriceFeed
  * @dev Contract provides sUSD1/USD in 8 DPs
  */
contract sUSD1PriceFeed {

  IResilientOracle public resilientOracle;
  AggregatorV3Interface public sUSD1_USD1_PriceFeed;
  address public constant USD1_TOKEN_ADDR = 0x8d0D000Ee44948FC98c9B98A4FA4921476f08B0d;

  /**
    * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    * @param _sUSD1_USD1_PriceFeed The address of the sUSD1/USD1 price feed contract (ChainLink)
    */
  constructor(address _resilientOracle, address _sUSD1_USD1_PriceFeed) {
    require(_resilientOracle != address(0) && _sUSD1_USD1_PriceFeed != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
    sUSD1_USD1_PriceFeed = AggregatorV3Interface(_sUSD1_USD1_PriceFeed);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "sUSD1/USD Price Feed";
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function latestAnswer() external view returns (int256 answer) {
    // get price
    uint256 price = getPrice();
    // cast price to int256
    answer = int256(price);
  }

  function latestRoundData()
  external
  view
  returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  ) {
    // get price
    uint256 _answer = getPrice();
    // mock timestamp to latest block timestamp
    uint256 timestamp = block.timestamp;
    // mock roundId to timestamp
    roundId = uint80(timestamp);
    return (
      roundId,
      int256(_answer),
      timestamp,
      timestamp,
      roundId
    );
  }

  /**
    * @dev Get the price of sUSD1/USD in 8 DPs
    *      sUSD1/USD1 from chainlink and USD1/USD prices from Resilient Oracle
    *      multiply them and divide by 1e8
    * @return price The price of sUSD1/USD in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // (1) sUSD1/USD1 in 18 DPs
    (
    /*uint80 roundID*/,
      int sUSD1_USD1_Price,
    /*uint startedAt*/,
      uint updatedAt1,
    /*uint80 answeredInRound*/
    ) = sUSD1_USD1_PriceFeed.latestRoundData();

    require(sUSD1_USD1_Price > 0, "sUSD1_USD1_PriceFeed/price-not-valid");
    require(block.timestamp - updatedAt1 < (24 * 3600 + 300), "sUSD1_USD1_PriceFeed/timestamp-too-old");

    // (2) USD1/USD in 8 DPs
    uint256 USD1_Usd_Price = resilientOracle.peek(USD1_TOKEN_ADDR);

    return FullMath.mulDiv(uint256(sUSD1_USD1_Price), USD1_Usd_Price, 1e18);
  }

}
