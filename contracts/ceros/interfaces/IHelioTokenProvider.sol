// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

interface IHelioTokenProvider {

    /**
     * Structs
     */
    struct Delegation {
        address delegateTo; // who helps delegator to hold clisBNB, aka the delegatee
        uint256 amount;
    }

    /**
     * Events
     */
    event Deposit(address indexed account, uint256 amount, uint256 lPAmount);
    event Claim(address indexed recipient, uint256 amount);
    event Withdrawal(address indexed owner, address indexed recipient, uint256 amount);
    event Liquidation(address indexed recipient, uint256 amount);

    event ChangeDelegateTo(address account, address oldDelegatee, address newDelegatee);
    event SyncUserLp(address account, uint256 userLp);

    /**
     * Deposit
     */
    function provide(uint256 amount) external returns (uint256);
    function provide(uint256 amount, address delegateTo) external returns (uint256);
    function delegateAllTo(address newDelegateTo) external;

    /**
     * Withdrawal
     */
    function release(address recipient, uint256 amount) external returns (uint256);

    /**
     * DAO FUNCTIONALITY
     */
    function liquidation(address recipient, uint256 amount) external;
    function daoBurn(address account, uint256 amount) external;
}
