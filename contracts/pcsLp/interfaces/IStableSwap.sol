// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IStableSwap {
  function token() external view returns (address);

  function coins(uint256 i) external view returns (address);

  function balances(uint256 i) external view returns (uint256);

  function calc_token_amount(uint256[2] memory amounts, bool deposit) external view returns (uint256);

  function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external;

  function remove_liquidity(uint256 _amount, uint256[2] memory min_amounts) external;

  function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;

  function remove_liquidity_imbalance(uint256[2] memory amounts, uint256 max_burn_amount) external;

  function get_virtual_price() external view returns (uint256);

  function get_dy(uint256 i, uint256 j, uint256 dx) external view returns (uint256);
}

interface IStableSwapPoolInfo {
  function get_add_liquidity_mint_amount(
    address stableSwapPool,
    uint256[2] memory amounts
  ) external view returns (uint256);

  function calc_coins_amount(address stableSwapPool, uint256 _lpAmount) external view returns (uint256[2] memory);
}
