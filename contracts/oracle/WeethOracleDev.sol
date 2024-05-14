// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract WeethOracleDev is Initializable,AccessControl {

    AggregatorV3Interface internal weethEthPrice;
    AggregatorV3Interface internal ethUsdPrice;
    uint internal weethEthHeartbeat ;
    uint internal ethUsdHeartbeat;

    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    function initialize(address weethEthPriceAddr,address ethUsdPriceAddr,uint weethHeartbeat,uint ethHeartbeat) external initializer {
        weethEthPrice = AggregatorV3Interface(weethEthPriceAddr);
        ethUsdPrice = AggregatorV3Interface(ethUsdPriceAddr);
        weethEthHeartbeat = weethHeartbeat;
        ethUsdHeartbeat = ethHeartbeat;
        _setupRole(UPDATER_ROLE, msg.sender);
    }

    function updateAddress(address weethEthPriceAddr,address ethUsdPriceAddr) external {
        require(hasRole(UPDATER_ROLE, msg.sender), "Caller is not an updater");
        weethEthPrice = AggregatorV3Interface(weethEthPriceAddr);
        ethUsdPrice = AggregatorV3Interface(ethUsdPriceAddr);
    }

    function updateHeartBeat(uint weethHeartbeat,uint ethHeartbeat) external {
        require(hasRole(UPDATER_ROLE, msg.sender), "Caller is not an updater");
        if ( weethEthHeartbeat > 0 ) {
            weethEthHeartbeat = weethHeartbeat;
        }
        if( ethHeartbeat > 0 ) {
            ethUsdHeartbeat = ethHeartbeat;
        }
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

        require(block.timestamp - timeStamp1 < weethEthHeartbeat, "weethEthPriceFeed/timestamp-too-old");

        (
        /*uint80 roundID*/,
            int price2,
        /*uint startedAt*/,
            uint timeStamp2,
        /*uint80 answeredInRound*/
        ) = ethUsdPrice.latestRoundData();

        require(block.timestamp - timeStamp2 < ethUsdHeartbeat, "ethUsdPriceFeed/timestamp-too-old");

        if (price1 <= 0 || price2 <= 0) {
            return (0, false);
        }


        return (bytes32(uint(price1) * uint(price2) * (10**2)), true);
    }
}
