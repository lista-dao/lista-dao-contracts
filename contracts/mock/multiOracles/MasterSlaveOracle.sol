// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

import "./interfaces/OracleInterface.sol";

contract MasterSlaveOracle is OracleInterfaceMock {
  PriceFeedInterfaceMock private masterOracle;
  PriceFeedInterfaceMock private slaveOracle;

  mapping(address => address[2]) public assetToOracle;

  function setOracle(address _asset, address _masterOracle, address _slaveOracle) external {
    assetToOracle[_asset] = [_masterOracle, _slaveOracle];
  }

  function getPrice(address asset) external view returns (uint256) {
    // get price from main masterOracle
    (
    /*uint80 roundID*/,
      uint256 mainPrice,
    /*uint startedAt*/,
    /*uint timeStamp*/,
    /*uint80 answeredInRound*/
    ) = PriceFeedInterfaceMock(assetToOracle[asset][0]).latestRoundData();
    if (mainPrice > 0) {
      return mainPrice;
    }
    // get price from main slaveOracle
    (
    /*uint80 roundID*/,
      uint256 slavePrice,
    /*uint startedAt*/,
    /*uint timeStamp*/,
    /*uint80 answeredInRound*/
    ) = PriceFeedInterfaceMock(assetToOracle[asset][1]).latestRoundData();
    if (slavePrice > 0) {
      return slavePrice;
    }
    revert("MasterSlaveOracle/price-invalid");
  }

}
