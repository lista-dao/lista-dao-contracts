pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VaultManager is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    address public psm;
    address public gem;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _psm,
        address _gem
    ) public initializer {
        require(_psm != address(0), "psm cannot be zero address");
        require(_gem != address(0), "gem cannot be zero address");
        __Ownable_init();
        psm = _psm;
        gem = _gem;
    }

    modifier onlyPSM() {
        require(msg.sender == psm, "Only PSM can call this function");
        _;
    }

    function deposit(uint256 amount) external onlyPSM {
        IERC20(gem).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address receiver, uint256 amount) external onlyPSM returns (uint256) {
        IERC20(gem).safeTransfer(receiver, amount);
        return amount;
    }

}
