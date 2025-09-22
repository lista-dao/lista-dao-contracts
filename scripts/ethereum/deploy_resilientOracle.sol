// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ResilientOracle } from "../../contracts/oracle/ResilientOracle.sol";

contract ResilentOracleDeploy is Script {
  address boundValidator = 0x6e59A37BA9A1a5AbDCEE3cb37f677535dB82f7f7;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy ResilientOracle implementation
    ResilientOracle impl = new ResilientOracle();
    console.log("ResilientOracle implementation: ", address(impl));

    ERC1967Proxy proxy = new ERC1967Proxy(
      address(impl),
      abi.encodeWithSelector(ResilientOracle.initialize.selector, boundValidator)
    );
    console.log("ResilientOracle proxy: ", address(proxy));

    vm.stopBroadcast();
  }
}
