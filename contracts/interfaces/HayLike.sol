// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface HayLike {
    function balanceOf(address) external returns (uint256);

    function transferFrom(address, address, uint256) external returns (bool);

    function approve(address, uint256) external returns (bool);
}
