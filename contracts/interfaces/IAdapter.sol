pragma solidity ^0.8.10;

interface IAdapter {
    function deposit(uint256 amount) external;

    function withdraw(address account, uint256 amount) external;
}