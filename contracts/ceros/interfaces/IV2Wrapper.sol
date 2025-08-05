pragma solidity ^0.8.10;

interface IV2Wrapper {
    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 rewardDebt;
        uint256 boostMultiplier; // currently active multiplier
        uint256 boostedAmount; // combined boosted amount
        uint256 unsettledRewards; // rewards haven't been transferred to users but already accounted in rewardDebt
    }

    function stakedToken() external view returns (address);

    function rewardToken() external view returns (address);

    function deposit(uint256 _amount, bool _noHarvest) external;

    function withdraw(uint256 _amount, bool _noHarvest) external;

    function pendingReward(address _userAddress) external view returns (uint256);

    function userInfo(address _userAddress) external view returns (UserInfo memory);

    function emergencyWithdraw() external;
}