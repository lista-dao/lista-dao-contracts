// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { JugLike } from "../../interfaces/JugLike.sol";
import { GemJoinLike } from "../../interfaces/GemJoinLike.sol";
import { IDao } from "../interfaces/IDao.sol";

contract Dao is IDao {
  JugLike public jug;
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

  function setCollateralDuty(address token, uint256 duty) external {}

  function setHelioProvider(address token, address helioProvider) external {}

  function collaterals(address token) external view returns (GemJoinLike gem, bytes32 ilk, uint32 live, address clip) {}

  function locked(address token, address usr) public view returns (uint256) {
    return 0;
  }

  function free(address token, address usr) public view returns (uint256) {
    return 0;
  }
}
