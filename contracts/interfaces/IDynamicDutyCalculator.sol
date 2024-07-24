// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

interface IDynamicDutyCalculator {
    struct Ilk {
        bool enabled; // if the collateral token is enabled for the dynamic interest rate mechanism
        uint256 lastPrice; // the last price applied for updating ilk duty; [1e8]
        uint256 rate0; // [1e27]
        uint256 beta;
    }
    event CollateralParamsUpdated(address indexed collateral, uint256 beta, uint256 rate0, bool enabled);
    event PriceRangeUpdated(uint256 minPrice, uint256 maxPrice);
    event DutyRangeUpdated(uint256 minDuty, uint256 maxDuty);
    event DeltaUpdated(uint256 newDelta);
    event File(bytes32 what, address addr);

    function interaction() external view returns (address);

    function calculateDuty(address _collateral, uint256 _currentDuty, bool _updateLastPrice) external returns (uint256 duty);
}
