// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IResilientOracle } from "./interfaces/IResilientOracle.sol";
import "./interfaces/AggregatorV3Interface.sol";

contract BnbOracle is Initializable {

    AggregatorV3Interface internal priceFeed;
    // @dev resilient oracle address
    address constant public resilientOracleAddr = 0xf3afD82A4071f272F403dC176916141f44E6c750;
    // @dev *WBNB* token address
    address constant public TOKEN = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    function initialize(address aggregatorAddress) external initializer {
        priceFeed = AggregatorV3Interface(aggregatorAddress);
    }

    /**
     * Returns the latest price
     */
    function peek() public view returns (bytes32, bool) {
        // get BNB price from resilient oracle, 8 decimals
        // in case price is zero, resilient oracle will revert
        uint256 price = IResilientOracle(resilientOracleAddr).peek(TOKEN);
        return (bytes32(uint(price) * (10**10)), true);
    }
}
