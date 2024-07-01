// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IAPI3Proxy.sol";

contract WBETHOracleV2 is Initializable, AggregatorV3Interface {

  address internal ethUsdPriceFeed;
  address internal wBethEthPriceFeed;

  function initialize(address _ethUsdPriceFeedAddr, address _wBethEthPriceFeedAddr) external initializer {
    ethUsdPriceFeed = _ethUsdPriceFeedAddr;
    wBethEthPriceFeed = _wBethEthPriceFeedAddr;
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "WBETH/USD Oracle";
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
    (int224 ethUsdPrice, uint32 updateTimestamp1) = IAPI3Proxy(ethUsdPriceFeed).read();
    require(block.timestamp - updateTimestamp1 < 86700, "Oracle/ethUsd-timestamp-too-old");
    require(ethUsdPrice > 0, "Oracle/ethUsd-price-invalid");

    // get the latest wbETH/ETH price
    (int224 wBethEthPrice, uint32 updateTimestamp2) = IAPI3Proxy(wBethEthPriceFeed).read();
    require(block.timestamp - updateTimestamp2 < 86700, "Oracle/wbethEth-timestamp-too-old");
    require(wBethEthPrice > 0, "Oracle/wbethEth-price-invalid");

    timestamp = uint256(updateTimestamp2 > updateTimestamp1 ? updateTimestamp2 : updateTimestamp1);
    value = int256(wBethEthPrice * ethUsdPrice) / 1e28;
  }
}
