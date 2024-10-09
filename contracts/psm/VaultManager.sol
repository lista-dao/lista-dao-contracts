pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IAdapter.sol";

contract VaultManager is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    address public psm; // PSM address
    address public gem; // gem address

    struct Adapter {
        address adapter; // adapter address
        bool active; // active status
        uint256 pct; // distributor percentage
    }

    Adapter[] public adapters; // adapter list
    uint256 public localGem; // local gem amount
    address public bot; // bot address

    uint256 constant public MAX_PRECISION = 10000;

    event SetPSM(address psm);
    event SetGem(address gem);
    event SetBot(address bot);
    event SetAdapter(address adapter, bool active, uint256 pct);
    event AddAdapter(address adapter, uint256 pct);
    event Deposit(uint256 amount);
    event Withdraw(address receiver, uint256 amount);
    event Rebalance(uint256 amount);
    event EmergencyWithdraw(address account, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
      * @dev initialize contract
      * @param _psm PSM address
      * @param _gem gem address
      */
    function initialize(
        address _psm,
        address _gem
    ) public initializer {
        require(_psm != address(0), "psm cannot be zero address");
        require(_gem != address(0), "gem cannot be zero address");
        __Ownable_init();
        psm = _psm;
        gem = _gem;

        emit SetPSM(_psm);
        emit SetGem(_gem);
    }

    modifier onlyPSM() {
        require(msg.sender == psm, "Only PSM can call this function");
        _;
    }

    /**
      * @dev deposit gem to adapters, only PSM can call this function
      * @param amount deposit amount
      */
    function deposit(uint256 amount) external onlyPSM {
        require(amount > 0, "deposit amount cannot be zero");

        // transfer gem to this contract
        IERC20(gem).safeTransferFrom(msg.sender, address(this), amount);
        _distribute(amount);

        emit Deposit(amount);
    }

    function _distribute(uint256 amount) private {
        uint256 remain = amount;

        // deposit gem to adapters by adapter percentage
        for (uint256 i = 0; i < adapters.length; i++) {
            if (adapters[i].active) { // only active adapter can be used
                //  adapterAmount = depositAmount * adapterPercentage / 10000
                uint256 amt = Math.mulDiv(amount, adapters[i].pct, MAX_PRECISION);
                if (amt > 0) {
                    IERC20(gem).safeIncreaseAllowance(adapters[i].adapter, amt);
                    IAdapter(adapters[i].adapter).deposit(amt);
                    remain -= amt;
                }
            }
        }

        // if remain amount > 0, add to localGem
        if (remain > 0) {
            localGem += remain;
        }
    }

    /**
      * @dev withdraw gem from adapters, only PSM can call this function
      * @param receiver receiver address
      * @param amount withdraw amount
      */
    function withdraw(address receiver, uint256 amount) external onlyPSM {
        require(amount > 0, "withdraw amount cannot be zero");

        uint256 remain = amount;

        // withdraw gem from local first
        if (localGem >= remain) {
            IERC20(gem).safeTransfer(receiver, remain);
            localGem -= remain;
            return;
        } else {
            IERC20(gem).safeTransfer(receiver, localGem);
            remain -= localGem;
            localGem = 0;
        }

        // withdraw gem from adapters
        for (uint256 i = 0; i < adapters.length; i++) {
            uint256 totalAvailableAmount = IAdapter(adapters[i].adapter).totalAvailableAmount();
            if (totalAvailableAmount >= remain) {
                IAdapter(adapters[i].adapter).withdraw(receiver, remain);
                return;
            } else {
                IAdapter(adapters[i].adapter).withdraw(receiver, totalAvailableAmount);
                remain -= totalAvailableAmount;
            }
        }

        require(remain == 0, "not enough available balance");

        emit Withdraw(receiver, amount);
    }

    /**
      * @dev add adapter
      * @param adapter adapter address
      * @param pct adapter percentage
      */
    function addAdapter(address adapter, uint256 pct) external onlyOwner {
        require(adapter != address(0), "adapter cannot be zero address");
        require(pct > 0, "pct cannot be zero");
        for (uint256 i = 0; i < adapters.length; i++) {
            require(adapters[i].adapter != adapter, "adapter already exists");
        }

        adapters.push(Adapter({
            adapter: adapter,
            active: true,
            pct: pct
        }));

        require(checkPct(), "total pct exceeds MAX_PCT");
        emit AddAdapter(adapter, pct);
    }

    /**
      * @dev update adapter
      * @param index adapter index
      * @param active active status
      * @param pct adapter percentage
      */
    function setAdapter(uint256 index, bool active, uint256 pct) external onlyOwner {
        require(index < adapters.length, "index out of range");
        adapters[index].active = active;
        adapters[index].pct = pct;

        require(checkPct(), "total pct exceeds MAX_PCT");
        emit SetAdapter(adapters[index].adapter, active, pct);
    }

    // check total percentage
    function checkPct() private returns (bool) {
        uint256 totalPct;
        for (uint256 i = 0; i < adapters.length; i++) {
            if (adapters[i].active) {
                totalPct += adapters[i].pct;
            }
        }

        return totalPct <= MAX_PRECISION;
    }

    /**
      * @dev rebalance gem to adapters, only bot can call this function
      */
    function rebalance() external {
        require(msg.sender == bot, "Only bot can call this function");

        uint256 amount = localGem;
        for (uint256 i = 0; i < adapters.length; i++) {
            amount += IAdapter(adapters[i].adapter).withdrawAll();
        }

        if (amount > 0) {
            _distribute(amount);
        }

        emit Rebalance(amount);
    }

    /**
      * @dev set bot address
      * @param _bot bot address
      */
    function setBot(address _bot) external onlyOwner {
        require(_bot != address(0), "bot cannot be zero address");
        bot = _bot;

        emit SetBot(_bot);
    }

    /**
      * @dev emergency withdraw gem from adapters
      * @param index adapter index
      */
    function emergencyWithdraw(uint256 index) external onlyOwner {
        require(index < adapters.length, "index out of range");
        uint256 amount = IAdapter(adapters[index].adapter).withdrawAll();

        IERC20(gem).safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, amount);
    }
}
