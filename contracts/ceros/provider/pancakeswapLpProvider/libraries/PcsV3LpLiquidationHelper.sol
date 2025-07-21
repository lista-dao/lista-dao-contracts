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
    // Get leftover token balances from previous liquidation (if any)
    uint256 amount0 = paymentParams.token0Left;
    uint256 amount1 = paymentParams.token1Left;

    // Track how much of each token is actually sent
    uint256 token0Sent = 0;
    uint256 token1Sent = 0;

    // Remaining amount (in USD) that needs to be paid
    uint256 amountLeft = amountToPay;

    // Use the token with lower value first
    if (token0Value < token1Value) {
      // If token0 cannot fully cover the amount and has non-zero balance and price
      if (amountLeft > token0Value && amount0 > 0 && token0Value > 0) {
        IERC20(token0).safeTransfer(recipient, amount0); // Send all token0
        amountLeft -= token0Value;
        token0Sent = amount0;

        // Use token1 for remaining payment
        if (amount1 > 0 && token1Value > 0) {
          uint256 token1AmountToSend = FullMath.mulDiv(amountLeft, amount1, token1Value);
          IERC20(token1).safeTransfer(recipient, token1AmountToSend);
          token1Sent = token1AmountToSend;
        }
      } else if (amount0 > 0 && token0Value > 0) {
        // token0 alone is enough to cover the amount
        uint256 token0AmountToSend = FullMath.mulDiv(amountLeft, amount0, token0Value);
        IERC20(token0).safeTransfer(recipient, token0AmountToSend);
        token0Sent = token0AmountToSend;
      }
    } else {
      // Use token1 first
      if (amountLeft > token1Value && amount1 > 0 && token1Value > 0) {
        IERC20(token1).safeTransfer(recipient, amount1); // Send all token1
        amountLeft -= token1Value;
        token1Sent = amount1;

        // Use token0 for remaining payment
        if (amount0 > 0 && token0Value > 0) {
          uint256 token0AmountToSend = FullMath.mulDiv(amountLeft, amount0, token0Value);
          IERC20(token0).safeTransfer(recipient, token0AmountToSend);
          token0Sent = token0AmountToSend;
        }
      } else if (amount1 > 0 && token1Value > 0) {
        // token1 alone is enough to cover the amount
        uint256 token1AmountToSend = FullMath.mulDiv(amountLeft, amount1, token1Value);
        IERC20(token1).safeTransfer(recipient, token1AmountToSend);
        token1Sent = token1AmountToSend;
      }
    }

    // Update and return remaining token balances
    newToken0Left = amount0 > token0Sent ? amount0 - token0Sent : 0;
    newToken1Left = amount1 > token1Sent ? amount1 - token1Sent : 0;
  }
}
