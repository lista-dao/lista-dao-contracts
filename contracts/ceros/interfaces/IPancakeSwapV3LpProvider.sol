// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// @dev interface for PancakeSwapV3LpProvider
interface IPancakeSwapV3LpProvider {

  // @dev Structs
  // if an user CDP position is being liquidated
  // token0 and token1 amounts from burned LP tokens will be store in this struct
  // to be used in liquidation process, and the leftover amounts will be transferred to the user
  struct UserLiquidation {
    bool ongoing;
    uint256 token0Left;
    uint256 token1Left;
  }

  // @dev Events
  event DepositLp(address user, uint256 tokenId, uint256 lpValue);
  event WithdrawLp(address user, uint256 tokenId, uint256 lpValue);
  event UserCdpPositionSynced(address user, uint256 userTotalLpValue, uint256 userCdpPositionValue);
  event MaxLpPerUserSet(uint256 oldMaxLpValue, uint256 newMaxLpValue);
  event LpExchangeRateSet(uint256 oldExchangeRate, uint256 newExchangeRate);
  event MinLpValueSet(uint256 oldMinLpValue, uint256 newMinLpValue);
  event Liquidated(
    address user,
    address receipient,
    uint256 amount,
    bool isLeftover,
    uint256 token0Left,
    uint256 token1Left
  );

  // @dev External methods
  function token0() external view returns (address);
  function token1() external view returns (address);
  function provide(uint256 tokenId) external;
  function release(uint256 tokenId) external;
  function vaultClaimStakingReward(address account, uint256[] memory tokenIds) external returns (uint256);
  function claimableStakingRewards(address account) external returns (uint256);
  function syncUserLpValues(address user) external;
  function batchSyncUserLpValues(address[] calldata users) external;
  function getLpValue(uint256 tokenId) external view returns (uint256);
  function getLatestUserTotalLpValue(address user) external returns (uint256);
  function peek() external view returns (bytes32, bool);
}
