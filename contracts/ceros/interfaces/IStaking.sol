pragma solidity ^0.8.10;

interface IStaking {
    struct Pool {
        address lpToken;
        address rewardToken;
        address poolAddress;
        address distributor;
        bool isActive;
    }

    function deposit(address pool, uint256 amount) external;

    function harvest(address pool) external returns (uint256);

    function withdraw(address to, address pool, uint256 amount) external;

    function registerPool(address lpToken, address rewardToken, address poolAddress, address distributor) external;

    function unregisterPool(address lpToken) external;

    function pools(address pool) external view returns (Pool memory);
}
