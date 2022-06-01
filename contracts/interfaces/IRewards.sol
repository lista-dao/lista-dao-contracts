// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IRewards {
    function drop(address token, address usr) external;
}