//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../StkBnbStrategy.sol";

contract MockStkBnbStrategy is StkBnbStrategy {
    function setupDistribute(WithdrawRequest[] calldata _withdrawReqs) payable public {
        _bnbToDistribute = msg.value;
        for (uint i = 0; i < _withdrawReqs.length; i++) {
            withdrawReqs[_endIndex++] = _withdrawReqs[i];
        }
    }

    function setupDistributeManual(address recipient, uint256 amount) payable public {
        _bnbToDistribute = msg.value;
        manualWithdrawAmount[recipient] = amount;
    }
}
