// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract StoneOracleDev is Initializable {

    AggregatorV3Interface internal priceFeed;

    function initialize(address stoneAddr) external initializer {
        priceFeed = AggregatorV3Interface(stoneAddr);
    }

    function updateAddress(address stoneAddr) external {
        priceFeed = AggregatorV3Interface(stoneAddr);
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

        require(block.timestamp - timeStamp < 8 * 60 * 60, "StoneOracle/timestamp-too-old");

        return (bytes32(uint(price) * (10**10)), true);
    }
}
