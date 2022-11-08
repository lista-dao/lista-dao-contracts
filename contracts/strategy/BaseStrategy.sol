//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../masterVault/interfaces/IMasterVault.sol";
import "./IBaseStrategy.sol";

abstract contract BaseStrategy is
    IBaseStrategy,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public strategist;
    address public destination;
    address public rewards;

    bool public depositPaused;

    IMasterVault public vault;

    event UpdatedStrategist(address strategist);
    event UpdatedRewards(address rewards);

    function __BaseStrategy_init(
        address destinationAddr,
        address rewardsAddr,
        address masterVault
    ) internal initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        strategist = msg.sender;
        destination = destinationAddr;
        rewards = rewardsAddr;
        vault = IMasterVault(masterVault);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyStrategist() {
        require(msg.sender == strategist);
        _;
    }

    /**
     * @dev Throws if deposits are paused.
     */
    modifier whenDepositNotPaused() {
        require(!depositPaused, "deposits are paused");
        _;
    }

    /**
     * @dev Throws if called by any account other than the masterVault
     */
    modifier onlyVault() {
        require(msg.sender == address(vault), "!vault");
        _;
    }

    function balanceOfWant() public view returns (uint256) {
        return address(this).balance;
    }

    function balanceOfPool() public view virtual returns (uint256) {
        return address(destination).balance;
    }

    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceOfPool();
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

    function setRewards(address newRewardsAddr) external onlyOwner {
        require(newRewardsAddr != address(0));
        rewards = newRewardsAddr;
        emit UpdatedRewards(newRewardsAddr);
    }
}
