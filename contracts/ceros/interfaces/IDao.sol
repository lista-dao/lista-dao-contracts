// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../interfaces/GemJoinLike.sol";
import "../../interfaces/JugLike.sol";

struct CollateralType {
    GemJoinLike gem;
    bytes32 ilk;
    uint32 live; //0 - inactive, 1 - started, 2 - stopped
    address clip;
}

interface IDao {
    event Deposit(address indexed user, address collateral, uint256 amount, uint256 totalAmount);
    event Borrow(address indexed user, address collateral, uint256 collateralAmount, uint256 amount, uint256 liquidationPrice);
    event Payback(address indexed user, address collateral, uint256 amount, uint256 debt, uint256 liquidationPrice);
    event Withdraw(address indexed user, uint256 amount);
    event CollateralEnabled(address token, bytes32 ilk);
    event CollateralDisabled(address token, bytes32 ilk);
    event AuctionStarted(address indexed token, address user, uint256 amount, uint256 price);
    event AuctionFinished(address indexed token, address keeper,  uint256 amount);

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

    function setCollateralDuty(address token, uint256 duty) external;

    function jug() external view returns(JugLike);

    function collaterals(address token) external view returns (GemJoinLike, bytes32, uint32, address);

    function locked(address token, address usr) external view returns (uint256);

    function free(address token, address usr) external view returns (uint256);
}
