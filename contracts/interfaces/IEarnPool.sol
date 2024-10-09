pragma solidity ^0.8.10;

interface IEarnPool {
    function deposit(address account, uint256 gemAmount, uint256 lisUSDAmount) external;

    function withdrawLisUSD(address account, uint256 amount) external returns (uint256);

    function withdrawGem(address account, uint256 amount) external returns (uint256);
}