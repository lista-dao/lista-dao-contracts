// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWaitingPool {
    function addToQueue(address, uint256) external;
    function tryRemove() external;
    function totalDebt() external view returns(uint256);
    function setCapLimit(uint256 _capLimit) external; 
}