// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract EzethOracle is Initializable, AccessControl {

    AggregatorV3Interface internal ethUsdPriceFeed;
    AggregatorV3Interface internal ezethEthPriceFeed;


    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    function initialize(address ethUsdAddr,address ezethEthAddr) external initializer {
        ethUsdPriceFeed = AggregatorV3Interface(ethUsdAddr);
        ezethEthPriceFeed = AggregatorV3Interface(ezethEthAddr);
        _setupRole(UPDATER_ROLE, msg.sender);
    }

    function updateAddress(address ethUsdAddr,address ezethEthAddr) external {
        require(hasRole(UPDATER_ROLE, msg.sender), "Caller is not an updater");
        ethUsdPriceFeed = AggregatorV3Interface(ethUsdAddr);
        ezethEthPriceFeed = AggregatorV3Interface(ezethEthAddr);
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
        ) = ethUsdPriceFeed.latestRoundData();

        require(block.timestamp - timeStamp1 < 300, "EthUsdOracle/timestamp-too-old");

        (
        /*uint80 roundID*/,
            int price2,
        /*uint startedAt*/,
            uint timeStamp2,
        /*uint80 answeredInRound*/
        ) = ezethEthPriceFeed.latestRoundData();

        require(block.timestamp - timeStamp2 < (13 * 3600), "EzethEthOracle/timestamp-too-old");

        if (price1 <= 0 || price2 <= 0) {
            return (0, false);
        }


        return (bytes32(uint(price1) * uint(price2) * (10**2)), true);
    }
}
