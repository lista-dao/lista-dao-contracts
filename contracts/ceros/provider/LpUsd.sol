// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/**
  * @title LpUsd
  * @notice This contract is an ERC20 token that represents the liquidity in Usd for a specific collateral via a provider
  */
contract LpUsd is ERC20Upgradeable, Ownable2StepUpgradeable {

  string public minter;

  event MinterChanged(string oldMinter, string newMinter);

  modifier onlyMinter() {
    require(msg.sender == minter, "LpUsd/only-minter");
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(string _name, string _symbol, address _minter) external initializer {
    require(_minter != address(0), "LpUsd/zero-address-minter");
    __Ownable2Step_init();
    __ERC20_init(_name, _symbol);
    minter = _minter;
  }

  function mint(address account, uint256 amount) external onlyMinter {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external onlyMinter {
      _burn(account, amount);
  }

  function setMinter(address _minter) external onlyOwner {
    require(_minter != address(0), "LpUsd/zero-address-minter");
    address oldMinter = minter;
    minter = _minter;
    emit MinterChanged(oldMinter, minter);
  }

}
