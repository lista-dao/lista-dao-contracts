//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../ceros/interfaces/IWETH.sol";
import "./IBaseStrategy.sol";

abstract contract BaseStrategy is
IBaseStrategy,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable {

    address public strategist;
    address public destination;
    address public feeRecipient;

    IWETH public underlying;

    bool public depositPaused;

    event UpdatedStrategist(address strategist);
    event UpdatedFeeRecipient(address feeRecipient);
    event UpdatedPerformanceFee(uint256 performanceFee);

    function __BaseStrategy_init(
        address destinationAddr,
        address feeRecipientAddr,
        address underlyingToken
    ) internal initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        strategist = msg.sender;
        destination = destinationAddr;
        feeRecipient = feeRecipientAddr;
        underlying = IWETH(underlyingToken);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyStrategist() {
        require(msg.sender == strategist);
        _;
    }

    function _beforeDeposit(uint256 amount) internal virtual returns (bool) {
    }

    function balanceOfWant() public view returns(uint256) {
        return underlying.balanceOf(address(this));
    }

    function balanceOfPool() public view returns(uint256) {
        return underlying.balanceOf(address(destination));
    }

    function balanceOf() public view returns(uint256) {
        return underlying.balanceOf(address(this)) + underlying.balanceOf(address(destination));
    }

    function pause() external onlyStrategist {
        depositPaused = true;
    }

    function unpause() external onlyStrategist {
        depositPaused = false;
    }

    function setStrategist(address newStrategist) external onlyOwner {
        require(newStrategist != address(0));
        strategist = newStrategist;
        emit UpdatedStrategist(newStrategist);
    }
    
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0));
        feeRecipient = newFeeRecipient;
        emit UpdatedFeeRecipient(newFeeRecipient);
    }
}
