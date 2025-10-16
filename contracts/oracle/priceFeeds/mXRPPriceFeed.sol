// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import "../libraries/FullMath.sol";
import "../interfaces/AggregatorV3Interface.sol";

/**
  * @title mXRPPriceFeed
  * @dev This contract is used to get the price of mXRP/XRP from Red Stone and XRP/USD from ChainLink
  */
contract mXRPPriceFeed {

  IResilientOracle public resilientOracle;
  AggregatorV3Interface public mXRP_XRP_PriceFeed;
  address public constant XRP_TOKEN_ADDR = 0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE;

  /**
    * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    * @param _mXRP_XRP_PriceFeed The address of the mXRP/XRP price feed contract
    */
  constructor(address _resilientOracle, address _mXRP_XRP_PriceFeed) {
    require(_resilientOracle != address(0) && _mXRP_XRP_PriceFeed != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
      mXRP_XRP_PriceFeed = AggregatorV3Interface(_mXRP_XRP_PriceFeed);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "mXRP Price Feed";
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
    * @dev Get the price of mXRP in 8 DPs
    *      XRP/USD from ChainLink
    *      multiply them and divide by 1e8
    * @return price The price of mXRP in 8 decimals
    */
  function getPrice() private view returns (uint256 price) {
    // mXRP/XRP in 8 DPs
    (
    /*uint80 roundID*/,
      int256 mXRP_XRP_Price,
    /*uint startedAt*/,
    /*uint256 updatedAt*/,
    /*uint80 answeredInRound*/
    ) = mXRP_XRP_PriceFeed.latestRoundData();
    require(mXRP_XRP_Price > 0, "mXRP_XRP_PriceFeed/price-not-valid");

    // XRP/USD in 8 DPs
    uint256 xrpPrice = resilientOracle.peek(XRP_TOKEN_ADDR);

    return FullMath.mulDiv(uint256(mXRP_XRP_Price), xrpPrice, 1e8);
  }

}
