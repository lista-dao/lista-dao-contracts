// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./hMath.sol";

import "hardhat/console.sol";

interface VatLike {
    function ilks(bytes32) external view returns (
        uint256 Art,   // [wad]
        uint256 rate   // [ray]
    );
    function urns(bytes32, address) external view  returns (
        uint256 ink,   // [wad]
        uint256 art   // [ray]
    );
    function fold(bytes32,address,int) external;
}

interface MCDOracle {
    function peek() external view returns (bytes32, bool);
}

interface Mintable {
    function mint(address _to, uint256 _amount) external returns(bool);
}

contract HelioRewards {
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
    uint256 constant ONE = 10 ** 27; // ray
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

    event Claimed(address indexed user, uint256 amount);


    struct Pile {
        uint256 amount;
        uint256 ts;
    }

    mapping (address => mapping(address => Pile)) public piles; // usr => token(collateral type) => time last realise

    mapping (address => uint256) public claimedRewards;
    mapping (address => Ilk) public pools;
    address[] public poolsList;

    VatLike                  public vat; // CDP engine
    address public helioToken;
    MCDOracle public oracle;

    uint256 public rewardsPool;

    constructor(address vat_) {
        live = 1;
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
    }

    function stop() public auth {
        live = 0;
    }

    function initPool(address token, bytes32 ilk, uint256 rate) external auth {
        pools[token] = Ilk(rate, block.timestamp, ilk);
        poolsList.push(token);
    }

    function setHelioToken(address helioToken_) external auth {
        helioToken = helioToken_;
    }

    function setOracle(address oracle_) external auth {
        oracle = MCDOracle(oracle_);
    }

    function setRate(address token, uint256 newRate) external auth {
        Ilk storage pool = pools[token];
        pool.rewardRate = newRate;
    }

    // 1 USB is helioPrice() helios
    function helioPrice() public view returns(uint256) {
        (bytes32 price, bool has) = oracle.peek();
        if (has) {
            return uint256(price);
        } else {
            return 0;
        }
    }

    function rate(address token) public view returns(uint256) {
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
        Pile storage pile = piles[usr][token];

        pile.amount += unrealisedRewards(token, usr);
        pile.ts = block.timestamp;
    }

    function unrealisedRewards(address token, address usr) public poolInit(token) view returns(uint256) {
        bytes32 poolIlk = pools[token].ilk;
        (, uint256 usrDebt) = vat.urns(poolIlk, usr);
        uint256 last = piles[usr][token].ts;
        if (last == 0) {
            return 0;
        }
        uint256 rate = hMath.rpow(pools[token].rewardRate, block.timestamp - last, ONE);
        uint256 rewards = hMath.mulDiv(rate, usrDebt, 10 ** 27) - usrDebt; //$ amount
        return hMath.mulDiv(rewards, helioPrice(), 10 ** 18); //helio tokens
    }

    function claim(uint256 amount) external {
        require(amount <= pendingRewards(msg.sender), "Rewards/not-enough-rewards");
        uint256 i = 0;
        while (i < poolsList.length) {
            drop(poolsList[i], msg.sender);
            i++;
        }
        claimedRewards[msg.sender] += amount;
        Mintable(helioToken).mint(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }
}