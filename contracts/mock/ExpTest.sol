pragma solidity ^0.8.10;

import "../hMath.sol";
import { FixedMath0x } from "../libraries/FixedMath0x.sol";

import "hardhat/console.sol";

contract ExpTest {
    uint256 constant PEG = 1e8;
    uint256 constant SIGMA = 1e7;

    // e^(delta/sigma)
    // a = e^delta
    // b = a^sigma
    // c = 1 / b
    function exp(int256 delta, int256 sigma) public view returns (int256 _r) {
        uint gasBefore = gasleft();
        int256 power = delta * FixedMath0x.FIXED_1 / sigma;
        //uint256 power2 = MathEx.mulDivF(uint256(delta), uint256(FixedMath0x.FIXED_1), uint256(sigma));

        console.logInt(power);
        //console.log("pwoer2 : %s", power2);
        _r = FixedMath0x._exp(power);
       // console.log(gasBefore - gasleft());
    }

    function exp_pos(int256 delta, int256 sigma) public view returns (int256 _r) {
        uint gasBefore = gasleft();
        delta = -1 * delta;
        int256 power = delta * FixedMath0x.FIXED_1 / sigma;
        //uint256 power2 = MathEx.mulDivF(uint256(delta), uint256(FixedMath0x.FIXED_1), uint256(sigma));

        console.logInt(power);
        //console.log("pwoer2 : %s", power2);
        _r = FixedMath0x._exp(power);
       console.log(gasBefore - gasleft());
    }

}

