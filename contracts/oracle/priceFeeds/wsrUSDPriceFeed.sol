// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../interfaces/IResilientOracle.sol";
import "../libraries/FullMath.sol";
import "../interfaces/AggregatorV3Interface.sol";

/**
  * @title wsrUSD Price Feed
  * @dev This contract get the price of wsrUSD/RUSD from the chainlink Oracle
  * 1 RUSD = 1 USDT
  */
contract wsrUSDPriceFeed {

    IResilientOracle public resilientOracle;
    // wsrUSD/RUSD Price Feed Address
    AggregatorV3Interface public wsrUSD_RUSD_PriceFeed;
    address public constant USDT_TOKEN_ADDR = 0x55d398326f99059fF775485246999027B3197955;

    /**
      * @dev Constructor
    * @param _resilientOracle The address of the Resilient Oracle contract
    */
    constructor(address _resilientOracle, address _wsrUSD_RUSD_PriceFeed) {
        require(_resilientOracle != address(0) && _wsrUSD_RUSD_PriceFeed != address(0), "Zero address provided");
        resilientOracle = IResilientOracle(_resilientOracle);
        wsrUSD_RUSD_PriceFeed = AggregatorV3Interface(_wsrUSD_RUSD_PriceFeed);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "wsrUSD/RUSD Price Feed";
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
      * @dev Get the price of wsrUSD/RUSD from chainlink oracle in 18 DPs,
      *      get the price of USDT from multi oracle in 8 DPs
      * @return price The price of wsrUSD/USD in 8 decimal places
    */
    function getPrice() private view returns (uint256 price) {
        // wsrUSD/RUSD in 18 DPs
        (
        /*uint80 roundID*/,
            int256 wsrUSD_RUSD_Price,
        /*uint startedAt*/,
            uint256 updatedAt,
        /*uint80 answeredInRound*/
        ) = wsrUSD_RUSD_PriceFeed.latestRoundData();
        require(wsrUSD_RUSD_Price > 0, "wsrUSDPriceFeed/rate-not-valid");
        require(block.timestamp - updatedAt < (86400 + 300), "wsrUSDPriceFeed/timestamp-too-old");

        uint256 usdtPrice = resilientOracle.peek(USDT_TOKEN_ADDR);


        return FullMath.mulDiv(uint256(wsrUSD_RUSD_Price), usdtPrice, 1e18);
    }

}
