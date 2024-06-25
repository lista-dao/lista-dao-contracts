// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

library ExchangeRate {

    // 1 stkBNB = (totalWei / poolTokenSupply) BNB
    // 1 BNB = (poolTokenSupply / totalWei) stkBNB
    // Over time, stkBNB appreciates in value as compared to BNB.
    struct Data {
        uint256 totalWei; // total amount of BNB managed by the pool
        uint256 poolTokenSupply; // total amount of stkBNB managed by the pool
    }

    function _calcPoolTokensForDeposit(Data memory self, uint256 weiAmount)
        internal
        pure
        returns (uint256)
    {
        if (self.totalWei == 0 || self.poolTokenSupply == 0) {
            return weiAmount;
        }
        return (weiAmount * self.poolTokenSupply) / self.totalWei;
    }

    function _calcWeiWithdrawAmount(Data memory self, uint256 poolTokens)
        internal
        pure
        returns (uint256)
    {
        uint256 numerator = poolTokens * self.totalWei;
        uint256 denominator = self.poolTokenSupply;

        if (numerator < denominator || denominator == 0) {
            return 0;
        }
        return numerator / denominator;
    }
}
