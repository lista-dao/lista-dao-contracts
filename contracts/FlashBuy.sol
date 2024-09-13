// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

    // added on 2024/09/12
    address public revenuePool;

    event RevenuePoolChanged(address indexed newAddress);

    using SafeERC20 for IERC20;

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

    modifier auctionWhitelisted {
        if (IInteraction(interaction).auctionWhitelistMode() == 1)
            require(IInteraction(interaction).auctionWhitelist(msg.sender) == 1, "Interaction/not-in-auction-whitelist");
        _;
    }

    function transfer(address token) external {
        require(revenuePool != address(0), "Revenue pool not set");

        IERC20(token).safeTransfer(
            revenuePool,
            IERC20(token).balanceOf(address(this))
        );
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
    ) public auctionWhitelisted {
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

    function changeRevenuePool(address _revenuePool) external onlyOwner {
        require(_revenuePool != address(0), "Invalid zero address");
        require(_revenuePool != revenuePool, "Already set");

        revenuePool = _revenuePool;
        emit RevenuePoolChanged(_revenuePool);
    }
}
