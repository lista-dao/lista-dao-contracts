// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;

interface IUnwrapETH {

    struct WithdrawRequest {
        address recipient; // user who withdraw
        uint256 wbethAmount; //WBETH
        uint256 ethAmount; //ETH
        uint256 triggerTime; //user trigger time
        uint256 claimTime; //user claim time
        bool allocated;  //is it allocated
    }

    /**
      * @dev claim the allocated eth
      * @param _index the index to claim
      * @return the eth amount
      */
    function claimWithdraw(uint256 _index) external returns (uint256);

    /**
      * @dev Retrieves all withdraw requests initiated by the given address
      * @param _recipient - Address of an user
      * @return WithdrawRequest array of user withdraw requests NO more then 1000
      */
    function getUserWithdrawRequests(address _recipient) external view returns (WithdrawRequest[] memory);

    /**
      * @dev Retrieves withdraw requests by index
      * @param _startIndex - the startIndex
      * @return WithdrawRequest array of user withdraw requests
      */
    function getWithdrawRequests(uint256 _startIndex) external view returns (WithdrawRequest[] memory);
}
