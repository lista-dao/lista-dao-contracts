// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../../snbnb/interfaces/ISnBnbStakeManager.sol";
import "./SnBnbMock.sol";

contract SnBnbStakeManagerMock is ISnBnbStakeManager {
    SnBnbMock snBnb;
    uint256 exchangeRate;

    function deposit() external payable override {
        uint256 snBnbToMint = convertBnbToSnBnb(msg.value);
        SnBnbMock(snBnb).mint(msg.sender, snBnbToMint);
    }

    function requestWithdraw(uint256 _amountInSnBnb) external override {
        SnBnbMock(snBnb).transferFrom(msg.sender, address(this), _amountInSnBnb);
    }

    function claimWithdraw(uint256 _idx) external override {
        payable(msg.sender).call{gas: 5000, value: 2e18}("");
    }

    function getUserWithdrawalRequests(address _address)
        external
        pure
        override
        returns (WithdrawalRequest[] memory)
    {
        WithdrawalRequest[] memory requests = new WithdrawalRequest[](1);
        requests[0] = WithdrawalRequest({
            uuid: 0,
            amountInSnBnb: 2e18,
            startTime: 1234
        });

        return requests;
    }

    function getUserRequestStatus(address _user, uint256 _idx)
        external
        view
        override
        returns (bool _isClaimable, uint256 _amount)
    {
        return (true, 2e18);
    }

    receive() external payable {}

    function convertBnbToSnBnb(uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        return (_amount * 1e18) / exchangeRate;
    }

    function convertSnBnbToBnb(uint256 _amountInSnBnb)
        public
        view
        override
        returns (uint256)
    {
        return (exchangeRate * _amountInSnBnb) / 1e18;
    }

    function changeER(uint256 er) external {
        exchangeRate = er;
    }

    function changeSnBnb(address _snBnb) external {
        snBnb = SnBnbMock(_snBnb);
    }
}
