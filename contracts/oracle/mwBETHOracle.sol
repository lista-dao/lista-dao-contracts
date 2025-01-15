// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/IResilientOracle.sol";


contract mwBETHOracle is Initializable {
    IResilientOracle constant public resilientOracle = IResilientOracle(0xf3afD82A4071f272F403dC176916141f44E6c750);
    address constant public TOKEN = 0x7dC91cBD6CB5A3E6A95EED713Aa6bF1d987146c8;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {}

    /**
     * Returns the latest price
     */
    function peek() public view returns (bytes32, bool) {
        uint256 price = resilientOracle.peek(TOKEN);
        if (price <= 0) {
            return (0, false);
        }
        return (bytes32(uint(price) * 1e10), true);
    }
}
