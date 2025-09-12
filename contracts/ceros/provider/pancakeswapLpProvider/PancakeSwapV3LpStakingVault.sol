// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../../interfaces/IPancakeSwapV3LpStakingHub.sol";
import "../../interfaces/IPancakeSwapV3LpProvider.sol";
import "../../interfaces/IPancakeSwapV3LpStakingVault.sol";

import "../../../oracle/libraries/FullMath.sol";

contract PancakeSwapV3LpStakingVault is
IPancakeSwapV3LpStakingVault,
PausableUpgradeable,
ReentrancyGuardUpgradeable,
AccessControlEnumerableUpgradeable,
UUPSUpgradeable
{
  using SafeERC20 for IERC20;

  /// @dev ROLES
  bytes32 public constant MANAGER = keccak256("MANAGER");
  bytes32 public constant PAUSER = keccak256("PAUSER");

  // fee rate denominator
  uint256 public constant DENOMINATOR = 10000;
  // PancakeSwap Staking Hub address
  address public immutable stakingHub;
  // CAKE token address
  address public immutable rewardToken;
  // lp Proxy address
  address public lpProxy;

  // PancakeSwapV3LpProvider address => fee rate
  mapping(address => uint256) public feeRates;
  // registered providers
  mapping(address => bool) public lpProviders;
  // available fees
  uint256 public availableFees;

  /// @dev MODIFIERS
  modifier onlyLpProxy() {
      require(msg.sender == lpProxy, "PancakeSwapV3LpStakingVault: caller-is-not-lp-proxy");
      _;
  }

  modifier onlyLpProvider() {
      require(lpProviders[msg.sender], "PancakeSwapV3LpStakingVault: caller-is-not-lp-provider");
      _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor(
    address _stakingHub,
    address _rewardToken
  ) {
    require(
      _stakingHub != address(0) &&
      _rewardToken != address(0),
      "PancakeSwapV3LpStakingVault: zero-address-provided"
    );

    stakingHub = _stakingHub;
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
    address _pauser,
    address _lpProxy
  ) public initializer {
    require(
      _admin != address(0) &&
      _manager != address(0) &&
      _pauser != address(0) &&
      _lpProxy != address(0),
      "PancakeSwapV3LpStakingVault: zero-address-provided"
    );
    __Pausable_init();
    __ReentrancyGuard_init();
    __AccessControlEnumerable_init();
    __UUPSUpgradeable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    _setupRole(MANAGER, _manager);
    _setupRole(PAUSER, _pauser);

    lpProxy = _lpProxy;
  }

  ///////////////////////////////////////////////////////////////
  ////////////           External Functions          ////////////
  ///////////////////////////////////////////////////////////////

  /**
    * @dev fee cut before give user
    * @param amount amount of rewards
    * @return rewardAfterFeeCut amount after fee cut
    * @return fee amount of fee cut
    */
  function feeCut(uint256 amount) override external onlyLpProvider whenNotPaused nonReentrant returns (uint256 rewardAfterFeeCut, uint256 fee) {
    require(amount > 0, "PancakeSwapLpStakingVault: zero-amount-provided");
    // cut fee
    uint256 feeRate = feeRates[msg.sender];
    rewardAfterFeeCut = amount;
    if (feeRate > 0) {
      fee = FullMath.mulDivRoundingUp(amount, feeRate, DENOMINATOR);
      availableFees += fee;
      rewardAfterFeeCut -= fee;
    }
    // emit Fee cut event (provider address, amount, fee rate)
    emit FeeCut(msg.sender, amount, feeRate);
  }

  /**
    * @dev batch claim rewards via proxy
    * @param account user address
    * @param providers provider addresses
    */
  function batchClaimRewardsWithProxy(address account, address[] memory providers, uint256[][] memory tokenIds) external onlyLpProxy whenNotPaused nonReentrant {
    require(account != address(0), "PancakeSwapLpStakingVault: zero-address-provided");
    _batchClaimRewards(account, providers, tokenIds);
  }

  /**
    * @dev batch claim rewards
    * @param providers provider addresses
    */
  function batchClaimRewards(address[] memory providers, uint256[][] memory tokenIds) external whenNotPaused nonReentrant {
    _batchClaimRewards(msg.sender, providers, tokenIds);
  }

  /**
    * @dev claim rewards from PancakeSwap Staking Hub and send to account
    * @param account user address
    * @param providers PancakeSwapLpProvider addresses
    */
  function _batchClaimRewards(address account, address[] memory providers, uint256[][] memory tokenIds) private {
    require(account != address(0), "PancakeSwapLpStakingVault: zero-address-provided");
    require(providers.length > 0, "PancakeSwapLpStakingVault: no-providers-provided");
    require(tokenIds.length == providers.length, "PancakeSwapLpStakingVault: tokenIds-length-mismatch");
    uint256 total;
    for (uint16 i = 0; i < providers.length; ++i) {
      uint256[] memory _tokenIds = tokenIds[i];
      address provider = providers[i];
      require(_tokenIds.length > 0, "PancakeSwapLpStakingVault: no-tokenIds");
      require(lpProviders[provider], "PancakeSwapLpStakingVault: provider-not-registered");
      uint256 amount = IPancakeSwapV3LpProvider(provider).vaultClaimStakingReward(account, _tokenIds);
      // cut fee
      uint256 feeRate = feeRates[provider];
      if (feeRate > 0) {
          uint256 fee = FullMath.mulDivRoundingUp(amount, feeRate, DENOMINATOR);
          availableFees += fee;
          amount -= fee;
      }
      total += amount;
    }
    if (total > 0) {
      IERC20(rewardToken).safeTransfer(account, total);
    }
  }

  ///////////////////////////////////////////////////////////////
  ////////////             Administrative            ////////////
  ///////////////////////////////////////////////////////////////

  /**
   * @dev collect fees
   * @param recipient recipient address
   */
  function collectFees(address recipient) external onlyRole(MANAGER) {
    require(recipient != address(0), "PancakeSwapLpStakingVault: zero-address-provided");
    require(availableFees > 0, "PancakeSwapLpStakingVault: no fees to collect");
    uint256 fees = availableFees;
    availableFees = 0;
    IERC20(rewardToken).safeTransfer(recipient, fees);
    emit CollectFees(recipient, fees);
  }

  /**
    * @dev set LpProxy address
    * @param _lpProxy LpProxy address
    */
  function setLpProxy(address _lpProxy) external onlyRole(MANAGER) {
    require(_lpProxy != address(0) && lpProxy != _lpProxy, "PancakeSwapLpStakingVault: invalid-lpProxy-address");
    address oldLpProxy = lpProxy;
    lpProxy = _lpProxy;
    emit LpProxyUpdated(oldLpProxy, _lpProxy);
  }

  /**
    * @dev set PancakeSwapLpProvider fee rate
    * @param provider PancakeSwapLpProvider address
    * @param feeRate fee rate in basis points (0-10000)
    */
  function setLpProviderFeeRate(address provider, uint256 feeRate) external onlyRole(MANAGER) {
    require(provider != address(0) && lpProviders[provider], "PancakeSwapLpStakingVault: provider-not-registered");
    uint256 oldFeeRate = feeRates[provider];
    require(feeRate != oldFeeRate && feeRate <= DENOMINATOR, "PancakeSwapLpStakingVault: invalid-fee-rate");
    lpProviders[provider] = true;
    feeRates[provider] = feeRate;
    emit FeeRateUpdated(provider, oldFeeRate, feeRate);
  }

  /**
    * @dev register PancakeSwapLpProvider
    * @param provider PancakeSwapLpProvider address
    * @param feeRate fee rate in basis points (0-10000)
    */
  function registerLpProvider(address provider, uint256 feeRate) external onlyRole(MANAGER) {
    require(
      provider != address(0) &&
      !lpProviders[provider],
      "PancakeSwapLpStakingVault: provider-already-registered"
    );
    require(feeRate <= DENOMINATOR, "PancakeSwapLpStakingVault: invalid-fee-rate");
    lpProviders[provider] = true;
    feeRates[provider] = feeRate;
    emit LpProviderRegistered(provider, feeRate);
  }

  /**
    * @dev deregister PancakeSwapLpProvider
    * @param provider PancakeSwapLpProvider address
    */
  function deregisterLpProvider(address provider) external onlyRole(MANAGER) {
    require(
      provider != address(0) &&
      lpProviders[provider],
      "PancakeSwapLpStakingVault: provider-not-registered"
    );
    lpProviders[provider] = false;
    feeRates[provider] = 0;
    emit LpProviderDeregistered(provider);
  }

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
    * @dev only admin can upgrade the contract
    * @param _newImplementation new implementation address
    */
  function _authorizeUpgrade(address _newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
