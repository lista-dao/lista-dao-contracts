// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IResilientOracle.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "../libraries/FullMath.sol";

/**
  * @title uniBTC Price Feed
  * @dev This contract get the price of BTC from the Resilient Oracle
  *      and the exchange rate of uniBTC/BTC from chainlink,
  *      and returns the price of uniBTC in USD.
  */
contract uniBTCPriceFeed {

    IResilientOracle public resilientOracle;
    AggregatorV3Interface public uniBTC_BTC_PriceFeed;
    address public constant BTC_TOKEN_ADDR = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;

    /**
      * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    */
    constructor(address _resilientOracle, address _uniBTC_BTC_PriceFeed) {
        require(_resilientOracle != address(0) && _uniBTC_BTC_PriceFeed != address(0), "Zero address provided");
        resilientOracle = IResilientOracle(_resilientOracle);
        uniBTC_BTC_PriceFeed = AggregatorV3Interface(_uniBTC_BTC_PriceFeed);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "uniBTC/USD Price Feed";
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
      * @dev Get the price of uniBTC/BTC from Chainlink Oracle,
    *      and BTC/USD from resilient oracle,
    *      multiply them and divide by 1e8
    * @return price The price of uniBTC/BTC in 8 decimal places
    */
    function getPrice() private view returns (uint256 price) {
        uint256 DENOMINATOR = 1e18;
        // uniBTC/BTC in 18 DPs
        (
        /*uint80 roundID*/,
            int256 uniBTC_BTC_Price,
        /*uint startedAt*/,
            uint256 updatedAt,
        /*uint80 answeredInRound*/
        ) = uniBTC_BTC_PriceFeed.latestRoundData();
        require(uniBTC_BTC_Price > 0, "uniBTCPriceFeed/rate-not-valid");
        require(block.timestamp - updatedAt < (86400 + 300), "uniBTCPriceFeed/timestamp-too-old");
        // BTC/USD in 8 DPs
        uint256 btcPrice = resilientOracle.peek(BTC_TOKEN_ADDR);
        // return uniBTC/USD price in 8 DPs
        return FullMath.mulDiv(uint256(uniBTC_BTC_Price), btcPrice, DENOMINATOR);
    }

}
