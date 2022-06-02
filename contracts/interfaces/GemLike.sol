// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface GemLike is IERC20 {
    function decimals() external view returns (uint);
}