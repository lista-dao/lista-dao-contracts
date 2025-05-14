// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";

contract StoneOracle is Initializable {

    address public constant STONE_TOKEN_ADDR = 0x80137510979822322193FC997d400D5A6C747bf7;
    address public constant RESILIENT_ORACLE_ADDR = 0xf3afD82A4071f272F403dC176916141f44E6c750;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
      * Returns the latest price of Stone in USD
      */
    function peek() public view returns (bytes32, bool) {
        // get price from resilient oracle in 8 DPs
        uint256 price = IResilientOracle(RESILIENT_ORACLE_ADDR).peek(STONE_TOKEN_ADDR);
        return (bytes32(uint(price) * 1e10), true);
    }
}
