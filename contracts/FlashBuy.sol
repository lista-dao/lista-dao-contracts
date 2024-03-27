// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { IAuctionProxy } from "./interfaces/IAuctionProxy.sol";
import { IERC3156FlashBorrower } from "./interfaces/IERC3156FlashBorrower.sol";
import { IERC3156FlashLender } from "./interfaces/IERC3156FlashLender.sol";

interface IDEX {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}


contract FlashBuy is IERC3156FlashBorrower, OwnableUpgradeable {
    enum Action {NORMAL, OTHER}

    IERC3156FlashLender public lender;
    IAuctionProxy public auction;
    IDEX dex;

    // --- Init ---
    function initialize(IERC3156FlashLender lender_, IAuctionProxy auction_, IDEX dex_) public initializer {
        __Ownable_init();

        require(address(lender_) != address(0) && address(auction_) != address(0) && address(dex_) != address(0), "Invalid address provided");
        lender = lender_;
        auction = auction_;
        dex = dex_;
    }

    function transfer(address token) onlyOwner external {
        bool success = IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
        require(success, "Failed to transfer");
    }

    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(
            msg.sender == address(lender),
            "FlashBorrower: Untrusted lender"
        );
        require(
            initiator == address(this),
            "FlashBorrower: Untrusted loan initiator"
        );

        (Action action, uint256 auctionId, address collateral, uint256 collateralAm, uint256 maxPrice) = abi.decode(
            data, (Action, uint256, address, uint256, uint256)
        );
        require(action == Action.NORMAL, "such action is not implemented");
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        require(tokenBalance >= amount, "borrow amount not received");

        auction.buyFromAuction(collateral, auctionId, collateralAm, maxPrice, address(this));
        uint256 minOut = amount + fee;

        address[] memory path = new address[](2);
        path[0] = collateral;
        path[1] = token;
        dex.swapExactTokensForTokens(collateralAm, minOut, path, address(this), block.timestamp + 300);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBuyAuction(
        address token,
        uint256 auctionId,
        uint256 borrowAm,
        address collateral,
        uint256 collateralAm,
        uint256 maxPrice
    ) public {
        require(borrowAm <= lender.maxFlashLoan(token));
        bytes memory data = abi.encode(Action.NORMAL, auctionId, collateral, collateralAm, maxPrice);
        uint256 _fee = lender.flashFee(token, borrowAm);
        uint256 _repayment = borrowAm + _fee;
        uint256 _allowance = IERC20(token).allowance(address(this), address(lender));
        IERC20(token).approve(address(lender), _allowance + _repayment);
        IERC20(token).approve(address(auction), _allowance + _repayment);
        IERC20(collateral).approve(address(dex), collateralAm);

        lender.flashLoan(this, token, borrowAm, data);
    }
}
