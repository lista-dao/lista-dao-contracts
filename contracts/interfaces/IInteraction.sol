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

    function collateralPrice(address token) external view returns (uint256);

    function auctionWhitelistMode() external view returns (uint256);

    function auctionWhitelist(address account) external view returns (uint256);
}
