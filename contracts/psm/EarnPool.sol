pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/ILisUSDPool.sol";
import "../interfaces/IPSM.sol";
import "../interfaces/IStakeLisUSDListaDistributor.sol";

contract EarnPool is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    address public psm;
    address public adapter;
    address public lisUSDPool;
    address public gem;
    address public lisUSD;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    string public name;
    string public symbol;

    uint256 public endTime;         // period finish time
    uint256 public rate;            // emission per second
    uint256 public tps;             // lisUSD per share
    uint256 public lastUpdate;      // Last tps update
    mapping(address => uint) public tpsPaid;      // lisUSD per share paid
    mapping(address => uint) public rewards;      // accumulated rewards

    uint256 constant REWARD_DURATION = 1 weeks;

    address public stakeLisUSDListaDistributor;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event FetchRewards(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
      * @dev initialize contract
      */
    function initialize(
        string memory _name,
        string memory _symbol,
        address _psm,
        address _lisUSDPool,
        address _gem,
        address _lisUSD
    ) public initializer {
        require(_psm != address(0), "psm cannot be zero address");
        require(_lisUSDPool != address(0), "lisUSDPool cannot be zero address");
        require(_gem != address(0), "gem cannot be zero address");
        require(_lisUSD != address(0), "lisUSD cannot be zero address");
        __Ownable_init();

        name = _name;
        symbol = _symbol;
        psm = _psm;
        lisUSDPool = _lisUSDPool;
        gem = _gem;
        lisUSD = _lisUSD;
    }

    function deposit(uint256 amount) external updateReward(msg.sender) nonReentrant {
        require(amount > 0, "amount must be greater than zero");
        IERC20(gem).safeTransferFrom(msg.sender, address(this), amount);
        // convert gem to lisUSD
        IERC20(gem).safeIncreaseAllowance(psm, amount);
        uint256 before = IERC20(lisUSD).balanceOf(address(this));
        IPSM(psm).sellGem(amount);
        uint256 lisUSDAmount = IERC20(lisUSD).balanceOf(address(this)) - before;

        // deposit lisUSD to lisUSD pool
        IERC20(lisUSD).safeIncreaseAllowance(lisUSDPool, lisUSDAmount);
        ILisUSDPool(lisUSDPool).deposit(lisUSDAmount);

        balanceOf[msg.sender] += lisUSDAmount;
        totalSupply += lisUSDAmount;

        emit Transfer(address(0), msg.sender, lisUSDAmount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) returns (uint256) {
        address account = msg.sender;
        require(amount > 0, "amount must be greater than zero");
        require(balanceOf[account] + rewards[account] >= amount, "insufficient balance");

        uint256 withdrawAmount = amount;
        uint256 rewardAmount = 0;
        // withdraw from balance first
        if (balanceOf[account] < amount) {
            withdrawAmount = balanceOf[account];
            rewardAmount = amount - balanceOf[account];
        }

        balanceOf[account] -= withdrawAmount;
        totalSupply -= withdrawAmount;
        rewards[account] -= rewardAmount;

        uint256 before = IERC20(lisUSD).balanceOf(address(this));
        ILisUSDPool(lisUSDPool).withdraw(amount);
        uint256 realAmount = IERC20(lisUSD).balanceOf(address(this)) - before;

        IERC20(lisUSD).safeTransfer(account, realAmount);

        takeSnapshot(account, balanceOf[account]);

        emit Transfer(account, address(0), withdrawAmount);

        return realAmount;
    }

    modifier updateReward(address account) {
        tps = tokensPerShare();
        lastUpdate = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            tpsPaid[account] = tps;
        }
        _;
    }

    function tokensPerShare() public view returns (uint256) {
        if (totalSupply <= 0 || block.timestamp <= lastUpdate) {
            return tps;
        }
        uint256 latest = lastTimeRewardApplicable();
        return tps + (((latest - lastUpdate) * rate * 1e18) / totalSupply);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(block.timestamp, endTime);
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function earned(address account) public view returns (uint) {
        uint perToken = tokensPerShare() - tpsPaid[account];
        return ((balanceOf[account] * perToken) / 1e18) + rewards[account];
    }

    /**
     * @dev take snapshot of user's LisUSD staking amount
     * @param user user address
     * @param balance user's latest staked LisUSD amount
     */
    function takeSnapshot(address user, uint256 balance) private {
        // ensure the distributor address is set
        if (stakeLisUSDListaDistributor != address(0)) {
            IStakeLisUSDListaDistributor(stakeLisUSDListaDistributor).takeSnapshot(user, balance);
        }
    }

    function setStakeLisUSDListaDistributor(address _distributor) external onlyOwner {
        require(_distributor != address(0), "distributor cannot be zero address");
        stakeLisUSDListaDistributor = _distributor;
    }

    function fetchRewards() external updateReward(address(0)) {
        // get reward from lisUSD pool
        uint256 before = IERC20(lisUSD).balanceOf(address(this));
        ILisUSDPool(lisUSDPool).getReward();
        uint256 amount = IERC20(lisUSD).balanceOf(address(this)) - before;
        // stake to lisUSDPool
        IERC20(lisUSD).safeIncreaseAllowance(lisUSDPool, amount);
        ILisUSDPool(lisUSDPool).deposit(amount);

        uint256 _endTime = endTime;
        if (block.timestamp < _endTime) {
            uint256 remaining = _endTime - block.timestamp;
            amount += remaining * _endTime;
        }

        rate = amount / REWARD_DURATION;

        lastUpdate = block.timestamp;
        endTime = block.timestamp + REWARD_DURATION;

        emit FetchRewards(amount);
    }
}