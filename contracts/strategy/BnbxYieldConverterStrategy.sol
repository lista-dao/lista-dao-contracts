//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../masterVault/interfaces/IMasterVault.sol";
import "../bnbx/interfaces/IStakeManager.sol";
import "./BaseStrategy.sol";

contract BnbxYieldConverterStrategy is BaseStrategy {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable private _bnbxToken;
    IStakeManager private _stakeManager;

    struct UserWithdrawRequest {
        address recipient;
        uint256 amount;
        uint256 bnbxAmount;
        uint256 triggerTime;
    }
    mapping(uint256 => UserWithdrawRequest) private _withdrawRequests;
    uint256 private _firstDistributeIdx;
    uint256 private _nextWithdrawIdx;

    uint256 private _bnbDepositBalance; // amount of bnb deposited by this strategy
    uint256 private _bnbxToUnstake; // amount of bnbx to withdraw from stader in next batchWithdraw
    uint256 private _bnbToDistribute; // amount of bnb to distribute to users who unstaked

    event StakeManagerChanged(address stakeManager);

    /// @dev initialize function - Constructor for Upgradable contract, can be only called once during deployment
    /// @param destination Address of the stakeManager contract
    /// @param rewardsAddr Address which receives yield
    /// @param bnbxToken Address of BNBx token
    /// @param masterVault Address of the masterVault contract
    /// @param stakeManager Address of stakeManager contract
    function initialize(
        address destination,
        address rewardsAddr,
        address bnbxToken,
        address masterVault,
        address stakeManager
    ) public initializer {
        __BaseStrategy_init(destination, rewardsAddr, masterVault);

        _bnbxToken = IERC20Upgradeable(bnbxToken);
        _stakeManager = IStakeManager(stakeManager);

        _bnbxToken.approve(stakeManager, type(uint256).max);
    }

    /// @dev deposits the given amount of BNB into Stader stakeManager through bnbxRouter
    function deposit() external payable onlyVault returns (uint256) {
        uint256 amount = msg.value;
        require(amount <= address(this).balance, "insufficient balance");

        return _deposit(amount);
    }

    /// @dev deposits all the available BNB into Stader stakeManager through bnbxRouter
    function depositAll() external payable onlyVault returns (uint256) {
        return _deposit(address(this).balance);
    }

    /// @dev internal function to deposit the given amount of BNB into Stader stakeManager through bnbxRouter
    /// @param amount amount of BNB to deposit
    function _deposit(uint256 amount)
        internal
        whenDepositNotPaused
        returns (uint256)
    {
        require(canDeposit(amount), "invalid amount");

        _bnbDepositBalance += amount;
        _stakeManager.deposit{value: amount}();
        return amount;
    }

    /// @dev withdraws the given amount of BNB from Stader's stakeManager
    /// @param amount amount of BNB to withdraw
    function withdraw(address recipient, uint256 amount)
        external
        onlyVault
        returns (uint256)
    {
        return _withdraw(recipient, amount);
    }

    /// @dev withdraws everything from Stader's stakeManager
    function panic() external onlyStrategist returns (uint256) {
        (, , uint256 debt) = vault.strategyParams(address(this));
        return _withdraw(address(vault), debt);
    }

    /// @dev internal function to withdraw the given amount of BNB from Stader's stakeManager
    /// @param amount amount of BNB
    /// @return value - returns the amount of BNB that will be withdrawn from stader in future
    function _withdraw(address recipient, uint256 amount)
        internal
        returns (uint256 value)
    {
        require(amount > 0, "invalid amount");

        uint256 bnbxAmount = _stakeManager.convertBnbToBnbX(amount);
        _bnbDepositBalance -= amount;
        _bnbxToUnstake += bnbxAmount;
        _withdrawRequests[_nextWithdrawIdx++] = UserWithdrawRequest({
            recipient: recipient,
            amount: amount,
            bnbxAmount: bnbxAmount,
            triggerTime: block.timestamp
        });

        return amount;
    }

    // actual withdraw request to stader
    function batchWithdraw() external {
        require(_bnbxToUnstake > 0, "No BNBx to unstake");

        uint256 bnbxToUnstake = _bnbxToUnstake; // To prevent reentrancy
        _bnbxToUnstake = 0;
        _stakeManager.requestWithdraw(bnbxToUnstake);
    }

    /// @dev claims the next available withdraw batch from stader
    /// @dev transfer funds(BNB) from stakeManager to strategy
    /// @return foundClaimableReq : true if claimed any batch, false if no batch is available to claim
    function claimNextBatch() external returns (bool foundClaimableReq) {
        uint256 claimableIdx;
        bool foundClaimableReq = false;

        IStakeManager.WithdrawalRequest[] memory requests = _stakeManager
            .getUserWithdrawalRequests(address(this));

        for (uint256 idx = 0; idx < requests.length; idx++) {
            (bool isClaimable, uint256 amount) = _stakeManager
                .getUserRequestStatus(address(this), idx);
            if (isClaimable) {
                foundClaimableReq = true;
                claimableIdx = idx;
                _bnbToDistribute += amount;
                break;
            }
        }

        if (!foundClaimableReq) return foundClaimableReq;

        _stakeManager.claimWithdraw(claimableIdx);
        return foundClaimableReq;
    }

    /// @dev distribute claimed funds to users in FIFO order of withdraw requests
    /// @param maxNumRequests : parameter to control max number of requests to refund
    /// @return reqCount : actual number requests refunded
    function distributeFund(uint256 maxNumRequests)
        external
        returns (uint256 reqCount)
    {
        reqCount = 0;

        while (
            _firstDistributeIdx < _nextWithdrawIdx &&
            _withdrawRequests[_firstDistributeIdx].amount <= _bnbToDistribute
        ) {
            if (reqCount == maxNumRequests) break;
            address recipient = _withdrawRequests[_firstDistributeIdx].recipient;
            uint256 amount = _withdrawRequests[_firstDistributeIdx].amount;

            delete _withdrawRequests[_firstDistributeIdx];
            _firstDistributeIdx++;

            _bnbToDistribute -= amount;
            AddressUpgradeable.sendValue(payable(recipient), amount);
        }
    }

    /// @dev claims yield from stader in BNBx and transfers to rewardsAddr
    function harvest() external onlyStrategist {
        _harvestTo(rewards);
    }

    /// @dev internal function to claim yield from stader in BNBx and transfer them to desired address
    function _harvestTo(address to) private returns (uint256 yield) {
        yield = _calculateYield();
        
        // TODO(helio): is this required ? as yield is already uint256
        require(yield > 0, "no yield to harvest");

        _bnbxToken.safeTransfer(to, yield);
    }

    function _calculateYield() private view returns (uint256 yield) {
        uint256 bnbxEqAmount = _stakeManager.convertBnbToBnbX(
            _bnbDepositBalance
        );

        // yield = bnbxHoldingBalance - bnbxEqAmout
        // bnbxHoldingBalance = _bnbxToken.balanceOf(address(this)) - _bnbxToUnstake
        yield = _bnbxToken.balanceOf(address(this)) - _bnbxToUnstake - bnbxEqAmount;
    }

    // returns the total amount of tokens in the destination contract
    function balanceOfPool() public view override returns (uint256) {
        return _bnbDepositBalance;
    }

    receive() external payable {}

    function canDeposit(uint256 amount) public pure returns (bool) {
        return (amount > 0);
    }

    function assessDepositFee(uint256 amount) public pure returns (uint256) {
        return amount;
    }

    /// @dev only owner can change stakeManager address
    /// @param stakeManager new stakeManager address
    function changeStakeManager(address stakeManager) external onlyOwner {
        require(stakeManager != address(0), "zero address");
        require(address(_stakeManager) != stakeManager, "old address provided");

        _bnbxToken.approve(address(_stakeManager), 0);
        _stakeManager = IStakeManager(stakeManager);
        _bnbxToken.approve(address(_stakeManager), type(uint256).max);
        emit StakeManagerChanged(stakeManager);
    }
}
