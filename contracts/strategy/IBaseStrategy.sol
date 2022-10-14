//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBaseStrategy {

// to deposit funds to a destination contract
function deposit() payable external returns(uint256);

function depositAll() payable external returns(uint256);

// to withdraw funds from the destination contract
function withdraw(address recipient, uint256 amount) external returns(uint256);

// claim or collect rewards functions
function harvest() external;

// withdraw all funds from the destination contract
function panic() external returns (uint256);

// disable deposit
function pause() external;

// enable deposit
function unpause() external;

// calculate the total underlying token in the strategy contract and destination contract
function balanceOf() external view returns(uint256);

// calculate the total amount of tokens in the strategy contract
function balanceOfWant() external view returns(uint256);

// calculate the total amount of tokens in the destination contract
function balanceOfPool() external view returns(uint256);

// set the recipient address of the collected fee
function setFeeRecipient(address newFeeRecipient) external;

function canDeposit(uint256 amount) external view returns(bool);
}