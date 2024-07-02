// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract WeEthOracleMain is Initializable, AggregatorV3Interface {

  AggregatorV3Interface public weEthPriceFeed;
  AggregatorV3Interface public ethPriceFeed;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address _weEthPriceFeed, address _ethPriceFeed) external initializer {
    weEthPriceFeed = AggregatorV3Interface(_weEthPriceFeed);
    ethPriceFeed = AggregatorV3Interface(_ethPriceFeed);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "WeETH/USD Oracle";
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
      uint timeStamp1,
    /*uint80 answeredInRound*/
    ) = weEthPriceFeed.latestRoundData();

    require(block.timestamp - timeStamp1 < (6 * 3600 + 300), "weEthPriceFeed/timestamp-too-old");

    (
    /*uint80 roundID*/,
      int256 price2,
    /*uint startedAt*/,
      uint timeStamp2,
    /*uint80 answeredInRound*/
    ) = ethPriceFeed.latestRoundData();

    require(block.timestamp - timeStamp2 < 300, "ethPriceFeed/timestamp-too-old");

    timestamp = uint256(timeStamp1 > timeStamp2 ? timeStamp1 : timeStamp2);
    value = int256(price1 * price2) * 1e2;
  }
}
