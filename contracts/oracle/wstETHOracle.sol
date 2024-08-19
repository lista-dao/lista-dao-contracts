// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IResilientOracle.sol";

contract WstETHOracle is Initializable {

  IResilientOracle public resilientOracle;
  address constant ETH_TOKEN_ADDR = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
  address constant WSTETH_TOKEN_ADDR = 0x26c5e01524d2E6280A48F2c50fF6De7e52E9611C;

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
    // get ETH/USD price (8 decimals)
    uint256 ethPrice = resilientOracle.peek(ETH_TOKEN_ADDR);
    // get wstETH/ETH price (8 decimals)
    uint256 wstETHPrice = resilientOracle.peek(WSTETH_TOKEN_ADDR);
    // calculate wstETH/USD (18 decimals)
    return (bytes32(uint(ethPrice) * uint(wstETHPrice) * 1e2), true);
  }
}
