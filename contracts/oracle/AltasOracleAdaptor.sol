// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./interfaces/OracleInterface.sol";
import "./libraries/FullMath.sol";

/**
 * @title AltasOracleAdaptor
 * @author Lista
 * @notice Adaptor that wraps an Atlas Oracle push feed (18-decimal Chainlink-style)
 * and exposes it as an 8-decimal AggregatorV3Interface so it can be plugged into ResilientOracle.
 * @dev Pure passthrough; the only transformation is rescaling the answer from 1e18
 * to 1e8 via FullMath.mulDiv. Staleness is enforced by ResilientOracle via
 * `timeDeltaTolerance` in TokenConfig, so this adaptor deliberately does not
 * perform a staleness check.
 */
contract AltasOracleAdaptor is AggregatorV3Interface {

    /// @notice Source decimals of the Atlas Oracle push feed.
    uint256 private constant SOURCE_SCALE = 1e18;
    /// @notice Target decimals exposed to ResilientOracle (8).
    uint256 private constant TARGET_SCALE = 1e8;

    /// @notice The underlying Atlas Oracle push feed (returns 18-decimal answers).
    AggregatorV3Interface public immutable atlasFeed;

    constructor(address _atlasFeed) {
        require(_atlasFeed != address(0), "AltasOracleAdaptor/zero-feed");
        require(
            AggregatorV3Interface(_atlasFeed).decimals() == 18,
            "AltasOracleAdaptor/feed-decimals-not-18"
        );
        atlasFeed = AggregatorV3Interface(_atlasFeed);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external view returns (string memory) {
        return atlasFeed.description();
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function latestAnswer() external view returns (int256) {
        (, int256 ans, , , ) = atlasFeed.latestRoundData();
        return _scale(ans);
    }

    function getRoundData(uint80 _roundId)
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = atlasFeed.getRoundData(_roundId);
        answer = _scale(answer);
    }

    function latestRoundData()
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = atlasFeed.latestRoundData();
        answer = _scale(answer);
    }

    /**
     * @dev Rescale an 18-decimal answer to 8 decimals via FullMath.mulDiv to
     * avoid intermediate overflow. Non-positive answers are coerced to zero,
     * which ResilientOracle treats as INVALID_PRICE (preventing a signed-to-
     * unsigned underflow wrap when uint256(answer) is taken downstream).
     */
    function _scale(int256 ans) internal pure returns (int256) {
        if (ans <= 0) return 0;
        return int256(FullMath.mulDiv(uint256(ans), TARGET_SCALE, SOURCE_SCALE));
    }
}
