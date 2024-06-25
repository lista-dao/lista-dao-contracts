// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IStakeLisUSDListaDistributor {
  function takeSnapshot(address user, uint256 _balance) external;
}
