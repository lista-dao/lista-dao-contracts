// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IInteraction {

    function buyFromAuction(
        address token,
        uint256 auctionId,
        uint256 collateralAmount,
        uint256 maxPrice,
        address receiverAddress
    ) external;

}
