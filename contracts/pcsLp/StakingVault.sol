pragma solidity ^0.8.10;

//import "./interfaces/IStaking.sol";
import "./interfaces/IStakingVault.sol";
import "./interfaces/IV2Wrapper.sol";
import "./interfaces/IDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract StakingVault is OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    // staking address
    address public staking;
    // reward token
    address public rewardToken;
    // distributor => allocated amount
    mapping(address => uint256) public allocated;
    // fees
    uint256 public fees;
    // fee rate
    uint256 public feeRate;
    // max fee rate
    uint256 public constant MAX_FEE = 7000;
    // fee precision
    uint256 public constant FEE_PRECISION = 10000;
    // fee receiver
    address public feeReceiver;
    // lp proxy address
    address public lpProxy;
    // pauser address
    address public pauser;
    // usdt distributor address
    address public usdtDistributor;

    event AddRewards(address distributor, uint256 amount, uint256 fee);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
      * @dev initialize contract
      * @param _owner owner address
      * @param _rewardToken reward token address
      * @param _feeReceiver fee receiver address
      */
    function initialize(
        address _owner,
        address _rewardToken,
        address _feeReceiver
    ) public initializer {
        require(_owner != address(0), "owner cannot be zero address");
        require(_rewardToken != address(0), "rewardToken cannot be zero address");
        require(_feeReceiver != address(0), "feeReceiver cannot be zero address");
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        transferOwnership(_owner);

        rewardToken = _rewardToken;
        feeReceiver = _feeReceiver;
    }

    modifier onlyPauser() {
        require(msg.sender == pauser, "Only pauser can call this function");
        _;
    }

    modifier onlyStakingOrUsdtDistributor() {
        require(msg.sender == staking || msg.sender == usdtDistributor, "Only staking contract can call this function");
        _;
    }

    modifier onlyLpProxy() {
        require(msg.sender == lpProxy, "Only lp proxy can call this function");
        _;
    }

    /**
      * @dev update rewards for distributor
      * @param distributor distributor address
      * @param amount reward amount
      */
    function sendRewards(address distributor, uint256 amount) external onlyStakingOrUsdtDistributor {
        // The caller should pay the staking rewards
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);

        uint256 rewardAmount = amount;
        uint256 fee;
        if (feeRate > 0) {
            fee = Math.mulDiv(amount, feeRate, FEE_PRECISION);

            fees += fee;
            rewardAmount -= fee;
        }

        if (rewardAmount > 0) {
            allocated[distributor] += rewardAmount;

            IDistributor(distributor).notifyStakingReward(rewardAmount);
        }

        emit AddRewards(distributor, rewardAmount, fee);
    }
    /**
      * @dev harvest fees
      */
    function harvest() external nonReentrant {
        if (fees > 0) {
            uint256 harvestFee = fees;
            fees = 0;
            IERC20(rewardToken).safeTransfer(feeReceiver, harvestFee);
        }
    }

    /**
      * @dev set fee receiver
      * @param _feeReceiver fee receiver address
      */
    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        require(_feeReceiver != address(0), "feeReceiver cannot be zero address");
        feeReceiver = _feeReceiver;
    }

    /**
      * @dev batch claim rewards
      * @param _distributors distributor addresses
      */
    function batchClaimRewards(address[] memory _distributors) external whenNotPaused nonReentrant {
        _batchClaimRewards(msg.sender, _distributors);
    }

    function _batchClaimRewards(address account, address[] memory _distributors) private {
        uint256 total;
        for (uint16 i = 0; i < _distributors.length; ++i) {
            uint256 amount = IDistributor(_distributors[i]).vaultClaimStakingReward(account);
            require(allocated[_distributors[i]] >= amount, "Insufficient allocated balance");
            allocated[_distributors[i]] -= amount;
            total += amount;
        }
        if (total > 0) {
            IERC20(rewardToken).safeTransfer(account, total);
        }
    }

    /**
      * @dev set fee rate
      * @param _feeRate fee rate
      */
    function setFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= MAX_FEE, "Fee rate is too high");
        feeRate = _feeRate;
    }

    /**
      * @dev set staking address
      * @param _staking staking address
      */
    function setStaking(address _staking) external onlyOwner {
        require(_staking != address(0), "staking cannot be zero address");
        staking = _staking;
    }

    /**
      * @dev set lp proxy address
      * @param _lpProxy lp proxy address
      */
    function setLpProxy(address _lpProxy) external onlyOwner {
        require(_lpProxy != address(0), "lpProxy cannot be zero address");
        lpProxy = _lpProxy;
    }

    /**
      * @dev set USDTLpListaDistributor address since it's not registered in the staking contract
      * @param _usdtDistributor USDTLpListaDistributor address
      */
    function setUsdtDistributor(address _usdtDistributor) external onlyOwner {
        require(_usdtDistributor != address(0) && usdtDistributor != _usdtDistributor, "invalid usdtDistributor provided");
        usdtDistributor = _usdtDistributor;
    }

    /**
     * @dev transfer allocated tokens to account
     * @param account account address
     * @param amount amount of token
     */
    function transferAllocatedTokens(address account, uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "amount must be greater than 0");
        address distributor = msg.sender;
        require(allocated[distributor] >= amount, "insufficient allocated balance");
        allocated[distributor] -= amount;

        IERC20(rewardToken).safeTransfer(account, amount);
    }

    /**
      * @dev batch claim rewards with proxy
      * @param account user address
      * @param _distributors distributor addresses
      */
    function batchClaimRewardsWithProxy(address account, address[] memory _distributors) external onlyLpProxy whenNotPaused nonReentrant {
        _batchClaimRewards(account, _distributors);
    }

    /**
      * @dev _pause pauser address
      */
    function setPauser(address _pauser) external onlyOwner {
        require(_pauser != address(0), "pauser cannot be zero address");
        pauser = _pauser;
    }

    /**
      * @dev pause contract
      */
    function pause() external onlyPauser {
        _pause();
    }

    /**
      * @dev toggle pause contract
      */
    function togglePause() external onlyOwner {
        paused() ? _unpause() : _pause();
    }
}
