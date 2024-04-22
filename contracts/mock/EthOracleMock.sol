// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../oracle/interfaces/OracleInterface.sol";

contract EthOracleMock is Initializable {

  AggregatorV3Interface internal priceFeed;
  address constant internal resilientOracleAddress = 0x2D9f861Fb030Fa2Bf9Ac64EBD11dF7f337bA7582;
  address constant internal tokenAddress = 0xE7bCB9e341D546b66a46298f4893f5650a56e99E;

  function initialize(address aggregatorAddress) external initializer {
    priceFeed = AggregatorV3Interface(aggregatorAddress);
  }

  /**
   * Returns the latest price
   */
  function peek() public view returns (bytes32, bool) {
    uint256 price = OracleInterface(resilientOracleAddress).peek(tokenAddress);
    return (bytes32(uint(price) * (10**10)), true);
  }
}
