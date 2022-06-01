// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface JugLike {
    function drip(bytes32 ilk) external returns (uint256);

    function ilks(bytes32) external view returns (uint256, uint256);

    function base() external view returns (uint256);
}