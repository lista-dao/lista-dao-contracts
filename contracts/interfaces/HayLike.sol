// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface HayLike is IERC20{
    function balanceOf(address) external view returns (uint256);

    function transferFrom(address, address, uint256) external returns (bool);

    function approve(address, uint256) external returns (bool);

    function mint(address, uint256) external;

    function burn(address, uint256) external;
}
