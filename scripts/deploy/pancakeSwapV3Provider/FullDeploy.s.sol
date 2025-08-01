// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { PancakeSwapV3LpProvider } from "../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpProvider.sol";
import { PancakeSwapV3LpStakingHub } from "../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpStakingHub.sol";
import { PancakeSwapV3LpStakingVault } from "../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpStakingVault.sol";
import { LpUsd } from "../../../contracts/ceros/provider/LpUsd.sol";

contract PcsV3Deployment is Script {

  PancakeSwapV3LpProvider public pcsProvider;
  PancakeSwapV3LpStakingHub public pcsStakingHub;
  PancakeSwapV3LpStakingVault public pcsStakingVault;
  LpUsd public lpUsd;

  address pancakeSwapV3Factory;
  address masterChefV3;
  address nonfungiblePositionManager;
  address interaction;
  address admin;
  address manager;
  address pauser;
  address bot;
  address token0;
  address token1;
  address cake;
  address oracle;

  uint256 MAX_LP_DEPOSIT = 5; // Max Lp can be deposit
  uint256 MIN_LP_USD = 1000 * 1e18; // 1000 LP USD
  uint256 DISCOUNT_RATE = 8000; // 80% discount rate
  uint256 REWARD_FEE_RATE = 300; // 3% reward fee rate

  uint256 deployerPrivateKey;
  address deployer;

  function setUp() public {
    // load addresses
    deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    deployer = vm.addr(deployerPrivateKey);

    pancakeSwapV3Factory = vm.envAddress("PCS_V3_FACTORY");
    masterChefV3 = vm.envAddress("MASTER_CHEF_V3");
    nonfungiblePositionManager = vm.envAddress("NON_FUNGIBLE_POSITION_MANAGER");
    admin = deployer;
    manager = vm.envAddress("MANAGER");
    pauser = vm.envAddress("PAUSER");
    bot = vm.envAddress("BOT");
    interaction = vm.envAddress("INTERACTION");
    token0 = vm.envAddress("TOKEN0");
    token1 = vm.envAddress("TOKEN1");
    cake = vm.envAddress("CAKE");
    oracle = vm.envAddress("ORACLE");
  }

  function run() public {

    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // deploy LpUSD
    lpUsd = new LpUsd(token0, token1);
    console.log("LpUsd deployed at: ", address(lpUsd));

    // deploy PCS StakingHub
    PancakeSwapV3LpStakingHub pcsStakingHubImpl = new PancakeSwapV3LpStakingHub(
      nonfungiblePositionManager,
      address(masterChefV3),
      address(cake)
    );
    ERC1967Proxy pcsStakingHubProxy = new ERC1967Proxy(
      address(pcsStakingHubImpl),
      abi.encodeWithSelector(
        PancakeSwapV3LpStakingHub.initialize.selector,
        admin,
        manager,
        pauser
      )
    );
    pcsStakingHub = PancakeSwapV3LpStakingHub(address(pcsStakingHubProxy));
    console.log("PancakeSwapV3LpStakingHub deployed at: ", address(pcsStakingHub));

    // Deploy PCS StakingVault
    PancakeSwapV3LpStakingVault pcsStakingVaultImpl = new PancakeSwapV3LpStakingVault(
      address(pcsStakingHub),
      address(cake)
    );
    ERC1967Proxy pcsStakingVaultProxy = new ERC1967Proxy(
      address(pcsStakingVaultImpl),
      abi.encodeWithSelector(
        pcsStakingVaultImpl.initialize.selector,
        admin,
        manager,
        pauser,
        address(0x5A0E3291514F5F1797A0C7eFefdac81eeC70ec01)
      )
    );
    pcsStakingVault = PancakeSwapV3LpStakingVault(address(pcsStakingVaultProxy));
    console.log("PancakeSwapV3LpStakingVault deployed at: ", address(pcsStakingVault));

    // Deploy PCS LpProvider
    PancakeSwapV3LpProvider pcsProviderImpl = new PancakeSwapV3LpProvider(
      address(interaction),
      nonfungiblePositionManager,
      address(masterChefV3),
      address(lpUsd),
      token0,
      token1,
      address(cake)
    );
    ERC1967Proxy pcsProviderProxy = new ERC1967Proxy(
      address(pcsProviderImpl),
      abi.encodeWithSelector(
        PancakeSwapV3LpProvider.initialize.selector,
        admin,
        manager,
        bot,
        pauser,
        address(pcsStakingHub),
        address(pcsStakingVault),
        address(oracle),
        MAX_LP_DEPOSIT, // Max Lp can be deposit
        MIN_LP_USD, // 1000 LP USD
        DISCOUNT_RATE // 80% discount rate
      )
    );
    pcsProvider = PancakeSwapV3LpProvider(address(pcsProviderProxy));
    console.log("PancakeSwapV3LpProvider deployed at: ", address(pcsProvider));

    lpUsd.setMinter(address(pcsProvider));
    pcsStakingHub.registerProvider(address(pcsProvider));
    pcsStakingVault.registerLpProvider(address(pcsProvider), REWARD_FEE_RATE);

    vm.stopBroadcast();
  }


}
