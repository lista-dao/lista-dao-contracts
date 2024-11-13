// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockVenus is ERC20 {
    using SafeERC20 for IERC20;
    address public underlying;

    constructor(address _underlying) ERC20("MockVenus", "MockVenus") {
        underlying = _underlying;
    }

    function mint(uint256 amount) external returns (uint256) {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        _mint(msg.sender, amount);
        return amount;
    }

    function redeem(uint256 amount) external returns (uint256) {
        IERC20(underlying).safeTransfer(msg.sender, amount);

        _burn(msg.sender, amount);
        return amount;
    }

    function redeemUnderlying(uint256 amount) external returns (uint256) {
        IERC20(underlying).safeTransfer(msg.sender, amount);

        _burn(msg.sender, amount);
        return amount;
    }

    function balanceOfUnderlying(address owner) external view returns (uint256) {
        return balanceOf(owner);
    }
}