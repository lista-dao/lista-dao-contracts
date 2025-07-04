// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import { IStakingHub } from "./interfaces/IStakingHub.sol";
import { IStakingVault } from "./interfaces/IStakingVault.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title Pancake ERC20 Lp Farming Reward Distributor
 * @dev
 */
abstract contract ERC20LpRewardDistributor is AccessControlEnumerableUpgradeable, PausableUpgradeable {
  using SafeERC20 for IERC20;

  ///@dev V2/SS LP token address
  address public pancakeLpToken;

  // token name
  string public name;
  // token symbol
  string public symbol;

  // staking address
  address public stakingHub;
  // stake vault address
  address public stakingVault;

  // v2/ss lp token balance of each account
  mapping(address => uint256) public lpBalanceOf;
  // v2/ss lp token supply
  uint256 public lpTotalSupply;
  // stake token period finish
  uint256 public stakePeriodFinish;
  // stake token last update operation timestamp
  uint256 public stakeLastUpdate;
  // stake token reward of per token
  uint256 public stakeRewardIntegral;
  // stake token reward of per second
  uint256 public stakeRewardRate;
  // stake token reward integral for each account on last update time
  // account -> reward integral
  mapping(address => uint256) public stakeRewardIntegralFor;
  // stake token pending reward for each account
  // account -> pending reward
  mapping(address => uint256) private stakeStoredPendingReward;

  // reward duration is 1 week
  uint256 constant REWARD_DURATION = 1 weeks;
  // decimals
  uint8 public constant decimals = 18;

  bytes32 public constant PAUSER = keccak256("PAUSER");

  event StakeRewardClaimed(address indexed receiver, uint256 amount);
  event LPTokenDeposited(address indexed pancakeLpToken, address indexed receiver, uint256 amount);
  event LPTokenWithdrawn(address indexed pancakeLpToken, address indexed receiver, uint256 amount);

  modifier onlyStakeVault() {
    require(msg.sender == stakingVault, "only stake vault can call this function");
    _;
  }

  /**
   * @dev deposit LP token to get rewards
   * @param amount amount of LP token
   */
  function _deposit(uint256 amount) internal {
    require(amount > 0, "Cannot deposit zero");
    IERC20(pancakeLpToken).safeTransferFrom(msg.sender, address(this), amount);
    _depositLp(msg.sender, amount);
  }

  /**
   * @dev withdraw LP token
   * @param amount amount of LP token
   */
  function _withdraw(uint256 amount) internal {
    require(amount > 0, "Cannot withdraw zero");
    _withdrawLp(msg.sender, amount);
  }

  // deposit lp to staking pool
  function _depositLp(address _account, uint256 amount) private {
    uint256 balance = lpBalanceOf[_account];
    uint256 supply = lpTotalSupply;

    lpBalanceOf[_account] = balance + amount;
    lpTotalSupply = supply + amount;

    _updateStakeReward(_account, balance, supply);

    // deposit to staking contract to earn reward
    IERC20(pancakeLpToken).safeApprove(stakingHub, amount);
    IStakingHub(stakingHub).deposit(pancakeLpToken, amount);

    emit LPTokenDeposited(pancakeLpToken, _account, amount);
  }

  // withdraw lp from staking pool
  function _withdrawLp(address _account, uint256 amount) private {
    uint256 balance = lpBalanceOf[_account];
    uint256 supply = lpTotalSupply;
    require(balance >= amount, "insufficient balance");
    lpBalanceOf[_account] = balance - amount;
    lpTotalSupply = supply - amount;

    _updateStakeReward(_account, balance, supply);

    IStakingHub(stakingHub).withdraw(_account, pancakeLpToken, amount);

    emit LPTokenWithdrawn(pancakeLpToken, _account, amount);
  }

  // when account do write operation, update reward
  function _updateStakeReward(address _account, uint256 balance, uint256 supply) internal {
    // update reward
    uint256 updated = stakePeriodFinish;
    if (updated > block.timestamp) updated = block.timestamp;
    uint256 duration = updated - stakeLastUpdate;
    if (duration > 0) stakeLastUpdate = uint32(updated);

    if (duration > 0 && supply > 0) {
      stakeRewardIntegral += (duration * stakeRewardRate * 1e18) / supply;
    }
    if (_account != address(0)) {
      uint256 integralFor = stakeRewardIntegralFor[_account];
      if (stakeRewardIntegral > integralFor) {
        stakeStoredPendingReward[_account] += (balance * (stakeRewardIntegral - integralFor)) / 1e18;
        stakeRewardIntegralFor[_account] = stakeRewardIntegral;
      }
    }
  }

  /**
   * @dev notify staking reward, only staking vault can call this function
   * @param amount reward amount
   */
  function notifyStakingReward(uint256 amount) external onlyStakeVault {
    _updateStakeReward(address(0), 0, lpTotalSupply);
    uint256 _periodFinish = stakePeriodFinish;
    if (block.timestamp < _periodFinish) {
      uint256 remaining = _periodFinish - block.timestamp;
      amount += remaining * stakeRewardRate;
    }

    stakeRewardRate = amount / REWARD_DURATION;

    stakeLastUpdate = block.timestamp;
    stakePeriodFinish = block.timestamp + REWARD_DURATION;
  }

  /**
   * @dev claim reward, only staking vault can call this function
   * @param _account account address
   * @return reward amount
   */
  function vaultClaimStakingReward(address _account) external onlyStakeVault returns (uint256) {
    return _claimStakingReward(_account);
  }

  function _claimStakingReward(address _account) internal returns (uint256) {
    _updateStakeReward(_account, lpBalanceOf[_account], lpTotalSupply);
    uint256 amount = stakeStoredPendingReward[_account];
    delete stakeStoredPendingReward[_account];

    emit StakeRewardClaimed(_account, amount);
    return amount;
  }

  /**
   * @dev claim stake reward
   * @return reward amount
   */
  function claimStakeReward() external returns (uint256) {
    address _account = msg.sender;
    uint256 amount = _claimStakingReward(_account);
    IStakingVault(stakingVault).transferAllocatedTokens(_account, amount);
    return amount;
  }

  /**
   * @dev get stake claimable reward amount
   * @param account account address
   * @return reward amount
   */
  function getStakeClaimableReward(address account) external view returns (uint256) {
    uint256 balance = lpBalanceOf[account];
    uint256 supply = lpTotalSupply;
    uint256 updated = stakePeriodFinish;
    if (updated > block.timestamp) updated = block.timestamp;
    uint256 duration = updated - stakeLastUpdate;
    uint256 integral = stakeRewardIntegral;
    if (supply > 0) {
      integral += (duration * stakeRewardRate * 1e18) / supply;
    }
    uint256 integralFor = stakeRewardIntegralFor[account];
    return stakeStoredPendingReward[account] + (balance * (integral - integralFor)) / 1e18;
  }

  /// @dev Flips the pause state
  function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    paused() ? _unpause() : _pause();
  }

  /// @dev pause the contract
  function pause() external onlyRole(PAUSER) {
    _pause();
  }

  /// @dev harvest farming reward from third-party staking pool
  function harvest() external {
    IStakingHub(stakingHub).harvest(pancakeLpToken);
  }
  // storage gap
  uint256[49] __gap;
}
