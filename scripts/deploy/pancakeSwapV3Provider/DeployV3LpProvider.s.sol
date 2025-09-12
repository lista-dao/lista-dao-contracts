// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { PancakeSwapV3LpProvider } from "../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpProvider.sol";
import { PancakeSwapV3LpStakingHub } from "../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpStakingHub.sol";
import { PancakeSwapV3LpStakingVault } from "../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpStakingVault.sol";
import { LpUsd } from "../../../contracts/ceros/provider/LpUsd.sol";

contract PcsV3Deployment is Script {

  PancakeSwapV3LpProvider public pcsProvider;
  PancakeSwapV3LpStakingHub public pcsStakingHub;
  PancakeSwapV3LpStakingVault public pcsStakingVault;
  LpUsd public lpUsd;

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
  address timelock;

  uint256 MAX_LP_DEPOSIT = 5; // Max Lp can be deposit
  uint256 MIN_LP_USD = 1000 * 1e18; // 1000 LP USD
  uint256 DISCOUNT_RATE = 10000; // 100% discount rate
  uint256 REWARD_FEE_RATE = 300; // 3% reward fee rate

  uint256 deployerPrivateKey;
  address deployer;

  function setUp() public {
    // load addresses
    deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    deployer = vm.addr(deployerPrivateKey);

    pcsStakingVault = PancakeSwapV3LpStakingVault(
      vm.envAddress("PCS_STAKING_VAULT")
    );
    pcsStakingHub = PancakeSwapV3LpStakingHub(
      vm.envAddress("PCS_STAKING_HUB")
    );

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
    timelock = vm.envAddress("TIMELOCK");
  }

  function run() public {

    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // deploy LpUSD
    lpUsd = new LpUsd(token0, token1);
    console.log("LpUsd deployed at: ", address(lpUsd));

    string memory token0Name = IERC20Metadata(token0).symbol();
    string memory token1Name = IERC20Metadata(token1).symbol();
    string memory name = string(abi.encodePacked("Lista-PancakeSwap ", token0Name, "/", token1Name, " V3-LP Provider"));

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
        admin,
        bot,
        pauser,
        address(pcsStakingHub),
        address(pcsStakingVault),
        address(oracle),
        MAX_LP_DEPOSIT, // Max Lp can be deposit
        MIN_LP_USD, // 1000 LP USD
        DISCOUNT_RATE, // 80% discount rate
        name
      )
    );
    pcsProvider = PancakeSwapV3LpProvider(address(pcsProviderProxy));
    console.log("PancakeSwapV3LpProvider deployed at: ", address(pcsProvider));

    lpUsd.setMinter(address(pcsProvider));
    pcsStakingHub.registerProvider(address(pcsProvider));
    pcsStakingVault.registerLpProvider(address(pcsProvider), REWARD_FEE_RATE);
    lpUsd.transferOwnership(timelock);

    // grant manager as MANAGER as well
    bytes32 MANAGER = keccak256("MANAGER");
    bytes32 DEFAULT_ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    pcsProvider.grantRole(MANAGER, manager);
    pcsProvider.grantRole(DEFAULT_ADMIN_ROLE, timelock);

    vm.stopBroadcast();
  }
}
