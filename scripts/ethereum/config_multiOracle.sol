// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { BoundValidator } from "../../contracts/oracle/BoundValidator.sol";
import { ResilientOracle } from "../../contracts/oracle/ResilientOracle.sol";
import { MockResilientOracle } from "../../contracts/mock/multiOracles/MockResilientOracle.sol";

contract ResilientOracleConfig is Script {
  address boundValidator = 0x6e59A37BA9A1a5AbDCEE3cb37f677535dB82f7f7;
  address resilientOracle = 0x173e2400842c9352b4dea5B3D9bEf7a706Fbb81d;
  address resilientOracleAddr_mock = 0x05F8B0D79CA88A6B91419068b2Cd7eDA5a1A9b8d;

  /// @notice sepolia mock tokens
  address usdt = 0xC5543Af4dE1a3972e8D1dBd0831dE97941ACd358;
  address usdt_mockFeed = 0x8Fef3D55C365a4796B89B0ECB3f7042cBdaE3C61;
  address usd1 = 0x9AA4F208A969E1e01b4c1691322E0fEDCB8C003d;
  address stableUsdtFeed = 0x59Df2af159770F1Aae85957a2A84e9c545737724;
  address wBTC = 0xD4151B2B7087e305f29E4032f8531Be42dFf5568;
  address wBTC_mockFeed = 0x4d1d018E2925f7675bEe0DcF1f037a782583F0f0;
  address wETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
  address wETH_mockFeed = 0x0084830E4433Cd521F1a8440dD14B4F7f2Af5BC4;

  address cbBTC = 0x95188a991d9779C9B98C9c4b6b9632C59cD774ee;
  address cbBTC_mockFeed = 0x4d1d018E2925f7675bEe0DcF1f037a782583F0f0;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    ResilientOracle.TokenConfig[] memory tokenConfigs = new ResilientOracle.TokenConfig[](5);

    ResilientOracle.TokenConfig memory _usdt = ResilientOracle.TokenConfig({
      asset: usdt,
      oracles: [usdt_mockFeed, address(0), address(0)],
      enableFlagsForOracles: [true, false, false],
      timeDeltaTolerance: 36000000
    });

    ResilientOracle.TokenConfig memory _usd1 = ResilientOracle.TokenConfig({
      asset: usd1,
      oracles: [stableUsdtFeed, address(0), address(0)],
      enableFlagsForOracles: [true, false, false],
      timeDeltaTolerance: 36000000
    });
    ResilientOracle.TokenConfig memory _wBTC = ResilientOracle.TokenConfig({
      asset: wBTC,
      oracles: [wBTC_mockFeed, address(0), address(0)],
      enableFlagsForOracles: [true, false, false],
      timeDeltaTolerance: 36000000
    });
    ResilientOracle.TokenConfig memory _wETH = ResilientOracle.TokenConfig({
      asset: wETH,
      oracles: [wETH_mockFeed, address(0), address(0)],
      enableFlagsForOracles: [true, false, false],
      timeDeltaTolerance: 36000000
    });
    ResilientOracle.TokenConfig memory _cbBTC = ResilientOracle.TokenConfig({
      asset: cbBTC,
      oracles: [cbBTC_mockFeed, address(0), address(0)],
      enableFlagsForOracles: [true, false, false],
      timeDeltaTolerance: 36000000
    });

    tokenConfigs[0] = _usdt;
    tokenConfigs[1] = _usd1;
    tokenConfigs[2] = _wBTC;
    tokenConfigs[3] = _wETH;
    tokenConfigs[4] = _cbBTC;

    ResilientOracle(resilientOracle).setTokenConfigs(tokenConfigs);

    BoundValidator.ValidateConfig[] memory configs = new BoundValidator.ValidateConfig[](5);
    BoundValidator.ValidateConfig memory usdtConfig = BoundValidator.ValidateConfig({
      asset: usdt,
      upperBoundRatio: 1010000000000000000, // 1.01
      lowerBoundRatio: 990000000000000000 // 0.99
    });
    BoundValidator.ValidateConfig memory usd1Config = BoundValidator.ValidateConfig({
      asset: usd1,
      upperBoundRatio: 1010000000000000000, // 1.01
      lowerBoundRatio: 990000000000000000 // 0.99
    });
    BoundValidator.ValidateConfig memory wbtcConfig = BoundValidator.ValidateConfig({
      asset: wBTC,
      upperBoundRatio: 1010000000000000000, // 1.01
      lowerBoundRatio: 990000000000000000 // 0.99
    });
    BoundValidator.ValidateConfig memory wethConfig = BoundValidator.ValidateConfig({
      asset: wETH,
      upperBoundRatio: 1010000000000000000, // 1.01
      lowerBoundRatio: 990000000000000000
    });
    BoundValidator.ValidateConfig memory cbBtcConfig = BoundValidator.ValidateConfig({
      asset: cbBTC,
      upperBoundRatio: 1010000000000000000, // 1.01
      lowerBoundRatio: 990000000000000000 // 0.99
    });

    configs[0] = usdtConfig;
    configs[1] = usd1Config;
    configs[2] = wbtcConfig;
    configs[3] = wethConfig;
    configs[4] = cbBtcConfig;

    BoundValidator(boundValidator).setValidateConfigs(configs);

    sync_mockPrice();

    vm.stopBroadcast();
  }

  function sync_mockPrice() public {
    MockResilientOracle mockOracle = MockResilientOracle(resilientOracleAddr_mock);

    address[] memory assets = new address[](5);
    assets[0] = usdt;
    assets[1] = usd1;
    assets[2] = wBTC;
    assets[3] = wETH;
    assets[4] = cbBTC;

    for (uint i = 0; i < assets.length; i++) {
      mockOracle.syncRealPrice(assets[i]);
    }
  }
}
