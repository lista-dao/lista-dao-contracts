// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./interfaces/IResilientOracle.sol";

contract WBETHOracle {

  /// @dev resilient oracle address
  address constant public resilientOracleAddr = 0xf3afD82A4071f272F403dC176916141f44E6c750;
  /// @dev *WBETH* token address
  address constant public WBETH_TOKEN_ADDR = 0xa2E3356610840701BDf5611a53974510Ae27E2e1;

  /**
   * returns the latest price of WBETH
   */
  function peek() public view returns (bytes32, bool) {
    uint256 price = IResilientOracle(resilientOracleAddr).peek(WBETH_TOKEN_ADDR);
    return (bytes32(uint(price) * (10**10)), true);
  }
}
