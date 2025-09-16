// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import { PancakeSwapV3LpProvider } from "../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpProvider.sol";

contract DeployPcsV3LpProviderImpl is Script {

  address masterChefV3;
  address nonfungiblePositionManager;
  address interaction;
  address token0;
  address token1;
  address cake;
  address lpUsd;

  uint256 deployerPrivateKey;
  address deployer;

  function setUp() public {
    // load addresses
    deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    deployer = vm.addr(deployerPrivateKey);

    masterChefV3 = vm.envAddress("MASTER_CHEF_V3");
    nonfungiblePositionManager = vm.envAddress("NON_FUNGIBLE_POSITION_MANAGER");
    interaction = vm.envAddress("INTERACTION");
    token0 = vm.envAddress("TOKEN0");
    token1 = vm.envAddress("TOKEN1");
    cake = vm.envAddress("CAKE");
    lpUsd = vm.envAddress("LP_USD");
  }

  function run() public {

    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

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
    console.log("PancakeSwapV3LpProvider deployed at: ", address(pcsProviderImpl));

    vm.stopBroadcast();
  }


}
