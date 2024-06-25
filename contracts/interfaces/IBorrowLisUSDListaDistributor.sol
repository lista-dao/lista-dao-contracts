// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBorrowLisUSDListaDistributor {
  function takeSnapshot(address token, address user, uint256 _debt) external;
}
