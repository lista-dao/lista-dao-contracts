pragma solidity ^0.8.10;

interface ILisUSDPool {
    function withdraw(uint256 amount) external;

    function deposit(uint256 amount) external;

    function getReward() external;
}