// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface GemJoinLike {
    function join(address usr, uint256 wad) external;

    function exit(address usr, uint256 wad) external;

    function gem() external view returns (IERC20);
}