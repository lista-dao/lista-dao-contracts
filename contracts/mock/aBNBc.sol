// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../ceros/interfaces/ICertToken.sol";

contract aBNBc is ERC20, ICertToken {
  /**
   * Variables
   */

  address private _binancePool;
  address private _bondToken;

  /**
   * Events
   */

  event BinancePoolChanged(address indexed binancePool);
  event BondTokenChanged(address indexed bondToken);

  /**
   * Modifiers
   */

  modifier onlyMinter() {
    require(
      msg.sender == _binancePool || msg.sender == _bondToken,
      "Minter: not allowed"
    );
    _;
  }

constructor(address binancePool, address bondToken) ERC20("Ankr BNB Reward Bearing Certificate", "aBNBc") {
    _binancePool = binancePool;
    _bondToken = bondToken;
    uint256 initSupply = ICertToken(_bondToken).totalSupply();
    // mint init supply if not inizialized
    super._mint(address(_bondToken), initSupply);
}

  function ratio() public view returns (uint256) {
    return ICertToken(_bondToken).ratio();
  }

  function burn(address account, uint256 amount) external override {
    _burn(account, amount);
  }

  function mint(address account, uint256 amount) external override {
    _mint(account, amount);
  }
  function mintApprovedTo(
    address account,
    address spender,
    uint256 amount
  ) external {
    _mint(account, amount);
    _approve(account, spender, amount);
  }

  function changeBinancePool(address binancePool) external {
    _binancePool = binancePool;
    emit BinancePoolChanged(binancePool);
  }

  function changeBondToken(address bondToken) external {
    _bondToken = bondToken;
    emit BondTokenChanged(bondToken);
  }

  function balanceWithRewardsOf(
      address account
  ) public view override returns (uint256) {
      uint256 shares = this.balanceOf(account);
      return sharesToBonds(shares);
  }

  function isRebasing() public pure returns (bool) {
    return false;
  }

  function sharesToBonds(uint256 amount) public view returns (uint256) {
        return multiplyAndDivideCeil(amount, 1 ether, ratio());
  }

  function bondsToShares(uint256 amount) public view override returns (uint256) {
        return multiplyAndDivideFloor(amount, ratio(), 1 ether);
  }
  function saturatingMultiply(uint256 a, uint256 b)
      internal
      pure
      returns (uint256)
  {
      unchecked {
          if (a == 0) return 0;
          uint256 c = a * b;
          if (c / a != b) return type(uint256).max;
          return c;
      }
  }

  function saturatingAdd(uint256 a, uint256 b)
      internal
      pure
      returns (uint256)
  {
      unchecked {
          uint256 c = a + b;
          if (c < a) return type(uint256).max;
          return c;
      }
  }

  // Preconditions:
  //  1. a may be arbitrary (up to 2 ** 256 - 1)
  //  2. b * c < 2 ** 256
  // Returned value: min(floor((a * b) / c), 2 ** 256 - 1)
  function multiplyAndDivideFloor(
      uint256 a,
      uint256 b,
      uint256 c
  ) internal pure returns (uint256) {
      return
          saturatingAdd(
              saturatingMultiply(a / c, b),
              ((a % c) * b) / c // can't fail because of assumption 2.
          );
  }

  // Preconditions:
  //  1. a may be arbitrary (up to 2 ** 256 - 1)
  //  2. b * c < 2 ** 256
  // Returned value: min(ceil((a * b) / c), 2 ** 256 - 1)
  function multiplyAndDivideCeil(
      uint256 a,
      uint256 b,
      uint256 c
  ) internal pure returns (uint256) {
      return
          saturatingAdd(
              saturatingMultiply(a / c, b),
              ((a % c) * b + (c - 1)) / c // can't fail because of assumption 2.
          );
  }

}
