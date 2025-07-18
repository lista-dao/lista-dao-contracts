// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../interfaces/IPancakeSwapV3LpStakingHub.sol";
import "../../../interfaces/IPancakeSwapV3LpProvider.sol";
import "../../../../oracle/libraries/FullMath.sol";

uint256 constant _RESILIENT_ORACLE_DECIMALS = 1e8;

library PcsV3LpLiquidationHelper {

  using SafeERC20 for IERC20;

  struct PaymentParams {
    address recipient;
    address token0;
    address token1;
    uint256 amountToPay;
    uint256 token0Value;
    uint256 token1Value;
    uint256 token0Left;
    uint256 token1Left;
  }

  /**
    * @dev pay liquidator/user by leftover token0 and token1
    */
  function payByToken0AndToken1(
    PaymentParams memory paymentParams
  ) public returns (uint256 newToken0Left, uint256 newToken1Left) {
    address recipient = paymentParams.recipient;
    uint256 amountToPay = paymentParams.amountToPay;
    address token0 = paymentParams.token0;
    address token1 = paymentParams.token1;
    uint256 token0Value = paymentParams.token0Value;
    uint256 token1Value = paymentParams.token1Value;
    // get user token0 and token1 leftover from previous liquidation(if any)
    uint256 amount0 = paymentParams.token0Left;
    uint256 amount1 = paymentParams.token1Left;
    uint256 token0Sent = 0;
    uint256 token1Sent = 0;
    uint256 amountLeft = amountToPay;
    // use the token with lower value first
    if (token0Value < token1Value) {
      // Use token0 first
      if (amountLeft > token0Value) {
        IERC20(token0).safeTransfer(recipient, amount0);
        amountLeft -= token0Value;
        token0Sent = amount0;
        // Use token1 for the rest
        uint256 token1AmountToSend = FullMath.mulDiv(amountLeft, amount1, token1Value);
        IERC20(token1).safeTransfer(recipient, token1AmountToSend);
        token1Sent = token1AmountToSend;
      } else {
        // Only token0 is needed
        uint256 token0AmountToSend = FullMath.mulDiv(amountLeft, amount0, token0Value);
        IERC20(token0).safeTransfer(recipient, token0AmountToSend);
        token0Sent = token0AmountToSend;
      }
    } else {
      // Use token1 first
      if (amountLeft > token1Value) {
        IERC20(token1).safeTransfer(recipient, amount1);
        amountLeft -= token1Value;
        token1Sent = amount1;
        // Use token0 for the rest
        uint256 token0AmountToSend = FullMath.mulDiv(amountLeft, amount0, token0Value);
        IERC20(token0).safeTransfer(recipient, token0AmountToSend);
        token0Sent = token0AmountToSend;
      } else {
        // Only token1 is needed
        uint256 token1AmountToSend = FullMath.mulDiv(amountLeft, amount1, token1Value);
        IERC20(token1).safeTransfer(recipient, token1AmountToSend);
        token1Sent = token1AmountToSend;
      }
    }
    // update leftovers
    newToken0Left = amount0 - token0Sent;
    newToken1Left = amount1 - token1Sent;
  }
}
