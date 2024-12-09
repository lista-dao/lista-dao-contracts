// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";

contract ETHV2Oracle is Initializable {

    IResilientOracle constant public resilientOracle = IResilientOracle(0xf3afD82A4071f272F403dC176916141f44E6c750);
    address constant ETH_TOKEN_ADDR = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
      * Returns the latest price
      */
    function peek() public view returns (bytes32, bool) {
        // get ETH/USD price (8 decimals)
        uint256 price = resilientOracle.peek(ETH_TOKEN_ADDR);
        return (bytes32(uint(price) * 1e10), true);
    }
}
