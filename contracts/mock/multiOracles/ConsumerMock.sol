// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

import "./interfaces/OracleInterface.sol";

contract ConsumerMock {

  OracleInterfaceMock private oracle;

  uint256 public price;

  constructor (address _oracle) {
    oracle = OracleInterfaceMock(_oracle);
  }

  function storePrice(address asset) external {
    price = oracle.getPrice(asset);
  }

}
