// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

interface INonfungiblePositionManager {
  function createAndInitializePoolIfNecessary(
    address token0,
    address token1,
    uint24 fee,
    uint160 sqrtPriceX96
  ) external payable returns (address pool);
}

interface IResilientOracle {
  function peek(address token) external view returns (uint256 price);
}

contract CreateAndInitPools is Script {

  address token0;
  address token1;
  address nonfungiblePositionManager;
  address oracle;

  function setUp() public {
    nonfungiblePositionManager = vm.envAddress("NON_FUNGIBLE_POSITION_MANAGER");
    token0 = vm.envAddress("TOKEN0");
    token1 = vm.envAddress("TOKEN1");
  }

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    uint160 sqrtPriceX96 = computeFairSqrtPriceX96();
    INonfungiblePositionManager(nonfungiblePositionManager)
      .createAndInitializePoolIfNecessary(
        token0,
        token1,
        10000, // fee tier
        sqrtPriceX96
      );

    vm.stopBroadcast();
  }


  function computeFairSqrtPriceX96() private view returns (uint160 sqrtPriceX96) {
    // @note: oracle returns 8-decimal prices
    uint256 price0 = 35*1e8;
    uint256 price1 = 70*1e8;
    require(price0 != 0 && price1 != 0, "PcsV3LpNumbersHelper: zero-price");

    // scale both to 18 decimals (8 + 10)
    uint256 p0 = price0 * 1e10;
    uint256 p1 = price1 * 1e10;

    sqrtPriceX96 = toUint160(
      sqrt(_mul(p0, (1 << 96)) / p1) << 48
    );
  }

  function _mul(uint256 _x, uint256 _y) private pure returns (uint256 z) {
    require(_y == 0 || (z = _x * _y) / _y == _x, "PcsV3LpNumbersHelper: mul-overflow");
  }

  function toUint160(uint256 x) private pure returns (uint160 z) {
    require((z = uint160(x)) == x, "PcsV3LpNumbersHelper: uint160-overflow");
  }

  function sqrt(uint256 _x) private pure returns (uint128) {
    if (_x == 0) return 0;
    else {
      uint256 xx = _x;
      uint256 r = 1;
      if (xx >= 0x100000000000000000000000000000000) { xx >>= 128; r <<= 64; }
      if (xx >= 0x10000000000000000) { xx >>= 64; r <<= 32; }
      if (xx >= 0x100000000) { xx >>= 32; r <<= 16; }
      if (xx >= 0x10000) { xx >>= 16; r <<= 8; }
      if (xx >= 0x100) { xx >>= 8; r <<= 4; }
      if (xx >= 0x10) { xx >>= 4; r <<= 2; }
      if (xx >= 0x8) { r <<= 1; }
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      r = (r + _x / r) >> 1;
      uint256 r1 = _x / r;
      return uint128 (r < r1 ? r : r1);
    }
  }
}
