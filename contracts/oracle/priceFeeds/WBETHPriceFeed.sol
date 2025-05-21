// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import "../interfaces/IWBETH.sol";
import "../libraries/FullMath.sol";

/**
  * @title WBETHPriceFeed
  * @dev This contract is used to get the price of wBETH/ETH from wBETH exchangeRate and ETH/USD from ChainLink
  */
contract WBETHPriceFeed {

  IResilientOracle public resilientOracle;
  address public constant ETH_TOKEN_ADDR = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
  address public constant WBETH_TOKEN_ADDR = 0xa2E3356610840701BDf5611a53974510Ae27E2e1;

  /**
    * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    */
  constructor(address _resilientOracle) {
    require(_resilientOracle != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "wBETH Price Feed";
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
    * @dev Get the price of wBETH in 8 DPs
    *      wBETH/ETH from wBETH exchange Rate and ETH/USD from ChainLink
    *      multiply them and divide by 1e8
    * @return price The price of wBETH in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // wstETH/ETH in 18 DPs
    uint256 exchangeRate = IWBETH(WBETH_TOKEN_ADDR).exchangeRate();

    // ETH/USD in 8 DPs
    uint256 ethPrice = resilientOracle.peek(ETH_TOKEN_ADDR);

    return FullMath.mulDiv(exchangeRate, ethPrice, 1e18);
  }

}
