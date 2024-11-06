pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../contracts/psm/LisUSDPoolSet.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../contracts/psm/PSM.sol";
import "../../contracts/psm/VaultManager.sol";
import "../../contracts/LisUSD.sol";
import "../../contracts/hMath.sol";
import {EarnPool} from "../../contracts/psm/EarnPool.sol";

contract ATest is Test {
    PSM psm = PSM(0x89F5e21Ed5d716FcD86dfF00fDAbf9Bbc9327AC5);
    EarnPool earnPool = EarnPool(0xaee2bE007109194C86a08A3349869a7df9dE30D7);
    LisUSDPoolSet lisUSDPoolSet = LisUSDPoolSet(0xd3c66df615fe10E756019208515b86D98FA205E5);

    address usdc = 0xA528b0E61b72A0191515944cD8818a88d1D1D22b;

    address user = 0x6616EF47F4d997137a04C2AD7FF8e5c228dA4f06;

    function setUp() public {
        vm.createSelectFork("bsc-test");

    }

    function test_depositAndWithdraw() public {
        vm.startPrank(user);
//        psm.sell(100 ether);
//        earnPool.deposit(usdc, 100 ether);
        vm.stopPrank();

    }

    function test_gas() public {
        skip(365 days);
        lisUSDPoolSet.getRate();
    }

    function rpow(uint x, uint n, uint b) internal pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := b} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := b } default { z := x }
                let half := div(b, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0,0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0,0) }
                    x := div(xxRound, b)
                    if mod(n,2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0,0) }
                        z := div(zxRound, b)
                    }
                }
            }
        }
    }

    function rmul(uint x, uint y) internal pure returns (uint z) {
        unchecked {
            z = x * y;
            require(y == 0 || z / y == x);
            z = z / hMath.ONE;
        }
    }
}