// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./hMath.sol";
import "./oracle/libraries/FullMath.sol";

import "./interfaces/VatLike.sol";
import "./interfaces/IRewards.sol";
import "./interfaces/PipLike.sol";


contract HelioRewards is IRewards, OwnableUpgradeable {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external auth { require(live == 1, "Rewards/not-live"); wards[usr] = 1; }
    function deny(address usr) external auth { require(live == 1, "Rewards/not-live"); wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "Rewards/not-authorized");
        _;
    }

    uint256 constant YEAR = 365 * 24 * 3600; //seconds
    uint256 constant RAD = 10 ** 18; // ray
    uint256 constant ONE = 10 ** 27; // wad
    uint256 public live;  // Active Flag

    // --- Data ---
    struct Ilk {
        uint256 rewardRate;  // Collateral-specific, per-second reward rate [ray]
        uint256 rho;  // Time of last drip [unix epoch time]
        bytes32 ilk;
    }

    modifier poolInit(address token) {
        require(pools[token].rho != 0, "Reward/pool-not-init");
        _;
    }

    struct Pile {
        uint256 amount;
        uint256 ts;
    }

    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping (address => mapping(address => Pile)) public piles; // usr => token(collateral type) => time last realise
    mapping (address => uint256) public claimedRewards;
    mapping (address => Ilk) public pools;
    address[] public poolsList;

    VatLike                  public vat; // CDP engine
    address public helioToken;
    PipLike public oracle;

    uint256 public rewardsPool;
    uint256 public poolLimit;

    function initialize(address vat_, uint256 poolLimit_ ) public initializer {
        __Ownable_init();

        live = 1;
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        poolLimit = poolLimit_;
    }

    function stop() public auth {
        live = 0;

        emit Stop(msg.sender);
    }

    function start() public auth {
        live = 1;

        emit Start(msg.sender);
    }

    function initPool(address token, bytes32 ilk, uint256 rate) external auth {
        require(IERC20Upgradeable(helioToken).balanceOf(address(this)) >= poolLimit, "Reward/not-enough-reward-token");
        require(pools[token].rho == 0, "Reward/pool-existed");
        require(token != address(0), "Reward/invalid-token");
        pools[token] = Ilk(rate, block.timestamp, ilk);
        poolsList.push(token);

        emit PoolInited(token, rate);
    }

    function setHelioToken(address helioToken_) external auth {
        require(helioToken_ != address(0), "Reward/invalid-token");
        helioToken = helioToken_;

        emit HelioTokenChanged(helioToken);
    }

    function setRewardsMaxLimit(uint256 newLimit) external auth {
        require(IERC20Upgradeable(helioToken).balanceOf(address(this)) >= newLimit, "Reward/not-enough-reward-token");
        poolLimit = newLimit;

        emit RewardsLimitChanged(poolLimit);
    }

    function setOracle(address oracle_) external auth {
        require(oracle_ != address(0), "Reward/invalid-oracle");
        oracle = PipLike(oracle_);

        emit HelioOracleChanged(address(oracle));
    }

    function setRate(address token, uint256 newRate) external auth {
        require(pools[token].rho == 0, "Reward/pool-existed");
        require(token != address(0), "Reward/invalid-token");
        require(newRate >= ONE, "Reward/negative-rate");
        require(newRate < 2 * ONE, "Reward/high-rate");
        Ilk storage pool = pools[token];
        pool.rewardRate = newRate;

        emit RateChanged(token, newRate);
    }

    // 1 HAY is helioPrice() helios
    function helioPrice() public view returns(uint256) {
        (bytes32 price, bool has) = oracle.peek();
        if (has) {
            return uint256(price);
        } else {
            return 0;
        }
    }

    function rewardsRate(address token) public view returns(uint256) {
        return pools[token].rewardRate;
    }

    // Yearly api in percents with 18 decimals
    function distributionApy(address token) public view returns(uint256) {
        return (hMath.rpow(pools[token].rewardRate, YEAR, ONE) - ONE) / 10 ** 7;
    }
//
    function claimable(address token, address usr) public poolInit(token) view returns (uint256) {
        return piles[usr][token].amount + unrealisedRewards(token, usr);
    }

    function pendingRewards(address usr) public view returns(uint256) {
        uint256 i = 0;
        uint256 acc = 0;
        while (i < poolsList.length) {
            acc += claimable(poolsList[i], usr);
            i++;
        }
        return acc - claimedRewards[usr];
    }

    //drop unrealised rewards
    function drop(address token, address usr) public {
        if (pools[token].rho == 0) {
            // No pool for this token — skip rewards
            return;
        }
        Pile storage pile = piles[usr][token];

        pile.amount += unrealisedRewards(token, usr);
        pile.ts = block.timestamp;
    }

    function unrealisedRewards(address token, address usr) public poolInit(token) view returns(uint256) {
        if (pools[token].rho == 0) {
            // No pool for this token
            return 0;
        }
        bytes32 poolIlk = pools[token].ilk;
        (, uint256 usrDebt) = vat.urns(poolIlk, usr);
        uint256 last = piles[usr][token].ts;
        if (last == 0) {
            return 0;
        }
        uint256 rate = hMath.rpow(pools[token].rewardRate, block.timestamp - last, ONE);
        uint256 rewards = FullMath.mulDiv(rate, usrDebt, 10 ** 27) - usrDebt; //$ amount
        return FullMath.mulDiv(rewards, helioPrice(), 10 ** 18); //helio tokens
    }

    function claim(uint256 amount) external {
        require(amount <= pendingRewards(msg.sender), "Rewards/not-enough-rewards");
        require(poolLimit >= amount, "Rewards/rewards-limit-exceeded");
        uint256 i = 0;
        while (i < poolsList.length) {
            drop(poolsList[i], msg.sender);
            i++;
        }
        claimedRewards[msg.sender] += amount;
        IERC20Upgradeable(helioToken).safeTransfer(msg.sender, amount);

        poolLimit -= amount;
        emit Claimed(msg.sender, amount);
    }
}
