// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../interfaces/IPancakeSwapV3LpStakingHub.sol";
import "../../../interfaces/IPancakeSwapV3LpProvider.sol";
import "../../../interfaces/ICdp.sol";
import { Sale } from "../../../interfaces/ICdp.sol";
import "../../../interfaces/ILpUsd.sol";
import "../../../../oracle/libraries/FullMath.sol";


library PcsV3LpLiquidationHelper {

  using SafeERC20 for IERC20;

  struct PostLiquidationParams {
    address cdp;
    address collateral;
    address user;
    address token0;
    address token1;
    uint256 token0Left;
    uint256 token1Left;
    // when is true, either all debt is repaid or all collateral is seized
    // but it as `true` might never happen
    bool isLeftOver;
  }

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

      if (token1MaxPayable >= amountLeft) {
        // token1 is enough to pay the rest of the amount
        uint256 token1AmountToSend = FullMath.mulDiv(amountLeft, amount1, token1MaxPayable);
        IERC20(token1).safeTransfer(recipient, token1AmountToSend);
        token1Sent = token1AmountToSend;
        amountLeft = 0;
      } else {
        // send all of token1
        IERC20(token1).safeTransfer(recipient, amount1);
        token1Sent = amount1;
        amountLeft -= token1MaxPayable;
      }
    }

    // Update and return new token balances
    newToken0Left = amount0 > token0Sent ? amount0 - token0Sent : 0;
    newToken1Left = amount1 > token1Sent ? amount1 - token1Sent : 0;
  }

  /**
    * @dev Post liquidation logic
    *      - Check if liquidation ended by checking user's remaining debt and collateral
    *      - Sweep leftover LpUsd after liquidation
    *      - Send leftover token0 and token1 to user
    * @param postLiquidationParams The parameters for post-liquidation processing
    */
  function postLiquidation(PostLiquidationParams memory postLiquidationParams) public returns (bool liquidationEnded) {
    address cdp = postLiquidationParams.cdp;
    address collateral = postLiquidationParams.collateral;
    address user = postLiquidationParams.user;
    address token0 = postLiquidationParams.token0;
    address token1 = postLiquidationParams.token1;
    bool isLeftOver = postLiquidationParams.isLeftOver;
    liquidationEnded = false;
    // Get user's remaining debt and collateral
    (uint256 remainingDebt, uint256 remainingCollateral) = getUserRemainingDebtAndCollaterals(cdp, collateral, user);
    // no collateral or debt is left, liquidation ended
    if (remainingDebt == 0 || remainingCollateral == 0 || isLeftOver) {
      // send leftover token0 and token1 to user
      uint256 token0Left = postLiquidationParams.token0Left;
      uint256 token1Left = postLiquidationParams.token1Left;
      if (token1Left > 0) {
        IERC20(token1).safeTransfer(user, token1Left);
      }
      if (token0Left > 0) {
        IERC20(token0).safeTransfer(user, token0Left);
      }
      liquidationEnded = true;
    }
  }

  /**
    * @dev Search a liquidating position with user address
    *      If either of user's debt or/and leftover collateral is 0, liquidation is considered done
    * @param cdp CDP address
    * @param token Token address
    * @param user User address
    */
  function getUserRemainingDebtAndCollaterals(address cdp, address token, address user) internal view returns (uint256 remainingDebt, uint256 remainingCollateral) {
    // get clipper of LpUsd
    (,,,address clipper) = ICdp(cdp).collaterals(token);
    // get all acitve auction ids from clipper
    uint256[] memory auctionIds = ClipperLike(clipper).list();
    // search user's auction Id by matching
    for (uint256 i = 0; i < auctionIds.length; ++i) {
      Sale memory sale = ClipperLike(clipper).sales(auctionIds[i]);
      // Check if the sale belongs to the user
      if (sale.usr == user) {
        remainingDebt = sale.tab;
        remainingCollateral = sale.lot;
        break;
      }
    }
  }

  /**
   * @dev Check if user's total LP value can cover all lot
   * @param user User address
   * @param token0Value Token0 value in USD
   * @param token1Value Token1 value in USD
   * @param amount amount of `lot` to cover
   */
  function canUserWealthCoversAmount(
    address user,
    uint256 token0Value,
    uint256 token1Value,
    uint256 amount
  ) public returns (bool) {
    // get user's latest total Lp Value
    uint256 totalLpValue = IPancakeSwapV3LpProvider(address(this)).getLatestUserTotalLpValue(user);
    // tells if user's total LP value is enough to cover the debt
    return totalLpValue + token0Value + token1Value >= amount;
  }
}
