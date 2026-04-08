// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
  * @title lisUSDPriceFeed
  * @dev Fixed-price feed that returns 1 USD (1e8) for lisUSD,
  *      compatible with Chainlink AggregatorV3Interface.
  */
contract lisUSDPriceFeed {
  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "lisUSD Price Feed";
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  /**
    * @dev Returns the latest lisUSD price in 8 decimals
    * @return answer The price of lisUSD in USD (always 1e8)
    */
  function latestAnswer() external pure returns (int256 answer) {
    answer = int256(getPrice());
  }

  /**
    * @dev Returns Chainlink-compatible round data with mocked fields
    * @return roundId Mocked as current block timestamp
    * @return answer The price of lisUSD in USD (always 1e8)
    * @return startedAt Current block timestamp
    * @return updatedAt Current block timestamp
    * @return answeredInRound Same as roundId
    */
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    uint256 _answer = getPrice();
    uint256 timestamp = block.timestamp;
    roundId = uint80(timestamp);
    return (
      roundId,
      int256(_answer),
      timestamp,
      timestamp,
      roundId
    );
  }

  function getPrice() private pure returns (uint256 price) {
    return 1e8;
  }
}
