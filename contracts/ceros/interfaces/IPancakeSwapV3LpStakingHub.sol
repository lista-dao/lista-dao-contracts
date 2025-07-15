// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IPancakeSwapV3StakingHub {

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

  function deposit(uint256 payload) external;
  function withdraw(uint256 payload) external;
  function harvest(uint256 payload) external returns (uint256);

  event RegisterProvider(
    address provider,
    address lpToken,
    address rewardToken,
    LpType lpType
  );
  event DeregisterProvider(address provider);
  event DepositV3Lp(address provider, uint256 tokenId);
  event WithdrawV3Lp(address provider, address tokenId, uint256 rewardAmount);
  event HarvestV3(address provider, uint256 tokenId, uint256 rewardAmount);
  event StopEmergencyMode();
  event EmergencyWithdraw();
}
