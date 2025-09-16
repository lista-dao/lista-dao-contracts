// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IPancakeSwapV3LpStakingVault {

  /// @dev Functions
  function feeCut(uint256 amount) external returns (uint256 rewardsAfterFeeCut, uint256 fee);

  /// @dev Events
  event FeeCut(address indexed recipient, uint256 amount, uint256 fee);
  event LpProxyUpdated(address oldLpProxy, address newLpProxy);
  event CollectFees(address recipient, uint256 fees);
  event FeeRateUpdated(address lpProvider, uint256 oldFeeRate, uint256 newFeeRate);
  event LpProviderRegistered(address provider, uint256 feeRate);
  event LpProviderDeregistered(address provider);
}
