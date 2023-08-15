// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

interface ICerosETHRouter {
    /**
     * Events
     */

    event Deposit(
        address indexed account,
        uint256 certAmount,
        uint256 BETHAmount
    );

    event Claim(
        address indexed recipient,
        address indexed token,
        uint256 amount
    );

    event Withdrawal(
        address indexed owner,
        address indexed recipient,
        address indexed token,
        uint256 amount
    );

    event ChangeVault(address vault);

    event ChangeDao(address dao);

    event ChangeCeToken(address ceToken);

    event ChangeCeTokenJoin(address ceTokenJoin);

    event ChangeCertToken(address certToken);

    event ChangeCollateralToken(address collateralToken);

    event ChangeProvider(address provider);

    event ChangeMinStakeAmount(uint256 amount);

    event ChangeCertTokenRatio(uint256 amount);
    /**
     * Methods
     */

    /**
     * Deposit
     */

    // in ETH
    function deposit(uint256 amount) external returns (uint256);

    /**
     * Claim
     */

    // claim in wBETH and ETH
    function claim(address recipient) external returns (uint256);

    function liquidation(address recipient, uint256 amount) external;
    /**
     * Withdrawal
     */

    // BNB
    function withdrawETH(address recipient, uint256 amount)
    external
    returns (uint256);

    function withdrawBETH(address recipient, uint256 amount)
    external
    returns (uint256);

    function getCertTokenRatio() external view returns(uint256);
    function getReferral() external view returns(address);
    function getProvider() external view returns(address);
}