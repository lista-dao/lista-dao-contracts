// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreateAndInitPools is Script {

  address token0;
  address token1;
  address nonfungiblePositionManager;
  address pancakeV3Factory;
  address deployer;

  function setUp() public {
    nonfungiblePositionManager = vm.envAddress("NON_FUNGIBLE_POSITION_MANAGER");
    token0 = vm.envAddress("TOKEN0");
    token1 = vm.envAddress("TOKEN1");
    pancakeV3Factory = vm.envAddress("PCS_V3_FACTORY");
  }

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    deployer = vm.addr(deployerPrivateKey);

    // start tx
    vm.startBroadcast(deployerPrivateKey);

    // mint some token first
    MintableERC20(token0).mint(10000 ether);
    MintableERC20(token1).mint(10000 ether);

    // mock price
    uint256 token0Price = 35 * 1e8;
    uint256 token1Price = 70 * 1e8;
    uint24 fee = 10000;
    uint256 amount1Desired = 100 ether;
    uint256 amount0Desired = amount1Desired * (token1Price / 1e8);

    IERC20(token0).approve(address(nonfungiblePositionManager), type(uint256).max);
    IERC20(token1).approve(address(nonfungiblePositionManager), type(uint256).max);
    INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
      token0: token0,
      token1: token1,
      fee: fee,
      tickLower: -887200,
      tickUpper: 887200,
      amount0Desired: amount1Desired * (token1Price/token0Price),
      amount1Desired: amount1Desired,
      amount0Min: 0,
      amount1Min: 0,
      recipient: deployer,
      deadline: block.timestamp + 1 hours
    });
    // Mint LP NFT
    (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
                INonfungiblePositionManager(nonfungiblePositionManager).mint(params);

    console.log("Minted LP NFT with tokenId: ", tokenId);
  }
}

interface INonfungiblePositionManager {
  struct MintParams {
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    address recipient;
    uint256 deadline;
  }

  function mint(MintParams calldata params)
  external
  payable
  returns (
    uint256 tokenId,
    uint128 liquidity,
    uint256 amount0,
    uint256 amount1
  );
}

interface MintableERC20 is IERC20 {
  function mint(uint256 amount) external;
}
