// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../oracle/interfaces/AggregatorV3Interface.sol";

contract StoneOracleDev is Initializable {

    AggregatorV3Interface public stoneEthPriceFeed;
    AggregatorV3Interface public ethPriceFeed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stoneEthPriceFeed,address _ethPriceFeed) external initializer {
        stoneEthPriceFeed = AggregatorV3Interface(_stoneEthPriceFeed);
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
        ) = stoneEthPriceFeed.latestRoundData();

        require(block.timestamp - timeStamp1 < (24 * 3600 * 365 + 300), "stoneEthPriceFeed/timestamp-too-old");

        (
        /*uint80 roundID*/,
            int price2,
        /*uint startedAt*/,
            uint timeStamp2,
        /*uint80 answeredInRound*/
        ) = ethPriceFeed.latestRoundData();

        require(block.timestamp - timeStamp2 < (24 * 3600 + 300), "ethPriceFeed/timestamp-too-old");

        if (price1 < 0 || price2 < 0) {
            return (0, false);
        }


        return (bytes32(uint(price1) * uint(price2) * 1e2), true);
    }
}
