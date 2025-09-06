// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

import { SlisBNBProvider } from "../../../contracts/ceros/provider/SlisBNBProvider.sol";
import { FDUSDProvider } from "../../../contracts/ceros/provider/FDUSDProvider.sol";
import { mBTCProvider } from "../../../contracts/ceros/provider/mBTCProvider.sol";
import { PumpBTCProvider } from "../../../contracts/ceros/provider/PumpBTCProvider.sol";

contract DeployProviderImpls is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy SlisBNBProvider implementation
    SlisBNBProvider slisBNBProviderImpl = new SlisBNBProvider();
    console.log("SlisBNBProvider implementation: ", address(slisBNBProviderImpl));
    // Deploy FDUSDProvider implementation
    FDUSDProvider fdusdProviderImpl = new FDUSDProvider();
    console.log("FDUSDProvider implementation: ", address(fdusdProviderImpl));
    // Deploy mBTCProvider implementation
    mBTCProvider mBTCProviderImpl = new mBTCProvider();
    console.log("mBTCProvider implementation: ", address(mBTCProviderImpl));
    // Deploy PumpBTCProvider implementation
    PumpBTCProvider pumpBTCProviderImpl = new PumpBTCProvider();
    console.log("PumpBTCProvider implementation: ", address(pumpBTCProviderImpl));

    vm.stopBroadcast();
  }
}
