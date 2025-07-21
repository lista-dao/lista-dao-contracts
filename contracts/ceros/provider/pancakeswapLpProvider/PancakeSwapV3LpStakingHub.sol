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

import "../../interfaces/IPancakeSwapV3LpProvider.sol";
import "../../interfaces/IPancakeSwapV3LpStakingHub.sol";
import "../../interfaces/INonfungiblePositionManager.sol";
import "../../interfaces/IMasterChefV3.sol";

contract PancakeSwapV3LpStakingHub is
IPancakeSwapV3LpStakingHub,
PausableUpgradeable,
ReentrancyGuardUpgradeable,
AccessControlEnumerableUpgradeable,
UUPSUpgradeable,
IERC721Receiver
{

  using SafeERC20 for IERC20;

  /// @dev ROLES
  bytes32 public constant MANAGER = keccak256("MANAGER");
  bytes32 public constant PAUSER = keccak256("PAUSER");

  // PancakeSwap NonFungiblePositionManager address
  address public immutable nonFungiblePositionManager;
  // MasterChefV3(V3 farming contract) address
  address public immutable masterChefV3;
  // CAKE token
  address public immutable rewardToken;
  // emergency mode
  // when it's turned on, all LP tokens will be withdrawn from MasterChefV3
  bool public emergencyMode;
  // holding of tokenIds
  uint256[] private tokenIds;
  // provider => bool(isActive)
  mapping(address => bool) public lpProviders;
  // tokenId => provider
  mapping(uint256 => address) public tokenIdToProvider;


  // @dev MODIFIERS
  modifier onlyProvider() {
    require(lpProviders[msg.sender], "PancakeSwapStakingHub: inactive-provider");
    _;
  }

  modifier checkTokenIdWithProvider(uint256 tokenId) {
    require(tokenIdToProvider[tokenId] == msg.sender, "PancakeSwapStakingHub: tokenId-not-owned-by-provider");
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor(
    address _nonFungiblePositionManager,
    address _masterChefV3,
    address _rewardToken
  ) {
    require(
      _nonFungiblePositionManager != address(0) &&
      _masterChefV3 != address(0) &&
      _rewardToken != address(0),
      "zero address provided"
    );
    nonFungiblePositionManager = _nonFungiblePositionManager;
    masterChefV3 = _masterChefV3;
    rewardToken = _rewardToken;

    _disableInitializers();
  }

  /**
   * @dev initialize contract
   * @param _admin admin address
   * @param _manager manager address
   * @param _pauser pauser address
   */
  function initialize(
    address _admin,
    address _manager,
    address _pauser
  ) external initializer {
    require(
      _admin != address(0) &&
      _manager != address(0) &&
      _pauser != address(0),
      "zero-address-provided"
    );

    __Pausable_init();
    __ReentrancyGuard_init();
    __AccessControlEnumerable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    _setupRole(MANAGER, _manager);
    _setupRole(PAUSER, _pauser);
  }

  ///////////////////////////////////////////////////////////////
  ////////////           External Functions          ////////////
  ///////////////////////////////////////////////////////////////

  /**
    * @dev deposit LP token to V3 provider, then stake it to MasterChefV3
    * @param tokenId ID of the NFT token to deposit
    */
  function deposit(uint256 tokenId) override external onlyProvider whenNotPaused nonReentrant {
    require(tokenId > 0, "PancakeSwapStakingHub: non-zero-tokenId");
    address provider = msg.sender;
    // transfer token from provider to MasterChefV3
    IERC721(nonFungiblePositionManager).safeTransferFrom(provider, address(this), tokenId);
    // transfer to MasterChefV3
    IERC721(nonFungiblePositionManager).safeTransferFrom(address(this), masterChefV3, tokenId);
    // record tokenId
    tokenIds.push(tokenId);
    tokenIdToProvider[tokenId] = provider;

    emit DepositLp(provider, tokenId);
  }

  /**
    * @dev withdraw LP token from MasterChefV3, send NFT and reward token to the provider
    * @param tokenId ID of the NFT token to withdraw
    */
  function withdraw(uint256 tokenId)
  override
  external
  checkTokenIdWithProvider(tokenId)
  onlyProvider
  whenNotPaused
  nonReentrant
  returns (uint256 rewards) {
    require(tokenId > 0, "PancakeSwapStakingHub: non-zero-tokenId");
    address provider = msg.sender;
    // reward token pre-balance
    uint256 preBalance = IERC20(rewardToken).balanceOf(address(this));
    // withdraw token from MasterChefV3
    rewards = IMasterChefV3(masterChefV3).withdraw(tokenId, address(this));
    // post balance of reward token
    uint256 postBalance = IERC20(rewardToken).balanceOf(address(this));
    require(postBalance == preBalance + rewards, "PancakeSwapStakingHub: invalid-reward-balance");
    // send rewards and NFT to provider
    if (rewards > 0) {
      // send rewards to provider
      IERC20(rewardToken).safeTransfer(provider, rewards);
      emit Harvest(provider, tokenId, rewards);
    }
    // transfer NFT back to the provider
    IERC721(nonFungiblePositionManager).safeTransferFrom(address(this), provider, tokenId);
    // remove if from tokenIds
    _removeTokenRecord(tokenId);
    // emit event
    emit WithdrawLp(provider, tokenId, rewards);
  }

  /**
    * @dev burn LP token, collect fees and rewards, then send them to the provider
    * @param tokenId ID of the NFT token to burn
    * @param amount0Min minimum amount of token0 to collect
    * @param amount1Min minimum amount of token1 to collect
    * @return amount0 collected amount of token0
    * @return amount1 collected amount of token1
    * @return rewards collected amount of rewards
    */
  function burnAndCollect(uint256 tokenId, uint256 amount0Min, uint256 amount1Min)
  override
  external
  checkTokenIdWithProvider(tokenId)
  onlyProvider
  whenNotPaused
  nonReentrant
  returns (uint256 amount0, uint256 amount1, uint256 rewards) {
    require(tokenId > 0, "PancakeSwapStakingHub: non-zero-tokenId");
    // pre-balance of reward
    uint256 preRewardBalance = IERC20(rewardToken).balanceOf(address(this));
    // decrease liquidity then burn LP
    // @note will harvest reward as well
    (amount0, amount1) = _burnAndCollectTokens(
      tokenId,
      amount0Min,
      amount1Min
    );
    // get rewards amount
    rewards = IERC20(rewardToken).balanceOf(address(this)) - preRewardBalance;
    // send rewards to provider
    if (rewards > 0) {
      IERC20(rewardToken).safeTransfer(msg.sender, rewards);
      emit Harvest(msg.sender, tokenId, rewards);
    }
    // remove tokenId record
    _removeTokenRecord(tokenId);
    // emit event
    emit BurnLp(msg.sender, tokenId, rewards, amount1, amount0);
  }

  /**
    * @dev harvest rewards from MasterChefV3 and send to the provider
    * @param tokenId ID of the NFT token to harvest
    * @return rewards amount of rewards harvested
    */
  function harvest(uint256 tokenId) override external onlyProvider whenNotPaused nonReentrant returns (uint256 rewards) {
    require(tokenId > 0, "PancakeSwapStakingHub: non-zero-tokenId");
    address provider = msg.sender;
    // reward token pre-balance
    uint256 preBalance = IERC20(rewardToken).balanceOf(address(this));
    // withdraw rewards from MasterChefV3
    rewards = IMasterChefV3(masterChefV3).harvest(tokenId, address(this));
    // post balance of reward token
    uint256 postBalance = IERC20(rewardToken).balanceOf(address(this));
    require(postBalance == preBalance + rewards, "PancakeSwapStakingHub: invalid-reward-balance");
    // send rewards to provider
    if (rewards > 0) {
      IERC20(rewardToken).safeTransfer(provider, rewards);
      emit Harvest(provider, tokenId, rewards);
    }
    return rewards;
  }

  ///////////////////////////////////////////////////////////////
  ////////////           Internal Functions          ////////////
  ///////////////////////////////////////////////////////////////

  /**
    * @notice to avoid stack too deep error, this function is separated from burnAndCollect()
    * @dev burn LP token, collect fees and rewards, then send them to the provider
    * @param tokenId ID of the NFT token to burn
    * @param amount0Min minimum amount of token0 to collect
    * @param amount1Min minimum amount of token1 to collect
    * @return collectedAmount0 collected amount of token0
    * @return collectedAmount1 collected amount of token1
    */
  function _burnAndCollectTokens(
    uint256 tokenId,
    uint256 amount0Min,
    uint256 amount1Min
  ) internal returns (uint256 collectedAmount0, uint256 collectedAmount1) {
    address provider = msg.sender;
    IERC20 token0 = IERC20(IPancakeSwapV3LpProvider(provider).token0());
    IERC20 token1 = IERC20(IPancakeSwapV3LpProvider(provider).token1());

    uint256 preToken0Balance = token0.balanceOf(address(this));
    uint256 preToken1Balance = token1.balanceOf(address(this));

    // fully remove liquidity from the tokenId
    // after this tokens including fees are ready to collect
    IMasterChefV3(masterChefV3).decreaseLiquidity(
      IMasterChefV3.DecreaseLiquidityParams({
        tokenId: tokenId,
        liquidity: getLiquidity(tokenId),
        amount0Min: amount0Min,
        amount1Min: amount1Min,
        deadline: block.timestamp + 20 minutes // 20 minutes deadline
      })
    );
    // collect token0 and token1 including fees from the tokenId
    (collectedAmount0, collectedAmount1) = IMasterChefV3(masterChefV3).collect(
      IMasterChefV3.CollectParams({
        tokenId: tokenId,
        recipient: address(this),
        amount0Max: type(uint128).max, // just put max value to collect all fees
        amount1Max: type(uint128).max // just put max value to collect all fees
      })
    );
    // burn the LP
    IMasterChefV3(masterChefV3).burn(tokenId);

    uint256 postToken0Balance = token0.balanceOf(address(this));
    uint256 postToken1Balance = token1.balanceOf(address(this));

    uint256 collectedAmount0WithFees = postToken0Balance - preToken0Balance;
    uint256 collectedAmount1WithFees = postToken1Balance - preToken1Balance;

    // verify amount0 and amount1
    require(
      collectedAmount0WithFees >= collectedAmount0 && collectedAmount1WithFees >= collectedAmount1,
      "PancakeSwapStakingHub: invalid-token-balances"
    );
    // transfer token0 & token 1 to provider
    if (collectedAmount0 > 0) {
      token0.safeTransfer(provider, collectedAmount0);
    }
    if (collectedAmount1 > 0) {
      token1.safeTransfer(provider, collectedAmount1);
    }
  }

  /**
    * @dev remove tokenId from the tokenIds array and mapping
    * @param tokenId ID of the NFT token to remove
    */
  function _removeTokenRecord(uint256 tokenId) internal {
    // remove if from tokenIds
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (tokenIds[i] == tokenId) {
        tokenIds[i] = tokenIds[tokenIds.length - 1];
        tokenIds.pop();
        break;
      }
    }
    // remove tokenId from mapping
    delete tokenIdToProvider[tokenId];
  }

  /**
    * @dev get liquidity of the tokenId
    * @param tokenId ID of the NFT token
    * @return liquidity amount of liquidity in the position
    */
  function getLiquidity(uint256 tokenId) internal view returns (uint128 liquidity) {
    require(tokenId > 0, "PancakeSwapStakingHub: non-zero-tokenId");
    (
      /* uint96 nonce */,
      /* address operator */,
      /* address token0 */,
      /* address token1 */,
      /* uint24 fee */,
      /* int24 tickLower */,
      /* int24 tickUpper */,
      liquidity,
      /* uint256 feeGrowthInside0LastX128 */,
      /* uint256 feeGrowthInside1LastX128 */,
      /* uint128 tokensOwed0 */,
      /* uint128 tokensOwed1 */
    ) = INonfungiblePositionManager(nonFungiblePositionManager).positions(tokenId);
  }

  /**
    * @inheritdoc IERC721Receiver
    */
  function onERC721Received(
    address /*operator*/,
    address from,
    uint256 /*tokenId*/,
    bytes calldata /*data*/
  ) override external view returns (bytes4) {
    // LP token must coming from active lpProviders or MasterChefV3
    require(
      lpProviders[from] || from == masterChefV3,
      "PancakeSwapStakingHub: invalid-token-sender"
    );
    return IERC721Receiver.onERC721Received.selector;
  }


  ///////////////////////////////////////////////////////////////
  ////////////            Admin Functions            ////////////
  ///////////////////////////////////////////////////////////////

  /**
   * @dev pause the contract
   */
  function pause() external onlyRole(PAUSER) {
    _pause();
  }

  /**
   * @dev toggle the pause status
   */
  function unpause() external onlyRole(MANAGER) {
    _unpause();
  }

  /**
    * @dev register provider
    * @param provider address of the PancakeSwap V3 LP provider
    */
  function registerProvider(address provider) external onlyRole(MANAGER) {
    require(!lpProviders[provider], "PancakeSwapStakingHub: Provider is already registered");
    require(provider != address(0), "PancakeSwapStakingHub: zero-address-provided");
    lpProviders[provider] = true;
    emit RegisterProvider(provider);
  }

  /**
    * @dev deregister provider
    * @param provider address of the PancakeSwap V3 LP provider
    */
  function deregisterProvider(address provider) external onlyRole(MANAGER) {
    require(lpProviders[provider], "PancakeSwapStakingHub: Provider is no registered");
    require(provider != address(0), "PancakeSwapStakingHub: zero-address-provided");
    lpProviders[provider] = false;
    emit DeregisterProvider(provider);
  }

  /**
    * @dev stop emergency mode
    */
  function stopEmergencyMode() external nonReentrant onlyRole(MANAGER) {
    require(emergencyMode, "PancakeSwapStakingHub: not-in-emergency-mode");
    require(!IMasterChefV3(masterChefV3).emergency(), "PancakeSwapStakingHub: masterChefV3-is-in-emergency-mode");
    emergencyMode = false;
    // transfer all LP back to MasterChefV3 for farming
    for (uint256 i = 0; i < tokenIds.length; i++) {
      // transfer token to MasterChefV3
      IERC721(nonFungiblePositionManager).safeTransferFrom(address(this), masterChefV3, tokenIds[i]);
    }
    emit StopEmergencyMode();
  }

  /**
    * @dev emergency withdraw all LPs from the farming contract of specific LP version
    * @notice No staking is required for Infinity LP, so this function is only applicable for V3 LP
    */
  function emergencyWithdraw() external nonReentrant onlyRole(MANAGER) {
    require(!emergencyMode, "PancakeSwapStakingHub: already-in-emergency-mode");
    require(IMasterChefV3(masterChefV3).emergency(), "PancakeSwapStakingHub: masterChefV3-not-in-emergency-mode");
    emergencyMode = true;
    // withdraw all tokenIds from MasterChefV3
    for (uint256 i = 0; i < tokenIds.length; i++) {
      IMasterChefV3(masterChefV3).withdraw(tokenIds[i], address(this));
    }
    emit EmergencyWithdraw();
  }

  /**
    * @dev only admin can upgrade the contract
    * @param _newImplementation new implementation address
    */
  function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
