// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;

interface IETHVault {
    /**
     * Events
     */
    event Deposited(
        address indexed owner,
        address indexed recipient,
        uint256 value
    );
    event Claimed(
        address indexed owner,
        address indexed recipient,
        uint256 value
    );
    event Withdrawn(
        address indexed owner,
        address indexed recipient,
        uint256 value
    );
    event RouterChanged(address router);
    event SetStrategist(address strategist);
    event Rebalanced(uint256 amount);
    event WithdrawalFeeChanged(uint256 amount);
    /**
     * Methods
     */
    event RatioUpdated(uint256 currentRatio);
    function depositFor(address recipient, uint256 certTokenAmount, uint256 BETHAmount)
    external
    returns (uint256);
    function claimYieldsFor(address owner, address recipient)
    external
    returns (uint256);
    function withdrawETHFor(
        address owner,
        address recipient,
        uint256 amount
    ) external returns (uint256);
    function withdrawBETHFor(
        address owner,
        address recipient,
        uint256 amount
    ) external returns (uint256);
    function getPrincipalOf(address account) external view returns (uint256);
    function getYieldFor(address account) external view returns (uint256);
    function getTotalBETHAmountInVault() external view returns (uint256);
    function getTotalETHAmountInVault() external view returns (uint256);
    function getCeTokenBalanceOf(address account) external view returns (uint256);
}