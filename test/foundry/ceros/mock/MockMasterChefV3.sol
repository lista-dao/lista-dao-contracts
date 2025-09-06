// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface INonfungiblePositionManagerStruct {
  struct DecreaseLiquidityParams {
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
  }
  struct CollectParams {
    uint256 tokenId;
    address recipient;
    uint128 amount0Max;
    uint128 amount1Max;
  }
}

interface INFTManager is INonfungiblePositionManagerStruct, IERC721 {
  function decreaseLiquidity(
    DecreaseLiquidityParams calldata params
  ) external payable returns (uint256 amount0, uint256 amount1);
  function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);
  function burn(uint256 tokenId) external payable;
}

contract MockMasterChefV3 {
  using SafeERC20 for IERC20;

  /// @notice Address of CAKE contract.
  IERC20 public immutable CAKE;
  INFTManager public immutable nonfungiblePositionManager;
  bool public emergency;

  constructor(address _CAKE, address _nonfungiblePositionManager) {
    CAKE = IERC20(_CAKE);
    nonfungiblePositionManager = INFTManager(_nonfungiblePositionManager);
  }

  function withdraw(uint256 tokenId, address to) external returns (uint256 reward) {
//    require(to == address(this) || to == address(0), "wrong receiver");
    CAKE.safeTransfer(to, reward);
    nonfungiblePositionManager.safeTransferFrom(address(this), to, tokenId);
  }

  function harvest(uint256 tokenId, address to) external returns (uint256 reward) {
    reward = 5 ether;
    CAKE.safeTransfer(to, reward);
  }

  function pendingCake(uint256 tokenId) external view returns (uint256 reward) {
    reward = 5 ether;
  }

  function decreaseLiquidity(INFTManager.DecreaseLiquidityParams memory params) external returns (uint256 amount0, uint256 amount1) {
    // simulate harvest
    CAKE.safeTransfer(msg.sender, 5 ether);
    (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
  }

  function collect(INFTManager.CollectParams memory params) external returns (uint256 amount0, uint256 amount1) {
    (amount0, amount1) = nonfungiblePositionManager.collect(params);
  }

  function burn(uint256 tokenId) external {
    nonfungiblePositionManager.burn(tokenId);
  }

  function onERC721Received(
    address,
    address _from,
    uint256 _tokenId,
    bytes calldata
  ) external returns (bytes4) {
    return this.onERC721Received.selector;
  }
}
