pragma solidity ^0.8.10;

interface ILisUSDPool {
    function depositFor(address account, uint256 amount) external;
}