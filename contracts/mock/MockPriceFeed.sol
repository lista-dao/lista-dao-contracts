// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MockPriceFeed is AggregatorV3Interface,AccessControl {
    uint80 public roundId = 1;
    int256 public answer = 2000000000000000000;
    uint256 public startedAt = block.timestamp;
    uint256 public updatedAt = block.timestamp;
    uint80 public answeredInRound = 1;

    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    constructor() public {
        _setupRole(UPDATER_ROLE, msg.sender);
    }

    function decimals() external view override returns (uint8) {
        return 18;
    }

    function description() external view override returns (string memory) {
        return "Mock Oracle Price Feed";
    }

    function version() external view override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId) external view override returns (
        uint80 mostRecentRoundId,
        int256 newAnswer,
        uint256 startedTimestamp,
        uint256 updatedAtTimestamp,
        uint80 answeredInRoundId
    ){
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function latestRoundData() external view override returns (
        uint80 latestRoundId,
        int256 latestAnswer,
        uint256 startedTimestamp,
        uint256 updatedAtTimestamp,
        uint80 answeredInRoundId
    ){
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function updateAnswer(int256 _answer) external {
        require(hasRole(UPDATER_ROLE, msg.sender), "Caller is not an updater");
        roundId++;
        answer = _answer;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
    }
}
