// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { Sale } from "./IAuctionProxy.sol";

interface ClipperLike {
    function ilk() external view returns (bytes32);

    function kick(
        uint256 tab,
        uint256 lot,
        address usr,
        address kpr
    ) external returns (uint256);

    function take(
        uint256 id,
        uint256 amt,
        uint256 max,
        address who,
        bytes calldata data
    ) external;

    function kicks() external view returns (uint256);

    function count() external view returns (uint256);

    function list() external view returns (uint256[] memory);

    function sales(uint256 auctionId) external view returns (Sale memory);
}