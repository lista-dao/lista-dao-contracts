//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../masterVault/interfaces/IMasterVault.sol";
import "./bnbx/interfaces/IStakeManager.sol";
import "../../strategy/BaseStrategy.sol";

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

    /**
     * @dev for storing the withdraw requests that can't be fulfilled via the automated mechanism because of gas limits
     * and have to be manually distributed. It stores the sum of all such requests for a recipient.
     */
    mapping(address => uint256) public manualWithdrawAmount;

    uint256 public bnbDepositBalance; // amount of bnb deposited by this strategy
    uint256 public bnbxToUnstake; // amount of bnbx to withdraw from stader in next batchWithdraw
    uint256 public bnbToDistribute; // amount of bnb to distribute to users who unstaked

    uint256 public lastUnstakeTriggerTime; // last time when batchWithdraw was invoked

    event StakeManagerChanged(address stakeManager);

    /// @dev initialize function - Constructor for Upgradable contract, can be only called once during deployment
    /// @param destination Address of the stakeManager contract
    /// @param rewardsAddr Address which receives yield
    /// @param bnbxToken Address of BNBx token
    /// @param masterVault Address of the masterVault contract
    function initialize(
        address destination,
        address rewardsAddr,
        address bnbxToken,
        address masterVault
    ) public initializer {
        __BaseStrategy_init(destination, rewardsAddr, masterVault);

        _bnbxToken = IERC20Upgradeable(bnbxToken);
        _stakeManager = IStakeManager(destination);
        lastUnstakeTriggerTime = block.timestamp;

        _bnbxToken.safeApprove(destination, type(uint256).max);
    }

    /// @dev deposits the given amount of BNB into Stader stakeManager
    function deposit()
        external
        payable
        nonReentrant
        onlyVault
        returns (uint256)
    {
        uint256 amount = msg.value;
        return _deposit(amount);
    }

    /// @dev deposits all the available BNB(extraBNB if any + BNB passed) into Stader stakeManager
    function depositAll() external nonReentrant onlyStrategist {
        _deposit(address(this).balance - bnbToDistribute);
    }

    /// @dev internal function to deposit the given amount of BNB into Stader stakeManager
    /// @param amount amount of BNB to deposit
    function _deposit(uint256 amount)
        internal
        whenDepositNotPaused
        returns (uint256)
    {
        require(canDeposit(amount), "invalid amount");
        bnbDepositBalance += amount;
        _stakeManager.deposit{value: amount}();
        return amount;
    }

    /// @dev creates an entry to withdraw the given amount of BNB from Stader's stakeManager
    /// @param amount amount of BNB to withdraw
    function withdraw(address recipient, uint256 amount)
        external
        nonReentrant
        onlyVault
        returns (uint256)
    {
        return _withdraw(recipient, amount);
    }

    // @dev get BNBx from strategy
    /// @param amount amount of BNB to withdraw
    /// returns the amount of BNBx that will be transfer to recipient
    function withdrawInToken(address recipient, uint256 amount)
    external
    nonReentrant
    onlyVault
    returns (uint256){
        uint256 bnbxAmount = _stakeManager.convertBnbToBnbX(amount);
        require(bnbxAmount > 0, "invalid amount");
        _bnbxToken.safeTransfer(recipient, bnbxAmount);
        bnbDepositBalance -= amount;
        return bnbxAmount;
    }

    //estimate how much token(BNBx) can get when do withdrawInToken
    function estimateInToken(uint256 amount) external view returns(uint256){
        return _stakeManager.convertBnbToBnbX(amount);
    }

    // calculate the total(BNBx) in the strategy contract
    function balanceOfToken() external view returns(uint256){
        return _bnbxToken.balanceOf(address(this));
    }

    /// @dev creates an entry to withdraw everything(bnbDeposited) from Stader's stakeManager
    function panic() external nonReentrant onlyStrategist returns (uint256) {
        (, , uint256 debt) = vault.strategyParams(address(this));
        return _withdraw(address(vault), debt);
    }

    /// @dev internal function to create an withdraw the given amount of BNB from Stader's stakeManager
    /// @param amount amount of BNB
    /// @return value - returns the amount of BNB that will be withdrawn from stader in future
    function _withdraw(address recipient, uint256 amount)
        internal
        returns (uint256 value)
    {
        uint256 bnbxAmount = _stakeManager.convertBnbToBnbX(amount);
        bnbDepositBalance -= amount;
        bnbxToUnstake += bnbxAmount;
        _withdrawRequests[_nextWithdrawIdx++] = UserWithdrawRequest({
            recipient: recipient,
            amount: amount,
            bnbxAmount: bnbxAmount,
            triggerTime: block.timestamp
        });

        return amount;
    }

    // actual withdraw request to stader, should be called max once a day
    function batchWithdraw() external nonReentrant {
        require(
            block.timestamp - lastUnstakeTriggerTime >= 24 hours,
            "Allowed once daily"
        );
        require(bnbxToUnstake > 0, "No BNBx to unstake");

        uint256 bnbxToUnstake_ = bnbxToUnstake; // To prevent reentrancy
        bnbxToUnstake = 0;
        lastUnstakeTriggerTime = block.timestamp;
        _stakeManager.requestWithdraw(bnbxToUnstake_);
    }

    /// @param maxNumRequests : parameter to control max number of requests to refund
    /// @return foundClaimableReq : true if claimed any batch, false if no batch is available to claim
    /// @return reqCount : actual number requests refunded
    function claimNextBatchAndDistribute(uint256 maxNumRequests)
        external
        nonReentrant
        returns (bool foundClaimableReq, uint256 reqCount)
    {
        foundClaimableReq = _claimNextBatch();
        reqCount = _distributeFund(maxNumRequests);
    }

    /// @dev claims the next available withdraw batch from stader
    /// @dev transfer funds(BNB) from stakeManager to strategy
    /// @return foundClaimableReq : true if claimed any batch, false if no batch is available to claim
    function claimNextBatch()
        public
        nonReentrant
        returns (bool foundClaimableReq)
    {
        return _claimNextBatch();
    }

    function _claimNextBatch() private returns (bool foundClaimableReq) {
        IStakeManager.WithdrawalRequest[] memory requests = _stakeManager
            .getUserWithdrawalRequests(address(this));

        for (uint256 idx = 0; idx < requests.length; idx++) {
            (bool isClaimable, uint256 amount) = _stakeManager
                .getUserRequestStatus(address(this), idx);

            if (!isClaimable) continue;
            bnbToDistribute += amount; // amount here returned from stader will be a little more than requested to withdraw
            _stakeManager.claimWithdraw(idx);
            return true;
        }

        return false;
    }

    /// @dev distribute claimed funds to users in FIFO order of withdraw requests
    /// @param maxNumRequests : parameter to control max number of requests to refund
    /// @return reqCount : actual number requests refunded
    function distributeFund(uint256 maxNumRequests)
        public
        nonReentrant
        returns (uint256 reqCount)
    {
        return _distributeFund(maxNumRequests);
    }

    function _distributeFund(uint256 maxNumRequests)
        private
        returns (uint256 reqCount)
    {
        for (
            reqCount = 0;
            reqCount < maxNumRequests &&
                _firstDistributeIdx < _nextWithdrawIdx &&
                _withdrawRequests[_firstDistributeIdx].amount <=
                bnbToDistribute;
            reqCount++
        ) {
            address recipient = _withdrawRequests[_firstDistributeIdx]
                .recipient;
            uint256 amount = _withdrawRequests[_firstDistributeIdx].amount;

            delete _withdrawRequests[_firstDistributeIdx];
            _firstDistributeIdx++;
            bnbToDistribute -= amount;

            (
                bool sent, /*memory data*/

            ) = payable(recipient).call{value: amount}("");

            if (!sent) {
                // the recipient didn't accept direct funds within the specified gas, so save the whole request to be
                // withdrawn by the recipient manually later
                manualWithdrawAmount[recipient] += amount;
                bnbToDistribute += amount;
            }
        }
    }

    /// @dev Anybody can call this to manually send the withdrawn funds to a recipient, if the recipient had funds that
    /// need to be manually withdrawn.
    function distributeManual(address recipient) external nonReentrant {
        uint256 amount = manualWithdrawAmount[recipient];
        require(amount > 0, "!distributeManual");

        bnbToDistribute -= amount;
        delete manualWithdrawAmount[recipient];

        (
            bool sent, /*memory data*/

        ) = payable(recipient).call{value: amount}("");
        require(sent, "!sent");
    }

    /// @dev claims yield from stader in BNBx and transfers to rewardsAddr
    function harvest() external nonReentrant onlyStrategist {
        _harvestTo(rewards);
    }

    /// @dev internal function to claim yield from stader in BNBx and transfer them to desired address
    function _harvestTo(address to) private returns (uint256 yield) {
        yield = calculateYield();

        require(yield > 0, "no yield to harvest");

        _bnbxToken.safeTransfer(to, yield);
        emit Harvested(to, yield);
    }

    function calculateYield() public view returns (uint256 yield) {
        uint256 bnbxEqAmount = _stakeManager.convertBnbToBnbX(
            bnbDepositBalance
        );

        // yield = bnbxHoldingBalance - bnbxEqAmout
        // bnbxHoldingBalance = _bnbxToken.balanceOf(address(this)) - _bnbxToUnstake
        yield =
            _bnbxToken.balanceOf(address(this)) -
            bnbxToUnstake -
            bnbxEqAmount;
    }

    // returns the total amount of tokens in the destination contract
    function balanceOfPool() public view override returns (uint256) {
        return bnbDepositBalance;
    }

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

        _bnbxToken.safeApprove(address(_stakeManager), 0);
        _stakeManager = IStakeManager(stakeManager);
        _bnbxToken.safeApprove(address(_stakeManager), type(uint256).max);
        emit StakeManagerChanged(stakeManager);
    }
}
