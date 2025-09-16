// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import { PancakeSwapV3LpStakingHub } from "../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpStakingHub.sol";

contract DeployPcsV3LpStakingHubImpl is Script {

  address masterChefV3;
  address nonfungiblePositionManager;
  address cake;

  uint256 deployerPrivateKey;
  address deployer;

  function setUp() public {
    // load addresses
    deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    deployer = vm.addr(deployerPrivateKey);

    masterChefV3 = vm.envAddress("MASTER_CHEF_V3");
    nonfungiblePositionManager = vm.envAddress("NON_FUNGIBLE_POSITION_MANAGER");
    cake = vm.envAddress("CAKE");
  }

  function run() public {

    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    PancakeSwapV3LpStakingHub pcsStakingHubImpl = new PancakeSwapV3LpStakingHub(
      nonfungiblePositionManager,
      masterChefV3,
      cake
    );

    console.log("PancakeSwapV3LpStakingHub Impl. deployed at: ", address(pcsStakingHubImpl));

    vm.stopBroadcast();
  }


}
