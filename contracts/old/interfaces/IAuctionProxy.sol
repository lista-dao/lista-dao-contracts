// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../interfaces/HayJoinLike.sol";
import "../../interfaces/VatLike.sol";
import "../../interfaces/ClipperLike.sol";
import "../../interfaces/DogLike.sol";
//import { CollateralType } from "../../ceros/interfaces/IDao.sol";
//import "../ceros/interfaces/IHelioProvider.sol";


interface IAuctionProxy {

  event Liquidation(address indexed user, address indexed collateral, uint256 amount, uint256 leftover);

  function startAuction(
    address token,
    address user,
    address keeper
  ) external returns (uint256 id);

  function buyFromAuction(
    address user,
    uint256 auctionId,
    uint256 collateralAmount,
    uint256 maxPrice,
    address receiverAddress
  ) external;

  function getAllActiveAuctionsForToken(address token) external view returns (Sale[] memory sales);
}
