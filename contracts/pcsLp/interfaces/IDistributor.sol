pragma solidity ^0.8.10;

interface IDistributor {
    function vaultClaimReward(address _account) external returns (uint256);
    function vaultClaimStakingReward(address _account) external returns (uint256);
    function notifyRegisteredId(uint16 _emissionId) external returns (bool);
    function claimableReward(address account) external view returns (uint256);
    function notifyStakingReward(uint256 amount) external;
    function lpToken() external view returns (address);
}