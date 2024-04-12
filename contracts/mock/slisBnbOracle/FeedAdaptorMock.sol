// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract FeedAdaptorMock {

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
    return (18446744073709551616, 54450350763, block.timestamp, block.timestamp, 18446744073709551616);
  }

}
