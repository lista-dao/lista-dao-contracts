pragma solidity ^0.8.10;

interface IStakingVault {
    function sendRewards(address distributor, uint256 amount) external;
    function transferAllocatedTokens(address account, uint256 amount) external;
    function batchClaimRewardsWithProxy(address account, address[] memory _distributors) external;
    function rewardToken() external view returns (address);
}
