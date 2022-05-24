// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface DogLike {
  function bark(
    bytes32 ilk,
    address urn,
    address kpr
  ) external returns (uint256 id);
}

interface UsbGemLike {
  function join(address usr, uint256 wad) external;

  function exit(address usr, uint256 wad) external;
}

interface GemJoinLike is UsbGemLike {
  function gem() external view returns (IERC20);
}

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

interface HelioProviderLike {
  function liquidation(address recipient, uint256 amount) external;

  function daoBurn(address, uint256) external;

  function daoMint(address, uint256) external;
}

interface VatLike {
  function init(bytes32 ilk) external;

  function hope(address usr) external;

  function rely(address usr) external;

  function move(
    address src,
    address dst,
    uint256 rad
  ) external;

  function behalf(address bit, address usr) external;

  function frob(
    bytes32 i,
    address u,
    address v,
    address w,
    int256 dink,
    int256 dart
  ) external;

  function flux(
    bytes32 ilk,
    address src,
    address dst,
    uint256 wad
  ) external;

  function ilks(bytes32)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    );

  function gem(bytes32, address) external view returns (uint256);

  function usb(address) external view returns (uint256);

  function urns(bytes32, address) external view returns (uint256, uint256);
}

struct CollateralType {
  GemJoinLike gem;
  bytes32 ilk;
  uint32 live;
  ClipperLike clip;
}

struct Sale {
  uint256 pos; // Index in active array
  uint256 tab; // Usb to raise       [rad]
  uint256 lot; // collateral to sell [wad]
  address usr; // Liquidated CDP
  uint96 tic; // Auction start time
  uint256 top; // Starting price     [ray]
}

uint256 constant RAY = 10**27;

contract AuctionProxy {
  using SafeERC20 for IERC20;
  mapping(address => uint256) public wards;

  function rely(address usr) external auth {
    wards[usr] = 1;
  }

  function deny(address usr) external auth {
    wards[usr] = 0;
  }

  modifier auth() {
    require(wards[msg.sender] == 1, "Interaction/not-authorized");
    _;
  }

  address public dao;

  modifier onlyDao() {
    require(msg.sender == dao, "Only dao contract can call");
    _;
  }

  constructor() {
    wards[msg.sender] = 1;
  }

  function setDao(address _dao) external auth {
    dao = _dao;
  }

  function startAuction(
    address user,
    address keeper,
    IERC20 usb,
    UsbGemLike usbJoin,
    VatLike vat,
    DogLike dog,
    HelioProviderLike helioProvider,
    CollateralType calldata collateral
  ) external onlyDao returns (uint256 id) {
    uint256 usbBal = usb.balanceOf(address(this));
    id = dog.bark(collateral.ilk, user, address(this));

    usbJoin.exit(address(this), vat.usb(address(this)) / RAY);
    usbBal = usb.balanceOf(address(this)) - usbBal;
    usb.transfer(keeper, usbBal);

    // Burn any derivative token (hBNB incase of ceabnbc collateral)
    if (address(helioProvider) != address(0)) {
      helioProvider.daoBurn(user, collateral.clip.sales(id).lot);
    }
  }

  function buyFromAuction(
    address user,
    uint256 auctionId,
    uint256 collateralAmount,
    uint256 maxPrice,
    address receiverAddress,
    IERC20 usb,
    UsbGemLike usbJoin,
    VatLike vat,
    HelioProviderLike helioProvider,
    CollateralType calldata collateral
  ) external onlyDao {
    // Balances before
    uint256 usbBal = usb.balanceOf(address(this));
    uint256 gemBal = collateral.gem.gem().balanceOf(address(this));

    uint256 usbMaxAmount = (maxPrice * collateralAmount) / RAY;

    usb.transferFrom(user, address(this), usbMaxAmount);
    usbJoin.join(address(this), usbMaxAmount);

    vat.hope(address(collateral.clip));
    address urn = collateral.clip.sales(auctionId).usr; // Liquidated address
    uint256 leftover = vat.gem(collateral.ilk, urn); // userGemBalanceBefore
    collateral.clip.take(auctionId, collateralAmount, maxPrice, address(this), "");
    leftover = vat.gem(collateral.ilk, urn) - leftover; // leftover

    collateral.gem.exit(address(this), vat.gem(collateral.ilk, address(this)));
    usbJoin.exit(address(this), vat.usb(address(this)) / RAY);

    // Balances rest
    usbBal = usb.balanceOf(address(this)) - usbBal;
    gemBal = collateral.gem.gem().balanceOf(address(this)) - gemBal;
    usb.transfer(receiverAddress, usbBal);

    if (address(helioProvider) != address(0)) {
      collateral.gem.gem().safeTransfer(address(helioProvider), gemBal);
      HelioProviderLike(helioProvider).liquidation(receiverAddress, gemBal); // Burn router ceToken and mint abnbc to receiver

      if (leftover != 0) {
        // Auction ended with leftover
        vat.flux(collateral.ilk, urn, address(this), leftover);
        collateral.gem.exit(address(helioProvider), leftover); // Router (disc) gets the remaining ceabnbc
        HelioProviderLike(helioProvider).liquidation(urn, leftover); // Router burns them and gives abnbc remaining
      }
    } else {
      collateral.gem.gem().safeTransfer(receiverAddress, gemBal);
    }
  }

  function getAllActiveAuctionsForClip(ClipperLike clip)
    external
    view
    returns (Sale[] memory sales)
  {
    uint256[] memory auctionIds = clip.list();
    uint256 auctionsCount = auctionIds.length;
    sales = new Sale[](auctionsCount);
    for (uint256 i = 0; i < auctionsCount; i++) {
      sales[i] = clip.sales(auctionIds[i]);
    }
  }
}
