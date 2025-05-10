// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import { ISnBnbStakeManager } from "../../snbnb/interfaces/ISnBnbStakeManager.sol";

/**
  * @title slisBnbPriceFeed
  * @dev The contract obtains WBNB price from the Resilient Oracle and converts it to slisBNB using the SnBnbStakeManager.
  */
contract SlisBnbPriceFeed {

  IResilientOracle public resilientOracle;
  ISnBnbStakeManager public stakeManager;

  address public constant WBNB_TOKEN_ADDR = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

  constructor(address _resilientOracle, address _stakeManager) {
    require(_resilientOracle != address(0) && _stakeManager != address (0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
    stakeManager = ISnBnbStakeManager(_stakeManager);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "slisBNB Price Feed";
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
    * @dev Get the WBNB price from the Resilient Oracle, and multiply it by the conversion rate
    * @return price The price of slisBNB in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // get BNB price from resilient oracle (8 Decimal place)
    // in case price is zero, resilient oracle will revert
    price = resilientOracle.peek(WBNB_TOKEN_ADDR);
    price = stakeManager.convertSnBnbToBnb(price);
  }

}
