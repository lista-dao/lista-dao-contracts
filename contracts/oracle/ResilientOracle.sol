// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/OracleInterface.sol";

/**
 * @title ResilientOracle
 * @author Lista
 * @notice The Resilient Oracle is the main contract that the protocol uses to fetch prices of assets.
 *
 * The Resilient Oracle uses multiple sources and fallback mechanisms to provide accurate prices and protect
 * the protocol from oracle attacks.
 *
 * For every market (vToken) we configure the main, pivot and fallback oracles. The oracles are configured per
 * vToken's underlying asset address. The main oracle oracle is the most trustworthy price source, the pivot
 * oracle is used as a loose sanity checker and the fallback oracle is used as a backup price source.
 *
 * To validate prices returned from two oracles, we use an upper and lower bound ratio that is set for every
 * market. The upper bound ratio represents the deviation between reported price (the price that’s being
 * validated) and the anchor price (the price we are validating against) above which the reported price will
 * be invalidated. The lower bound ratio presents the deviation between reported price and anchor price below
 * which the reported price will be invalidated. So for oracle price to be considered valid the below statement
 * should be true:

```
anchorRatio = anchorPrice/reporterPrice
isValid = anchorRatio <= upperBoundAnchorRatio && anchorRatio >= lowerBoundAnchorRatio
```

 *
 * For a fetched price to be valid it must be positive and not stagnant. If the price is invalid then we consider the
 * oracle to be stagnant and treat it like it's disabled.
 */
contract ResilientOracle is OwnableUpgradeable, OracleInterface {
  /**
   * @dev Oracle roles:
     * **main**: The most trustworthy price source
     * **pivot**: Price oracle used as a loose sanity checker
     * **fallback**: The backup source when main oracle price is invalidated
     */
  enum OracleRole {
    MAIN,
    PIVOT,
    FALLBACK
  }

  struct TokenConfig {
    /// @notice asset address
    address asset;
    /// @notice `oracles` stores the oracles based on their role in the following order:
    /// [main, pivot, fallback],
    /// It can be indexed with the corresponding enum OracleRole value
    address[3] oracles;
    /// @notice `enableFlagsForOracles` stores the enabled state
    /// for each oracle in the same order as `oracles`
    bool[3] enableFlagsForOracles;
    /// @notice `timeDeltaTolerance` stores the tolerance of
    /// the difference between the block timestamp and the price update time
    /// the unit is seconds
    uint256 timeDeltaTolerance;
  }

  uint256 public constant INVALID_PRICE = 0;

  /// @notice Bound validator contract address
  BoundValidatorInterface public boundValidator;

  mapping(address => TokenConfig) private tokenConfigs;

  event TokenConfigAdded(
    address indexed asset,
    address indexed mainOracle,
    address indexed pivotOracle,
    address fallbackOracle,
    uint256 timeDeltaTolerance
  );

  /// Event emitted when an oracle is set
  event OracleSet(address indexed asset, address indexed oracle, uint256 indexed role);

  /// Event emitted when an oracle is enabled or disabled
  event OracleEnabled(address indexed asset, uint256 indexed role, bool indexed enable);

  /**
   * @notice Checks whether an address is null or not
     */
  modifier notNullAddress(address someone) {
    if (someone == address(0)) revert("can't be zero address");
    _;
  }

  /**
   * @notice Checks whether token config exists by checking whether asset is null address
     * @dev address can't be null, so it's suitable to be used to check the validity of the config
     * @param asset asset address
     */
  modifier checkTokenConfigExistence(address asset) {
    if (tokenConfigs[asset].asset == address(0)) revert("token config must exist");
    _;
  }

  /// @notice Initializes the contract
  function initialize(BoundValidatorInterface _boundValidator) public initializer {
    __Ownable_init();
    boundValidator = _boundValidator;
  }

  /**
   * @notice Batch sets token configs
     * @param tokenConfigs_ Token config array
     * @custom:access Only Governance
     * @custom:error Throws a length error if the length of the token configs array is 0
     */
  function setTokenConfigs(TokenConfig[] memory tokenConfigs_) external {
    if (tokenConfigs_.length == 0) revert("length can't be 0");
    uint256 numTokenConfigs = tokenConfigs_.length;
    for (uint256 i; i < numTokenConfigs; ) {
      setTokenConfig(tokenConfigs_[i]);
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice Sets oracle for a given asset and role.
     * @dev Supplied asset **must** exist and main oracle may not be null
     * @param asset Asset address
     * @param oracle Oracle address
     * @param role Oracle role
     * @custom:access Only Governance
     * @custom:error Null address error if main-role oracle address is null
     * @custom:error NotNullAddress error is thrown if asset address is null
     * @custom:error TokenConfigExistence error is thrown if token config is not set
     * @custom:event Emits OracleSet event with asset address, oracle address and role of the oracle for the asset
     */
  function setOracle(
    address asset,
    address oracle,
    OracleRole role
  ) external onlyOwner notNullAddress(asset) checkTokenConfigExistence(asset) {
    if (oracle == address(0) && role == OracleRole.MAIN) revert("can't set zero address to main oracle");
    tokenConfigs[asset].oracles[uint256(role)] = oracle;
    emit OracleSet(asset, oracle, uint256(role));
  }

  /**
   * @notice Enables/ disables oracle for the input asset. Token config for the input asset **must** exist
     * @dev Configuration for the asset **must** already exist and the asset cannot be 0 address
     * @param asset Asset address
     * @param role Oracle role
     * @param enable Enabled boolean of the oracle
     * @custom:access Only Governance
     * @custom:error NotNullAddress error is thrown if asset address is null
     * @custom:error TokenConfigExistence error is thrown if token config is not set
     */
  function enableOracle(
    address asset,
    OracleRole role,
    bool enable
  ) external onlyOwner notNullAddress(asset) checkTokenConfigExistence(asset) {
    tokenConfigs[asset].enableFlagsForOracles[uint256(role)] = enable;
    emit OracleEnabled(asset, uint256(role), enable);
  }

  /**
   * @dev Gets token config by asset address
     * @param asset asset address
     * @return tokenConfig Config for the asset
     */
  function getTokenConfig(address asset) external view returns (TokenConfig memory) {
    return tokenConfigs[asset];
  }

  /**
   * @notice Gets price of the asset
     * @param asset asset address
     * @return price USD price in scaled decimal places.
     * @custom:error Paused error is thrown when resilent oracle is paused
     * @custom:error Invalid resilient oracle price error is thrown if fetched prices from oracle is invalid
     */
  function peek(address asset) external view override returns (uint256) {
    return _getPrice(asset);
  }

  /**
   * @notice Sets/resets single token configs.
     * @dev main oracle **must not** be a null address
     * @param tokenConfig Token config struct
     * @custom:access Only Governance
     * @custom:error NotNullAddress is thrown if asset address is null
     * @custom:error NotNullAddress is thrown if main-role oracle address for asset is null
     * @custom:event Emits TokenConfigAdded event when the asset config is set successfully by the authorized account
     */
  function setTokenConfig(
    TokenConfig memory tokenConfig
  ) public onlyOwner notNullAddress(tokenConfig.asset) notNullAddress(tokenConfig.oracles[uint256(OracleRole.MAIN)]) {
    tokenConfigs[tokenConfig.asset] = tokenConfig;
    emit TokenConfigAdded(
      tokenConfig.asset,
      tokenConfig.oracles[uint256(OracleRole.MAIN)],
      tokenConfig.oracles[uint256(OracleRole.PIVOT)],
      tokenConfig.oracles[uint256(OracleRole.FALLBACK)],
      tokenConfig.timeDeltaTolerance
    );
  }

  /**
   * @notice Gets oracle and enabled status by asset address
     * @param asset asset address
     * @param role Oracle role
     * @return oracle Oracle address based on role
     * @return enabled Enabled flag of the oracle based on token config
     */
  function getOracle(address asset, OracleRole role)public view returns (address oracle, bool enabled) {
    oracle = tokenConfigs[asset].oracles[uint256(role)];
    enabled = tokenConfigs[asset].enableFlagsForOracles[uint256(role)];
  }

  /**
    * @notice Gets price from the oracle, which transform price's data type from int256 to uint256
      * @param oracle Oracle address
      * @return price USD price in scaled decimal places
      * @custom:error Invalid price error is thrown if the price fetched from the oracle is invalid
      */
  function getPriceFromOracle(address oracle, uint256 tolerance) external view returns (uint256) {
    try AggregatorV3Interface(oracle).latestRoundData() returns (
      uint80, int256 answer, uint256, uint256 updatedAt, uint80
    ) {
      if (tolerance != 0 && block.timestamp - updatedAt > tolerance) {
        return INVALID_PRICE;
      }
      return uint256(answer);
    } catch {
      return INVALID_PRICE;
    }
  }

  /**
    * @notice Gets price for the provided asset
      * @param asset asset address
      * @return price USD price in scaled decimal places
      * @custom:error Invalid price error is thrown if the price fetched from the oracle is invalid
      */
  function _getPrice(address asset) internal view returns (uint256) {
    uint256 pivotPrice = INVALID_PRICE; // 0

    // Get pivot oracle price, Invalid price if not available or error
    (address pivotOracle, bool pivotOracleEnabled) = getOracle(asset, OracleRole.PIVOT);
    if (pivotOracleEnabled && pivotOracle != address(0)) {
      try this.getPriceFromOracle(
        pivotOracle,
        tokenConfigs[asset].timeDeltaTolerance
      ) returns (uint256 pricePivot) {
        pivotPrice = pricePivot;
      } catch {}
    }

    // Compare main price and pivot price, return main price and if validation was successful
    // note: In case pivot oracle is not available but main price is available and
    // validation is successful, the main oracle price is returned.
    (uint256 mainPrice, bool validatedPivotMain) = _getMainOraclePrice(
      asset,
      pivotPrice,
      pivotOracleEnabled && pivotOracle != address(0)
    );
    if (mainPrice != INVALID_PRICE && validatedPivotMain) return mainPrice;

    // Compare fallback and pivot if main oracle comparision fails with pivot
    // Return fallback price when fallback price is validated successfully with pivot oracle
    (uint256 fallbackPrice, bool validatedPivotFallback) = _getFallbackOraclePrice(asset, pivotPrice);
    if (fallbackPrice != INVALID_PRICE && validatedPivotFallback) return fallbackPrice;

    // Lastly compare main price and fallback price
    if (
      mainPrice != INVALID_PRICE &&
      fallbackPrice != INVALID_PRICE &&
      boundValidator.validatePriceWithAnchorPrice(asset, mainPrice, fallbackPrice)
    ) {
      return mainPrice;
    }

    revert("invalid resilient oracle price");
  }

  /**
   * @notice Gets a price for the provided asset
     * @dev This function won't revert when price is 0, because the fallback oracle may still be
     * able to fetch a correct price
     * @param asset asset address
     * @param pivotPrice Pivot oracle price
     * @param pivotEnabled If pivot oracle is not empty and enabled
     * @return price USD price in scaled decimals
     * e.g. asset decimals is 8 then price is returned as 10**18 * 10**(18-8) = 10**28 decimals
     * @return pivotValidated Boolean representing if the validation of main oracle price
     * and pivot oracle price were successful
     * @custom:error Invalid price error is thrown if main oracle fails to fetch price of the asset
     * @custom:error Invalid price error is thrown if main oracle is not enabled or main oracle
     * address is null
     */
  function _getMainOraclePrice(
    address asset,
    uint256 pivotPrice,
    bool pivotEnabled
  ) internal view returns (uint256, bool) {
    (address mainOracle, bool mainOracleEnabled) = getOracle(asset, OracleRole.MAIN);
    if (mainOracleEnabled && mainOracle != address(0)) {
      try this.getPriceFromOracle(
        mainOracle,
        tokenConfigs[asset].timeDeltaTolerance
      ) returns (uint256 mainOraclePrice) {
        if (!pivotEnabled) {
          return (mainOraclePrice, true);
        }
        if (pivotPrice == INVALID_PRICE) {
          return (mainOraclePrice, false);
        }
        return (
          mainOraclePrice,
          boundValidator.validatePriceWithAnchorPrice(asset, mainOraclePrice, pivotPrice)
        );
      } catch {
        return (INVALID_PRICE, false);
      }
    }

    return (INVALID_PRICE, false);
  }

  /**
   * @dev This function won't revert when the price is 0 because getPrice checks if price is > 0
     * @param asset asset address
     * @return price USD price in 18 decimals
     * @return pivotValidated Boolean representing if the validation of fallback oracle price
     * and pivot oracle price were successfull
     * @custom:error Invalid price error is thrown if fallback oracle fails to fetch price of the asset
     * @custom:error Invalid price error is thrown if fallback oracle is not enabled or fallback oracle
     * address is null
     */
  function _getFallbackOraclePrice(address asset, uint256 pivotPrice) private view returns (uint256, bool) {
    (address fallbackOracle, bool fallbackEnabled) = getOracle(asset, OracleRole.FALLBACK);
    if (fallbackEnabled && fallbackOracle != address(0)) {
      try this.getPriceFromOracle(
        fallbackOracle,
        tokenConfigs[asset].timeDeltaTolerance
      ) returns (uint256 fallbackOraclePrice) {
        if (pivotPrice == INVALID_PRICE) {
          return (fallbackOraclePrice, false);
        }
        return (
          fallbackOraclePrice,
          boundValidator.validatePriceWithAnchorPrice(asset, fallbackOraclePrice, pivotPrice)
        );
      } catch {
        return (INVALID_PRICE, false);
      }
    }

    return (INVALID_PRICE, false);
  }
}
