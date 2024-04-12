// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract FeedAdaptorProxy {

  AggregatorV3Interface internal priceFeed = AggregatorV3Interface(0x1A26d803C2e796601794f8C5609549643832702C);

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
    (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = priceFeed.latestRoundData();

    return (roundId, answer, block.timestamp, block.timestamp, answeredInRound);
  }

}
