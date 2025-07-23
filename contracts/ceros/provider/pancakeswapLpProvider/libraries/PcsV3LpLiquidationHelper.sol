// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../interfaces/IPancakeSwapV3LpStakingHub.sol";
import "../../../interfaces/IPancakeSwapV3LpProvider.sol";
import "../../../interfaces/ICdp.sol";
import "../../../interfaces/ILpUsd.sol";
import "../../../../oracle/libraries/FullMath.sol";


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

    // pay with token0 first
    if (amount0 > 0 && token0Value > 0) {
      uint256 token0MaxPayable = token0Value;

      if (token0MaxPayable >= amountLeft) {
        // token0 alone is enough to pay the required amount
        uint256 token0AmountToSend = FullMath.mulDiv(amountLeft, amount0, token0MaxPayable);
        IERC20(token0).safeTransfer(recipient, token0AmountToSend);
        token0Sent = token0AmountToSend;
        amountLeft = 0;
      } else {
        // send all of token0
        IERC20(token0).safeTransfer(recipient, amount0);
        token0Sent = amount0;
        amountLeft -= token0MaxPayable;
      }
    }

    // pay the remainder with token1 if necessary
    if (amountLeft > 0 && amount1 > 0 && token1Value > 0) {
      uint256 token1MaxPayable = token1Value;
      require(token1MaxPayable >= amountLeft, "Insufficient token1 value");

      uint256 token1AmountToSend = FullMath.mulDiv(amountLeft, amount1, token1MaxPayable);
      IERC20(token1).safeTransfer(recipient, token1AmountToSend);
      token1Sent = token1AmountToSend;
      amountLeft = 0;
    }

    // Update and return new token balances
    newToken0Left = amount0 > token0Sent ? amount0 - token0Sent : 0;
    newToken1Left = amount1 > token1Sent ? amount1 - token1Sent : 0;
  }

  /**
    * @dev sweep leftover LpUsd after liquidation
    * @param user user address
    * @param lpUsd LpUsd token address
    * @param cdp cdp address
    */
  function sweepLeftoverLpUsd(address user, address lpUsd, address cdp) public {
    // fetch the remaining value of LpUsd after liquidation
    uint256 remaining = ICdp(cdp).free(lpUsd, user);
    // has leftover LpUsd
    if (remaining > 0) {
      // withdraw the remaining and burn
      ICdp(cdp).withdraw(user, lpUsd, remaining);
      ILpUsd(lpUsd).burn(address(this), remaining);
    }
  }
}
