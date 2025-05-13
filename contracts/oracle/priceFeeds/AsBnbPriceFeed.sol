// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IResilientOracle } from "../interfaces/IResilientOracle.sol";
import { IAsBnbMinter } from "../interfaces/IAsBnbMinter.sol";

contract AsBnbPriceFeed {
  // @dev AsBnb Minter
  IAsBnbMinter public asBnbMinter;
  // @dev Resilient oracle
  IResilientOracle public resilientOracle;
  // @dev slisBNB token address
  address constant public SLISBNB_TOKEN_ADDR = 0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B;

  /**
   * @dev initialize the contract
   * @param _resilientOracle Resilient oracle address
   * @param _abBnbMinter AsBnb Minter address
   */
  constructor(address _resilientOracle, address _abBnbMinter) {
    require(_resilientOracle != address(0) && _abBnbMinter != address (0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
    asBnbMinter = IAsBnbMinter(_abBnbMinter);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "asBNB Price Feed";
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
    * @dev Get the slisBNB price from the Resilient Oracle, and multiply it by the conversion rate
    * @return price The price of asBNB in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // get slisBNB price from resilient oracle (8 Decimal place)
    // in case price is zero, resilient oracle will revert
    price = resilientOracle.peek(SLISBNB_TOKEN_ADDR);
    price = asBnbMinter.convertToTokens(price);
  }
}
