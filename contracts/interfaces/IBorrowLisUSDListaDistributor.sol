// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBorrowLisUSDListaDistributor {
  function takeSnapshot(address token, address user, uint256 _debt) external;

  function takeSnapshot(
    address _collateralToken, address _user,
    uint256 _ink, uint256 _art,
    bool _inkUpdated, bool _artUpdated
  ) external;
}
