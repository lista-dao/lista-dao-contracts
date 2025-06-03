// SPDX-License-Identifier: MIT
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
contract sUSDXPriceFeed {

  IResilientOracle public resilientOracle;
  // sUSDX Token Address (non-upgradeable)
  IERC4626 public sUSDX = IERC4626(0x7788A3538C5fc7F9c7C8A74EAC4c898fC8d87d92);
  address public constant USDX_TOKEN_ADDR = 0xf3527ef8dE265eAa3716FB312c12847bFBA66Cef;

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
    // sUSDX/USDX rate in 18 DPs
    uint256 sUSDXUSDXRate = sUSDX.convertToAssets(DENOMINATOR);
    require(sUSDXUSDXRate > 0, "sUSDXPriceFeed/rate-not-valid");
    // USDX/USD in 8 DPs
    uint256 usdxPrice = resilientOracle.peek(USDX_TOKEN_ADDR);
    // return sUSDX/USD price in 8 DPs
    return FullMath.mulDiv(usdxPrice, sUSDXUSDXRate, DENOMINATOR);
  }

}
