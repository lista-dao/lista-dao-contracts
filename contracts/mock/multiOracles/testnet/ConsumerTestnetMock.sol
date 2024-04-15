// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

import "./interfaces/IListaOracle.sol";

contract ConsumerTestnetMock {

  IListaOracleTestnet private oracle;

  int256 public price;

  constructor (address _oracle) {
    oracle = IListaOracleTestnet(_oracle);
  }

  function storePrice(address asset) external {
    price = oracle.getPrice(asset);
  }

}
