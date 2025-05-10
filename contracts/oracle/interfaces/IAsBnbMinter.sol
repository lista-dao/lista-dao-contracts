// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IAsBnbMinter {
  function convertToTokens(uint256 asBNBAmount) external view returns (uint256);
  function convertToAsBnb(uint256 tokenAmount) external view returns (uint256);
}
