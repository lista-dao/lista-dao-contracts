pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/HayLike.sol";
import "../hMath.sol";
import "../interfaces/HayLike.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract LisUSDPool is OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    address public lisUSD; // lisUSD address

    mapping(address => uint256) public balanceOf; // user's balance
    uint256 public totalSupply; // total supply
    string public name; // pool name
    string public symbol; // pool symbol

    uint256 public tps; // lisUSD per share
    uint256 public lastUpdate; // last tps update time
    uint256 public duty; // rate per second

    uint256 public MAX_DUTY; // max rate per second

    mapping(address => uint256) public rewards; // accumulated rewards
    mapping(address => uint256) public tpsPaid; // lisUSD per share paid
    address public pauser; // pauser address

    event SetPauser(address pauser);
    event Withdraw(address account, uint256 amount);
    event Deposit(address account, uint256 amount);
    event SetDuty(uint256 duty);
    event SetMaxDuty(uint256 maxDuty);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev initialize contract
     * @param _lisUSD lisUSD address
     * @param maxDuty max rate per second
     */
    function initialize(
        address _lisUSD,
        uint256 maxDuty
    ) public initializer {
        require(_lisUSD != address(0), "lisUSD cannot be zero address");
        __Ownable_init();
        lisUSD = _lisUSD;

        name = "lisUSD single staking Pool";
        symbol = "sLisUSD";
        MAX_DUTY = maxDuty;

        emit SetMaxDuty(maxDuty);
    }

    /**
     * @dev withdraw lisUSD
     * @param amount amount to withdraw
     */
    function withdraw(uint256 amount) public updateReward(msg.sender) nonReentrant whenNotPaused {
        require(amount > 0, "amount cannot be zero");
        address account = msg.sender;
        require(balanceOf[account] + rewards[account] >= amount, "insufficient balance");

        // withdraw from rewards first
        // if rewards is not enough, withdraw from balance
        uint256 rewardsAmount = amount;
        if (rewards[account] >= amount) {
            rewards[account] -= amount;
        } else {
            rewardsAmount = rewards[account];
            rewards[account] = 0;

            uint256 balanceAmount = amount - rewardsAmount;
            balanceOf[account] -= balanceAmount;
            totalSupply -= balanceAmount;
        }

        // mint lisUSD and transfer to account
        HayLike(lisUSD).mint(address(this), rewardsAmount);
        IERC20(lisUSD).safeTransfer(account, amount);

        emit Withdraw(account, amount);
    }

    /**
     * @dev withdraw all lisUSD
     */
    function withdrawAll() external updateReward(msg.sender) nonReentrant whenNotPaused {
        address account = msg.sender;
        require(balanceOf[account] + rewards[account] > 0, "balance cannot be zero");

        // withdraw all from rewards and balance
        uint256 rewardsAmount = rewards[account];
        uint256 balanceAmount = balanceOf[account];
        totalSupply -= balanceAmount;
        balanceOf[account] = 0;
        rewards[account] = 0;

        // mint lisUSD and transfer to account
        HayLike(lisUSD).mint(address(this), rewardsAmount);
        IERC20(lisUSD).safeTransfer(account, balanceAmount + rewardsAmount);

        emit Withdraw(account, balanceAmount + rewardsAmount);
    }

    /**
     * @dev deposit lisUSD
     * @param amount amount to deposit
     */
    function deposit(uint256 amount) external updateReward(msg.sender) nonReentrant whenNotPaused {
        require(amount > 0, "amount cannot be zero");
        // transfer lisUSD to pool
        IERC20(lisUSD).safeTransferFrom(msg.sender, address(this), amount);

        // update balance and total supply
        balanceOf[msg.sender] += amount;
        totalSupply += amount;

        emit Deposit(msg.sender, amount);
    }

    // update reward when user do write operation
    modifier updateReward(address account) {
        tps = tokensPerShare();
        lastUpdate = block.timestamp;

        if (account != address(0)) {
            rewards[account] = earned(account);
            tpsPaid[account] = tps;
        }

        _;
    }

    // get reward amount
    function earned(address account) public view returns (uint) {
        uint perToken = tokensPerShare() - tpsPaid[account];
        return ((balanceOf[account] * perToken) / hMath.ONE) + rewards[account];
    }

    // get tokens per share
    function tokensPerShare() public view returns (uint256) {
        if (totalSupply <= 0 || block.timestamp <= lastUpdate) {
            return tps;
        }

        return tps + getRate();
    }

    // get last time reward applicable
    function getReward() external updateReward(msg.sender) nonReentrant {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "reward cannot be zero");
        rewards[msg.sender] = 0;
        HayLike(lisUSD).mint(address(this), reward);
        IERC20(lisUSD).safeTransfer(msg.sender, reward);
    }

    // get rate between current time and last update time
    function getRate() public view returns (uint256) {
        return hMath.rpow(duty, block.timestamp - lastUpdate, hMath.ONE) - hMath.ONE;
    }

    /**
     * @dev set duty
     * @param _duty duty
     */
    function setDuty(uint256 _duty) external updateReward(address(0)) onlyOwner {
        require(_duty <= MAX_DUTY, "duty cannot exceed max duty");

        duty = _duty;
        emit SetDuty(_duty);
    }

    /**
     * @dev set max duty
     * @param _maxDuty max duty
     */
    function setMaxDuty(uint256 _maxDuty) external onlyOwner {
        MAX_DUTY = _maxDuty;
        emit SetMaxDuty(_maxDuty);
    }

    /**
     * @dev set pauser address
     * @param _pauser pauser address
     */
    function setPauser(address _pauser) external onlyOwner {
        require(_pauser != address(0), "pauser cannot be zero address");
        pauser = _pauser;

        emit SetPauser(_pauser);
    }

    /**
     * @dev pause contract
     */
    function pause() external {
        require(msg.sender == pauser, "only pauser can pause");
        _pause();
    }

    /**
     * @dev toggle pause contract
     */
    function togglePause() external onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }
}