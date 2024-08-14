// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../../strategy/bnbx/interfaces/IStakeManager.sol";
import "./BnbxMock.sol";

contract BnbxStakeManagerMock is IStakeManager {
    BnbxMock bnbX;
    uint256 exchangeRate;

    function deposit() external payable override {
        uint256 bnbXToMint = convertBnbToBnbX(msg.value);
        BnbxMock(bnbX).mint(msg.sender, bnbXToMint);
    }

    function requestWithdraw(uint256 _amountInBnbX) external override {
        BnbxMock(bnbX).transferFrom(msg.sender, address(this), _amountInBnbX);
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
            amountInBnbX: 2e18,
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

    function convertBnbToBnbX(uint256 _amount)
        public
        view
        override
        returns (uint256)
    {
        return (_amount * 1e18) / exchangeRate;
    }

    function convertBnbXToBnb(uint256 _amountInBnbX)
        public
        view
        override
        returns (uint256)
    {
        return (exchangeRate * _amountInBnbX) / 1e18;
    }

    function changeER(uint256 er) external {
        exchangeRate = er;
    }

    function changeBnbx(address _bnbX) external {
        bnbX = BnbxMock(_bnbX);
    }
}
