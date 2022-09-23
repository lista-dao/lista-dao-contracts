// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IDao } from "../interfaces/IDao.sol";

contract Dao is IDao {
  mapping(address => mapping(address => uint256)) public deposits;
  mapping(address => mapping(address => uint256)) public withdraws;

  function deposit(
    address participant,
    address token,
    uint256 dink
  ) external returns (uint256) {
    IERC20(token).transferFrom(msg.sender, address(this), dink);
    deposits[participant][token] += dink;
    return dink;
  }

  function withdraw(
    address participant,
    address token,
    uint256 dink
  ) external returns (uint256) {
    deposits[participant][token] -= dink;
    IERC20(token).transfer(msg.sender, dink);
    return dink;
  }

  function dropRewards(address token, address usr) external {}
}
