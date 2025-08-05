// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { MintableERC20 } from "../../../contracts/ceros/mocks/MintableERC20.sol";

contract DeployMockTokens is Script {

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    address token0 = address(new MintableERC20("LST0", "LISTA-TOKEN-0"));
    address token1 = address(new MintableERC20("LST1", "LISTA-TOKEN-1"));

    console.log("Token0: ", token0);
    console.log("Token1: ", token1);
    vm.stopBroadcast();
  }
}
