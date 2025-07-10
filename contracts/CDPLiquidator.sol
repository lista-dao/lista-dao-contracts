// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "./interfaces/IERC3156FlashLender.sol";
import {IInteraction} from "./interfaces/IInteraction.sol";

contract CDPLiquidator is IERC3156FlashBorrower, UUPSUpgradeable, AccessControlEnumerableUpgradeable {
    using SafeERC20 for IERC20;

    struct LiquidationData {
        uint256 auctionId;
        address collateral;
        uint256 collateralAm;
        uint256 maxPrice;
        address collateralReal;
        address pair;
        bytes swapData;
    }

    /// @dev The address of the flash lender.
    IERC3156FlashLender public lender;
    /// @dev The address of the interaction contract.
    IInteraction public interaction;
    /// @dev The address of the lisUSD token.
    address public lisUSD;
    /// @dev Whitelists for tokens.
    mapping(address => bool) public tokenWhitelist;
    /// @dev Whitelist for pairs.
    mapping(address => bool) public pairWhitelist;

    bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role
    bytes32 public constant BOT = keccak256("BOT"); // bot role


    event TokenWhitelistChanged(address indexed token, bool added);
    event PairWhitelistChanged(address pair, bool added);
    event SellToken(address pair, address tokenIn, uint256 amountIn, uint256 amountOutMin);

    /* CONSTRUCTOR */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev initializes the contract.
    /// @param admin The address of the admin.
    /// @param manager The address of the manager.
    /// @param bot The address of the bot.
    /// @param _lender The address of the flash lender.
    /// @param _interaction The address of the interaction contract.
    /// @param _lisUSD The address of the lisUSD token.
    function initialize(
        address admin,
        address manager,
        address bot,
        IERC3156FlashLender _lender,
        IInteraction _interaction,
        address _lisUSD
    ) public initializer {
        require(
            address(_lender) != address(0) &&
            address(_interaction) != address(0) &&
            _lisUSD != address(0),
            "Invalid address provided"
        );

        __UUPSUpgradeable_init();
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(MANAGER, manager);
        _setupRole(BOT, bot);
        lender = _lender;
        interaction = _interaction;
        lisUSD = _lisUSD;
    }

    modifier auctionWhitelisted {
        if (IInteraction(interaction).auctionWhitelistMode() == 1)
            require(IInteraction(interaction).auctionWhitelist(msg.sender) == 1, "Interaction/not-in-auction-whitelist");
        _;
    }


    /// @dev withdraws ERC20 tokens.
    /// @param token The address of the token.
    /// @param amount The amount to withdraw.
    function withdrawERC20(address token, uint256 amount) external onlyRole(MANAGER) {
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /// @dev sets the token whitelist.
    /// @param token The address of the token.
    /// @param status The status of the token.
    function setTokenWhitelist(address token, bool status) external onlyRole(MANAGER) {
        require(tokenWhitelist[token] != status, "whitelist same status");
        tokenWhitelist[token] = status;
        emit TokenWhitelistChanged(token, status);
    }

    /// @dev sets the pair whitelist.
    /// @param pair The address of the pair.
    /// @param status The status of the pair.
    function setPairWhitelist(address pair, bool status) external onlyRole(MANAGER) {
        require(pair != address(0), "pair is zero address");
        require(pairWhitelist[pair] != status, "whitelist same status");
        pairWhitelist[pair] = status;
        emit PairWhitelistChanged(pair, status);
    }

    /// @dev sell tokens.
    /// @param pair The address of the pair.
    /// @param tokenIn The address of the input token.
    /// @param amountIn The amount to sell.
    /// @param amountOutMin The minimum amount to receive.
    /// @param swapData The swap data.
    function sellToken(
        address pair,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes calldata swapData
    ) external onlyRole(BOT) {
        require(tokenWhitelist[tokenIn], "not whitelisted");
        require(pairWhitelist[pair], "not whitelisted");

        require(IERC20(tokenIn).balanceOf(address(this)) >= amountIn, "exceed amount");

        uint256 beforeTokenIn = IERC20(tokenIn).balanceOf(address(this));
        uint256 beforeTokenOut = IERC20(lisUSD).balanceOf(address(this));

        IERC20(tokenIn).safeApprove(pair, amountIn);
        (bool success, ) = pair.call(swapData);
        require(success, "swap failed");
        IERC20(tokenIn).safeApprove(pair, 0);

        uint256 actualAmountIn = beforeTokenIn - IERC20(tokenIn).balanceOf(address(this));
        uint256 actualAmountOut = IERC20(lisUSD).balanceOf(address(this)) - beforeTokenOut;

        require(actualAmountIn <= amountIn, "exceed amount in");
        require(actualAmountOut >= amountOutMin, "no profit");

        emit SellToken(pair, tokenIn, actualAmountIn, actualAmountOut);
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

        LiquidationData memory liquidationData = abi.decode(data, (LiquidationData));

        IERC20(lisUSD).safeApprove(address(interaction), type(uint256).max);
        uint256 before = IERC20(liquidationData.collateralReal).balanceOf(address(this));
        interaction.buyFromAuction(
            liquidationData.collateral,
            liquidationData.auctionId,
            liquidationData.collateralAm,
            liquidationData.maxPrice,
            address(this)
        );
        uint256 amountIn = IERC20(liquidationData.collateralReal).balanceOf(address(this)) - before;

        IERC20(liquidationData.collateralReal).safeApprove(liquidationData.pair, amountIn);
        (bool success,) = liquidationData.pair.call(liquidationData.swapData);
        require(success, "swap failed");

        IERC20(lisUSD).safeApprove(address(interaction), 0);
        IERC20(liquidationData.collateralReal).safeApprove(liquidationData.pair, 0);


        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev flash liquidates a position.
    /// @param auctionId The id of the auction.
    /// @param borrowAm The amount to borrow.
    /// @param collateral The address of the collateral token.
    /// @param collateralAm The amount of collateral to liquidate.
    /// @param maxPrice The maximum price to pay for the collateral.
    /// @param collateralReal The real address of the collateral token.
    /// @param pair The address of the pair to swap.
    /// @param swapData The swap data to execute.
    function flashLiquidate(
        uint256 auctionId,
        uint256 borrowAm,
        address collateral,
        uint256 collateralAm,
        uint256 maxPrice,
        address collateralReal,
        address pair,
        bytes memory swapData
    ) external onlyRole(BOT) auctionWhitelisted {
        require(pairWhitelist[pair], "Pair not whitelisted");
        require(borrowAm <= lender.maxFlashLoan(lisUSD));
        bytes memory data = abi.encode(
            LiquidationData(auctionId, collateral, collateralAm, maxPrice, collateralReal, pair, swapData)
        );
        uint256 _repayment = borrowAm + lender.flashFee(lisUSD, borrowAm);
        uint256 _allowance = IERC20(lisUSD).allowance(
            address(this),
            address(lender)
        );
        IERC20(lisUSD).safeApprove(address(lender), _allowance + _repayment);

        uint256 before = IERC20(lisUSD).balanceOf(address(this));
        lender.flashLoan(this, lisUSD, borrowAm, data);
        require(IERC20(lisUSD).balanceOf(address(this)) > before, "Flash loan failed");

        IERC20(lisUSD).safeApprove(address(lender), 0);
    }

    /// @dev liquidates an auction.
    /// @param auctionId The id of the auction.
    /// @param collateral The address of the collateral token.
    /// @param collateralAm The amount of collateral to liquidate.
    /// @param maxPrice The maximum price to pay for the collateral.
    function liquidate(uint256 auctionId, address collateral, uint256 collateralAm, uint256 maxPrice) external onlyRole(BOT) auctionWhitelisted {
        IERC20(lisUSD).safeApprove(address(interaction), type(uint256).max);
        interaction.buyFromAuction(collateral, auctionId, collateralAm, maxPrice, address(this));
        IERC20(lisUSD).safeApprove(address(interaction), 0);
    }

    function _authorizeUpgrade(address newImplementations) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
