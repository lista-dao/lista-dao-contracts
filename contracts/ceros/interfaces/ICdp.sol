// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../interfaces/PipLike.sol";
import "../../interfaces/GemJoinLike.sol";

struct CollateralType {
  GemJoinLike gem;
  bytes32 ilk;
  uint32 live; //0 - inactive, 1 - started, 2 - stopped
  address clip;
}

interface VatLike {
  function ilks(bytes32) external view returns (
    uint256 art, // Total Normalised Debt     [wad]
    uint256 rate, // Accumulated Rates         [ray]
    uint256 spot, // Price with Safety Margin  [ray]
    uint256 line, // Debt Ceiling              [rad]
    uint256 dust // Urn Debt Floor            [rad]
  );
}

interface SpotLike {
  function ilks(bytes32) external view returns (PipLike, uint256);
}

uint256 constant RAY = 10 ** 27;

interface ICdp {
  function deposit(
    address participant,
    address token,
    uint256 dink
  ) external returns (uint256);

  function withdraw(
    address participant,
    address token,
    uint256 dink
  ) external returns (uint256);

  function collaterals(address token) external view returns (GemJoinLike, bytes32, uint32, address);
  function locked(address token, address usr) external view returns (uint256);
  function borrowed(address token, address usr) external view returns (uint256);
  function spotter() external view returns (SpotLike);
  function vat() external view returns (VatLike);
  function drip(address token) external;
}
