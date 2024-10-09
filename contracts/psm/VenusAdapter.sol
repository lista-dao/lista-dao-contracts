pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IVBep20Delegate.sol";

contract VenusAdapter is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    address public earnPool;
    address public venusPool;
    address public gem;
    address public vToken;

    event EarnPoolSet(address earnPool);
    event Deposit(uint256 amount);
    event Withdraw(address account, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyEarnPool() {
        require(msg.sender == earnPool, "only EarnPool can call this function");
        _;
    }

    function initialize(address _venusPool, address _gem, address _vToken) public initializer {
        __Ownable_init();
        require(_venusPool != address(0), "venusPool cannot be zero address");
        require(_gem != address(0), "gem cannot be zero address");
        require(_vToken != address(0), "vToken cannot be zero address");

        gem = _gem;
        venusPool = _venusPool;
        vToken = _vToken;
    }

    function deposit(uint256 amount) external onlyEarnPool {
        require(amount > 0, "deposit amount cannot be zero");
        IERC20(gem).safeTransferFrom(earnPool, address(this), amount);
        IERC20(gem).safeIncreaseAllowance(venusPool, amount);

        IVBep20Delegate(venusPool).mint(amount);

        emit Deposit(amount);
    }

    function withdraw(address account, uint256 amount) external onlyEarnPool {
        require(amount > 0, "withdraw amount cannot be zero");
        uint256 vTokenAmount = Math.mulDiv(amount, 1e18, IVBep20Delegate(venusPool).exchangeRateStored());

        if (vTokenAmount == 0) {
            return;
        }
        IERC20(vToken).safeIncreaseAllowance(venusPool, vTokenAmount);
        uint256 before = IERC20(gem).balanceOf(address(this));
        IVBep20Delegate(venusPool).redeem(vTokenAmount);
        uint256 gemAmount = IERC20(gem).balanceOf(address(this)) - before;

        IERC20(gem).safeTransfer(account, gemAmount);

        emit Withdraw(account, gemAmount);
    }

    function setEarnPool(address _earnPool) external onlyOwner {
        require(_earnPool != address(0), "earnPool cannot be zero address");
        earnPool = _earnPool;

        emit EarnPoolSet(_earnPool);
    }

    function getStakedGem() public view returns (uint256) {
        uint256 vTokenAmount = IERC20(vToken).balanceOf(address(this));
        uint256 gemAmount = Math.mulDiv(vTokenAmount, IVBep20Delegate(venusPool).exchangeRateStored(), 1e18);
        return gemAmount;
    }
}