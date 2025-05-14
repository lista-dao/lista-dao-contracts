// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "../libraries/FullMath.sol";

/**
  * @title sUSDePriceFeed
  * @dev Contract provides sUSDe/USD in 8 DPs
  */
contract sUSDePriceFeed {

  AggregatorV3Interface public sUSDe_USDe_PriceFeed;
  AggregatorV3Interface public USDe_USD_PriceFeed;

  constructor(address _sUSDe_USDe_PriceFeed, address _USDe_USD_PriceFeed) {
    require(_sUSDe_USDe_PriceFeed != address(0) && _USDe_USD_PriceFeed != address(0), "Zero address provided");
    sUSDe_USDe_PriceFeed = AggregatorV3Interface(_sUSDe_USDe_PriceFeed);
    USDe_USD_PriceFeed = AggregatorV3Interface(_USDe_USD_PriceFeed);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "sUSDe/USD Price Feed";
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
    * @dev Get the price of sUSDe/USD in 8 DPs
    *      sUSDe/USDe and USDe/USD prices from ChainLink
    *      multiply them and divide by 1e8
    * @return price The price of sUSDe/USD in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // sUSDe/USDe in 8 DPs
    (
    /*uint80 roundID*/,
      int sUSDe_USDe_Price,
    /*uint startedAt*/,
      uint updatedAt1,
    /*uint80 answeredInRound*/
    ) = sUSDe_USDe_PriceFeed.latestRoundData();

    require(sUSDe_USDe_Price > 0, "sUSDe_USDe_PriceFeed/price-not-valid");
    require(block.timestamp - updatedAt1 < (24 * 3600 + 300), "sUSDe_USDe_PriceFeed/timestamp-too-old");

    // USDe/USD in 8 DPs
    (
    /*uint80 roundID*/,
      int USDe_Usd_Price,
    /*uint startedAt*/,
      uint updatedAt2,
    /*uint80 answeredInRound*/
    ) = USDe_USD_PriceFeed.latestRoundData();

    require(USDe_Usd_Price > 0, "USDe_USD_PriceFeed/price-not-valid");
    require(block.timestamp - updatedAt2 < (24 * 3600 + 300), "USDe_USD_PriceFeed/timestamp-too-old");

    return FullMath.mulDiv(uint256(sUSDe_USDe_Price), uint256(USDe_Usd_Price), 1e8);
  }

}
