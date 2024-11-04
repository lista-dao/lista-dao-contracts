pragma solidity ^0.8.10;

interface IVaultManager {
    function deposit(uint256 amount) external;

    function withdraw(address receiver, uint256 amount) external;
}