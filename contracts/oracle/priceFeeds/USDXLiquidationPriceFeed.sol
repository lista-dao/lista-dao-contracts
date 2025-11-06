
// SPDX-License-Identifier: MIT
// This contract is an extreme measure to trigger positions to be liquidated with USDX as collateral.
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IResilientOracle.sol";
import "../libraries/FullMath.sol";

/**
  * @title USDX Price Feed
  * @dev This contract get the price of USDX
  */
contract USDXLiquidationPriceFeed {

  // USDX Token Address (non-upgradeable)
  address public manager = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;
  uint256 public price;
  /**
    * @dev Constructor
    * @param _initPrice The initial price of USDX/USD in 8 decimal places
    */
  constructor(uint256 _initPrice) {
    price = _initPrice;
  }

  function setPrice(uint256 newPrice) external {
    require(msg.sender == manager, "Only manager can set price");
    price = newPrice;
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function description() external pure returns (string memory) {
    return "USDX/USD Price Feed";
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
    * @dev Get the price of USDX/USD
    */
  function getPrice() private view returns (uint256) {
    return price;
  }

}
