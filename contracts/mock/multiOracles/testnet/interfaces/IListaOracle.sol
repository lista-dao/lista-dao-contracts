// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

interface IListaOracleTestnet {
  function getPrice(address asset) external view returns (int256);
}
