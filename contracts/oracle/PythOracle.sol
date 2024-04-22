// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { PythAggregatorV3 } from "@pythnetwork/pyth-sdk-solidity/PythAggregatorV3.sol";
import "./interfaces/OracleInterface.sol";

contract PythOracle is AggregatorV3Interface {

  PythAggregatorV3 immutable public pythFeedAdaptor;

  constructor(address pythContract, bytes32 priceId) {
    pythFeedAdaptor = new PythAggregatorV3(pythContract, priceId);
  }

  function decimals() external view returns (uint8) {
    return pythFeedAdaptor.decimals();
  }

  function description() external view returns (string memory) {
    return pythFeedAdaptor.description();
  }

  function version() external view returns (uint256) {
    return pythFeedAdaptor.version();
  }

  function latestAnswer() external view returns (int256) {
    return pythFeedAdaptor.latestAnswer();
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
    return pythFeedAdaptor.getRoundData(_roundId);
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
    return pythFeedAdaptor.latestRoundData();
  }
}
