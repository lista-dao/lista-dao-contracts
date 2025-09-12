// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;

struct DecreaseLiquidityParams {
  uint256 tokenId; // tokenId The ID of the token for which liquidity is being decreased,
  uint128 liquidity; // amount The amount by which liquidity will be decreased,
  uint256 amount0Min; // amount0Min The minimum amount of token0 that should be accounted for the burned liquidity,
  uint256 amount1Min; // amount1Min The minimum amount of token1 that should be accounted for the burned liquidity,
  uint256 deadline; // deadline The time by which the transaction must be included to effect the change (20mins from pancakeSwap frontend)
}

struct CollectParams {
  uint256 tokenId;
  address recipient;
  uint128 amount0Max;
  uint128 amount1Max;
}
