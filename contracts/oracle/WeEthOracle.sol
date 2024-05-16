// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/AggregatorV3Interface.sol";

contract WeEthOracle is Initializable {

    AggregatorV3Interface public weEthPriceFeed;
    AggregatorV3Interface public ethPriceFeed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _weEthPriceFeed,address _ethPriceFeed) external initializer {
        weEthPriceFeed = AggregatorV3Interface(_weEthPriceFeed);
        ethPriceFeed = AggregatorV3Interface(_ethPriceFeed);
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
        ) = weEthPriceFeed.latestRoundData();

        require(block.timestamp - timeStamp1 < (6 * 3600 + 300), "weEthPriceFeed/timestamp-too-old");

        (
        /*uint80 roundID*/,
            int price2,
        /*uint startedAt*/,
            uint timeStamp2,
        /*uint80 answeredInRound*/
        ) = ethPriceFeed.latestRoundData();

        require(block.timestamp - timeStamp2 < 300, "ethPriceFeed/timestamp-too-old");

        if (price1 < 0 || price2 < 0) {
            return (0, false);
        }


        return (bytes32(uint(price1) * uint(price2) * 1e2), true);
    }
}
