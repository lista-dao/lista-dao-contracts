// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract StakeManagerMock {

  function convertBnbToSnBnb(uint256 _amount)
  external
  view
  returns (uint256) {
    return _amount * 9834983622/10000000000;
  }

}
