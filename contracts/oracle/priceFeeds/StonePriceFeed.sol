// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "../libraries/FullMath.sol";

/**
  * @title StonePriceFeed
  * @dev This contract is used to get the price of Stone/ETH from ChainLink and ETH/USD from ChainLink
  */
contract StonePriceFeed {

  IResilientOracle public resilientOracle;
  AggregatorV3Interface public stoneEthPriceFeed;
  address public constant ETH_TOKEN_ADDR = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;

  /**
    * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    * @param _stoneEthPriceFeed The address of the Stone/ETH price feed contract
    */
  constructor(address _resilientOracle, address _stoneEthPriceFeed) {
    require(_resilientOracle != address(0) && _stoneEthPriceFeed != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
    stoneEthPriceFeed = AggregatorV3Interface(_stoneEthPriceFeed);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "Stone/USD Price Feed";
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
    * @dev Get the price of Stone in 8 DPs
    *      Stone/ETH from ChainLink and ETH/USD from Resilient Oracle
    *      multiply them and divide by 1e8
    * @return price The price of Stone in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // Stone/ETH in 18 DPs
    (
    /*uint80 roundID*/,
      int stoneEthPrice,
    /*uint startedAt*/,
      uint updatedAt,
    /*uint80 answeredInRound*/
    ) = stoneEthPriceFeed.latestRoundData();
    require(stoneEthPrice > 0, "stoneEthPriceFeed/price-not-valid");
    require(block.timestamp - uint256(updatedAt) < (24 * 3600 + 300), "stoneEthPriceFeed/timestamp-too-old");

    // ETH/USD in 8 DPs
    uint256 ethPrice = resilientOracle.peek(ETH_TOKEN_ADDR);

    return FullMath.mulDiv(uint256(stoneEthPrice), ethPrice, 1e18);
  }

}
