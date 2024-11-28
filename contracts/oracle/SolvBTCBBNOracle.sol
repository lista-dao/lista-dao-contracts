// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";

contract SolvBTCBBNOracle is Initializable {

    address constant SOLVE_BTC_TOKEN_ADDR = 0x4aae823a6a0b376De6A78e74eCC5b079d38cBCf7;
    address constant SOLVE_BTC_BBN_TOKEN_ADDR = 0x1346b618dC92810EC74163e4c27004c921D446a5;

    IResilientOracle public resilientOracle;

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
        // get Btc/USD price (8 decimals)
        uint256 solveBtcPrice = resilientOracle.peek(SOLVE_BTC_TOKEN_ADDR);
        // get SolveBtcBBN/Btc price (8 decimals)
        uint256 solveBtcBbnPrice = resilientOracle.peek(SOLVE_BTC_BBN_TOKEN_ADDR);
        // calculate SolveBtcBBN/USD (18 decimals)
        return (bytes32(uint(solveBtcPrice) * uint(solveBtcBbnPrice) * 1e2), true);
    }
}
