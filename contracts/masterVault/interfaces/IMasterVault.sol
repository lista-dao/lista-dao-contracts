// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import "./IERC4626Upgradeable.sol";

interface IMasterVault {
    event DepositFeeChanged(uint256 newDepositFee);
    event MaxDepositFeeChanged(uint256 newMaxDepositFee);
    event WithdrawalFeeChanged(uint256 newWithdrawalFee);
    event MaxWithdrawalFeeChanged(uint256 newMaxWithdrawalFee);
    event ProviderChanged(address provider);
    event RouterChanged(address ceRouter);
    event ManagerAdded(address newManager);
    event ManagerRemoved(address manager);
    event FeeReceiverChanged(address feeReceiver);
    event WaitingPoolChanged(address waitingPool);
    event WaitingPoolCapChanged(uint256 cap);
    event StrategyAllocationChanged(address strategy, uint256 allocation);
    event BinancePoolChanged(address binancePool);
    event StrategyAdded(address strategy, uint256 allocation);
    event StrategyMigrated(address oldStrategy, address newStrategy, uint256 newAllocation);
    event DepositedToStrategy(address strategy, uint256 amount);
    event WithdrawnFromStrategy(address strategy, uint256 value);

    function withdrawETH(address account, uint256 amount) external  returns (uint256);
    function depositETH() external payable returns (uint256);
    function feeReceiver() external returns (address payable);
    function withdrawalFee() external view returns (uint256);
    function strategyParams(address strategy) external view returns(bool active, uint256 allocation, uint256 debt);
}