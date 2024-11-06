// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IAdapter {
    function deposit(uint256 amount) external;

    function withdraw(address account, uint256 amount) external;

    function totalAvailableAmount() external returns (uint256);

    function withdrawAll() external returns (uint256);

    function netDepositAmount() external view returns (uint256);
}