// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IResilientOracle.sol";
import "../libraries/FullMath.sol";

/**
  * @title yUSD Price Feed
  * @dev This contract get the price of USDT from the Resilient Oracle
  *      and the exchange rate of yUSD/USDT from the yUSD contract,
  *      and returns the price of yUSD in USD.
  */
contract yUSDFixedPriceFeed {
    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "yUSD/USD Price Feed";
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
      * @dev Get the price of yUSD/USDT from yUSD contract,
     * @return price The price of yUSD/USD in 8 decimal places
     */
    function getPrice() private view returns (uint256) {
        return 112400000;
    }

}
