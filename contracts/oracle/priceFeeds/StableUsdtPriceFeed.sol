// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";

/**
  * @title StableUsdtPriceFeed
  * @dev This contract is used to get the price of USDT from a Resilient Oracle
  *      and bounds the price to a certain range.
  */
contract StableUsdtPriceFeed {

  IResilientOracle public resilientOracle;

  address public constant USDT_TOKEN_ADDR = 0x55d398326f99059fF775485246999027B3197955;
  uint256 public constant UPPER_BOUND = 102000000; // 1.02 USD
  uint256 public constant LOWER_BOUND = 98000000; // 0.98 USD

  constructor(address _resilientOracle) {
    require(_resilientOracle != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "Stabilized USDT Price Feed";
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function latestAnswer() external view returns (int256 answer) {
    // get price
    uint256 price = getPrice();
    // cast price to int256
    answer = int256(price);
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
    // get price
    uint256 _answer = getPrice();
    // mock timestamp to latest block timestamp
    uint256 timestamp = block.timestamp;
    // mock roundId to timestamp
    roundId = uint80(timestamp);
    return (
      roundId,
      int256(_answer),
      timestamp,
      timestamp,
      roundId
    );
  }

  /**
    * @dev Get the price from the Resilient Oracle, and bound it to the range
    * @return price The price of USDT in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // get USDT price (8 decimals)
    price = resilientOracle.peek(USDT_TOKEN_ADDR);
    price = price < LOWER_BOUND ? LOWER_BOUND : (price > UPPER_BOUND ? UPPER_BOUND : price);
  }

}
