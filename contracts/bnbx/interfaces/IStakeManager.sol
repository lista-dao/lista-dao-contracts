//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IStakeManager {

    struct WithdrawalRequest {
        uint256 uuid;
        uint256 amountInBnbX;
        uint256 startTime;
    }

    struct BotUndelegateRequest {
        uint256 startTime;
        uint256 endTime;
        uint256 amount;
        uint256 amountInBnbX;
    }

    function deposit() external payable;

    function requestWithdraw(uint256 _amountInBnbX) external;

    function claimWithdraw(uint256 _idx) external;

    function getUserWithdrawalRequests(address _address)
        external
        view
        returns (WithdrawalRequest[] memory);

    function getUserRequestStatus(address _user, uint256 _idx)
        external
        view
        returns (bool _isClaimable, uint256 _amount);

    function convertBnbToBnbX(uint256 _amount) external view returns (uint256);

    function convertBnbXToBnb(uint256 _amountInBnbX)
        external
        view
        returns (uint256);
}
