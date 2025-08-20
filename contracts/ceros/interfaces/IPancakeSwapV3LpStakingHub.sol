// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IPancakeSwapV3LpStakingHub {

  /// @dev Functions
  function deposit(uint256 tokenId) external;
  function withdraw(uint256 tokenId) external returns (uint256);
  function harvest(uint256 tokenId) external returns (uint256);
  function burnAndCollect(
    uint256 tokenId,
    uint256 amount0Min,
    uint256 amount1Min,
    uint256 deadline
  ) external returns (uint256 amount0, uint256 amount1, uint256 rewards);

  /// @dev Events
  event RegisterProvider(address provider);
  event DeregisterProvider(address provider);
  event DepositLp(address provider, uint256 tokenId);
  event WithdrawLp(address provider, uint256 tokenId, uint256 rewardAmount);
  event BurnLp(address provider, uint256 tokenId, uint256 rewardAmount, uint256 amount1, uint256 amount0);
  event Harvest(address provider, uint256 tokenId, uint256 rewardAmount);
  event StopEmergencyMode();
  event EmergencyWithdraw();
}
