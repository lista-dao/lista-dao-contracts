// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { MockResilientOracle } from "../../contracts/mock/multiOracles/MockResilientOracle.sol";

contract MockResilentOracleDeploy is Script {
  address resilientOracleAddress;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy MockResilientOracle implementation
    MockResilientOracle impl = new MockResilientOracle();
    console.log("MockResilientOracle implementation: ", address(impl));
    // Initialize data
    ERC1967Proxy proxy = new ERC1967Proxy(
      address(impl),
      abi.encodeWithSelector(MockResilientOracle.initialize.selector, deployer, resilientOracleAddress)
    );
    console.log("MockResilientOracle proxy: ", address(proxy));

    vm.stopBroadcast();
  }
}
