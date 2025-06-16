// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import "../libraries/FullMath.sol";
import { AggregatorV3Interface } from "../interfaces/OracleInterface.sol";

/**
  * @title PufETHPriceFeed
  * @dev This contract is used to get the price of pufETH/ETH
  *      by combining Red Stone and ETH/USD from resilient Oracle
  */
contract PufETHPriceFeed {

  IResilientOracle public resilientOracle;
  AggregatorV3Interface public pufETH_ETH_PriceFeed;
  address public constant ETH_TOKEN_ADDR = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
  address public constant PUFETH_TOKEN_ADDR = 0x64274835D88F5c0215da8AADd9A5f2D2A2569381;

  /**
    * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    * @param _pufEth_ETH_PriceFeed The address of the pufETH/ETH price feed contract
    */
  constructor(address _resilientOracle, address _pufEth_ETH_PriceFeed) {
    require(_resilientOracle != address(0) && _pufEth_ETH_PriceFeed != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
    pufETH_ETH_PriceFeed = AggregatorV3Interface(_pufEth_ETH_PriceFeed);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "pufETH/USD Price Feed";
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
    *      pufETH/ETH from Red Stone and ETH/USD from ChainLink
    *      multiply them and divide by 1e8
    * @return price The price of wBETH in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // pufETH/ETH in 8 DPs
    (
    /*uint80 roundID*/,
      int256 pufETH_ETH_Price,
    /*uint startedAt*/,
      uint256 updatedAt,
    /*uint80 answeredInRound*/
    ) = pufETH_ETH_PriceFeed.latestRoundData();
    require(pufETH_ETH_Price > 0, "pufETH_ETH_PriceFeed/price-not-valid");
    require(block.timestamp - updatedAt < (6 * 3600 + 300), "pufETH_ETH_PriceFeed/timestamp-too-old");

    // ETH/USD in 8 DPs
    uint256 ethPrice = resilientOracle.peek(ETH_TOKEN_ADDR);

    return FullMath.mulDiv(uint256(int256(pufETH_ETH_Price)), ethPrice, 1e8);
  }

}
