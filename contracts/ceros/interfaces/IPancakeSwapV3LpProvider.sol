// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// @dev interface for PancakeSwapV3LpProvider
interface IPancakeSwapLpProvider {

  struct LiquidatedLp {
    address owner;
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

  // @dev External methods
  function provide(uint256 tokenId) external;
  function release(uint256 tokenId) external;
  function vaultClaimStakingReward(address account) external returns (uint256);
  function syncLpValues(uint256[] calldata tokenIds) external;
  function syncUserLpValues(address user) external;
  function batchSyncUserLpValues(address[] calldata users) external;
  function getLpValue(uint256 tokenId) external view returns (uint256);
  function getLatestUserTotalLpValue(address user) override external;
  function peek() external view returns (bytes32, bool);
}
