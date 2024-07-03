// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IAPI3Proxy.sol";

contract StoneOracleFallback is Initializable, AggregatorV3Interface {

  AggregatorV3Interface public ethPriceFeed;
  AggregatorV3Interface public stoneEthPriceFeed;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address _ethPriceFeedAddr, address _stoneETHPriceFeedAddr) external initializer {
    ethPriceFeed = AggregatorV3Interface(_ethPriceFeedAddr);
    stoneETHPriceFeed = AggregatorV3Interface(_stoneETHPriceFeedAddr);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "STONE/USD Oracle";
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function latestAnswer() external view returns (int256) {
    (int256 value, ) = getPrice();
    return value;
  }

  function getRoundData(uint80 _roundId)
  external
  view
  returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  ) {
    (int256 value, uint256 timestamp) = getPrice();
    return (
      _roundId,
      int256(value/10**10),
      uint256(timestamp),
      uint256(timestamp),
      _roundId
    );
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
    (int256 value, uint256 timestamp) = getPrice();
    roundId = uint80(timestamp);
    return (
      roundId,
      value,
      timestamp,
      timestamp,
      roundId
    );
  }

  /**
   * Returns the latest price
   */
  function getPrice() internal view returns (int256 value, uint256 timestamp) {
    (
    /*uint80 roundID*/,
      int256 price1,
    /*uint startedAt*/,
      uint256 timeStamp1,
    /*uint80 answeredInRound*/
    ) = stoneEthPriceFeed.latestRoundData();
    require(block.timestamp - timeStamp1 < (24 * 3600 + 300), "stoneEthPriceFeed/timestamp-too-old");
    require(price1 > 0, "stoneEthPriceFeed/price-is-zero");

    (
    /*uint80 roundID*/,
      int256 price2,
    /*uint startedAt*/,
      uint256 timeStamp2,
    /*uint80 answeredInRound*/
    ) = ethPriceFeed.latestRoundData();
    require(block.timestamp - timeStamp2 < 300, "ethPriceFeed/timestamp-too-old");
    require(price2 > 0, "ethPriceFeed/price-is-zero");

    value = uint256(price1) * uint(price2) * 1e2;
    // return the oldest timestamp
    timestamp = uint256(timeStamp1 > timeStamp2 ? timeStamp2 : timeStamp1);
  }
}
