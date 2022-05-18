// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../ceros/interfaces/ICertToken.sol";
import "../ceros/interfaces/IBondToken.sol";
import "../ceros/interfaces/IBinancePool.sol";

contract BinancePool is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    /**
     * Variables
     */

    uint256 private _minimumStake;
    uint256 private _expireTime;
    uint256 private _pendingGap;

    uint256 private _relayerFee;

    address private _operator;
    address private _intermediary;
    address private _bondContract;

    address[] private _pendingClaimers;
    mapping(address => uint256) public pendingClaimerUnstakes;

    uint256 public stashedForManualDistributes;
    mapping(uint256 => bool) public markedForManualDistribute;

    address private _certContract;

    mapping(address => bool) private _claimersForManualDistribute;

    modifier onlyOperator() {
        require(msg.sender == _operator, "sender is not an operator");
        _;
    }

    modifier badClaimer() {
        require(
            !_claimersForManualDistribute[msg.sender],
            "the address has a request for manual distribution"
        );
        _;
    }

    function initialize(
        address operator,
        address bcOperator,
        uint64 expireTime
    ) public initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        _operator = operator;
        _intermediary = bcOperator;
        _expireTime = expireTime;
        _minimumStake = 1e8;
        _relayerFee = 1e16;
    }

    function stake() external payable nonReentrant {
        _stake();
    }

    function stakeAndClaimCerts() external payable nonReentrant {
        uint256 realAmount = _stake();
        IBondToken(_bondContract).unlockSharesFor(msg.sender, realAmount);
    }

    function _stake() private returns (uint256) {
        uint256 realAmount = msg.value;
        /* mint Internet Bonds for user */
        IBondToken(_bondContract).mintBonds(msg.sender, realAmount);
        return realAmount;
    }

    function unstakeCerts(address recipient, uint256 shares)
        external
        badClaimer
        nonReentrant
    {
        uint256 amount = IBondToken(_bondContract).sharesToBonds(shares);
        require(
            amount >= _minimumStake,
            "value must be greater than min unstake amount"
        );
        require(
            ICertToken(_certContract).balanceWithRewardsOf(msg.sender) >=
                amount,
            "cannot unstake more than have on address"
        );
        if (pendingClaimerUnstakes[recipient] == 0) {
            _pendingClaimers.push(recipient);
        }
        pendingClaimerUnstakes[recipient] += amount;
        IBondToken(_bondContract).transferAndLockShares(msg.sender, shares);
        IBondToken(_bondContract).burnAndSetPendingFor(
            msg.sender,
            recipient,
            amount
        );
    }

    function pendingUnstakesOf(address claimer)
        external
        view
        returns (uint256)
    {
        return pendingClaimerUnstakes[claimer];
    }

    function changeBondContract(address bondContract) external onlyOwner {
        _bondContract = bondContract;
    }

    function changeCertContract(address certToken) external onlyOwner {
        _certContract = certToken;
    }

    function getMinimumStake() external view returns (uint256) {
        return _minimumStake;
    }

    function getRelayerFee() external view returns (uint256) {
        return _relayerFee;
    }

    function changeRelayerFee(uint256 relayerFee) external {
        _relayerFee = relayerFee;
    }
}
