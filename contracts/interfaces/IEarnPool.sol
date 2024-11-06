// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IEarnPool {
    function deposit(address account, uint256 gemAmount, uint256 lisUSDAmount) external;
}