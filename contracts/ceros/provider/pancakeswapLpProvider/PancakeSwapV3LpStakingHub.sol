// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

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
    // stake LP only if MasterChef is not in emergency mode
    if (!IMasterChefV3(masterChefV3).emergency()) {
      // transfer to MasterChefV3
      IERC721(nonFungiblePositionManager).safeTransferFrom(address(this), masterChefV3, tokenId);
    }
    // record tokenId
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
  whenNotPaused
  nonReentrant
  returns (uint256 rewards) {
    require(tokenId > 0, "PancakeSwapStakingHub: non-zero-tokenId");
    address provider = msg.sender;
    // check if token is staked
    if (_isStaked(tokenId)) {
      // reward token pre-balance
      uint256 preBalance = IERC20(rewardToken).balanceOf(address(this));
      // withdraw token from MasterChefV3
      IMasterChefV3(masterChefV3).withdraw(tokenId, address(this));
      // post balance of reward token
      rewards = IERC20(rewardToken).balanceOf(address(this)) - preBalance;
    }
    // send rewards and NFT to provider
    if (rewards > 0) {
      // send rewards to provider
      IERC20(rewardToken).safeTransfer(provider, rewards);
      emit Harvest(provider, tokenId, rewards);
    }
    // transfer NFT back to the provider
    IERC721(nonFungiblePositionManager).safeTransferFrom(address(this), provider, tokenId);
    // remove token record
    delete tokenIdToProvider[tokenId];
    // emit event
    emit WithdrawLp(provider, tokenId, rewards);
  }

  /**
    * @dev burn LP token, collect fees and rewards, then send them to the provider
    * @param tokenId ID of the NFT token to burn
    * @param amount0Min minimum amount of token0 to collect
    * @param amount1Min minimum amount of token1 to collect
    * @param deadline deadline for the transaction
    * @return amount0 collected amount of token0
    * @return amount1 collected amount of token1
    * @return rewards collected amount of rewards
    */
  function burnAndCollect(uint256 tokenId, uint256 amount0Min, uint256 amount1Min, uint256 deadline)
  override
  external
  checkTokenIdWithProvider(tokenId)
  whenNotPaused
  nonReentrant
  returns (uint256 amount0, uint256 amount1, uint256 rewards) {
    require(tokenId > 0, "PancakeSwapStakingHub: non-zero-tokenId");
    address provider = msg.sender;
    
    // decrease liquidity
    rewards = _decreaseLiquidityAndHarvest(
      tokenId,
      amount0Min,
      amount1Min,
      deadline
    );
    // burn LP and collect token0, token1 & reward token
    (amount0, amount1) = _burnAndCollectTokens(
      tokenId,
      IPancakeSwapV3LpProvider(provider).token0(),
      IPancakeSwapV3LpProvider(provider).token1()
    );
    // send rewards to provider
    if (rewards > 0) {
      IERC20(rewardToken).safeTransfer(msg.sender, rewards);
      emit Harvest(msg.sender, tokenId, rewards);
    }
    // remove tokenId record
    delete tokenIdToProvider[tokenId];
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
    // if token is not staked, no rewards will be harvested
    if (!_isStaked(tokenId)) {
      rewards = 0;
    } else {
      address provider = msg.sender;
      // reward token pre-balance
      uint256 preBalance = IERC20(rewardToken).balanceOf(address(this));
      // withdraw rewards from MasterChefV3
      IMasterChefV3(masterChefV3).harvest(tokenId, address(this));
      // post balance of reward token
      rewards = IERC20(rewardToken).balanceOf(address(this)) - preBalance;
      // send rewards to provider
      if (rewards > 0) {
        IERC20(rewardToken).safeTransfer(provider, rewards);
        emit Harvest(provider, tokenId, rewards);
      }
    }
  }

  ///////////////////////////////////////////////////////////////
  ////////////           Internal Functions          ////////////
  ///////////////////////////////////////////////////////////////

  /**
   * @dev Check if the token is staked at MasterChefV3
   *      otherwise, it should be inside this contract
   * @return true if the token is staked, false otherwise
   */
  function _isStaked(uint256 tokenId) internal view returns (bool) {
    // if the token is owned by MasterChefV3, then it's staked
    return IERC721(nonFungiblePositionManager).ownerOf(tokenId) == masterChefV3;
  }

  /**
    * @notice decrease liquidity for a specific tokenId and collect rewards
    * @param tokenId ID of the NFT token to burn
    * @param amount0Min minimum amount of token0 to collect
    * @param amount1Min minimum amount of token1 to collect
    */
  function _decreaseLiquidityAndHarvest(
    uint256 tokenId,
    uint256 amount0Min,
    uint256 amount1Min,
    uint256 deadline
  ) internal returns (uint256 rewardAmount) {
    // DecreaseLiquidity param
    DecreaseLiquidityParams memory params = 
      DecreaseLiquidityParams({
        tokenId: tokenId,
        liquidity: getLiquidity(tokenId),
        amount0Min: amount0Min,
        amount1Min: amount1Min,
        deadline: deadline
      });
    // check if it's inside the MasterChef contract
    if (_isStaked(tokenId)) {
      // fully remove liquidity from the tokenId
      // @note at this moment all rewards will be cached to the token's position too
      IMasterChefV3(masterChefV3).decreaseLiquidity(params);
      // Harvest will revert if no rewards + zero liquidity
      if(IMasterChefV3(masterChefV3).pendingCake(tokenId) > 0) {
          uint256 preRewardBalance = IERC20(rewardToken).balanceOf(address(this));
          // harvest reward
          IMasterChefV3(masterChefV3).harvest(tokenId, address(this));
          // calculate reward amount
          rewardAmount = IERC20(rewardToken).balanceOf(address(this)) - preRewardBalance;
      }
    } else {
      // if not staked, decrease liquidity using NonfungiblePositionManager
      INonfungiblePositionManager(nonFungiblePositionManager).decreaseLiquidity(params);
    }
  }

  /**
    * @notice to avoid stack too deep error, this function is separated from burnAndCollect()
    * @dev burn LP token, collect fees and rewards, then send them to the provider
    * @param tokenId ID of the NFT token to burn
    * @param token0 address of token0
    * @param token1 address of token1
    * @return collectedAmount0WithFees collected amount of token0
    * @return collectedAmount1WithFees collected amount of token1
    */
  function _burnAndCollectTokens(
    uint256 tokenId,
    address token0,
    address token1
  ) internal returns (
    uint256 collectedAmount0WithFees,
    uint256 collectedAmount1WithFees
  ) {
    CollectParams memory collectParams = CollectParams({
      tokenId: tokenId,
      recipient: address(this),
      amount0Max: type(uint128).max, // just put max value to collect all fees
      amount1Max: type(uint128).max // just put max value to collect all fees
    });

    // ------ Collect then burn the LP -------
    uint256 preToken0Balance = IERC20(token0).balanceOf(address(this));
    uint256 preToken1Balance = IERC20(token1).balanceOf(address(this));

    uint256 collectedAmount0; 
    uint256 collectedAmount1;
    // collect token0 and token1 including fees from the tokenId
    // check whether the token the staked
    if (_isStaked(tokenId)) {
      // collect tokens through MasterChefV3
      (collectedAmount0, collectedAmount1) = IMasterChefV3(masterChefV3).collect(collectParams);
      // burn the LP through MasterChefV3
      IMasterChefV3(masterChefV3).burn(tokenId);
    } else {
      // collect then burn through NonfungiblePositionManager
      (collectedAmount0, collectedAmount1) = INonfungiblePositionManager(nonFungiblePositionManager).collect(collectParams);
      // burn the LP through NonfungiblePositionManager
      INonfungiblePositionManager(nonFungiblePositionManager).burn(tokenId);
    }
    
    collectedAmount0WithFees = IERC20(token0).balanceOf(address(this)) - preToken0Balance;
    collectedAmount1WithFees = IERC20(token1).balanceOf(address(this)) - preToken1Balance;

    // verify amount0 and amount1
    require(
      collectedAmount0WithFees >= collectedAmount0 && collectedAmount1WithFees >= collectedAmount1,
      "PancakeSwapStakingHub: invalid-token-balances"
    );
    // transfer token0 & token 1 to provider
    if (collectedAmount0WithFees > 0) {
      IERC20(token0).safeTransfer(msg.sender, collectedAmount0WithFees);
    }
    if (collectedAmount1WithFees > 0) {
      IERC20(token1).safeTransfer(msg.sender, collectedAmount1WithFees);
    }
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
   * @dev restake LPs incase MasterChefV3 disabled the emergency mode
   * @param _tokenIds array of tokenIds to restake (obtained from NonfungiblePositionManager's balanceOf and tokenIdAtIndexOf)
   */
  function restake(uint256[] memory _tokenIds) external nonReentrant() onlyRole(MANAGER) {
    require(_tokenIds.length > 0, "PancakeSwapStakingHub: empty-tokenIds");
    for (uint256 i = 0; i < _tokenIds.length; i++) {
      uint256 tokenId = _tokenIds[i];
      if (!_isStaked(tokenId)) {
        IERC721(nonFungiblePositionManager).safeTransferFrom(address(this), masterChefV3, tokenId);
        emit ReStaked(address(this), tokenId);
      }
    }
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
    * @dev only admin can upgrade the contract
    * @param _newImplementation new implementation address
    */
  function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
