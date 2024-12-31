// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ILisUSDPool {
    function depositFor(address pool, address account, uint256 amount) external;
}