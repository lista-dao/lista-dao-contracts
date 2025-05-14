// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IResilientOracle.sol";
import "../interfaces/IAsUsdfEarn.sol";
import "../libraries/FullMath.sol";

/**
  * @title StableAsUSDFPriceFeed
  * @dev This contract is used to get the price of asUSDF by
  *      multiplying the price of USDF from the Resilient Oracle
  *      and the exchange rate of asUSDF<>USDF from the asUSDFEarn contract
  */
contract StableAsUsdfPriceFeed {

  IResilientOracle public resilientOracle;
  IAsUsdfEarn public asUsdfEarn;

  address public constant USDF_TOKEN_ADDR = 0x5A110fC00474038f6c02E89C707D638602EA44B5;
  // ported from AsUsdfEarn contract
  uint256 public constant EXCHANGE_PRICE_DECIMALS = 1e18;

  constructor(address _resilientOracle, address _asUsdfEarn) {
    require(_resilientOracle != address(0) && _asUsdfEarn != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
    asUsdfEarn = IAsUsdfEarn(_asUsdfEarn);
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "Stabilized asUSDF Price Feed";
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function latestAnswer() external view returns (int256 answer) {
    // get price
    answer = getPrice();
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
    int256 _answer = getPrice();
    // mock timestamp to latest block timestamp
    uint256 timestamp = block.timestamp;
    // mock roundId to timestamp
    roundId = uint80(timestamp);
    return (
      roundId,
      _answer,
      timestamp,
      timestamp,
      roundId
    );
  }

  /**
    * @dev Get the price of USDF from the Resilient Oracle
    *      and multiply it with the exchange rate
    * @return price - the price of asUSDF in 8 decimals
    */
  function getPrice() private view returns (int256 price) {
    // get USDF price (8 decimals)
    uint256 usdfPrice = resilientOracle.peek(USDF_TOKEN_ADDR);
    // get exchange rate (asUSDF > USDF)
    uint256 exchangeRate = asUsdfEarn.exchangePrice();
    // return coverted price
    price = int256(FullMath.mulDiv(usdfPrice, exchangeRate, EXCHANGE_PRICE_DECIMALS));
  }

}
