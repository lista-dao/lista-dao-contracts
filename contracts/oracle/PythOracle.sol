// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "./interfaces/OracleInterface.sol";

contract PythOracle is AggregatorV3Interface {

  IPyth immutable public pyth;
  bytes32 immutable public priceId;

  constructor(address _pyth, bytes32 _priceId) {
    pyth = IPyth(_pyth);
    priceId = _priceId;
  }

  function decimals() external view returns (uint8) {
    PythStructs.Price memory price = pyth.getPriceUnsafe(priceId);
    return uint8(-1 * int8(price.expo));
  }

  function description() external pure returns (string memory) {
    return "A port of a chainlink aggregator powered by pyth network feeds";
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function latestAnswer() external view returns (int256) {
    PythStructs.Price memory price = pyth.getPriceUnsafe(priceId);
    return int256(price.price);
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
    PythStructs.Price memory price = pyth.getPriceUnsafe(priceId);
    return (
      _roundId,
      int256(price.price),
      price.publishTime,
      price.publishTime,
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
    PythStructs.Price memory price = pyth.getPriceUnsafe(priceId);
    roundId = uint80(price.publishTime);
    return (
      roundId,
      int256(price.price),
      price.publishTime,
      price.publishTime,
      roundId
    );
  }
}
