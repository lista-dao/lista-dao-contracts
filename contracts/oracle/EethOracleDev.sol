// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract EethOracleDev is Initializable {

    AggregatorV3Interface internal priceFeed;

    function initialize(address eEthUsdAddr) external initializer {
        priceFeed = AggregatorV3Interface(eEthUsdAddr);
    }

    function updateAddress(address eEthUsdAddr) external {
        priceFeed = AggregatorV3Interface(eEthUsdAddr);
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

        require(block.timestamp - timeStamp < 8 * 60 * 60, "EethUsdOracle/timestamp-too-old");

        return (bytes32(uint(price) * (10**10)), true);
    }
}
