// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

interface IBNBStakingPool {
    function stakeCerts() external payable;

    function unstakeCertsFor(address receiverAddress, uint256 shares) external;

    function getMinStake() external view returns (uint256);

    function getMinUnstake() external view returns (uint256);

    function getPendingUnstakesOf(address claimer) external view returns (uint256);

    // ListaStakeManager, minimum amount of BNB required for a withdrawal
    function minBnb() external view returns (uint256);
}
