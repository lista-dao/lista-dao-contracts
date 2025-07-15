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

import "../../interfaces/IPancakeSwapV3StakingHub.sol";
import "../../interfaces/IMasterChefV3.sol";

contract PancakeSwapStakingHub is
IPancakeSwapV3StakingHub,
PausableUpgradeable,
ReentrancyGuardUpgradeable,
AccessControlEnumerableUpgradeable,
UUPSUpgradeable
{

  /// @dev ROLES
  bytes32 public constant MANAGER = keccak256("MANAGER");
  bytes32 public constant PAUSER = keccak256("PAUSER");

  // @dev share the same config among difference types of PancakeSwap V3+ LPs
  // provider => LpStaking
  mapping(address => LpProviderStaking) public providers;

  // @dev ------ V3 LP exclusive ------
  // MasterChefV3(V3 farming contract) address
  address public masterChefV3;
  // emergency mode for V3
  bool public emergencyModeV3;
  // holding of tokenIds
  uint256[] private tokenIdsV3;

  // @dev ----- Infinity LP exclusive(PENDING) -----


  // @dev MODIFIERS
  modifier onlyProvider() {
    require(providers[msg.sender].isActive, "PancakeSwapStakingHub: inactive-provider");
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
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
    address _pauser,
    address _masterChefV3
  ) external initializer {
    require(
      _admin != address(0) &&
      _manager != address(0) &&
      _pauser != address(0) &&
      _masterChefV3 != address(0),
      "zero-address-provided"
    );

    __Pausable_init();
    __ReentrancyGuard_init();
    __AccessControlEnumerable_init();

    _setupRole(ADMIN, _admin);
    _setupRole(MANAGER, _manager);
    _setupRole(PAUSER, _pauser);

    masterChefV3 = _masterChefV3;
  }

  ///////////////////////////////////////////////////////////////
  ////////////           External Functions          ////////////
  ///////////////////////////////////////////////////////////////

  function deposit(uint256 payload) external onlyProvider whenNotPaused nonReentrant {
    require(payload > 0, "PancakeSwapStakingHub: deposit-non-zero-amount");
    // get provider config
    LpProviderStaking storage provider = providers[msg.sender];
    if (provider.lpType == LpType.V3) {
      _depositV3(provider, payload);
    }
    // @notice Infinity are not supported at the moment
    revert("PancakeSwapStakingHub: unsupported-lp-type");
  }

  function withdraw(uint256 payload) external onlyProvider whenNotPaused nonReentrant returns (uint256) {
    require(payload > 0, "PancakeSwapStakingHub: withdraw-non-zero-amount");
    // get provider config
    LpProviderStaking storage provider = providers[msg.sender];
    // process deposit according to lpType
    if (provider.lpType == LpType.V3) {
      return _withdrawV3(provider, payload);
    }
    // @notice Infinity LPs are not supported at the moment
    revert("PancakeSwapStakingHub: unsupported-lp-type");
  }

  function harvest(uint256 payload) external onlyProvider whenNotPaused nonReentrant returns (uint256) {
    require(payload > 0, "PancakeSwapStakingHub: harvest-non-zero-amount");
    // get provider config
    LpProviderStaking storage provider = providers[msg.sender];
    // process harvest according to lpType
    if (provider.lpType == LpType.V3) {
      return _harvestV3(provider, payload);
    }
    // @notice Infinity LPs are not supported at the moment
    revert("PancakeSwapStakingHub: unsupported-lp-type");
  }

  ///////////////////////////////////////////////////////////////
  ////////////     Internal Functions(V3|Infinity)    ////////////
  ///////////////////////////////////////////////////////////////

  /**
    * @dev deposit LP token to V3 provider, then stake it to MasterChefV3
    * @param provider LpProviderStaking struct containing provider information
    * @param tokenId ID of the NFT token to deposit
    */
  function _depositV3(LpProviderStaking provider, uint256 tokenId) internal {
    // transfer token from provider to MasterChefV3
    IERC721(provider.lpToken).safeTransferFrom(msg.sender, masterChefV3, tokenId);
    // record tokenId
    tokenIdsV3.push(tokenId);

    emit DepositV3Lp(provider.provider, tokenId);
  }

  /**
    * @dev withdraw LP token from MasterChefV3, send NFT and reward token to the provider
    * @param provider LpProviderStaking struct containing provider information
    * @param tokenId ID of the NFT token to withdraw
    */
  function _withdrawV3(LpProviderStaking provider, uint256 tokenId) internal returns (uint256 _rewards) {
    // get reward token
    IERC20 rewardToken = IERC20(provider.rewardToken);
    // reward token pre-balance
    uint256 preBalance = rewardToken.balanceOf(address(this));
    // withdraw token from MasterChefV3
    _rewards = IMasterChefV3(masterChefV3).withdraw(tokenId, address(this));
    // post balance of reward token
    uint256 postBalance = rewardToken.balanceOf(address(this));
    require(postBalance == preBalance + _rewards, "PancakeSwapStakingHub: invalid-reward-balance");
    // send rewards and NFT to provider
    if (_rewards > 0) {
      // send rewards to provider
      rewardToken.safeTransfer(provider.provider, _rewards);
      emit Harvest(masterChefV3, provider.provider, _rewards);
    }
    // transfer NFT back to the provider
    IERC721(provider.lpToken).safeTransferFrom(address(this), provider.provider, tokenId);
    // remove if from tokenIdsV3
    for (uint256 i = 0; i < tokenIdsV3.length; i++) {
      if (tokenIdsV3[i] == tokenId) {
        tokenIdsV3[i] = tokenIdsV3[tokenIdsV3.length - 1];
        tokenIdsV3.pop();
        break;
      }
    }
    emit WithdrawV3Lp(provider.provider, tokenId, _rewards);
  }

  /**
    * @dev harvest rewards for V3 provider
    * @param tokenId ID of the NFT token to harvest
    */
  function _harvestV3(LpProviderStaking provider, uint256 tokenId) internal returns (uint256 _rewards){
    // get reward token
    IERC20 rewardToken = IERC20(provider.rewardToken);
    // reward token pre-balance
    uint256 preBalance = rewardToken.balanceOf(address(this));
    // withdraw rewards from MasterChefV3
    _rewards = IMasterChefV3(masterChefV3).harvest(tokenId, address(this));
    // post balance of reward token
    uint256 postBalance = rewardToken.balanceOf(address(this));
    require(postBalance == preBalance + _rewards, "PancakeSwapStakingHub: invalid-reward-balance");
    // send rewards to provider
    if (_rewards > 0) {
      rewardToken.safeTransfer(provider.provider, _rewards);
      emit HarvestV3(masterChefV3, provider.provider, tokenId, _rewards);
    }
  }

  /**
    * @dev callback function for receiving LP tokens
    * @param operator address of the operator
    * @param from address of the sender
    * @param tokenId ID of the token being sent
    * @param data additional data sent with the transfer
    * @return bytes4 selector of the function
    */
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external returns (bytes4) {
    // LP token must coming from active providers or MasterChefV3
    require(
      providers[from].isActive || msg.sender == masterChefV3,
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
  function togglePause() external onlyRole(MANAGER) {
    paused() ? _unpause() : _pause();
  }

  /**
    * @dev register staking pool
    * @param lpToken lp token address
    * @param poolAddress staking pool address
    * @param distributor distributor address
    */
  function registerProvider(
    address provider,
    address lpToken,
    address rewardToken,
    LpType lpType,
    uint256 minHarvestInterval
  ) external onlyRole(MANAGER) {
    require(!providers[provider].isActive, "PancakeSwapStakingHub: Pool is already registered");
    require(
      provider != address(0) &&
      lpToken != address(0) &&
      rewardToken != address(0) &&
      vault != address(0),
      "PancakeSwapStakingHub: zero-address-provided"
    );
    providers[provider] = LpProviderStaking({
      lpToken : lpToken,
      rewardToken : rewardToken,
      provider: provider,
      lpType: lpType,
      isActive : true,
      lpType: lpType
    });

    emit RegisterProvider(
      provider,
      lpToken,
      rewardToken,
      lpType
    );
  }

  /**
    * @dev stop emergency mode
    * @notice No staking is required for Infinity LP, so this function is only applicable for V3 LP
    */
  function stopEmergencyMode() external onlyOwner nonReentrant {
    require(emergencyModeV3, "PancakeSwapStakingHub: not-in-emergency-mode");
    require(IMasterChefV3(masterChefV3).emergency(), "PancakeSwapStakingHub: masterChefV3-is-in-emergency-mode");
    emergencyModeV3 = false;
    // transfer all LP back to MasterChefV3 for farming
    for (uint256 i = 0; i < tokenIdsV3.length; i++) {
      IMasterChefV3(masterChefV3).deposit(tokenIdsV3[i], address(this));
    }
    emit StopEmergencyMode();
  }

  /**
    * @dev emergency withdraw all LPs from the farming contract of specific LP version
    * @notice No staking is required for Infinity LP, so this function is only applicable for V3 LP
    */
  function emergencyWithdraw() external onlyOwner nonReentrant {
    require(!emergencyModeV3, "PancakeSwapStakingHub: already-in-emergency-mode");
    require(IMasterChefV3(masterChefV3).emergency(), "PancakeSwapStakingHub: masterChefV3-not-in-emergency-mode");
    emergencyModeV3 = false;
    // withdraw all tokenIdsV3 from MasterChefV3
    for (uint256 i = 0; i < tokenIdsV3.length; i++) {
      IMasterChefV3(masterChefV3).withdraw(tokenIdsV3[i], address(this));
    }
    emit EmergencyWithdraw();
  }

  /**
    * @dev only admin can upgrade the contract
    * @param _newImplementation new implementation address
    */
  function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
