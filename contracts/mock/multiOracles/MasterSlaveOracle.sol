// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

import "./interfaces/OracleInterface.sol";

contract MasterSlaveOracle {
  PriceFeedInterfaceMock private masterOracle;
  PriceFeedInterfaceMock private slaveOracle;

  constructor(address _masterOracle, address _slaveOracle) {
    masterOracle = PriceFeedInterfaceMock(_masterOracle);
    slaveOracle = PriceFeedInterfaceMock(_slaveOracle);
  }

  function getPrice() external view returns (int256) {
    // get price from main masterOracle
    (
    /*uint80 roundID*/,
      int mainPrice,
    /*uint startedAt*/,
    /*uint timeStamp*/,
    /*uint80 answeredInRound*/
    ) = masterOracle.latestRoundData();
    if (mainPrice > 0) {
      return mainPrice;
    }
    // get price from main slaveOracle
    (
    /*uint80 roundID*/,
      int slavePrice,
    /*uint startedAt*/,
    /*uint timeStamp*/,
    /*uint80 answeredInRound*/
    ) = slaveOracle.latestRoundData();
    if (slavePrice > 0) {
      return slavePrice;
    }
    revert("MasterSlaveOracle/price-invalid");
  }

}
