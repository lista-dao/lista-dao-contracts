// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import "../libraries/FullMath.sol";
import { AggregatorV3Interface } from "../interfaces/OracleInterface.sol";

/**
  * @title WstETHPriceFeed
  * @dev This contract is used to get the price of wstETH/ETH from Red Stone and ETH/USD from ChainLink
  */
contract WstETHPriceFeed {

  IResilientOracle public resilientOracle;
  AggregatorV3Interface public wstETH_ETH_PriceFeed;
  address public constant ETH_TOKEN_ADDR = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
  address public constant WSTETH_TOKEN_ADDR = 0x26c5e01524d2E6280A48F2c50fF6De7e52E9611C;

  /**
    * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    * @param _wstEth_ETH_PriceFeed The address of the wstETH/ETH price feed contract
    */
  constructor(address _resilientOracle, address _wstEth_ETH_PriceFeed) {
    require(_resilientOracle != address(0) && _wstEth_ETH_PriceFeed != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
    wstETH_ETH_PriceFeed = AggregatorV3Interface(_wstEth_ETH_PriceFeed);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "wstETH Price Feed";
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
    *      wstETH/ETH from Red Stone and ETH/USD from ChainLink
    *      multiply them and divide by 1e8
    * @return price The price of wBETH in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // wstETH/ETH in 18 DPs
    (
    /*uint80 roundID*/,
      int256 wstETH_ETH_Price,
    /*uint startedAt*/,
      uint256 updatedAt,
    /*uint80 answeredInRound*/
    ) = wstETH_ETH_PriceFeed.latestRoundData();
    require(wstETH_ETH_Price > 0, "wstETH_ETH_PriceFeed/price-not-valid");
    require(block.timestamp - updatedAt < (6 * 3600 + 300), "wstETH_ETH_PriceFeed/timestamp-too-old");

    // ETH/USD in 8 DPs
    uint256 ethPrice = resilientOracle.peek(ETH_TOKEN_ADDR);

    return FullMath.mulDiv(uint256(int256(wstETH_ETH_Price)), ethPrice, 1e8);
  }

}
