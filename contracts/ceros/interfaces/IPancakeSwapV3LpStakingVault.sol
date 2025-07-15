// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IPancakeSwapLpStakingVault {

  // @dev type of PancakeSwap LP
  enum LpType {
    V3, // V3 LP - ERC721
    Infinity // Infinity - ERC721
  }

  struct LpProviderStaking {
    address lpToken; // for v3, is the NonFungibleManager
    address rewardToken; // typically CAKE address
    address provider;    // LP provider address
    bool isActive; // is distributor active
    LpType lpType;
  }

  function feeCut(uint256 amount) external;

  /// @dev EVENTS
  event LpProxyUpdated(address oldLpProxy, address newLpProxy);
  event CollectFees(address indexed recipient, uint256 fees);
  event FeeRateUpdated(address indexed lpProvider, uint256 oldFeeRate, uint256 newFeeRate);
  event LpProviderRegistered(address indexed provider, uint256 feeRate);
  event LpProviderDeregistered(address indexed provider);
}
