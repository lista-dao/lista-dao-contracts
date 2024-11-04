pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../hMath.sol";
import "../interfaces/IStakeLisUSDListaDistributor.sol";
import "../interfaces/VatLike.sol";

contract LisUSDPoolSet is AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    struct Pool {
        address asset;
        address distributor;
        bool active;
    }

    address public lisUSD; // lisUSD address

    string public name; // pool name
    string public symbol; // pool symbol
    mapping(address => uint256) public balanceOf; // user's share
    uint256 public totalSupply; // total shares

    // pool => user => emission weights
    mapping(address => mapping(address => uint256)) public poolEmissionWeights;
    // user => emission weights
    mapping(address => uint256) public totalUserEmissionWeights;
    // pool => emission weights
    mapping(address => uint256) public totalAssetEmissionWeights;
    // pool => pool info
    mapping(address => Pool) public pools;

    uint256 public rate; // share to lisUSD rate when last update
    uint256 public lastUpdate; // last rate update time
    uint256 public duty; // interest rate per second
    uint256 public maxDuty; // max interest rate per second
    address public earnPool; // earn pool address
    uint256 public maxAmount; // max assets amount

    bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role
    bytes32 public constant PAUSER = keccak256("PAUSER"); // pause role
    uint256 constant public RATE_SCALE = 10**27;

    event Withdraw(address account, uint256 amount);
    event Deposit(address account, uint256 amount);
    event SetDuty(uint256 duty);
    event SetMaxDuty(uint256 maxDuty);
    event RegisterPool(address pool, address asset, address distributor);
    event RemovePool(address pool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event EmergencyWithdraw(address token, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyEarnPool() {
        require(earnPool == msg.sender, "only earnPool can call this function");
        _;
    }

    /**
     * @dev initialize contract
     * @param _admin admin address
     * @param _manager manager address
     * @param _lisUSD lisUSD address
     * @param _maxDuty max rate per second
     */
    function initialize(
        address _admin,
        address _manager,
        address _lisUSD,
        uint256 _maxDuty
    ) public initializer {
        require(_admin != address(0), "admin cannot be zero address");
        require(_manager != address(0), "manager cannot be zero address");
        require(_lisUSD != address(0), "lisUSD cannot be zero address");

        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MANAGER, _manager);

        lisUSD = _lisUSD;

        name = "lisUSD single staking Pool";
        symbol = "sLisUSD";
        maxDuty = _maxDuty;

        rate = RATE_SCALE;
        lastUpdate = block.timestamp;
        duty = RATE_SCALE;

        emit SetMaxDuty(_maxDuty);
    }

    /**
     * @dev withdraw lisUSD
     * @param _pools pools address
     * @param amount amount to withdraw
     */
    function withdraw(address[] memory _pools, uint256 amount) public update nonReentrant whenNotPaused {
        address account = msg.sender;
        require(amount > 0, "amount cannot be zero");

        uint256 share = convertToShares(amount);
        if (share * getRate() < amount * RATE_SCALE) {
            share += 1;
        }

        require(share <= balanceOf[account], "insufficient balance");

        // update shares
        balanceOf[account] -= share;
        totalSupply -= share;

        uint256 costWeight;

        // update pool balance
        uint256 remain = amount;
        for (uint i = 0; i < _pools.length; i++) {
            uint256 poolBalance = poolEmissionWeights[_pools[i]][account];
            if (poolBalance >= remain) {
                costWeight += remain;
                poolEmissionWeights[_pools[i]][account] -= remain;
                totalAssetEmissionWeights[_pools[i]] -= remain;
                takeSnapshot(account, _pools[i]);
                break;
            } else {
                costWeight += poolBalance;
                remain -= poolBalance;
                poolEmissionWeights[_pools[i]][account] = 0;
                totalAssetEmissionWeights[_pools[i]] -= poolBalance;
                takeSnapshot(account, _pools[i]);
            }
        }
        uint256 totalWeights = totalUserEmissionWeights[account];
        totalUserEmissionWeights[account] -= costWeight;
        require(
            (amount > totalWeights && costWeight == totalWeights) ||
            (amount <= totalWeights && costWeight == amount),
            "pool balance should be deducted first"
        );

        // transfer lisUSD to account
        require(IERC20(lisUSD).balanceOf(address(this)) >= amount, "not enough balance");
        IERC20(lisUSD).safeTransfer(account, amount);

        emit Transfer(account, address(0), share);
        emit Withdraw(account, amount);
    }


    /**
     * @dev get user's assets
     * @param account account address
     */
    function assetBalanceOf(address account) public view returns (uint256) {
        return convertToAssets(balanceOf[account]);
    }

    /**
     * @dev get total lisUSD assets
     */
    function totalAssets() public view returns (uint256) {
        return convertToAssets(totalSupply);
    }

    /**
     * @dev deposit lisUSD
     * @param account account address
     * @param amount amount to deposit
     */
    function depositFor(address pool, address account, uint256 amount) external onlyEarnPool nonReentrant whenNotPaused {
        _depositFor(msg.sender, pool, account, amount);
    }

    /**
     * @dev deposit lisUSD
     * @param amount amount to deposit
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        _depositFor(msg.sender, lisUSD, msg.sender, amount);

    }

    function _depositFor(address sender, address pool, address account, uint256 amount) private update {
        require(amount > 0, "amount cannot be zero");
        require(totalAssets() + amount <= maxAmount, "exceed max amount");
        require(pools[pool].active, "pool not active");
        // transfer lisUSD to pool
        IERC20(lisUSD).safeTransferFrom(sender, address(this), amount);

        // update shares and pool balance
        uint256 share = convertToShares(amount);
        balanceOf[account] += share;
        totalSupply += share;
        poolEmissionWeights[pool][account] += amount;
        totalUserEmissionWeights[account] += amount;
        totalAssetEmissionWeights[pool] += amount;

        takeSnapshot(account, pool);

        emit Transfer(address(0), account, share);
        emit Deposit(account, amount);
    }

    /**
     * @dev share to asset
     * @param share share
     */
    function convertToAssets(uint256 share) public view returns (uint256) {
        return Math.mulDiv(share, getRate(), RATE_SCALE);
    }

    /**
     * @dev asset to share
     * @param asset balance
     */
    function convertToShares(uint256 asset) public view returns (uint256) {
        return Math.mulDiv(asset, RATE_SCALE, getRate());
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
            return RATE_SCALE;
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
    function setDuty(uint256 _duty) public update onlyRole(MANAGER) {
        require(_duty <= maxDuty, "duty cannot exceed max duty");

        duty = _duty;
        emit SetDuty(_duty);
    }

    /**
     * @dev set max duty
     * @param _maxDuty max duty
     */
    function setMaxDuty(uint256 _maxDuty) external onlyRole(MANAGER) {
        maxDuty = _maxDuty;
        emit SetMaxDuty(_maxDuty);
    }


    /**
      * @dev allows admin to withdraw tokens for emergency or recover any other mistaken tokens.
      * @param _token token address
      * @param _amount token amount
    */
    function emergencyWithdraw(address _token, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_token == address(0)) {
            (bool success, ) = payable(msg.sender).call{ value: _amount }("");
            require(success, "Withdraw failed");
        } else {
            IERC20(_token).safeTransfer(msg.sender, _amount);
        }
        emit EmergencyWithdraw(_token, _amount);
    }
    /**
     * @dev set earn pool
     * @param _earnPool earn pool address
     */
    function setEarnPool(address _earnPool) external onlyRole(MANAGER) {
        require(_earnPool != address(0), "earnPool cannot be zero address");
        earnPool = _earnPool;
    }


    /**
     * @dev pause contract
     */
    function pause() external onlyRole(PAUSER) {
        _pause();
    }

    /**
     * @dev unpause contract
     */
    function unpause() external onlyRole(MANAGER) {
        _unpause();
    }

    /**
     * @dev take snapshot of user's LisUSD staking amount
     * @param user user address
     * @param pool pool address
     */
    function takeSnapshot(address user, address pool) private {
        address distributor = pools[pool].distributor;
        // ensure the distributor address is set
        if (distributor != address(0)) {
            IStakeLisUSDListaDistributor(distributor).takeSnapshot(user, poolEmissionWeights[pool][user]);
        }
    }

    function setDistributor(address pool, address _distributor) external onlyRole(MANAGER) {
        require(_distributor != address(0), "distributor cannot be zero address");
        require(pools[pool].distributor == address(0), "distributor already exists");

        pools[pool].distributor = _distributor;
    }

    /**
     * @dev remove distributor address
     * @param pool pool address
     */
    function removeDistributor(address pool) external onlyRole(MANAGER) {
        pools[pool].distributor = address(0);
    }

    /**
     * @dev register pool
     * @param pool pool address
     * @param asset asset address
     * @param distributor distributor address
     */
    function registerPool(address pool, address asset, address distributor) public onlyRole(MANAGER) {
        require(pool != address(0), "pool cannot be zero address");
        require(asset != address(0), "asset cannot be zero address");
        require(!pools[pool].active, "pool already exists");

        pools[pool] = Pool({
            asset: asset,
            distributor: distributor,
            active: true
        });

        emit RegisterPool(pool, asset, distributor);
    }

    /**
     * @dev remove pool
     * @param pool pool address
     */
    function removePool(address pool) external onlyRole(MANAGER) {
        require(pools[pool].active, "pool not exists");

        pools[pool].active = false;

        emit RemovePool(pool);
    }

    /**
     * @dev set max amount
     * @param _maxAmount max amount
     */
    function setMaxAmount(uint256 _maxAmount) external onlyRole(MANAGER) {
        maxAmount = _maxAmount;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}