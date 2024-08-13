// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "./interfaces/IERC3156FlashLender.sol";
import {IInteraction} from "./interfaces/IInteraction.sol";

interface IDEX {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

contract FlashBuy is IERC3156FlashBorrower, OwnableUpgradeable {
    enum Action {
        NORMAL,
        OTHER
    }

    IERC3156FlashLender public lender;
    IInteraction public interaction;
    IDEX public dex;

    uint256 constant public MAX_SLIPPAGE = 10000;

    // --- Init ---
    function initialize(
        IERC3156FlashLender lender_,
        IInteraction interaction_,
        IDEX dex_
    ) public initializer {
        __Ownable_init();

        require(
            address(lender_) != address(0) &&
            address(interaction_) != address(0) &&
            address(dex_) != address(0),
            "Invalid address provided"
        );
        lender = lender_;
        interaction = interaction_;
        dex = dex_;
    }

    function transfer(address token) external {
        bool success = IERC20(token).transfer(
            owner(),
            IERC20(token).balanceOf(address(this))
        );
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

        (
            Action action,
            uint256 auctionId,
            address collateral,
            uint256 collateralAm,
            uint256 maxPrice,
            uint256 slippage,
            address collateralReal,
            bytes memory path
        ) = abi.decode(data, (Action, uint256, address, uint256, uint256, uint256, address, bytes));
        require(action == Action.NORMAL, "such action is not implemented");
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        require(tokenBalance >= amount, "borrow amount not received");

        uint256 before = IERC20(collateralReal).balanceOf(address(this));

        interaction.buyFromAuction(
            collateral,
            auctionId,
            collateralAm,
            maxPrice,
            address(this)
        );

        uint256 amountIn = IERC20(collateralReal).balanceOf(address(this)) - before;
        IERC20(collateralReal).approve(address(dex), amountIn);

        uint256 currentPrice = interaction.collateralPrice(collateral);
        uint256 amountOut = (amountIn * currentPrice) / 1e18;
        uint256 amountOutMin = (amountOut * (MAX_SLIPPAGE - slippage)) / MAX_SLIPPAGE;

        dex.exactInput(IDEX.ExactInputParams({
            path: path,
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: amountOutMin
        }));

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBuyAuction(
        address token,
        uint256 auctionId,
        uint256 borrowAm,
        address collateral,
        uint256 collateralAm,
        uint256 maxPrice,
        uint256 slippage,
        address collateralReal,
        bytes memory path
    ) public {
        require(borrowAm <= lender.maxFlashLoan(token));
        bytes memory data = abi.encode(
            Action.NORMAL,
            auctionId,
            collateral,
            collateralAm,
            maxPrice,
            slippage,
            collateralReal,
            path
        );
        uint256 _repayment = borrowAm + lender.flashFee(token, borrowAm);
        uint256 _allowance = IERC20(token).allowance(
            address(this),
            address(lender)
        );
        IERC20(token).approve(address(lender), _allowance + _repayment);
        IERC20(token).approve(address(interaction), _allowance + _repayment);

        uint256 before = IERC20(token).balanceOf(address(this));
        lender.flashLoan(this, token, borrowAm, data);
        require(IERC20(token).balanceOf(address(this)) > before, "Flash loan failed");
    }
}
