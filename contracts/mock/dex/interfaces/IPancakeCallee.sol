// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IPancakeCallee {
    function pancakeCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}