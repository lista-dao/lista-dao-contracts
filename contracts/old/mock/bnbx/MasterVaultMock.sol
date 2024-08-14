// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../../../strategy/IBaseStrategy.sol";

contract MasterVaultMock {
    IBaseStrategy public strategy;

    function changeStrategy(address _strategy) external {
        strategy = IBaseStrategy(_strategy);
    }

    function deposit() external payable returns (uint256) {
        return strategy.deposit{value: msg.value}();
    }

    function withdraw(address recipient, uint256 amount)
        external
        returns (uint256)
    {
        return strategy.withdraw(recipient, amount);
    }

    function withdrawInToken(address recipient, uint256 amount)
    external
    returns (uint256)
    {
        return strategy.withdrawInToken(recipient, amount);
    }

    function strategyParams(address strategy_)
        external
        pure
        returns (
            bool active,
            uint256 allocation,
            uint256 debt
        )
    {
        return (true, 0, 3e18);
    }
}
