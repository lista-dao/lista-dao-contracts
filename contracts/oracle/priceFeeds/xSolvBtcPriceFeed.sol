// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import "../libraries/FullMath.sol";
import { AggregatorV3Interface } from "../interfaces/OracleInterface.sol";

/**
  * @title xSolvBtcPriceFeed
  * @dev This contract is used to get the price of xSolvBTC/solvBTC from RedStone
  *      and solvBTC/USD from the resilient Oracle
  */
contract xSolvBtcPriceFeed {

  IResilientOracle public resilientOracle;
  AggregatorV3Interface public xSolvBtc_solvBtc_PriceFeed;
  address public constant SOLV_BTC_TOKEN_ADDR = 0x4aae823a6a0b376De6A78e74eCC5b079d38cBCf7;

  /**
    * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    * @param _xSolvBtc_solvBtc_PriceFeed The address of the solvBtcBnb/SolvBtcBnb price feed contract
    */
  constructor(address _resilientOracle, address _xSolvBtc_solvBtc_PriceFeed) {
    require(_resilientOracle != address(0) && _xSolvBtc_solvBtc_PriceFeed != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
    xSolvBtc_solvBtc_PriceFeed = AggregatorV3Interface(_xSolvBtc_solvBtc_PriceFeed);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "solvBTC.BBN Price Feed";
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
    * @dev Get the price of xSolvBtcBnb in 8 DPs
    *      xSolvBTC/solvBTC from RedStone and solvBTC/USD from the resilient oracle
    * @return price The price of xSolvBtcBnb in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // solvBtcBnb/BTC in 8 DPs
    (
    /*uint80 roundID*/,
      int256 xSolvBtc_btc_price,
    /*uint startedAt*/,
      uint256 updatedAt,
    /*uint80 answeredInRound*/
    ) = xSolvBtc_solvBtc_PriceFeed.latestRoundData();
    require(xSolvBtc_btc_price > 0, "xSolvBtc_btc_priceFeed/price-not-valid");
    require(block.timestamp - updatedAt < (6 * 3600 + 300), "xSolvBtc_btc_priceFeed/timestamp-too-old");

    // solvBTC/USD in 8 DPs
    uint256 solvBtcPrice = resilientOracle.peek(SOLV_BTC_TOKEN_ADDR);

    // returns price of xSolvBtcBnb in 8 DPs
    return FullMath.mulDiv(uint256(int256(xSolvBtc_btc_price)), solvBtcPrice, 1e8);
  }

}
