// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "../libraries/FullMath.sol";

/**
  * @title SyrupUSDTPriceFeed
  * @dev Contract provides syrupUSDT/USD in 8 DPs
  */
contract SyrupUSDTPriceFeed {

  IResilientOracle public resilientOracle;
  AggregatorV3Interface public syrupUSDT_USDT_PriceFeed;
  address public constant USDT_TOKEN_ADDR = 0x55d398326f99059fF775485246999027B3197955;

  /**
    * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    * @param _syrupUSDT_USDT_PriceFeed The address of the syrupUSDT/USDT exchange rate price feed contract (ChainLink)
    */
  constructor(address _resilientOracle, address _syrupUSDT_USDT_PriceFeed) {
    require(_resilientOracle != address(0) && _syrupUSDT_USDT_PriceFeed != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
    syrupUSDT_USDT_PriceFeed = AggregatorV3Interface(_syrupUSDT_USDT_PriceFeed);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "syrupUSDT/USD Price Feed";
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
    * @dev Get the price of syrupUSDT/USD in 8 DPs
    *      syrupUSDT/USDT from ChainLink exchange rate feed and USDT/USD from Resilient Oracle
    *      multiply them and divide by 1e18
    * @return price The price of syrupUSDT/USD in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // (1) syrupUSDT/USDT exchange rate in 18 DPs
    (
    /*uint80 roundID*/,
      int syrupUSDT_USDT_Price,
    /*uint startedAt*/,
      uint updatedAt1,
    /*uint80 answeredInRound*/
    ) = syrupUSDT_USDT_PriceFeed.latestRoundData();

    require(syrupUSDT_USDT_Price > 0, "syrupUSDT_USDT_PriceFeed/price-not-valid");
    require(block.timestamp - updatedAt1 < (24 * 3600 + 300), "syrupUSDT_USDT_PriceFeed/timestamp-too-old");

    // (2) USDT/USD in 8 DPs
    uint256 USDT_Usd_Price = resilientOracle.peek(USDT_TOKEN_ADDR);

    return FullMath.mulDiv(uint256(syrupUSDT_USDT_Price), USDT_Usd_Price, 1e18);
  }

}
