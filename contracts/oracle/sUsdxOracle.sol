// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";

contract sUsdxOracle is Initializable {

    IResilientOracle public resilientOracle;
    address constant sUSDX_TOKEN_ADDR = 0xf3527ef8dE265eAa3716FB312c12847bFBA66Cef;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _resilientOracle) external initializer {
        resilientOracle = IResilientOracle(_resilientOracle);
    }

    /**
      * Returns the latest price
      */
    function peek() public view returns (bytes32, bool) {
        uint256 price = resilientOracle.peek(sUSDX_TOKEN_ADDR);
        return (bytes32(uint(price) * 1e10), true);
    }
}
