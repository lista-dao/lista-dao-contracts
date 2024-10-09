pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/HayLike.sol";

contract LisUSDPool is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    address public lisUSD;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _lisUSD
    ) public initializer {
        require(_lisUSD != address(0), "lisUSD cannot be zero address");
        __Ownable_init();
        lisUSD = _lisUSD;
    }


    function withdraw(uint256 amount) external {
        IERC20(lisUSD).safeTransfer(msg.sender, amount);
    }

    function deposit(uint256 amount) external {
        IERC20(lisUSD).safeTransferFrom(msg.sender, address(this), amount);
    }

    function getReward() external {
        HayLike(lisUSD).mint(msg.sender, 1 ether);
    }
}