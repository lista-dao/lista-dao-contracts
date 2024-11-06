pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../../contracts/oracle/SolvBTCBBNOracle.sol";

contract SolvBTCBBNOracleTest is Test {

    SolvBTCBBNOracle oracle;

    uint testnet;

    function setUp() public {
        testnet = vm.createSelectFork("https://bsc-testnet.bnbchain.org");
        oracle = SolvBTCBBNOracle(0x3e6c4Efe6D6A470439795756BEDE9f4cd6BdDd5d);
    }

    function test_setUp() public {
        (bytes32 price, ) = oracle.peek();
        console.logBytes32(price);
    }
}
