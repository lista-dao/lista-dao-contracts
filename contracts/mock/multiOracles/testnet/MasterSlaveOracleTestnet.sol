// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;

import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/IListaOracle.sol";

contract MasterSlaveOracleTestnet is IListaOracleTestnet {

  enum OracleRole {
    MAIN,
    FALLBACK
  }

  struct TokenConfig {
    address asset;
    /// [active, standby],
    address[2] oracles;
    bool[2] enableFlagsForOracles;
  }

  mapping(address => TokenConfig) private tokenConfigs;

  mapping(address => address[2]) public assetToOracle;

  function setTokenConfig(
    TokenConfig memory tokenConfig
  ) external {
    tokenConfigs[tokenConfig.asset] = tokenConfig;
  }

  function getOracle(address asset, OracleRole role) public view returns (address oracle, bool enabled) {
    oracle = tokenConfigs[asset].oracles[uint256(role)];
    enabled = tokenConfigs[asset].enableFlagsForOracles[uint256(role)];
  }

  function getPrice(address asset) external view returns (int256) {
    // get main oracle
    (address mainOracle, bool mainOracleEnabled) = getOracle(asset, OracleRole.MAIN);
    // get price from main masterOracle
    (
    /*uint80 roundID*/,
      int256 mainPrice,
    /*uint startedAt*/,
    /*uint timeStamp*/,
    /*uint80 answeredInRound*/
    ) = AggregatorV3Interface(mainOracle).latestRoundData();
    if (mainPrice > 0) {
      return mainPrice;
    }
    // get main oracle
    (address fallbackOracle, bool fallbackOracleEnabled) = getOracle(asset, OracleRole.FALLBACK);
    // get price from main slaveOracle
    (
    /*uint80 roundID*/,
      int256 fallbackPrice,
    /*uint startedAt*/,
    /*uint timeStamp*/,
    /*uint80 answeredInRound*/
    ) = AggregatorV3Interface(fallbackOracle).latestRoundData();
    if (fallbackPrice > 0) {
      return fallbackPrice;
    }
    revert("MasterSlaveOracle/price-invalid");
  }

}
