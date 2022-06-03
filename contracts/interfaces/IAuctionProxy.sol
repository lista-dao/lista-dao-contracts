// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./UsbLike.sol";
import "./UsbGemLike.sol";
import "./VatLike.sol";
import "./ClipperLike.sol";
import "./DogLike.sol";
import { CollateralType } from "./../ceros/interfaces/IDao.sol";
import "../ceros/interfaces/IHelioProvider.sol";

interface IAuctionProxy {

    event Liquidation(address user, address indexed collateral, uint256 amount, uint256 price);

    function startAuction(
        address user,
        address keeper,
        UsbLike usb,
        UsbGemLike usbJoin,
        VatLike vat,
        DogLike dog,
        IHelioProvider helioProvider,
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

    function getAllActiveAuctionsForClip(ClipperLike clip) external view returns (Sale[] memory sales);
}
