// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract EzethOracle is Initializable {

    AggregatorV3Interface internal priceFeed;

    function initialize(address aggregatorAddress) external initializer {
        priceFeed = AggregatorV3Interface(aggregatorAddress);
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
        ) = priceFeed.latestRoundData();

        require(block.timestamp - timeStamp1 < 3600, "ezETHUsdOracle/timestamp-too-old");

        return (bytes32(uint(price1) * (10**10)), true);
    }
}
