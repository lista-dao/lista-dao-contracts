pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../hMath.sol";
import "../interfaces/IStakeLisUSDListaDistributor.sol";
import "../interfaces/VatLike.sol";

contract LisUSDPool is AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    address public lisUSD; // lisUSD address

    mapping(address => uint256) public shares; // user's share
    // pool => user => balance
    mapping(address => mapping(address => uint256)) public poolBalanceOf;
    // pool => lista distributor
    mapping(address => address) public listaDistributors;
    uint256 public totalShares; // total
    string public name; // pool name
    string public symbol; // pool symbol

    uint256 public rate; // share to lisUSD rate when last update
    uint256 public lastUpdate; // last tps update time
    uint256 public duty; // rate per second

    uint256 public MAX_DUTY; // max rate per second

    mapping(address => uint256) public rewards; // accumulated rewards
    mapping(address => uint256) public tpsPaid; // lisUSD per share paid

    mapping(address => bool) public earnPool; // earn pool address

    address public vat; // vat address

    bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role
    bytes32 public constant PAUSE = keccak256("PAUSE"); // pause role
    uint256 constant public RAY = 10**27;

    event Withdraw(address account, uint256 amount);
    event Deposit(address account, uint256 amount);
    event SetDuty(uint256 duty);
    event SetMaxDuty(uint256 maxDuty);
    event SetStakeLisUSDListaDistributor(address distributor);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyEarnPool() {
        require(earnPool[msg.sender], "only earnPool can call this function");
        _;
    }

    /**
     * @dev initialize contract
     * @param _lisUSD lisUSD address
     * @param maxDuty max rate per second
     */
    function initialize(
        address _lisUSD,
        address _vat,
        uint256 maxDuty
    ) public initializer {
        require(_lisUSD != address(0), "lisUSD cannot be zero address");
        require(_vat != address(0), "vat cannot be zero address");

        __AccessControl_init();
        __ReentrancyGuard_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER, msg.sender);

        lisUSD = _lisUSD;
        vat = _vat;

        name = "lisUSD single staking Pool";
        symbol = "sLisUSD";
        MAX_DUTY = maxDuty;

        emit SetMaxDuty(maxDuty);
    }

    /**
     * @dev withdraw lisUSD
     * @param pools pools address
     * @param amount amount to withdraw
     */
    function withdraw(address[] memory pools, uint256 amount) public update nonReentrant whenNotPaused {
        address account = msg.sender;
        require(amount > 0, "amount cannot be zero");

        uint256 share = balanceToShare(amount);
        if (share * getRate() < amount * RAY) {
            share += 1;
        }

        require(share <= shares[account], "insufficient balance");

        // update shares
        shares[account] -= share;
        totalShares -= share;

        // update pool balance
        uint256 remain = amount;
        for (uint i = 0; i < pools.length; i++) {
            uint256 poolBalance = poolBalanceOf[pools[i]][account];
            if (poolBalance >= remain) {
                poolBalanceOf[pools[i]][account] -= remain;
                takeSnapshot(account, pools[i]);
                break;
            } else {
                remain -= poolBalance;
                poolBalanceOf[pools[i]][account] = 0;
                takeSnapshot(account, pools[i]);
            }
        }

        // transfer lisUSD to account
        require(IERC20(lisUSD).balanceOf(address(this)) >= amount, "not enough balance");
        IERC20(lisUSD).safeTransfer(account, amount);

        emit Withdraw(account, amount);
    }


    /**
     * @dev get user's balance
     * @param account account address
     */
    function balanceOf(address account) public view returns (uint256) {
        return shareToBalance(shares[account]);
    }

    /**
     * @dev get total lisUSD staked
     */
    function totalSupply() public view returns (uint256) {
        return shareToBalance(totalShares);
    }

    /**
     * @dev deposit lisUSD
     * @param account account address
     * @param amount amount to deposit
     */
    function depositFor(address account, uint256 amount) external onlyEarnPool nonReentrant whenNotPaused {
        address pool = msg.sender;
        _depositFor(pool, pool, account, amount);
    }

    /**
     * @dev deposit lisUSD
     * @param amount amount to deposit
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        address pool = address(this);
        address account = msg.sender;
        _depositFor(account, pool, account, amount);

    }

    function _depositFor(address sender, address pool, address account, uint256 amount) private update {
        require(amount > 0, "amount cannot be zero");
        require(totalSupply() + amount <= VatLike(vat).debt() / RAY, "exceed vat debt");
        // transfer lisUSD to pool
        IERC20(lisUSD).safeTransferFrom(sender, address(this), amount);

        // update shares and pool balance
        uint256 share = balanceToShare(amount);
        shares[account] += share;
        totalShares += share;
        poolBalanceOf[pool][account] += amount;

        takeSnapshot(account, pool);

        emit Deposit(account, amount);
    }

    /**
     * @dev share to lisUSD
     * @param share share
     */
    function shareToBalance(uint256 share) public view returns (uint256) {
        return Math.mulDiv(share, getRate(), RAY);
    }

    /**
     * @dev lisUSD to share
     * @param balance balance
     */
    function balanceToShare(uint256 balance) public view returns (uint256) {
        return Math.mulDiv(balance, RAY, getRate());
    }

    // update reward when user do write operation
    modifier update() {
        rate = getRate();
        lastUpdate = block.timestamp;

        _;
    }

    // get rate between current time and last update time
    function getRate() public view returns (uint256) {
        if (duty == 0) {
            return RAY;
        }
        if (lastUpdate == block.timestamp) {
            return rate;
        }
        return hMath.rmul(hMath.rpow(duty, block.timestamp - lastUpdate, hMath.ONE), rate);
    }

    /**
     * @dev set duty
     * @param _duty duty
     */
    function setDuty(uint256 _duty) external update onlyRole(MANAGER) {
        require(_duty <= MAX_DUTY, "duty cannot exceed max duty");

        duty = _duty;
        emit SetDuty(_duty);
    }

    /**
     * @dev set max duty
     * @param _maxDuty max duty
     */
    function setMaxDuty(uint256 _maxDuty) external onlyRole(MANAGER) {
        MAX_DUTY = _maxDuty;
        emit SetMaxDuty(_maxDuty);
    }


    /**
     * @dev emergency withdraw all lisUSD
     */
    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(lisUSD).safeTransfer(msg.sender, IERC20(lisUSD).balanceOf(address(this)));
    }

    /**
     * @dev set earn pool
     * @param _earnPool earn pool address
     */
    function setEarnPool(address _earnPool) external onlyRole(MANAGER) {
        require(_earnPool != address(0), "earnPool cannot be zero address");
        require(!earnPool[_earnPool], "earnPool already exists");
        earnPool[_earnPool] = true;
    }

    /**
     * @dev remove earn pool
     */
    function removeEarnPool(address _earnPool) external onlyRole(MANAGER) {
       delete earnPool[_earnPool];
    }


    /**
     * @dev pause contract
     */
    function pause() external onlyRole(PAUSE) {
        _pause();
    }

    /**
     * @dev toggle pause contract
     */
    function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }

    /**
     * @dev take snapshot of user's LisUSD staking amount
     * @param user user address
     * @param pool pool address
     */
    function takeSnapshot(address user, address pool) private {
        address stakeLisUSDListaDistributor = listaDistributors[pool];
        // ensure the distributor address is set
        if (stakeLisUSDListaDistributor != address(0)) {
            IStakeLisUSDListaDistributor(stakeLisUSDListaDistributor).takeSnapshot(user, poolBalanceOf[pool][user]);
        }
    }

    /**
   * @dev set distributor address
     * @param _distributor distributor address
     */
    function setListaDistributor(address pool, address _distributor) external onlyRole(MANAGER) {
        require(_distributor != address(0), "distributor cannot be zero address");
        require(listaDistributors[pool] == address(0), "distributor already exists");

        listaDistributors[pool] = _distributor;

        emit SetStakeLisUSDListaDistributor(_distributor);
    }

    /**
     * @dev remove distributor address
     * @param pool pool address
     */
    function removeListaDistributor(address pool) external onlyRole(MANAGER) {
        delete listaDistributors[pool];
    }
}