// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../interfaces/PipLike.sol";
import "../../interfaces/GemJoinLike.sol";

struct CollateralType {
  GemJoinLike gem;
  bytes32 ilk; // ilk, bytes32, e.g. "ETH-A"
  uint32 live; //0 - inactive, 1 - started, 2 - stopped
  address clip; // auction contract address
}

struct Sale {
    uint256 pos; // Index in active array
    uint256 tab; // Hay to raise       [rad]
    uint256 lot; // collateral to sell [wad]
    address usr; // Liquidated CDP
    uint96 tic; // Auction start time
    uint256 top; // Starting price     [ray]
}

interface ClipperLike {
  function sales(uint256 id) external view returns (Sale memory);
  function list() external view returns (uint256[] memory);
}

interface VatLike {
  function ilks(bytes32) external view returns (
    uint256 normalisedDebt, // Normalised Debt
    uint256 interestRate, // Accumulated Rates, refreshed when called drip() at CDP
    uint256 spot, // price with safety margin
    uint256 maxLoan, // max. debt - user can only borrow at most this amount
    uint256 minLoan // min. debt - user must borrow at least this amount
  );
  function urns(bytes32, address) external view returns (uint256 userCollateralAmt, uint256 userNormalisedDebt);
}

interface SpotLike {
  function ilks(bytes32) external view returns (PipLike, uint256);
}

// denominator when calculating interests
uint256 constant RAY = 10 ** 27;

interface ICdp {
  function deposit(
    address participant,
    address token,
    uint256 amount // amount of LP_USD
  ) external returns (uint256);

  function withdraw(
    address participant,
    address token,
    uint256 amount // amount of LP_USD
  ) external returns (uint256);

  function collaterals(address token) external view returns (GemJoinLike, bytes32, uint32, address);
  function locked(address token, address usr) external view returns (uint256);
  function borrowed(address token, address usr) external view returns (uint256);
  function spotter() external view returns (SpotLike);
  function vat() external view returns (VatLike);
  function drip(address token) external;
  function free(address token, address usr) external view returns (uint256);
}
