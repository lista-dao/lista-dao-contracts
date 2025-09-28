// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IStEth {
  function getPooledEthByShares(uint256) external view returns (uint256);
}
