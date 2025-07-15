// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../../interfaces/IUniswapV3Factory.sol";
import "../../interfaces/IUniswapV3Pool.sol";
import "../../interfaces/IMasterChefV3.sol";
import "../../interfaces/INonfungiblePositionManager.sol";
import "../../../oracle/interfaces/IResilientOracle.sol";
import "../../interfaces/IDao.sol";
import "../../interfaces/ILpUsd.sol";
import "../../interfaces/IPancakeSwapV3LpStakingHub.sol";
import "../../interfaces/IPancakeSwapV3LpProvider.sol";
import "../../interfaces/IPancakeSwapV3LpStakingVault.sol";
import "../../../libraries/TickMath.sol";
import "../../../libraries/LiquidityAmounts.sol";

/// @title PancakeSwapV3LpProvider
/// @author ListaDAO
/// @notice This contract allows user to lend LisUSD from the ListaDAO CDP by depositing PancakeSwap V3 LP tokens
contract PancakeSwapV3LpProvider is
IPancakeSwapV3LpProvider,
PausableUpgradeable,
ReentrancyGuardUpgradeable,
AccessControlEnumerableUpgradeable,
UUPSUpgradeable,
IERC721Receiver
{
  using SafeERC20 for IERC20;
  using SafeERC20 for ILpUsd;

  /// @dev ROLES
  bytes32 public constant MANAGER = keccak256("MANAGER");
  bytes32 public constant BOT = keccak256("BOT");
  bytes32 public constant PAUSER = keccak256("PAUSER");

  /// @dev STATE VARIABLES
  // ListaDAO cdp address
  address public immutable cdp;
  // PancakeSwap NonFungiblePositionManager address
  address public immutable nonFungiblePositionManager;
  // PancakeSwap V3 Pool Factory
  address public immutable pancakeV3Factory;
  // MasterChefV3 address
  address public immutable masterChefV3;
  // token0 address of the LP token
  address public immutable token0;
  // token1 address of the LP token
  address public immutable token1;
  // CAKE token address
  address public immutable rewardToken;
  // name of the provider
  string public name;
  // an ERC20 token as the collateral in the CDP
  // this token is minted when user deposit LP to the provider
  address public immutable lpUsd;
  // PancakeStakingHub address
  address public pancakeStakingHub;
  // pancakeSwapLpStakingVault address
  address public pancakeLpStakingVault;
  // resilient oracle address
  address public resilientOracle;
  // DENOMINATOR of lpExchangeRate
  uint256 public constant DENOMINATOR = 10000;

  // tokenId => owner
  mapping(uint256 => address) public lpOwners;
  // user => owned tokenIds
  mapping(address => uint256[]) public userLps;
  // tokenId -> appraised value in USD
  mapping(uint256 => uint256) public lpValues;
  // user => user's total appraised value of all LPs
  mapping(address => uint256) public userTotalLpValue;
  // user => liquidated LPs
  mapping(address => LiquidatedLp) public userLiquidatedLps;

  // the max. number of LPs a user can deposit
  uint256 public maxLpPerUser;
  // the minimum appraised value in USD of an LP to be accepted
  // the appraised value in USD must equals to or higher than this when user depositing LP
  uint256 public minLpValue;
  // When user deposit LP to the provider,
  // a amount of LP_USD(ERC20) equals to the appraised USD value of the LP will be minted and deposit to the cdp
  // 0 <= lpExchangeRate <= EXCHANGE_RATE_DENOMINATOR
  uint256 public lpExchangeRate;

  /// @dev MODIFIERS
  modifier onlyCdp() {
    require(msg.sender == cdp, "PancakeSwapV3LpProvider: caller-only-cdp");
    _;
  }

  modifier onlyPancakeStakingHub() {
    require(msg.sender == pancakeStakingHub, "PancakeSwapV3LpProvider: caller-only-pancakeStakingHub");
    _;
  }

  modifier onlyStakingVault() {
    require(
      msg.sender == pancakeLpStakingVault,
      "PancakeSwapStakingHub: only-staking-vault"
    );
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor(
    address _cdp,
    address _nonFungiblePositionManager,
    address _pancakeV3Factory,
    address _masterChefV3,
    address _lpUsd,
    address _token0,
    address _token1,
    address _rewardToken
  ) {
    require(
      _cdp != address(0) &&
      _nonFungiblePositionManager != address(0) &&
      _pancakeV3Factory != address(0) &&
      _masterChefV3 != address(0) &&
      _lpUsd != address(0) &&
      _token0 != address(0) &&
      _token1 != address(0) &&
      _rewardToken != address(0),
      "zero address provided"
    );
    cdp = _cdp;
    nonFungiblePositionManager = _nonFungiblePositionManager;
    pancakeV3Factory = _pancakeV3Factory;
    masterChefV3 = _masterChefV3;
    lpUsd = _lpUsd;
    token0 = _token0;
    token1 = _token1;
    rewardToken = _rewardToken;

    _disableInitializers();
  }

  /**
    * @dev initialize contract
    * @param _admin admin address
    * @param _manager manager address
    * @param _bot bot address
    * @param _pauser pauser address
    * @param _pancakeStakingHub PancakeStakingHub address
    * @param _maxLpPerUser max LPs per user
    * @param _minLpValue minimum LP value in USD
    * @param _lpExchangeRate exchange rate of LP in USD
    */
  function initialize(
    address _admin,
    address _manager,
    address _bot,
    address _pauser,
    address _pancakeStakingHub,
    address _pancakeStakingVault,
    address _resilientOracle,
    uint256 _maxLpPerUser,
    uint256 _minLpValue,
    uint256 _lpExchangeRate
  ) public initializer {
    require(
      _admin != address(0) &&
      _manager != address(0) &&
      _bot != address(0) &&
      _pauser != address(0) &&
      _pancakeStakingHub != address(0) &&
      _pancakeStakingVault != address(0) &&
      _resilientOracle != address(0),
      "zero address provided"
    );
    require(_maxLpPerUser > 0, "invalid maxLpPerUser value");
    require(_minLpValue > 0, "invalid minLpValue value");
    require(_lpExchangeRate <= DENOMINATOR, "invalid lpExchangeRate value");

    __AccessControlEnumerable_init();
    __Pausable_init();
    __ReentrancyGuard_init();
    // grant roles
    grantRole(DEFAULT_ADMIN_ROLE, _admin);
    grantRole(MANAGER, _manager);
    grantRole(BOT, _bot);
    grantRole(PAUSER, _pauser);
    // init state variables
    pancakeStakingHub = _pancakeStakingHub;
    pancakeLpStakingVault = _pancakeStakingVault;
    resilientOracle = _resilientOracle;
    maxLpPerUser = _maxLpPerUser;
    minLpValue = _minLpValue;
    lpExchangeRate = _lpExchangeRate;

    // set provider name
    string memory token0Name = IERC20Metadata(token0).symbol();
    string memory token1Name = IERC20Metadata(token1).symbol();
    name = string(abi.encodePacked("Lista-PancakeSwap ", token0Name, "-", token1Name, " V3 LP Provider"));
  }


  ///////////////////////////////////////////////////////////////
  ////////////           External Functions          ////////////
  ///////////////////////////////////////////////////////////////

  /**
   * @dev deposit LP token to the provider
   *      this will transfer the LP token to the provider and mint LP_USD to the user
   * @param tokenId the tokenId of the LP token
   */
  function provide(uint256 tokenId) override external nonReentrant whenNotPaused {
    require(IERC721(nonFungiblePositionManager).ownerOf(tokenId) == msg.sender, "PancakeSwapV3LpProvider: Not owner of token");
    // transfer user's LP token to this contract
    IERC721(nonFungiblePositionManager).safeTransferFrom(msg.sender, address(this), tokenId);
  }

  /**
    * @dev release LP token from the provider
    *      this will transfer the LP token back to the user and burn LP_USD
    * @param tokenId the tokenId of the LP token
    */
  function release(uint256 tokenId) override external nonReentrant whenNotPaused {
    // check if the caller is the owner of the LP token
    require(lpOwners[tokenId] == msg.sender, "PancakeSwapV3LpProvider: not-token-owner");
    // set lp value to zero
    lpValues[tokenId] = 0;
    // remove it from userLps
    uint256[] storage userLpTokens = userLps[msg.sender];
    for (uint256 i = 0; i < userLpTokens.length; i++) {
      if (userLpTokens[i] == tokenId) {
        userLpTokens[i] = userLpTokens[userLpTokens.length - 1];
        userLpTokens.pop();
        break;
      }
    }
    // sync user position
    _syncUserCdpPosition(msg.sender, false);
    // withdraw from Staking Hub with the harvested rewards
    uint256 rewardAmount = IPancakeSwapV3LpStakingHub(pancakeStakingHub).withdraw(tokenId);
    // send reward and cut fee
    sendRewardWithFeeCut(rewardAmount, msg.sender);
    // transfer LP token back to the user
    IERC721(nonFungiblePositionManager).safeTransferFrom(address(this), msg.sender, tokenId);

    emit WithdrawLp(msg.sender, tokenId, lpValues[tokenId]);
  }

  /**
    * @dev Harvest function to claim rewards from PancakeSwap Staking Hub
    */
  function vaultClaimStakingReward(address account) override external nonReentrant whenNotPaused onlyStakingVault returns (uint256 totalReward) {
    // harvest rewards for all user Lp tokens
    totalReward = 0;
    uint256[] storage userLpTokens = userLps[account];
    require(userLpTokens.length > 0, "PancakeSwapV3LpProvider: no-lp-tokens");
    for (uint256 i = 0; i < userLpTokens.length; i++) {
      uint256 tokenId = userLpTokens[i];
      // harvest rewards from PancakeStakingHub
      totalReward += IPancakeSwapV3LpStakingHub(pancakeStakingHub).harvest(tokenId);
    }
    // send rewards to vault
    if (totalReward > 0) {
      IERC20(rewardToken).safeTransfer(pancakeLpStakingVault, totalReward);
    }
  }

  /**
    * @dev Sync LP values for multiple tokenId
    * @param tokenIds array of tokenIds to sync
    */
  function syncLpValues(uint256[] calldata tokenIds) override external nonReentrant whenNotPaused onlyRole(BOT) {
    require(tokenIds.length > 0, "No tokenIds provided");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      address owner = lpOwners[tokenId];
      // verify does it exist
      require(owner != address(0), "PancakeSwapV3LpProvider: invalid-tokenId");
      // update lpValues
      _syncLpValue(tokenId);
      // sync user position
      _syncUserCdpPosition(owner, false);
    }
  }

  /**
    * @dev Sync user LP values
    *      this will alter user's CDP position
    * @param user the address of the user
    */
  function syncUserLpValues(address user) override external nonReentrant whenNotPaused onlyRole(BOT) {
    require(user != address(0), "PancakeSwapV3LpProvider: invalid-user");
    // sync user position
    _syncUserCdpPosition(user, true);
  }


  /**
    * @dev Batch sync user LP values
    *      this will alter users' CDP position
    * @param users array of user addresses
    */
  function batchSyncUserLpValues(address[] calldata users) override external nonReentrant whenNotPaused onlyRole(BOT) {
    require(users.length > 0, "No users provided");
    for (uint256 i = 0; i < users.length; i++) {
      address user = users[i];
      require(user != address(0), "PancakeSwapV3LpProvider: invalid-user");
      // sync user position
      _syncUserCdpPosition(user, true);
    }
  }

  /**
    * @dev Returns the price of the LP token in USD with 18 decimal places
    *      1 LpUsd = 1 USD
    */
  function peek() override public pure returns (bytes32, bool) {
    // returns in 18 decimals
    return (bytes32(uint(1e18)), true);
  }

  /**
   * @dev Get pending reward tokens of this account
   * @param account the address of the user
   * @return totalRewards the total claimable rewards in rewardToken
   */
  function claimableStakingRewards(address account) external view returns (uint256) {
    // get total rewards from PancakeSwap Staking Hub
    uint256 totalRewards = 0;
    uint256[] storage userLpTokens = userLps[account];
    for (uint256 i = 0; i < userLpTokens.length; i++) {
      uint256 tokenId = userLpTokens[i];
      // get claimable rewards from PancakeStakingHub
      totalRewards += IMasterChefV3(masterChefV3).pendingCake(tokenId);
    }
    return totalRewards;
  }
  ///////////////////////////////////////////////////////////////
  ////////////                CDP Only               ////////////
  ///////////////////////////////////////////////////////////////
  /**
    * @dev liquidation is being kick started by the cdp
    * @param user the address of the user to liquidate
    * @param lpAmount the amount of collateral(LpUsd)
    * @notice this function will burn LP_USD from the user
    */
  function daoBurn(address user, uint256 lpAmount) external nonReentrant onlyCdp {
    require(user != address(0), "PancakeSwapV3LpProvider: invalid-user");
    require(lpAmount > 0, "PancakeSwapV3LpProvider: invalid-lpAmount");
    // @notice unlike general providers in CDP, there is no cert token to burn
    // as the provider already recorded user's LP position
  }

  /**
    * @dev User's position is being liquidated
    *      when `isLeftOver` is false, a liquidator buys the LP token from the user and paid the debt
    *      liquidity will be removed from user's LP and transform to token0 and token1, then transfer them to the recipient(liquidator)
    *      if user has multiple LPs, the function will liquidate from the lowest value LP to the highest value LP until `amount` is covered
    *
    *      when `isLeftOver` is true, the CDP position is fully liquidated
    *      the remaining LP token, including token0 and token1 will be transferred to user
    *
    * @param owner the address of the user to liquidate
    * @param recipient the address of the liquidator or user
    * @param amount the amount of LP_USD to be bought by the liquidator
    * @param isLeftOver whether the liquidation is left over or not
    * @param data bytes consist of 3 uint256 variables: amount0min, amount1Min, tokenId
    */
  function liquidation(
    address owner,
    address recipient,
    uint256 amount,
    bytes memory data,
    bool isLeftOver
  ) external nonReentrant onlyCdp {
    require(owner != address(0), "PancakeSwapV3LpProvider: invalid-owner");
    require(recipient != address(0), "PancakeSwapV3LpProvider: invalid-recipient");
    require(amount > 0, "PancakeSwapV3LpProvider: invalid-amount");
    // get user token0 and token1 leftover from previous liquidation(if any)
    LiquidatedLp storage record = userLiquidatedLps[owner];
    // liquidation ended, send leftover tokens and LP to the owner
    if (isLeftOver) {
      // returns all leftover Lp tokens to user
      _returnLeftoverLpToUser(owner);
      // returns all leftover token0 and token1 to user
      if (record.token1Left > 0) {
        IERC20(token1).safeTransfer(owner, record.token1Left);
      }
      if (record.token1Left > 0) {
        IERC20(token0).safeTransfer(owner, record.token0Left);
      }
    } else {
      // get token0 and token1's price
      // and calculate their values
      uint256 token0Price = IResilientOracle(resilientOracle).peek(token0);
      uint256 token1Price = IResilientOracle(resilientOracle).peek(token1);
      uint256 token0Value = FullMath.mulDiv(record.token0Left, token0Price, 1e8);
      uint256 token1Value = FullMath.mulDiv(record.token1Left, token1Price, 1e8);
      // leftover tokens can't cover the amount to be paid
      // burn LP to get more token0 and token1
      if ((token0Value + token1Value) < amount) {
        (
          uint256 amount0,
          uint256 amount1,
          uint256 rewards
        ) = _burnLpWithTheLowestValue(
          owner,
          amount,
          data
        );
        // Step 3. rewards send to owner after fee is cut
        sendRewardWithFeeCut(rewards, owner);
        // Step 4. Update user leftover tokens
        record.token0Left += amount0;
        record.token1Left += amount1;
      }
      // step 5. pay by tokens
      _payByToken0AndToken1(
          owner,
          recipient,
          amount,
          token0Price,
          token1Price
      );
    }
    emit Liquidated(
      owner,
      recipient,
      amount,
      isLeftOver,
      record.token0Left,
      record.token1Left
    );
  }

  ///////////////////////////////////////////////////////////////
  ////////////           Internal Functions          ////////////
  ///////////////////////////////////////////////////////////////

  // ---------- Liquidation internal functions ---------- //
  /**
    * @notice ----- FOR Liquidation ------
    * @dev pay liquidator/user by leftover token0 and token1
    * @param owner the address of the user to liquidate
    * @param recipient the address of the liquidator or user
    * @param amountToPay the amount of LP_USD to be paid
    * @param token0Price the price of token0 in USD
    * @param token1Price the price of token1 in USD
    */
  function _payByToken0AndToken1(
    address owner,
    address recipient,
    uint256 amountToPay,
    uint256 token0Price,
    uint256 token1Price
  ) internal {
    // get user token0 and token1 leftover from previous liquidation(if any)
    LiquidatedLp storage record = userLiquidatedLps[owner];
    uint256 amount0 = record.token0Left;
    uint256 amount1 = record.token1Left;
    // calculate values of token0 and token1
    uint256 token0Value = FullMath.mulDiv(amount0, token0Price, 1e8);
    uint256 token1Value = FullMath.mulDiv(amount1, token1Price, 1e8);
    uint256 token0Sent = 0;
    uint256 token1Sent = 0;
    uint256 amountLeft = amountToPay;
    // use the token with lower value first
    if (token0Value < token1Value) {
      // Use token0 first
      if (amountLeft > token0Value) {
        IERC20(token0).safeTransfer(recipient, amount0);
        amountLeft -= token0Value;
        token0Sent = amount0;
        // Use token1 for the rest
        uint256 token1AmountToSend = FullMath.mulDiv(amountLeft, amount1, token1Value);
        IERC20(token1).safeTransfer(recipient, token1AmountToSend);
        token1Sent = token1AmountToSend;
      } else {
        // Only token0 is needed
        uint256 token0AmountToSend = FullMath.mulDiv(amountLeft, amount0, token0Value);
        IERC20(token0).safeTransfer(recipient, token0AmountToSend);
        token0Sent = token0AmountToSend;
      }
    } else {
      // Use token1 first
      if (amountLeft > token1Value) {
        IERC20(token1).safeTransfer(recipient, amount1);
        amountLeft -= token1Value;
        token1Sent = amount1;
        // Use token0 for the rest
        uint256 token0AmountToSend = FullMath.mulDiv(amountLeft, amount0, token0Value);
        IERC20(token0).safeTransfer(recipient, token0AmountToSend);
        token0Sent = token0AmountToSend;
      } else {
        // Only token1 is needed
        uint256 token1AmountToSend = FullMath.mulDiv(amountLeft, amount1, token1Value);
        IERC20(token1).safeTransfer(recipient, token1AmountToSend);
        token1Sent = token1AmountToSend;
      }
    }
    // update leftovers
    record.token0Left += (amount0 - token0Sent);
    record.token1Left += (amount1 - token1Sent);
  }

  /**
    * @notice ----- FOR Liquidation ------
    * @dev Burn user's LP with the lowest value in USD
    *     and return the token0, token1 and rewards to the recipient
    * @param owner the address of the user to liquidate
    * @param amount the amount of LP_USD to be bought by the liquidator
    * @param data bytes consist of 3 uint256 variables: amount0min, amount1Min, tokenId
    * @return amount0 the amount of token0 returned to the recipient
    * @return amount1 the amount of token1 returned to the recipient
    * @return rewards the amount of rewards returned to the recipient
    */
  function _burnLpWithTheLowestValue(
    address owner,
    uint256 amount,
    bytes memory data
  ) internal returns (uint256 amount0, uint256 amount1, uint256 rewards) {
    // decode data for decrease liquidity params
    (uint256 amount0Min, uint256 amount1Min, uint256 tokenId) = abi.decode(data, (uint256, uint256, uint256));
    require(amount1Min >= 0 && amount0Min >= 0 && tokenId > 0, "PancakeSwapV3LpProvider: invalid-data");
    // sync user's LP total value first to ensure the lowest LP value is correct
    _syncUserLpTotalValue(owner, true);
    uint256 lowestLpValue = type(uint256).max;
    uint256 lowestLpTokenId = 0;
    uint256[] storage userLpTokens = userLps[owner];
    // find user LPs with the lowest value
    for (uint256 i = 0; i < userLpTokens.length; i++) {
      uint256 currentTokenId = userLpTokens[i];
      // get the lp value in USD
      uint256 lpValue = lpValues[currentTokenId];
      // find the lowest lp value
      if (lpValue < lowestLpValue) {
        lowestLpValue = lpValue;
        lowestLpTokenId = currentTokenId;
      }
    }
    // the amount of LP_USD to be bought by the liquidator, must be covered by the lowest LP value
    require(amount <= lowestLpValue, "PancakeSwapV3LpProvider: amount-exceeds-lp-value");
    require(lowestLpTokenId == tokenId, "PancakeSwapV3LpProvider: invalid-tokenId");
    // remove it from userLps[]
    for (uint256 i = 0; i < userLpTokens.length; i++) {
      if (userLpTokens[i] == lowestLpTokenId) {
        userLpTokens[i] = userLpTokens[userLpTokens.length - 1];
        userLpTokens.pop();
        break;
      }
    }
    // remove if from lpOwners[tokenId]
    lpOwners[lowestLpTokenId] = address(0);
    // burn LP and collects token0, token1 and rewards
    (
      amount0,
      amount1,
      rewards
    ) = IPancakeSwapV3LpStakingHub(pancakeStakingHub).burn(tokenId, amount0Min, amount1Min);
  }

  /**
   * @notice ----- FOR Liquidation ------
   * @dev Withdraw all leftover LP tokens and send them back to user
   *      as well as harvesting rewards from PancakeSwap Staking Hub
   * @param user the address of the user to remove all LP tokens
   */
  function _returnLeftoverLpToUser(address user) internal {
    uint256[] storage userLpTokens = userLps[user];
    // remove all tokenIds from userLps
    for (uint256 i = 0; i < userLpTokens.length; i++) {
      uint256 tokenId = userLpTokens[i];
      // withdraw from Staking Hub with the harvested rewards
      uint256 rewardAmount = IPancakeSwapV3LpStakingHub(pancakeStakingHub).withdraw(tokenId);
      // send reward and cut fee
      sendRewardWithFeeCut(rewardAmount, user);
      // transfer LP token back to the user
      IERC721(nonFungiblePositionManager).safeTransferFrom(address(this), user, tokenId);
      lpOwners[tokenId] = address(0);
      lpValues[tokenId] = 0;
    }
    // remove all tokenIds from lpOwners
    delete userLps[user];
    // reset user's total LP value
    userTotalLpValue[user] = 0;
  }
  // ---------- /Liquidation internal functions ---------- //


  /*
   * @inheritdoc IERC721Receiver
   */
  function onERC721Received(
    address /*operator*/,
    address from,
    uint256 tokenId,
    bytes calldata /*data*/
  ) external returns (bytes4) {
    // only accept NFT sent from NonFungiblePositionManager
    require(msg.sender == nonFungiblePositionManager, "PancakeSwapV3LpProvider: invalid-lp-sender");
    // process deposit if NFT send from other than PancakeSwapV3LpStakingHub.sol
    if (from != pancakeStakingHub) {
      // check correctness of token0 and token1 and make sure non-zero liquidity
      bool isValid = verifyLp(tokenId);
      require(isValid, "PancakeSwapV3LpProvider: invalid-lp");
      // make deposit and stake LP
      _deposit(from, tokenId);
    } else {
      // if the NFT is sent from PancakeStakingHub, it should belongs to someone(lpOwners)
      require(lpOwners[tokenId] != address(0), "PancakeSwapV3LpProvider: invalid-lp-owner");
    }
    return IERC721Receiver.onERC721Received.selector;
  }

  /**
    * @dev Sync LP value in USD
    * @param amount amount of rewards to send
    * @param to the address to send the rewards to
    */
  function sendRewardWithFeeCut(uint256 amount, address to) internal {
    require(to != address(0), "PancakeSwapV3LpProvider: invalid-recipient");
    if (amount > 0) {
      // approve rewardToken to the vault
      IERC20(rewardToken).safeApprove(pancakeLpStakingVault, amount);
      // transfer rewards to the vault
      uint256 rewardAfterCut = IPancakeSwapV3LpStakingVault(pancakeLpStakingVault).feeCut(amount);
      // transfer rewards to the user
      IERC20(rewardToken).safeTransfer(to, rewardAfterCut);
    }
  }

  /**
    * @dev Check if the LP token is valid
    * @param tokenId the tokenId of the LP token
    * @return true if the LP token is valid, false otherwise
    */
  function verifyLp(uint256 tokenId) internal view returns (bool) {
    (
    /* uint96 nonce */,
    /* address operator */,
      address _token0,
      address _token1,
      /* uint24 fee */,
      /* int24 tickLower */,
      /* int24 tickUpper */,
      uint128 liquidity,
    /* uint256 feeGrowthInside0LastX128 */,
    /* uint256 feeGrowthInside1LastX128 */,
    /* uint128 tokensOwed0 */,
    /* uint128 tokensOwed1 */
    ) = INonfungiblePositionManager(nonFungiblePositionManager).positions(tokenId);
    // verify token0, token1 and make sure non-zero liquidity
    if (_token0 != token0 || _token1 != token1 || liquidity == 0) {
      return false;
    }
    return true;
  }

  /**
    * @dev Deposit LP token to the provider
    * @param tokenId the tokenId of the LP token
    */
  function _deposit(address user, uint256 tokenId) internal {
    // check if user has reached the max LP limit
    require(userLps[user].length < maxLpPerUser, "PancakeSwapV3LpProvider: max-lp-reached");

    // get lp value and verify the underlying price
    uint256 lpValue = _syncLpValue(tokenId);
    require(lpValue >= minLpValue, "PancakeSwapV3LpProvider: min-lp-value-not-met");

    // update lpOwners, lpValues
    lpOwners[tokenId] = user;
    userLps[user].push(tokenId);
    // update user position
    _syncUserCdpPosition(user, false);
    // farm LP by deposit to pancakeStakingHub
    IERC721(nonFungiblePositionManager).approve(pancakeStakingHub, tokenId);
    IPancakeSwapV3LpStakingHub(pancakeStakingHub).deposit(tokenId);

    emit DepositLp(user, tokenId, lpValue);
  }

  /**
    * @dev Sync user position in the cdp
    * @param user the address of the user
    * @param syncLpPrice whether to sync LP price or not
    *        when its true, it will sync the LP price before calculating the user's total LP value
    */
  function _syncUserCdpPosition(address user, bool syncLpPrice) internal nonReentrant {
    // sync current user Lp total value
    uint256 _userLpTotalValue = _syncUserLpTotalValue(user, syncLpPrice);
    // convert with lpExchangeRate
    _userLpTotalValue = FullMath.mulDiv(_userLpTotalValue, lpExchangeRate, DENOMINATOR);
    // get total deposited LP_USD amount in the cdp
    uint256 totalLpUsd = IDao(cdp).locked(lpUsd, user);
    // if user has more LP value than the total LP_USD amount in the cdp
    if (_userLpTotalValue > totalLpUsd) {
      // mint LP_USD
      uint256 mintAmount = _userLpTotalValue - totalLpUsd;
      ILpUsd(lpUsd).mint(address(this), mintAmount);
      // deposit the difference to cdp
      IDao(cdp).deposit(user, lpUsd, mintAmount);
    } else if (_userLpTotalValue < totalLpUsd) {
      // if user has less LP value than the total LP_USD amount in the cdp,
      // burn LP_USD from the user
      uint256 burnAmount = totalLpUsd - _userLpTotalValue;
      // update cdp position
      IDao(cdp).withdraw(user, lpUsd, burnAmount);
      ILpUsd(lpUsd).burn(user, burnAmount);
    }

    emit UserCdpPositionSynced(
      user,
      _userLpTotalValue,
      totalLpUsd
    );
  }

  /**
    * @dev Sync user position and update userTotalLpValue
    * @param user the address of the user
    * @param syncLpPrice whether to sync LP price or not
    * @return userLpTotalValue the total appraised value of the user's LPs
    */
  function _syncUserLpTotalValue(address user, bool syncLpPrice) internal returns (uint256 userLpTotalValue) {
    // reset userLpTotalValue
    userLpTotalValue = 0;
    // iterate through user's LPs and sum up the appraised value
    uint256[] storage userLpTokens = userLps[user];
    for (uint256 i = 0; i < userLpTokens.length; i++) {
      uint256 tokenId = userLpTokens[i];
      uint256 lpValue = syncLpPrice ? _syncLpValue(tokenId) : lpValues[tokenId];
      userLpTotalValue += lpValue;
    }
    // update user's total LP value
    userTotalLpValue[user] = userLpTotalValue;
  }

  /**
    * @dev fetch latest LP value and update lpValues
    * @param tokenId the tokenId of the LP token
    * @return appraisedValue the appraised value in USD with 8 decimal places
    */
  function _syncLpValue(uint256 tokenId) internal returns (uint256 appraisedValue) {
    // get appraised value of the LP token
    appraisedValue = getLpValue(tokenId);
    // update lpValues and userTotalLpValue
    lpValues[tokenId] = appraisedValue;
  }

  ///////////////////////////////////////////////////////////////
  ////////////         LP value calculation          ////////////
  ///////////////////////////////////////////////////////////////

  /**
    * @dev Get amounts of token0 and token1 for a given NFT
    * @param tokenId the tokenId of the NFT
    * @return amount0 the amount of token0
    * @return amount1 the amount of token1
    */
  function getAmounts(uint256 tokenId) internal view returns (uint256 amount0, uint256 amount1) {
    // Get fee, tickLower, tickUpper and liquidity
    (
      /* uint96 nonce */,
      /* address operator */,
      /* address token0 */,
      /* address token1 */,
      uint24 fee,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
      /* uint256 feeGrowthInside0LastX128 */,
      /* uint256 feeGrowthInside1LastX128 */,
      /* uint128 tokensOwed0 */,
      /* uint128 tokensOwed1 */
    ) = INonfungiblePositionManager(nonFungiblePositionManager).positions(tokenId);
    // get pool from pool factory
    address poolAddress = IUniswapV3Factory(pancakeV3Factory).getPool(token0, token1, fee);
    // get sqrtPriceX96 from slot0
    (
      uint160 sqrtPriceX96,
      /* int24 tick */,
      /* uint16 observationIndex */,
      /* uint16 observationCardinality */,
      /* uint16 observationCardinalityNext */,
      /* uint8 feeProtocol */,
      /* bool unlocked */
    ) = IUniswapV3Pool(poolAddress).slot0();
    uint160 sqrtPriceX96Lower = TickMath.getSqrtRatioAtTick(tickLower);
    uint160 sqrtPriceX96Upper = TickMath.getSqrtRatioAtTick(tickUpper);
    (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
      sqrtPriceX96, sqrtPriceX96Lower, sqrtPriceX96Upper, liquidity
    );
    // verification of zero liquidity when user deposit
    require(amount0 > 0 || amount1 > 0, "PancakeSwapV3LpProvider: zero-amounts");
  }

  /**
    * @dev Get the appraised value of a LP token in USD
    * @param tokenId the tokenId of the LP token
    * @return appraisedValue the appraised value in USD with 8 decimal places
    */
  function getLpValue(uint256 tokenId) public view returns (uint256 appraisedValue) {
    // get amounts of token0 and token1
    (uint256 amount0, uint256 amount1) = getAmounts(tokenId);
    // get price of token0 and token1 from oracle
    uint256 price0 = IResilientOracle(resilientOracle).peek(token0);
    uint256 price1 = IResilientOracle(resilientOracle).peek(token1);
    // calculate appraised value in USD with 8 decimal places
    appraisedValue = (amount0 * price0 + amount1 * price1);
  }

  /**
    * @dev Get the latest appraised value of a user's total LPs
    * @notice for external use only
    * @param user the address of the user
    * @return userLpTotalValue the total appraised value of the user's LPs in USD with 8 decimal places
    */
  function getLatestUserTotalLpValue(address user) override external view returns (uint256 userLpTotalValue) {
    userLpTotalValue = 0;
    // iterate through user's LPs and sum up the appraised value
    uint256[] storage userLpTokens = userLps[user];
    for (uint256 i = 0; i < userLpTokens.length; i++) {
      uint256 tokenId = userLpTokens[i];
      uint256 lpValue = getLpValue(tokenId);
      userLpTotalValue += lpValue;
    }
  }

  ///////////////////////////////////////////////////////////////
  ////////////             Administrative            ////////////
  ///////////////////////////////////////////////////////////////

  /**
   * @dev pause the contract
   */
  function pause() external onlyRole(PAUSER) {
    _pause();
  }

  /**
   * @dev resume contract
   */
  function unpause() external onlyRole(MANAGER) {
    _unpause();
  }

  /**
    * @dev Set maxLpPerUser
    * @param _maxLpPerUser the max LPs per user
    */
  function setMaxLpPerUser(uint256 _maxLpPerUser) external onlyRole(MANAGER) {
    require(_maxLpPerUser > 0 && maxLpPerUser != _maxLpPerUser, "PancakeSwapV3LpProvider: invalid-maxLpPerUser");
    uint256 oldMaxLpPerUser = maxLpPerUser;
    maxLpPerUser = _maxLpPerUser;
    emit MaxLpPerUserSet(oldMaxLpPerUser, _maxLpPerUser);
  }

  /**
    * @dev Set lpExchangeRate
    * @param _lpExchangeRate the exchange rate
    */
  function setLpExchangeRate(uint256 _lpExchangeRate) external onlyRole(MANAGER) {
    require(_lpExchangeRate <= DENOMINATOR && lpExchangeRate != _lpExchangeRate, "PancakeSwapV3LpProvider: invalid-lpExchangeRate");
    uint256 oldLpExchangeRate = lpExchangeRate;
    lpExchangeRate = _lpExchangeRate;
    emit LpExchangeRateSet(oldLpExchangeRate, _lpExchangeRate);
  }

  /**
    * @dev Set minLpValue
    * @param _minLpValue the minimum LP value in USD
    */
  function setMinLpValue(uint256 _minLpValue) external onlyRole(MANAGER) {
    require(_minLpValue > 0 && minLpValue != _minLpValue, "PancakeSwapV3LpProvider: invalid-minLpValue");
    uint256 oldMinLpValue = minLpValue;
    minLpValue = _minLpValue;
    emit MinLpValueSet(oldMinLpValue, _minLpValue);
  }

  /**
    * @dev only admin can upgrade the contract
    * @param _newImplementation new implementation address
    */
  function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
