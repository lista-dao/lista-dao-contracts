// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IAPI3Proxy.sol";

contract EzETHOracleFallback is Initializable, AggregatorV3Interface {

  address internal ethPriceFeed;
  address internal ezETHPriceFeed;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address _ethPriceFeedAddr, address _ezETHPriceFeedAddr) external initializer {
    ethPriceFeed = _ethPriceFeedAddr;
    ezETHPriceFeed = _ezETHPriceFeedAddr;
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "ezETH/USD Oracle";
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
    // get the latest ETH/USD price
    (int224 ethUsdPrice, uint32 updateTimestamp1) = IAPI3Proxy(ethPriceFeed).read();
    require(block.timestamp - updateTimestamp1 < 86700, "ethPriceFeed/timestamp-too-old");
    require(ethUsdPrice > 0, "ethPriceFeed/price-invalid");

    // get the latest ezETH/ETH price
    (int224 ezETHEthPrice, uint32 updateTimestamp2) = IAPI3Proxy(ezETHPriceFeed).read();
    require(block.timestamp - updateTimestamp2 < 86700, "ezETHPriceFeed/timestamp-too-old");
    require(ezETHEthPrice > 0, "ezETHPriceFeed/price-invalid");

    timestamp = uint256(updateTimestamp2 > updateTimestamp1 ? updateTimestamp2 : updateTimestamp1);
    value = int256(ezETHEthPrice * ethUsdPrice) / 1e28;
  }
}
