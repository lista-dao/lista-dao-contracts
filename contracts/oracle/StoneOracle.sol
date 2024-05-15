// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract StoneOracle is Initializable {

    AggregatorV3Interface internal stoneEthPrice;
    AggregatorV3Interface internal ethUsdPrice;

    function initialize(address stoneEthPriceAddr,address ethUsdPriceAddr) external initializer {
        stoneEthPrice = AggregatorV3Interface(stoneEthPriceAddr);
        ethUsdPrice = AggregatorV3Interface(ethUsdPriceAddr);
    }

    /**
      * Returns the latest price
      */
    function peek() public view returns (bytes32, bool) {
        (
        /*uint80 roundID*/,
            int price1,
        /*uint startedAt*/,
            uint timeStamp1,
        /*uint80 answeredInRound*/
        ) = stoneEthPrice.latestRoundData();

        require(block.timestamp - timeStamp1 < (24 * 3600 + 600), "stoneEthPriceFeed/timestamp-too-old");

        (
        /*uint80 roundID*/,
            int price2,
        /*uint startedAt*/,
            uint timeStamp2,
        /*uint80 answeredInRound*/
        ) = ethUsdPrice.latestRoundData();

        require(block.timestamp - timeStamp2 < 300, "ethUsdPriceFeed/timestamp-too-old");

        if (price1 <= 0 || price2 <= 0) {
            return (0, false);
        }


        return (bytes32(uint(price1) * uint(price2) * (10**2)), true);
    }
}
