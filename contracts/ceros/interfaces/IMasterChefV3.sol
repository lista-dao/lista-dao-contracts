// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;
import { DecreaseLiquidityParams, CollectParams } from "./IPancakeV3LpStructs.sol";

// @dev interface for MasterChefV3, the farming contract of PancakeSwap V3 LP
interface IMasterChefV3 {
  function emergency() external returns (bool);
  function withdraw(uint256 tokenId, address to) external returns (uint256 reward);
  function harvest(uint256 tokenId, address to) external returns (uint256 reward);
  function pendingCake(uint256 tokenId) external view returns (uint256 reward);

  /// @dev Decreases the amount of liquidity in a position and accounts it to the position
  /// @return amount0 The amount of token0 accounted to the position's tokens owed
  /// @return amount1 The amount of token1 accounted to the position's tokens owed
  function decreaseLiquidity(DecreaseLiquidityParams memory params) external returns (uint256 amount0, uint256 amount1);

  /// @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
  /// @param params tokenId The ID of the NFT for which tokens are being collected,
  /// recipient The account that should receive the tokens,
  /// @dev Warning!!! Please make sure to use multicall to call unwrapWETH9 or sweepToken when set recipient address(0), or you will lose your funds.
  /// amount0Max The maximum amount of token0 to collect,
  /// amount1Max The maximum amount of token1 to collect
  /// @return amount0 The amount of fees collected in token0
  /// @return amount1 The amount of fees collected in token1
  function collect(CollectParams memory params) external returns (uint256 amount0, uint256 amount1);

  /// @notice Burns a token ID, which deletes it from the NFT contract. The token must have 0 liquidity and all tokens
  /// must be collected first.
  /// @param tokenId The ID of the token that is being burned
  function burn(uint256 tokenId) external;
}
