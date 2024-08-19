// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./interfaces/OracleInterface.sol";

/**
  * @title API3Oracle
  * @author Lista
  * @notice The API3Oracle contract is used to fetch price data from an API3's dAPI.
  * which fully compatible with Chainlink's AggregatorV3Interface.
  * @dev Price returns in 18 decimal places, to match our businesses logic we will divide the value by 10^10.
  */
contract API3Oracle is AggregatorV3Interface {

  IAPI3Proxy public immutable api3Proxy;

  constructor(address _api3Proxy) {
    api3Proxy = IAPI3Proxy(_api3Proxy);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "An Adaptor contract of API3's dAPI Proxy";
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function latestAnswer() external view returns (int256) {
    (int224 value, ) = api3Proxy.read();
    return int256(value/10**10);
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
    (int224 value, uint32 timestamp) = api3Proxy.read();
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
    (int224 value, uint32 timestamp) = api3Proxy.read();
    roundId = uint80(timestamp);
    return (
      roundId,
      int256(value/10**10),
      uint256(timestamp),
      uint256(timestamp),
      roundId
    );
  }
}
