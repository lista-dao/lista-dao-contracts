// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IResilientOracle.sol";
import "../libraries/FullMath.sol";
import "../interfaces/AggregatorV3Interface.sol";

/**
  * @title wstUSR Price Feed
  * @dev This contract get the price of wstUSR/stUSR from the chainlink Oracle
  * 1 stUSR = 1 USR = 1 USD
  */
contract wstUSRPriceFeed {

    IResilientOracle public resilientOracle;
    // wstUSR/stUSR Price Feed Address
    AggregatorV3Interface public wstUSR_stUSR_PriceFeed;

    /**
      * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    */
    constructor(address _resilientOracle, address _wstUSR_stUSR_PriceFeed) {
        require(_resilientOracle != address(0) && _wstUSR_stUSR_PriceFeed != address(0), "Zero address provided");
        resilientOracle = IResilientOracle(_resilientOracle);
        wstUSR_stUSR_PriceFeed = AggregatorV3Interface(_wstUSR_stUSR_PriceFeed);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "wstUSR/USD Price Feed";
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
      * @dev Get the price of wstUSR/USR from chainlink oracle,
      *      divide by 1e10
      * @return price The price of wstUSR/USD in 8 decimal places
    */
    function getPrice() private view returns (uint256 price) {
        uint256 DENOMINATOR = 1e10;
        // wstUSR/stUSR in 18 DPs
        (
        /*uint80 roundID*/,
            int256 wstUSR_stUSR_Price,
        /*uint startedAt*/,
            uint256 updatedAt,
        /*uint80 answeredInRound*/
        ) = wstUSR_stUSR_PriceFeed.latestRoundData();
        require(wstUSR_stUSR_Price > 0, "wstUSRPriceFeed/rate-not-valid");
        require(block.timestamp - updatedAt < (86400 + 300), "wstUSRPriceFeed/timestamp-too-old");
        return uint256(wstUSR_stUSR_Price) / DENOMINATOR;
    }

}
