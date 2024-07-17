// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

interface IHelioETHProvider {
    /**
     * Events
     */

    event Deposit(address indexed account, uint256 amount);

    event Claim(address indexed recipient, uint256 amount);

    event Withdrawal(
        address indexed owner,
        address indexed recipient,
        uint256 amount
    );

    event ChangeDao(address dao);

    event ChangeCeToken(address ceToken);

    event ChangeCollateralToken(address collateralToken);

    event ChangeProxy(address auctionProxy);

    event ChangeOperator(address operator);

    event ChangeCertToken(address token);

    event ChangeWithdrwalAmount(uint256 amount);

    event FeeReceiverChanged(address feeReceiver);

    /**
     * Deposit
     */

    // in ETH
    function provideInETH(uint256 amount) external returns (uint256);

    /**
     * Claim
     */

    // claim
    function claim() external returns (uint256);

    /**
     * Withdrawal
     */

    // ETH
    function releaseInETH(address recipient, uint256 amount)
    external
    returns (uint256);

    function releaseInBETH(address recipient, uint256 amount)
    external
    returns (uint256);
    /**
     * DAO FUNCTIONALITY
     */

    function liquidation(address recipient, uint256 amount) external;

    function daoBurn(address account, uint256 value) external;

    function daoMint(address account, uint256 value) external;
}
