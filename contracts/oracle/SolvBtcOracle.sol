// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/IResilientOracle.sol";


contract SolvBtcOracle is Initializable {

    IResilientOracle constant public resilientOracle = IResilientOracle(0xf3afD82A4071f272F403dC176916141f44E6c750);
    address constant public TOKEN = 0x4aae823a6a0b376De6A78e74eCC5b079d38cBCf7;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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
