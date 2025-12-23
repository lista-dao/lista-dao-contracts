// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../interfaces/IResilientOracle.sol";
import "../../libraries/FullMath.sol";
import { AggregatorV3Interface } from "../../interfaces/OracleInterface.sol";
import { IStEth } from "../../interfaces/IStEth.sol";

/**
 * @title WstETHPriceFeed
 * @dev This contract is used to get the price of price of wstETH/stETH from wstETH exchangeRate and ETH/USD from ResilientOracle
 */
contract WstETHPriceFeed {
  IResilientOracle public resilientOracle;
  address public constant WETH_TOKEN_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  IStEth public constant ST_ETH = IStEth(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

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
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    // get price
    uint256 _answer = getPrice();
    // mock timestamp to latest block timestamp
    uint256 timestamp = block.timestamp;
    // mock roundId to timestamp
    roundId = uint80(timestamp);
    return (roundId, int256(_answer), timestamp, timestamp, roundId);
  }

  /**
   * @dev Get the price of wstETH in 8 DPs
   *      wstETH/stETH from stETH contract and ETH/USD from ResilientOracle
   * @return price The price of wstETH in 8 decimals
   */
  function getPrice() private view returns (uint256 price) {
    // wstETH/stETH in 18 DPs
    uint256 exchangeRate = ST_ETH.getPooledEthByShares(1e18);

    // ETH/USD in 8 DPs
    uint256 ethPrice = resilientOracle.peek(WETH_TOKEN_ADDR);

    return FullMath.mulDiv(exchangeRate, ethPrice, 1e18);
  }
}
