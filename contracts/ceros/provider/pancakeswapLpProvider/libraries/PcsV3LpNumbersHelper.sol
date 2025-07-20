// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../../interfaces/INonfungiblePositionManager.sol";
import "../../../../oracle/interfaces/IResilientOracle.sol";
import "../../../../libraries/LiquidityAmounts.sol";
import "../../../../libraries/TickMath.sol";

library PcsV3LpNumbersHelper {
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
    address resilientOracle
  )
  public
  view
  returns (uint256 amount0, uint256 amount1)
  {
    // Get fee, tickLower, tickUpper and liquidity
    (
      /* uint96 nonce */,
      /* address operator */,
      /* address token0 */,
      /* address token1 */,
      /*uint24 fee*/,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
      /* uint256 feeGrowthInside0LastX128 */,
      /* uint256 feeGrowthInside1LastX128 */,
      /* uint128 tokensOwed0 */,
      /* uint128 tokensOwed1 */
    ) = INonfungiblePositionManager(nonFungiblePositionManager).positions(tokenId);
    // To prevent manipulation of the price, we compute the fair sqrtPriceX96
    // instead of using slot0 from the pool.
    // address poolAddress = IUniswapV3Factory(pancakeV3Factory).getPool(token0, token1, fee);
    // (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddress).slot0();
    // get sqrtPriceX96 from slot0
    uint160 sqrtPriceX96 = computeFairSqrtPriceX96(resilientOracle, token0, token1);
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
    require(liquidity > 0, "PcsV3LpNumbersHelper: zero-liquidity");
    require(amount0 > 0 || amount1 > 0, "PcsV3LpNumbersHelper: zero-token-amounts");
  }

  // @dev reference from https://github.com/sky-ecosystem/univ3-lp-oracle/blob/master/src/GUniLPOracle.sol
  function computeFairSqrtPriceX96(
    address resilientOracle,
    address token0,
    address token1
  ) private view returns (uint160 sqrtPriceX96) {
    // @note: ResilientOracle returns 8-decimal prices
    uint256 price0 = IResilientOracle(resilientOracle).peek(token0); // 8 decimals
    uint256 price1 = IResilientOracle(resilientOracle).peek(token1); // 8 decimals
    require(price0 != 0 && price1 != 0, "PcsV3LpNumbersHelper: zero-price");

    // scale both to 18 decimals (8 + 10)
    uint256 p0 = price0 * 1e10;
    uint256 p1 = price1 * 1e10;

    // sqrtPriceX96 = sqrt(p1 / p0) * 2^96
    // (p1 * 2^96) / p0
    uint256 ratio = _mul(p1, 1 << 96) / p0;
    // sqrt(p1/p0 * 2^96)
    uint256 sqrtRatio = sqrt(ratio);
    // scale by 2^48 and divide by 1e9 to offset decimals
    sqrtPriceX96 = toUint160(sqrtRatio << 48) / 1e9;
  }

  function _mul(uint256 _x, uint256 _y) private pure returns (uint256 z) {
    require(_y == 0 || (z = _x * _y) / _y == _x, "PcsV3LpNumbersHelper: mul-overflow");
  }

  function toUint160(uint256 x) private pure returns (uint160 z) {
    require((z = uint160(x)) == x, "PcsV3LpNumbersHelper: uint160-overflow");
  }

  function sqrt(uint256 _x) private pure returns (uint128) {
    if (_x == 0) return 0;
    else {
      uint256 xx = _x;
      uint256 r = 1;
      if (xx >= 0x100000000000000000000000000000000) { xx >>= 128; r <<= 64; }
      if (xx >= 0x10000000000000000) { xx >>= 64; r <<= 32; }
      if (xx >= 0x100000000) { xx >>= 32; r <<= 16; }
      if (xx >= 0x10000) { xx >>= 16; r <<= 8; }
      if (xx >= 0x100) { xx >>= 8; r <<= 4; }
      if (xx >= 0x10) { xx >>= 4; r <<= 2; }
      if (xx >= 0x8) { r <<= 1; }
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      uint256 r1 = _x / r;
      return uint128 (r < r1 ? r : r1);
    }
  }
}
