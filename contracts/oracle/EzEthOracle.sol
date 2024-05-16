// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/AggregatorV3Interface.sol";

contract EzEthOracle is Initializable {

    AggregatorV3Interface public priceFeed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address aggregatorAddress) external initializer {
        priceFeed = AggregatorV3Interface(aggregatorAddress);
    }

    /**
      * Returns the latest price
      */
    function peek() public view returns (bytes32, bool) {
        (
        /*uint80 roundID*/,
            int price,
        /*uint startedAt*/,
            uint timeStamp,
        /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();

        require(block.timestamp - timeStamp < (3600 + 300), "ezEthOracle/timestamp-too-old");

        if (price < 0) {
            return (0, false);
        }
        return (bytes32(uint(price) * 1e10), true);
    }
}
