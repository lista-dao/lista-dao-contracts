// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// interface IFactory {
//     function admin() external view returns (address);
// }

// LP Token with rewards capability for http://ellipsis.finance/
// ERC20 that represents a deposit into an Ellipsis pool and allows 3rd-party incentives for token holders
// Based on SNX MultiRewards by iamdefinitelyahuman - https://github.com/iamdefinitelyahuman/multi-rewards
contract RewardsToken is ReentrancyGuard {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    string public symbol;
    string public name;
    uint256 public constant decimals = 18;
    uint256 public totalSupply;
    uint256 public rewardCount;

    address public minter;
    // IFactory public factory;

    address public owner; // Not in Elipsis

    struct Reward {
        address rewardsDistributor;
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }
    mapping(address => Reward) public rewardData;
    address[] public rewardTokens;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public depositedBalanceOf;

    mapping(address => bool) public depositContracts;

    // owner -> spender -> amount
    mapping(address => mapping(address => uint256)) public allowance;

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event RewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
    event RewardsDurationUpdated(address token, uint256 newDuration);
    event Recovered(address token, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /* ========== CONSTRUCTOR ========== */

    constructor() {
        // prevent the implementation contract from being used as a token
        // minter = address(31337);
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        address _minter,
        address _owner // Not in Elipsis
    )
        external
    {
        require(minter == address(0));
        name = _name;
        symbol = _symbol;
        minter = _minter;
        owner = _owner; // Not in Elipsis
        // factory = IFactory(msg.sender);
        emit Transfer(address(0), _minter, 0);

        // hardcode the EPSv2 staking contract as a deposit contract
        // depositContracts[0x5B74C99AA2356B4eAa7B85dC486843eDff8Dfdbe] = true;
    }

    /* ========== ADMIN FUNCTIONS ========== */

    function addReward(
        address _rewardsToken,
        address _rewardsDistributor,
        uint256 _rewardsDuration
    )
        public
        onlyOwner
    {
        require(_rewardsToken != address(this), "Cannot use token as own reward");
        require(rewardData[_rewardsToken].rewardsDuration == 0, "Already is a reward");

        // test transfer of 0 tokens to validate that `_rewardsToken` is an ERC20
        IERC20(_rewardsToken).safeTransfer(msg.sender, 0);

        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        rewardCount++;
    }

    function setRewardsDistributor(address _rewardsToken, address _rewardsDistributor) external onlyOwner {
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
    }

    function setDepositContract(address _account, bool _isDepositContract) external onlyOwner {
        require(balanceOf[_account] == 0, "Address has a balance");
        depositContracts[_account] = _isDepositContract;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOwner() {
        // admin functions are unguarded before setting the minter
        // so the pool can configure the token prior to token initialization
        require(minter == address(0) || msg.sender == owner);
        _;
    }

    modifier updateReward(address payable[2] memory accounts) {
        for (uint i; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            for (uint x = 0; x < accounts.length; x++) {
                address account = accounts[x];
                if (account == address(0)) break;
                if (depositContracts[account]) continue;
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardData[token].rewardPerTokenStored;
            }
        }
        _;
    }

    /* ========== VIEWS ========== */

    // function owner() public view returns (address) {
    //     //return factory.admin();
    // }

    function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256) {
        return Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function rewardPerToken(address _rewardsToken) public view returns (uint256) {
        Reward storage reward = rewardData[_rewardsToken];
        if (totalSupply == 0) {
            return reward.rewardPerTokenStored;
        }
        uint256 last = lastTimeRewardApplicable(_rewardsToken);
        return reward.rewardPerTokenStored.add(
            last.sub(reward.lastUpdateTime).mul(reward.rewardRate).mul(1e18).div(totalSupply)
        );
    }

    function earned(address account, address _rewardsToken) public view returns (uint256) {
        if (depositContracts[account]) return 0;
        uint256 balance = balanceOf[account].add(depositedBalanceOf[account]);
        uint256 perToken = rewardPerToken(_rewardsToken).sub(userRewardPerTokenPaid[account][_rewardsToken]);
        return balance.mul(perToken).div(1e18).add(rewards[account][_rewardsToken]);
    }

    function getRewardForDuration(address _rewardsToken) external view returns (uint256) {
        return rewardData[_rewardsToken].rewardRate.mul(rewardData[_rewardsToken].rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /** shared logic for transfer and transferFrom */
    function _transfer(
        address payable _from,
        address payable _to,
        uint256 _value
    )
        internal
        updateReward([_from, _to])
    {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        balanceOf[_from] = balanceOf[_from].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);

        if (depositContracts[_from]) {
            require(!depositContracts[_to], "Cannot transfer between deposit contracts");
            require(_from == msg.sender, "Cannot use transferFrom on a deposit contract");
            depositedBalanceOf[_to] = depositedBalanceOf[_to].sub(_value);
        } else if (depositContracts[_to]) {
            require(_to == msg.sender, "Deposit contract must call transferFrom to receive tokens");
            depositedBalanceOf[_from] = depositedBalanceOf[_from].add(_value);
        }
        emit Transfer(_from, _to, _value);
    }

    function transfer(address payable _to, uint256 _value) public returns (bool) {
        _transfer(payable(msg.sender), _to, _value);
        return true;
    }

    function transferFrom(
        address payable _from,
        address payable _to,
        uint256 _value
    )
        public
        returns (bool)
    {
        uint256 allowed = allowance[_from][msg.sender];
        require(allowed >= _value, "Insufficient allowance");
        if (allowed != type(uint256).max) {
            allowance[_from][msg.sender] = allowed.sub(_value);
        }
        _transfer(_from, _to, _value);
        return true;
    }

    function getReward() public nonReentrant updateReward([payable(msg.sender), payable(address(0))]) {
        for (uint i; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                IERC20(_rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardsToken, reward);
            }
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(
        address _rewardsToken,
        uint256 reward
    )
        external
        updateReward([payable(address(0)), payable(address(0))])
    {
        require(rewardData[_rewardsToken].rewardsDistributor == msg.sender, "Not a distibutor");
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(_rewardsToken).safeTransferFrom(msg.sender, address(this), reward);

        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate = reward.div(rewardData[_rewardsToken].rewardsDuration);
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardData[_rewardsToken].rewardRate);
            rewardData[_rewardsToken].rewardRate = reward.add(leftover).div(rewardData[_rewardsToken].rewardsDuration);
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp.add(rewardData[_rewardsToken].rewardsDuration);
        emit RewardAdded(reward);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(rewardData[tokenAddress].lastUpdateTime == 0, "Cannot withdraw reward token");
        IERC20(tokenAddress).safeTransfer(msg.sender, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(address _rewardsToken, uint256 _rewardsDuration) external {
        require(
            block.timestamp > rewardData[_rewardsToken].periodFinish,
            "Reward period still active"
        );
        require(rewardData[_rewardsToken].rewardsDistributor == msg.sender);
        require(_rewardsDuration > 0, "Reward duration must be non-zero");
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(_rewardsToken, rewardData[_rewardsToken].rewardsDuration);
    }

    function mint(
        address payable _to,
        uint256 _value
    )
        external
        updateReward([payable(_to), payable(address(0))])
        returns (bool)
    {
        require(msg.sender == minter);
        balanceOf[_to] = balanceOf[_to].add(_value);
        totalSupply = totalSupply.add(_value);
        emit Transfer(address(0), _to, _value);
        return true;
    }

    function burnFrom(
        address payable _to,
        uint256 _value
    )
        external
        updateReward([payable(_to), payable(address(0))])
        returns (bool)
    {
        require(msg.sender == minter);
        balanceOf[_to] = balanceOf[_to].sub(_value);
        totalSupply = totalSupply.sub(_value);
        emit Transfer(_to, address(0), _value);
        return true;
    }
}