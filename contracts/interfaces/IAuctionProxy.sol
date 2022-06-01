// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./UsbLike.sol";
import "./UsbGemLike.sol";
import "./VatLike.sol";
import { CollateralType } from "./../ceros/interfaces/IDao.sol";
import "../ceros/interfaces/IHelioProvider.sol";

    struct Sale {
    uint256 pos; // Index in active array
    uint256 tab; // Usb to raise       [rad]
    uint256 lot; // collateral to sell [wad]
    address usr; // Liquidated CDP
    uint96 tic; // Auction start time
    uint256 top; // Starting price     [ray]
}

interface IAuctionProxy {

    function startAuction(
        address user,
        address keeper,
        UsbLike usb,
        UsbGemLike usbJoin,
        VatLike vat,
        address dog,
        address helioProvider,
        CollateralType calldata collateral
    ) external returns (uint256 id);

    function buyFromAuction(
        address user,
        uint256 auctionId,
        uint256 collateralAmount,
        uint256 maxPrice,
        address receiverAddress,
        UsbLike usb,
        UsbGemLike usbJoin,
        VatLike vat,
        IHelioProvider helioProvider,
        CollateralType calldata collateral
    ) external;

    function getAllActiveAuctionsForClip(address clip) external view returns (Sale[] memory sales);
}
