// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract WeethOracle is Initializable {

    AggregatorV3Interface internal weethEthPrice;
    AggregatorV3Interface internal ethUsdPrice;

    function initialize(address weethEthPriceAddr,address ethUsdPriceAddr) external initializer {
        weethEthPrice = AggregatorV3Interface(weethEthPriceAddr);
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
        ) = weethEthPrice.latestRoundData();

        require(block.timestamp - timeStamp1 < (6 * 3600 + 600), "weethEthPriceFeed/timestamp-too-old");

        (
        /*uint80 roundID*/,
            int price2,
        /*uint startedAt*/,
            uint timeStamp2,
        /*uint80 answeredInRound*/
        ) = ethUsdPrice.latestRoundData();

        require(block.timestamp - timeStamp2 < 600, "ethUsdPriceFeed/timestamp-too-old");

        if (price1 <= 0 || price2 <= 0) {
            return (0, false);
        }


        return (bytes32(uint(price1) * uint(price2) * (10**2)), true);
    }
}
