pragma solidity ^0.8.10;

import "forge-std/Test.sol";
//import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../../contracts/ceros/ETH/CerosETHRouter.sol";

contract CerosETHRouterTest is Test {

    CerosETHRouter cerosETHRouter;

    address admin;

    function setUp() public {
        CerosETHRouter cerosETHRouterImpl = new CerosETHRouter();
    }

    function test_changeReferral() public {

    }
}
