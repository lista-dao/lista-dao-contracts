// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "../interfaces/IDynamicDutyCalculator.sol";
import "../interfaces/JugLike.sol";
import "../libraries/FixedMath0x.sol";
import "../oracle/interfaces/IResilientOracle.sol";

import {IDao} from "../ceros/interfaces/IDao.sol";

/**
    * @title DynamicDutyCalculator
    * @author Lista
    * @notice Contract for calculating the dynamic interest rate for collaterals to maintain the stability of the lisUSD peg.
    *
    * The calculation is based on the following formula:
    *
    *   deviation = PEG - lisUSD price
    *   r = r0 * e^(deviation / beta)
    *   duty = r + 1e27
    *
    * Where
        - r is the rate,
        - r0 is the baseline rate when the lisUSD price is equal to PEG,
        - deviation is the difference between the peg price and the lisUSD price,
        - beta is the parameter that determines the volatility of the rate.
        - duty is the final calculated duty, which will be set to Jug contract via Interaction contract.
    *
 */
contract DynamicDutyCalculator is IDynamicDutyCalculator, Initializable, AccessControlUpgradeable {
    address public interaction;

    // lisUSD address
    address lisUSD;

    // lisUSD price oracle
    IResilientOracle oracle;

    // the minimum price change required to update duty dynamically
    uint256 public delta;

    // collateral address => Ilk
    mapping (address => Ilk) public ilks;

    // 1000000034836767751273470154 (200% APY)
    uint256 public maxDuty;

    // 1e27 (0% APY)
    uint256 public minDuty;

    // 9e7  = 0.9 * PEG
    // the lowest lisUSD price of the dynamic interest rate mechanism's effect
    // set duty to maxDuty if price goes below minPrice; initial value is 0.9 * PEG
    uint256 public minPrice;

    // 11e7 = 1.1 * PEG
    // the highest lisUSD price of the dynamic interest rate mechanism's effect
    // set duty to minDuty if price goes above maxPrice; initial value is 1.1 * PEG
    uint256 public maxPrice;

    // $1; lisUSD price feed decimal is 8
    uint256 constant PEG = 1e8;

    bytes32 public constant INTERACTION = keccak256("INTERACTION");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*
     * @param _interaction The address of the interaction contract.
     * @param _priceOracle The address of the lisUSD price oracle contract.
     * @param _delta The minimum price difference required to update duty.
     * @param _admin The address of the admin.
     */
    function initialize(address _interaction, address _lisUSD, address _priceOracle, uint256 _delta, address _admin) external initializer {
        require(_interaction != address(0) && _lisUSD != address(0) &&  _priceOracle != address(0) && _admin != address(0), "AggMonetaryPolicy/invalid-address");

        interaction = _interaction;
        lisUSD = _lisUSD;
        oracle = IResilientOracle(_priceOracle);

        minDuty = 1e27;
        maxDuty = 1000000034836767751273470154;

        minPrice = 9 * PEG / 10;
        maxPrice = 11 * PEG / 10;

        require(_delta < (maxPrice - minPrice), "AggMonetaryPolicy/invalid-delta");
        delta = _delta;

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(INTERACTION, _interaction);
    }

    /**
     * @dev Set parameters for a collateral token.
     * @param collateral The collateral token address.
     * @param beta The volatility parameter.
     * @param rate0 The rate when the price is equal to PEG.
     * @param enabled If the collateral token is enabled for the dynamic interest rate mechanism.
     */
    function setCollateralParams(address collateral, uint256 beta, uint256 rate0, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(collateral != address(0), "AggMonetaryPolicy/invalid-address");
        require(beta > 3e5 && beta < 1e8, "AggMonetaryPolicy/invalid-beta");

        ilks[collateral].beta = beta;
        ilks[collateral].rate0 = rate0;
        ilks[collateral].enabled = enabled;

        uint256 price = oracle.peek(lisUSD);
        ilks[collateral].lastPrice = price;

        uint256 duty = calculateRate(price, beta, rate0) + 1e27;
        if (duty > maxDuty) duty = maxDuty;
        if (duty < minDuty) duty = minDuty;

        IDao(interaction).setCollateralDuty(collateral, duty);

        emit CollateralParamsUpdated(collateral, beta, rate0, enabled);
    }

    /**
     * @dev Calculate the duty for a collateral token based on the lisUSD price. Can only be called by the Interaction contract.
     *      price <= minPrice: set to maxDuty
     *      price >= maxPrice: set to minDuty
     *      lastPrice - 0.002 <= price <= lastPrice + 0.002: keep the current duty
     *      Otherwise, calculate the duty based on the price.
     * @param  _collateral The collateral token address.
     * @param  _currentDuty The current duty for the collateral token.
     * @param  _updateLastPrice If update the last price for the collateral token or not.
     * @return duty The duty for the collateral token.
     */
    function calculateDuty(address _collateral, uint256 _currentDuty, bool _updateLastPrice) public onlyRole(INTERACTION) returns (uint256 duty) {
        Ilk storage ilk = ilks[_collateral];
        if (!ilk.enabled) {
            return _currentDuty; // if collateral not enabled for dynamic interest rate mechanism, return current duty
        }
        uint256 price = oracle.peek(lisUSD);

        // return max duty if price is too low
        if (price <= minPrice) {
            if (_updateLastPrice) {
                ilk.lastPrice = price;
            }
            return maxDuty;
        }

        // return min duty if price is too high
        if (price >= maxPrice) {
            if (_updateLastPrice) {
                ilk.lastPrice = price;
            }
            return minDuty;
        }

        // return current duty if lastPrice - 0.002 <= price <= lastPrice + 0.002
        if (price <= ilk.lastPrice + delta && price >= ilk.lastPrice - delta) {
            return _currentDuty;
        }

        if (_updateLastPrice) {
            ilk.lastPrice = price;
        }

        uint256 rate = calculateRate(price, ilk.beta, ilk.rate0);
        duty = rate + 1e27;

        if (duty > maxDuty) return maxDuty;
        if (duty < minDuty) return minDuty;
    }

    /**
     * @dev Calculate rate given the lisUSD price, beta, and rate0.
     * @param price The lisUSD price.
     * @param beta The volatility parameter.
     * @param rate0 The rate when the price is equal to PEG.
     */
    function calculateRate(uint256 price, uint256 beta, uint256 rate0) internal pure returns (uint256 rate) {
        int256 deviation = int256(PEG) - int256(price);
        uint256 factor = exp(deviation, int256(beta));
        rate = rate0 * factor / 1e18;
    }

    /**
     * @dev Set the price range for the dynamic interest rate mechanism's effect.
     * @param _minPrice The lowest lisUSD price of the dynamic interest rate mechanism's effect.
     * @param _maxPrice The highest lisUSD price of the dynamic interest rate mechanism's effect.
     */
    function setPriceRange(uint256 _minPrice, uint256 _maxPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_minPrice < PEG && _maxPrice > PEG, "AggMonetaryPolicy/invalid-price-range");
        require(delta < (_maxPrice - _minPrice), "AggMonetaryPolicy/invalid-price-diff");

        minPrice = _minPrice;
        maxPrice = _maxPrice;

        emit PriceRangeUpdated(_minPrice, _maxPrice);
    }

    /**
     * @dev Set the max duty and min duty for the case that price goes outside of range.
     * @param _minDuty The minimum duty.
     * @param _maxDuty The maximum duty.
     */
    function setDutyRange(uint256 _minDuty, uint256 _maxDuty) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_minDuty >= 1e27 && _minDuty < _maxDuty, "AggMonetaryPolicy/invalid-duty-range");

        minDuty = _minDuty;
        maxDuty = _maxDuty;

        emit DutyRangeUpdated(_minDuty, _maxDuty);
    }

    /**
     * @dev Set the minimum price change required to update duty.
     * @param _delta The minimum price change required to update duty dynamically.
     */
    function setDelta(uint256 _delta) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(delta != _delta && _delta <= minPrice, "AggMonetaryPolicy/invalid-delta");
        require(_delta < (maxPrice - minPrice), "AggMonetaryPolicy/delta-is-too-large");

        delta = _delta;

        emit DeltaUpdated(_delta);
    }

    /**
     * @dev Set the address of the specified contract.
     * @param what The contract to set. bytes32 representation of the state variable name.
     * @param _addr The address to set.
     */
    function file(bytes32 what, address _addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_addr != address(0), "AggMonetaryPolicy/zero-address-provided");

        if (what == "interaction") {
            require(interaction != _addr, "AggMonetaryPolicy/interaction-already-set");
            revokeRole(INTERACTION, interaction);
            interaction = _addr;
            grantRole(INTERACTION, _addr);
        } else if (what == "lisUSD") {
            require(lisUSD != _addr, "AggMonetaryPolicy/lisUSD-already-set");
            lisUSD = _addr;
        } else if (what == "oracle") {
            require(address(oracle) != _addr, "AggMonetaryPolicy/oracle-already-set");
            oracle = IResilientOracle(_addr);
        } else revert("AggMonetaryPolicy/file-unrecognized-param");

        emit File(what, _addr);
    }

    /**
     * @dev Get the addresses of the contracts.
     */
    function getContracts() external view returns (address _interaction, address _lisUSD, address _oracle) {
        return (interaction, lisUSD, address(oracle));
    }

    /**
     * @dev Adaptor for `FixedMath0x._exp` method since it's designed for negative power only.
     *      if price > 1, use _exp directly
     *      if price < 1, e^power = 1 / e^(-power)
     * @param deviation  (peg price - lisUSD price)
     * @param beta  volatility parameter; initial value is 1e6
     * @return e^(deviation/beta)
     */
    function exp(int256 deviation, int256 beta) internal pure returns (uint256) {
        if (deviation < 0) {
            int256 power = deviation * FixedMath0x.FIXED_1 / beta;
            int256 _r = FixedMath0x._exp(power);
            return uint256(_r) * 1e18 / uint256(FixedMath0x.FIXED_1);
        } else if (deviation > 0 ) {
            deviation = -1 * deviation;
            int256 power = deviation * FixedMath0x.FIXED_1 / beta;
            int256 _r = FixedMath0x._exp(power);
            return uint256(FixedMath0x.FIXED_1) * 1e18 / uint256(_r);
        } else {
            return 1e18;
        }
    }
}
