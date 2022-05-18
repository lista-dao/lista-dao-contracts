// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { IBinancePool } from "../interfaces/IBinancePool.sol";
import { ICertToken } from "../interfaces/ICertToken.sol";

contract Pool is IBinancePool {
  ICertToken public certToken;
  uint256 internal minimumStake_;
  uint256 internal relayerFee_;

  constructor(address _certToken) {
    certToken = ICertToken(_certToken);
  }

  function stakeAndClaimCerts() external payable {
    require(msg.value >= minimumStake_ && msg.value > relayerFee_, "unpossible transaction");
    uint256 transferAmount = msg.value - relayerFee_;
    uint256 certAmount = (transferAmount * certToken.ratio()) / 1e18;
    certToken.mint(msg.sender, certAmount);
  }

  function unstakeCertsFor(address recipient, uint256 shares) external {
    certToken.burn(msg.sender, shares);
    _sendValue(recipient, (shares * 1e18) / certToken.ratio());
  }

  function getMinimumStake() external view returns (uint256) {
    return minimumStake_;
  }

  function getRelayerFee() external view returns (uint256) {
    return relayerFee_;
  }

  function pendingUnstakesOf(address claimer) external view returns (uint256) {}

  function setMinimumStake(uint256 _minimumStake) external {
    minimumStake_ = _minimumStake;
  }

  function setRelayerFee(uint256 _relayerFee) external {
    relayerFee_ = _relayerFee;
  }

  function _sendValue(address receiver, uint256 amount) internal {
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, ) = payable(receiver).call{ value: amount }("");
    require(success, "unable to send value, recipient may have reverted");
  }

  receive() external payable {}
}
