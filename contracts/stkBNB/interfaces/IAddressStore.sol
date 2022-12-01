// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface IAddressStore {
    function getStkBNB() external view returns (address);

    function getStakePool() external view returns (address);
}
