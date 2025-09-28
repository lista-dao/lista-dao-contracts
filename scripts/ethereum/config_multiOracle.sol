// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { BoundValidator } from "../../contracts/oracle/BoundValidator.sol";
import { ResilientOracle } from "../../contracts/oracle/ResilientOracle.sol";
import { MockResilientOracle } from "../../contracts/mock/multiOracles/MockResilientOracle.sol";

contract ResilientOracleConfig is Script {
  address boundValidator = 0x3127b40bd2E591BFa088CA98b92ED9a41dD370a1;
  address resilientOracle = 0xA64FE284EB8279B9b63946DD51813b0116099301;

  address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address usdt_chainlink = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
  address usdt_redstone = 0x02E1F8d15762047b7a87BA0E5d94B9a0c5b54Ed2;

  address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address weth_chainlink = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
  address weth_redstone = 0x67F6838e58859d612E4ddF04dA396d6DABB66Dc4;

  address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
  address wbtc_chainlink = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
  address wbtc_redstone = 0xAB7f623fb2F6fea6601D4350FA0E2290663C28Fc;

  address USD1 = 0x8d0D000Ee44948FC98c9B98A4FA4921476f08B0d;
  address usd1_priceFeed = 0x8B35291ecF29fD36BA405A03C9832725f2E9e164;

  address cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
  address bTC_chainlink_svr = 0xb41E773f507F7a7EA890b1afB7d2b660c30C8B0A;

  address wBETH = 0xa2E3356610840701BDf5611a53974510Ae27E2e1;
  address wbeth_priceFeed = 0x0709755A26b78Ce8e1F4cAB598AC7477858C4aA2;

  address wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address wsteth_priceFeed = 0x36B0AE9841C68dB46D8435760680134089ce166d;

  uint256 upperBond_101 = 1010000000000000000; // 1.01
  uint256 lowerBond_099 = 990000000000000000; // 0.99

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_BSC_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    ResilientOracle.TokenConfig[] memory tokenConfigs = new ResilientOracle.TokenConfig[](7);
    ResilientOracle.TokenConfig memory _usdt = ResilientOracle.TokenConfig({
      asset: USDT,
      oracles: [usdt_chainlink, usdt_redstone, usdt_chainlink],
      enableFlagsForOracles: [true, true, true],
      timeDeltaTolerance: 86700 // 24 hr + 5 min
    });

    ResilientOracle.TokenConfig memory _weth = ResilientOracle.TokenConfig({
      asset: WETH,
      oracles: [weth_chainlink, weth_redstone, weth_chainlink],
      enableFlagsForOracles: [true, true, true],
      timeDeltaTolerance: 86700 // 24 hr + 5 min
    });

    ResilientOracle.TokenConfig memory _wbtc = ResilientOracle.TokenConfig({
      asset: WBTC,
      oracles: [wbtc_chainlink, wbtc_redstone, wbtc_chainlink],
      enableFlagsForOracles: [true, true, true],
      timeDeltaTolerance: 86700 // 24 hr + 5 min
    });

    ResilientOracle.TokenConfig memory _usd1 = ResilientOracle.TokenConfig({
      asset: USD1,
      oracles: [usd1_priceFeed, address(0), address(0)],
      enableFlagsForOracles: [true, false, false],
      timeDeltaTolerance: 360
    });
    ResilientOracle.TokenConfig memory _cbBTC = ResilientOracle.TokenConfig({
      asset: cbBTC,
      oracles: [bTC_chainlink_svr, address(0), address(0)],
      enableFlagsForOracles: [true, false, false],
      timeDeltaTolerance: 3900 // 65 min
    });

    ResilientOracle.TokenConfig memory _wbETH = ResilientOracle.TokenConfig({
      asset: wBETH,
      oracles: [wbeth_priceFeed, address(0), address(0)],
      enableFlagsForOracles: [true, false, false],
      timeDeltaTolerance: 360
    });

    ResilientOracle.TokenConfig memory _wstETH = ResilientOracle.TokenConfig({
      asset: wstETH,
      oracles: [wsteth_priceFeed, address(0), address(0)],
      enableFlagsForOracles: [true, false, false],
      timeDeltaTolerance: 360
    });

    tokenConfigs[0] = _usdt;
    tokenConfigs[1] = _weth;
    tokenConfigs[2] = _wbtc;
    tokenConfigs[3] = _usd1;
    tokenConfigs[4] = _cbBTC;
    tokenConfigs[5] = _wbETH;
    tokenConfigs[6] = _wstETH;

    ResilientOracle(resilientOracle).setTokenConfigs(tokenConfigs);

    BoundValidator.ValidateConfig[] memory configs = new BoundValidator.ValidateConfig[](7);

    BoundValidator.ValidateConfig memory usdtConfig = BoundValidator.ValidateConfig({
      asset: USDT,
      upperBoundRatio: upperBond_101,
      lowerBoundRatio: lowerBond_099
    });
    BoundValidator.ValidateConfig memory wethConfig = BoundValidator.ValidateConfig({
      asset: WETH,
      upperBoundRatio: upperBond_101,
      lowerBoundRatio: lowerBond_099
    });
    BoundValidator.ValidateConfig memory wbtcConfig = BoundValidator.ValidateConfig({
      asset: WBTC,
      upperBoundRatio: upperBond_101,
      lowerBoundRatio: lowerBond_099
    });

    BoundValidator.ValidateConfig memory usd1Config = BoundValidator.ValidateConfig({
      asset: USD1,
      upperBoundRatio: upperBond_101,
      lowerBoundRatio: lowerBond_099
    });
    BoundValidator.ValidateConfig memory cbBtcConfig = BoundValidator.ValidateConfig({
      asset: cbBTC,
      upperBoundRatio: upperBond_101,
      lowerBoundRatio: lowerBond_099
    });

    BoundValidator.ValidateConfig memory wbETHConfig = BoundValidator.ValidateConfig({
      asset: wBETH,
      upperBoundRatio: upperBond_101,
      lowerBoundRatio: lowerBond_099
    });

    BoundValidator.ValidateConfig memory wstETHConfig = BoundValidator.ValidateConfig({
      asset: wstETH,
      upperBoundRatio: upperBond_101,
      lowerBoundRatio: lowerBond_099
    });

    configs[0] = usdtConfig;
    configs[1] = wethConfig;
    configs[2] = wbtcConfig;
    configs[3] = usd1Config;
    configs[4] = cbBtcConfig;
    configs[5] = wbETHConfig;
    configs[6] = wstETHConfig;

    BoundValidator(boundValidator).setValidateConfigs(configs);

    // peek the price after configuration
    uint256 price = ResilientOracle(resilientOracle).peek(USDT);
    console.log("USDT price: ", price);
    price = ResilientOracle(resilientOracle).peek(WETH);
    console.log("WETH price: ", price);
    price = ResilientOracle(resilientOracle).peek(WBTC);
    console.log("WBTC price: ", price);
    price = ResilientOracle(resilientOracle).peek(USD1);
    console.log("USD1 price: ", price);
    price = ResilientOracle(resilientOracle).peek(cbBTC);
    console.log("cbBTC price: ", price);
    price = ResilientOracle(resilientOracle).peek(wBETH);
    console.log("wBETH price: ", price);
    price = ResilientOracle(resilientOracle).peek(wstETH);
    console.log("wstETH price: ", price);

    vm.stopBroadcast();
  }
  /*
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
  */
}
