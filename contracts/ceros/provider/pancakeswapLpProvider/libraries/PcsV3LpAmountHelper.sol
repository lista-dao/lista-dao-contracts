// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../../interfaces/INonfungiblePositionManager.sol";
import "../../../interfaces/IUniswapV3Factory.sol";
import "../../../interfaces/IUniswapV3Pool.sol";
import "../../../../libraries/LiquidityAmounts.sol";
import "../../../../libraries/TickMath.sol";

library PcsV3LpAmountHelper {
  /**
  * @dev Get amounts of token0 and token1 for a given NFT
    * @param tokenId the tokenId of the NFT
    * @return amount0 the amount of token0
    * @return amount1 the amount of token1
    */
  function getAmounts(
    uint256 tokenId,
    address token0,
    address token1,
    address nonFungiblePositionManager,
    address pancakeV3Factory
  )
  external
  view
  returns (uint256 amount0, uint256 amount1)
  {
    // Get fee, tickLower, tickUpper and liquidity
    (
    /* uint96 nonce */,
    /* address operator */,
    /* address token0 */,
    /* address token1 */,
      uint24 fee,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
    /* uint256 feeGrowthInside0LastX128 */,
    /* uint256 feeGrowthInside1LastX128 */,
    /* uint128 tokensOwed0 */,
    /* uint128 tokensOwed1 */
    ) = INonfungiblePositionManager(nonFungiblePositionManager).positions(tokenId);
    // get pool from pool factory
    address poolAddress = IUniswapV3Factory(pancakeV3Factory).getPool(token0, token1, fee);
    // get sqrtPriceX96 from slot0
    (
      uint160 sqrtPriceX96,
    /* int24 tick */,
    /* uint16 observationIndex */,
    /* uint16 observationCardinality */,
    /* uint16 observationCardinalityNext */,
    /* uint8 feeProtocol */,
    /* bool unlocked */
    ) = IUniswapV3Pool(poolAddress).slot0();
    uint160 sqrtPriceX96Lower = TickMath.getSqrtRatioAtTick(tickLower);
    uint160 sqrtPriceX96Upper = TickMath.getSqrtRatioAtTick(tickUpper);
    (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
      sqrtPriceX96, sqrtPriceX96Lower, sqrtPriceX96Upper, liquidity
    );
    // normalize amount0 and amount1 into 18 decimal places
    uint8 decimals0 = IERC20Metadata(token0).decimals();
    uint8 decimals1 = IERC20Metadata(token1).decimals();

    if (decimals0 < 18) {
      amount0 = amount0 * (10 ** (18 - decimals0));
    } else if (decimals0 > 18) {
      amount0 = amount0 / (10 ** (decimals0 - 18));
    }

    if (decimals1 < 18) {
      amount1 = amount1 * (10 ** (18 - decimals1));
    } else if (decimals1 > 18) {
      amount1 = amount1 / (10 ** (decimals1 - 18));
    }
    // verification of zero liquidity when user deposit
    require(amount0 > 0 || amount1 > 0, "PcsV3LpProvider: zero-amounts");
  }
}
