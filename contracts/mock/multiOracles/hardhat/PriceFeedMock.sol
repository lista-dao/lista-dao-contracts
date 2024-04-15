// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interfaces/OracleInterface.sol";

contract PriceFeedMock is PriceFeedInterfaceMock, OracleInterfaceMock {

  uint8 private failRate;

  constructor(uint8 _failRate) {
    failRate = _failRate;
  }

  function latestRoundData()
    external
    view
    returns (uint80, uint256, uint256, uint256, uint80)
  {
    if (failRate > 0 && block.timestamp % uint256(failRate) == 0) {
      return (18446744073709551616, 0, block.timestamp, block.timestamp, 18446744073709551616);
    }
    return (18446744073709551616, 60735088942, block.timestamp, block.timestamp, 18446744073709551616);
  }

  function getPrice(address asset) external view returns (uint256) {
    if (failRate > 0 && block.timestamp % uint256(failRate) == 0) {
      return 0;
    }
    return 60735088942;
  }

}
