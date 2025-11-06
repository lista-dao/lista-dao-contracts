// SPDX-License-Identifier: MIT
// This contract is an extreme measure to trigger positions to be liquidated with sUSDX as collateral.
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IResilientOracle.sol";
import "../libraries/FullMath.sol";

/**
  * @title sUSDX Price Feed
  * @dev This contract get the price of USDX from the Resilient Oracle
  *      and the exchange rate of sUSDX/USDX from the sUSDX contract,
  *      and returns the price of sUSDX in USD.
  */
contract sUSDXLiquidationPriceFeed {

  IResilientOracle public resilientOracle;
  // sUSDX Token Address (non-upgradeable)
  address public constant USDX_TOKEN_ADDR = 0xf3527ef8dE265eAa3716FB312c12847bFBA66Cef;
  address public manager = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;
  uint256 public exchangeRate;
  /**
    * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    * @param _initialExchangeRate The initial exchange rate of sUSDX/USDX in 18 decimal places
    */
  constructor(address _resilientOracle, uint256 _initialExchangeRate) {
    require(_resilientOracle != address(0), "Zero address provided");
    resilientOracle = IResilientOracle(_resilientOracle);
    exchangeRate = _initialExchangeRate;
  }

  function setExchangeRate(uint256 _exchangeRate) external {
    require(msg.sender == manager, "Only manager can set exchange rate");
    exchangeRate = _exchangeRate;
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "sUSDX/USD Price Feed";
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
    * @dev Get the price of sUSDX/USDX from RedStone Oracle,
    *      and USDX/USD from resilient oracle,
    *      multiply them and divide by 1e8
    * @return price The price of sUSDX/USDX in 8 decimal places
    */
  function getPrice() private view returns (uint256 price) {
    uint256 DENOMINATOR = 1e18;
    // USDX/USD in 8 DPs
    uint256 usdxPrice = resilientOracle.peek(USDX_TOKEN_ADDR);
    // return sUSDX/USD price in 8 DPs
    return FullMath.mulDiv(usdxPrice, exchangeRate, DENOMINATOR);
  }

}
