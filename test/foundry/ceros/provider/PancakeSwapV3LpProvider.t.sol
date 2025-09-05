// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../../../contracts/interfaces/VatLike.sol";
import "../../../../contracts/interfaces/GemJoinLike.sol";
import "../../../../contracts/ceros/ClisToken.sol";
import "../../../../contracts/ceros/CeToken.sol";
import "../../../../contracts/Interaction.sol";
import { Clipper } from "../../../../contracts/clip.sol";
import { Spotter } from "../../../../contracts/spot.sol";
import { GemJoin } from "../../../../contracts/join.sol";
import { Dog } from "../../../../contracts/dog.sol";

import { MockMasterChefV3 } from "../mock/MockMasterChefV3.sol";
import { MockListaDistributor } from "../mock/MockListaDistributor.sol";
import { IUniswapV3Factory } from "../../../../contracts/ceros/interfaces/IUniswapV3Factory.sol";
import { IDao } from "../../../../contracts/ceros/interfaces/IDao.sol";
import { PancakeSwapV3LpProvider } from "../../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpProvider.sol";
import { PancakeSwapV3LpStakingHub } from "../../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpStakingHub.sol";
import { PancakeSwapV3LpStakingVault } from "../../../../contracts/ceros/provider/pancakeswapLpProvider/PancakeSwapV3LpStakingVault.sol";
import { LpUsd } from "../../../../contracts/ceros/provider/LpUsd.sol";
import { MockResilientOracle } from "../../../../contracts/mock/multiOracles/MockResilientOracle.sol";
import { AuctionProxy } from "../../../../contracts/libraries/AuctionProxy.sol";
import "../../../../contracts/oracle/libraries/FullMath.sol";

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

  function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IUniswapV3Pool {
  function slot0()
  external
  view
  returns (
    uint160 sqrtPriceX96,
    int24 tick,
    uint16 observationIndex,
    uint16 observationCardinality,
    uint16 observationCardinalityNext,
    uint32 feeProtocol,
    bool unlocked
  );

  function tickSpacing() external view returns (int24);
}


interface IChainLink {
  function latestRoundData()
  external
  view
  returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  );
}


contract PancakeSwapV3LpProviderTest is Test {

  address admin = 0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253;
  address manager = 0xAca0ed4651ddA1F43f00363643CFa5EBF8774b37;
  address pauser = address(0x2A11AB);
  address bot = address(0x2A11AC);
  address user = address(0x3A11AA);

  IERC20 Cake = IERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
  IERC20 LisUSD = IERC20(0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5);
  address pancakeV3Factory = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
  address nonfungiblePositionManager = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;

  address wards = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;
  address auth = manager;

  address token0 = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82; // CAKE
  address token1 = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB
  mapping(address => IChainLink) public priceFeeds;

  bytes32 public ilk = "USDT/WBNB-LPUSD";
  uint256 public mat = 2000000000000000000000000000; // 200% MCR

  uint256[] tokenIds = new uint256[](5);

  // ----- CDP ------
  Interaction interaction;
  GemJoin gemJoin;
  Clipper clip;
  VatLike vat;
  Spotter spotter;
  Dog dog;
  // ----- PCS Provider related ------
  LpUsd lpUsd; // <<<< collateral at CDP
  PancakeSwapV3LpProvider pcsProvider;
  PancakeSwapV3LpStakingHub pcsStakingHub;
  PancakeSwapV3LpStakingVault pcsStakingVault;
  MockResilientOracle oracle;

  function setUp() public {

    vm.createSelectFork("https://bsc-dataseed.binance.org");

    vat = VatLike(0x33A34eAB3ee892D40420507B820347b1cA2201c4);
    spotter = Spotter(0x49bc2c4E5B035341b7d92Da4e6B267F7426F3038);
    interaction = Interaction(0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4);
    dog = Dog(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    priceFeeds[token0] = IChainLink(0xB6064eD41d4f67e353768aA239cA86f4F73665a1); // CAKE/USD
    priceFeeds[token1] = IChainLink(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE); // WBNB/USD

    vm.startPrank(admin);

    MockMasterChefV3 masterChef = new MockMasterChefV3(
      address(Cake),
      nonfungiblePositionManager
    );
    deal(address(Cake), address(masterChef), 1000000 * 1e18, true);

    // 1. oracle
    oracle = new MockResilientOracle();
    oracle.initialize(
      admin,
      0xf3afD82A4071f272F403dC176916141f44E6c750
    );
    // 2. LP USD
    lpUsd = new LpUsd(token0, token1);

    // 3. PCS Staking hub
    PancakeSwapV3LpStakingHub pcsStakingHubImpl = new PancakeSwapV3LpStakingHub(
      nonfungiblePositionManager,
      address(masterChef),
      address(Cake)
    );
    ERC1967Proxy pcsStakingHubProxy = new ERC1967Proxy(
      address(pcsStakingHubImpl),
      abi.encodeWithSelector(
        PancakeSwapV3LpStakingHub.initialize.selector,
        admin,
        manager,
        pauser
      )
    );
    pcsStakingHub = PancakeSwapV3LpStakingHub(address(pcsStakingHubProxy));

    // 4. PCS Staking Vault
    PancakeSwapV3LpStakingVault pcsStakingVaultImpl = new PancakeSwapV3LpStakingVault(
      address(pcsStakingHub),
      address(Cake)
    );
    ERC1967Proxy pcsStakingVaultProxy = new ERC1967Proxy(
      address(pcsStakingVaultImpl),
      abi.encodeWithSelector(
        pcsStakingVaultImpl.initialize.selector,
        admin,
        manager,
        pauser,
        address(0x5A0E3291514F5F1797A0C7eFefdac81eeC70ec01)
      )
    );
    pcsStakingVault = PancakeSwapV3LpStakingVault(address(pcsStakingVaultProxy));

    // 4. PCS LP Provider
    PancakeSwapV3LpProvider pcsProviderImpl = new PancakeSwapV3LpProvider(
      address(interaction),
      nonfungiblePositionManager,
      address(masterChef),
      address(lpUsd),
      token0,
      token1,
      address(Cake)
    );
    ERC1967Proxy pcsProviderProxy = new ERC1967Proxy(
      address(pcsProviderImpl),
      abi.encodeWithSelector(
        PancakeSwapV3LpProvider.initialize.selector,
        admin,
        manager,
        bot,
        pauser,
        address(pcsStakingHub),
        address(pcsStakingVault),
        address(oracle),
        5, // Max Lp can be deposit
        1000 * 1e18, // 1000 LP USD
        8000, // 80% exchange rate
        "Lista-PancakeSwap LP V3 Provider"
      )
    );
    pcsProvider = PancakeSwapV3LpProvider(address(pcsProviderProxy));

    // transfer ownership of lpUSD
    lpUsd.setMinter(address(pcsProvider));

    // -------- upgrade interaction --------
    Interaction interactionImpl = new Interaction();
    ProxyAdmin(0x1Fa3E4718168077975fF4039304CC2e19Ae58c4C).upgrade(
      ITransparentUpgradeableProxy(address(interaction)),
      address(interactionImpl)
    );

    // deploy gemJoin
    gemJoin = new GemJoin();
    gemJoin.initialize(address(vat), ilk, address(lpUsd));

    // gemJoin: rely on interaction
    gemJoin.rely(address(interaction));

    // deploy clip
    clip = new Clipper();
    clip.initialize(address(vat), address(spotter), address(dog), ilk);

    vm.stopPrank();

    // Register PCS provider
    vm.prank(manager);
    pcsStakingHub.registerProvider(address(pcsProvider));
    vm.prank(manager);
    pcsStakingVault.registerLpProvider(address(pcsProvider), 500);

    vm.startPrank(auth);
    // vat: rely on clip
    vat.rely(address(clip));
    // vat: rely on gemJoin
    vat.rely(address(gemJoin));
    // vat: set ceiling for ilk
    vat.file(ilk, "line", 50000000000000000000000000000000000000000000000000);
    // spotter: configure oracle
    spotter.file(ilk, "pip", address(pcsProvider));
    vm.stopPrank();

    vm.startPrank(wards);
    // interaction: set provider of V3 LP
    interaction.setHelioProvider(address(lpUsd), address(pcsProvider), false);
    interaction.setCollateralType(address(lpUsd), address(gemJoin), ilk, address(clip), mat);
    // interaction: set listaDistributor
    MockListaDistributor listaDistributor = new MockListaDistributor();
    interaction.setListaDistributor(address(listaDistributor));
    vm.stopPrank();

    // ------ make user rich
    deal(address(token0), user, 1000000 * 1e18);
    deal(address(token1), user, 1000000 * 1e18);

  }

  /// @dev normal Provide
  function test_provide() public {
    normalProvide(10 ether);
  }

  /// @dev LP will low appraised value(< minLpValue) will be rejected
  function test_low_value_lp() public {
    mockPrice(token0, 1e8);
    mockPrice(token1, 1e8);
    // mint a low value LP token
    uint256 tokenId = mintLp(0.5 ether);
    vm.startPrank(user);
    // approve NFT to pcsProvider
    IERC721(nonfungiblePositionManager).approve(address(pcsProvider), tokenId);
    vm.expectRevert("PcsV3LpProvider: min-lp-value-not-met");
    // provide LP
    pcsProvider.provide(tokenId);
    vm.stopPrank();
  }

  /// @dev provide then borrow
  function test_borrow() public {
    // 1. provide LP
    uint256 tokenId = normalProvide(10 ether);
    // 2. borrow
    vm.startPrank(user);
    // borrow 1000 LP USD
    interaction.borrow(address(lpUsd), 100 * 1e18);
    vm.stopPrank();
    // check the balance of user
    assertEq(LisUSD.balanceOf(user), 100 * 1e18, "user should have 1000 LP USD");

    // at this point, user can't withdraw LP
    vm.startPrank(user);
    vm.expectRevert("PcsV3LpProvider: lp-value-exceeds-withdrawable-amount");
    pcsProvider.release(tokenId);
    vm.stopPrank();
  }

  /// @dev withdraw without debt
  function test_withdraw() public {
    uint256 tokenId = normalProvide(10 ether);

    // at this point, user can't withdraw LP
    vm.startPrank(user);
    pcsProvider.release(tokenId);
    vm.stopPrank();
  }

  /// @dev provide 2 LPs, then withdraw one of them after borrowed some LisUSD
  function test_provide_twice_and_withdraw() public {
    uint256 tokenId1 = normalProvide(10 ether);
    uint256 tokenId2 = normalProvide(10 ether);

    vm.startPrank(user);
    // borrow a little bit
    interaction.borrow(address(lpUsd), 100 * 1e18);
    // should be able to withdraw one LP
    pcsProvider.release(tokenId1);
    vm.stopPrank();
  }

  /// @dev liquidation kickstart
  function test_start_liquidation() public {
    // user provided
    uint256 tokenId1 = normalProvide(10 ether);

    // pretend CDP kickstart the liquidation
    vm.startPrank(address(interaction));
    // we pretend user needs to be liquidated
    pcsProvider.daoBurn(user, 1 ether);
    vm.stopPrank();

    vm.startPrank(user);
    // [1] user can't withdraw LP
    vm.expectRevert("PcsV3LpProvider: liquidation-ongoing");
    pcsProvider.release(tokenId1);
    vm.stopPrank();

    // [2] user can't provide LP
    uint256 tokenId2 = mintLp(5 ether);
    vm.startPrank(user);
    IERC721(nonfungiblePositionManager).approve(address(pcsProvider), tokenId2);
    vm.expectRevert("PcsV3LpProvider: liquidation-ongoing");
    pcsProvider.provide(tokenId2);
    vm.stopPrank();

    // user cdp position can't be synced
    vm.startPrank(bot);
    vm.expectRevert("PcsV3LpProvider: liquidation-ongoing");
    pcsProvider.syncUserLpValues(user);
    vm.stopPrank();
  }

  /// @dev buy from auction
  function test_liquidation() public {

    syncPrice(token0);
    syncPrice(token1);
    uint256 tokenId = normalProvide(5 ether);

    (uint256 amount0, uint256 amount1) = pcsProvider.getAmounts(tokenId);
    uint256 amount0Min = FullMath.mulDiv(
      amount0,
      8000,
      10000
    );
    uint256 amount1Min = FullMath.mulDiv(
      amount1,
      8000,
      10000
    );

    // pretend CDP kickstart the liquidation
    vm.startPrank(address(interaction));
    pcsProvider.daoBurn(user, 1 ether);
    vm.stopPrank();

    // pretend liquidator buy from auction
    vm.startPrank(address(interaction));
    // try liquidate with token with unmatched user
    vm.expectRevert("PcsV3LpProvider: not-lp-owner");
    pcsProvider.liquidation(
      user,
      address(bot),
      1 ether,
      abi.encode(1, 1, 1234),
      false
    );
    // try liquidate with token1 with all zero amounts
    vm.expectRevert("PcsV3LpProvider: invalid-data");
    pcsProvider.liquidation(
      user,
      address(bot),
      2 ether,
      abi.encode(0, 0, tokenId),
      false
    );
    vm.expectRevert("PcsV3LpProvider: insufficient-lp-value");
    pcsProvider.liquidation(
      user,
      address(bot),
      1000000 ether,
      abi.encode(1, 1, tokenId),
      false
    );
    // try liquidate
    pcsProvider.liquidation(
      user,
      address(bot),
      1000 ether,
      abi.encode(amount0Min, amount1Min, tokenId),
      false
    );
    vm.stopPrank();
  }
  // ------------------------ Utilities -------------------------- //
  function mockPrice(address token, uint256 price) public {
    vm.prank(admin);
    oracle.setPrice(token, price);
  }

  function syncPrice(address token) public {
    IChainLink priceFeed = priceFeeds[token];
    (,int256 answer,,,) = priceFeed.latestRoundData();
    vm.prank(admin);
    oracle.setPrice(token, uint256(answer));
  }

  function normalProvide(uint256 token1Amount) public returns (uint256) {
    syncPrice(token0);
    syncPrice(token1);

    // 10 WBNB + x CAKE which worth 10 BNB
    uint256 tokenId1 = mintLp(token1Amount);

    (uint256 amount0, uint256 amount1) = pcsProvider.getAmounts(tokenId1);
    assertGt(pcsProvider.getLpValue(tokenId1), 0, "pcsProvider should return a valid LP value");

    vm.startPrank(user);
    // approve NFT to pcsProvider
    IERC721(nonfungiblePositionManager).approve(address(pcsProvider), tokenId1);
    // provide LP
    pcsProvider.provide(tokenId1);
    vm.stopPrank();

    // LP goes into pcsStakingHub
    assertEq(pcsProvider.lpOwners(tokenId1), user, "pcsProvider should record the owner of LP token");
    assertGt(pcsProvider.userTotalLpValue(user), 0, "pcsProvider should record the user total LP value");
    assertGt(pcsProvider.lpValues(tokenId1), 0, "pcsProvider should record the LP value of the tokenId");
    assertGt(interaction.locked(address(lpUsd), user), 0, "interaction should record the locked LP USD for user");

    return tokenId1;
  }

  function mintLp(uint256 token1Amt) public returns (uint256) {
    uint256 token0Price = oracle.prices(token0);
    uint256 token1Price = oracle.prices(token1);
    uint24 fee = 2500; // 0.25% fee tier in practice
    address pool = IUniswapV3Factory(pancakeV3Factory).getPool(token0, token1, fee);
    (,int24 currentTick,,,,,) = IUniswapV3Pool(pool).slot0();
    int24 baseTick = (currentTick / 50) * 50; // round down to nearest tickSpacing
    int24 tickLower = baseTick - 3 * 50;
    int24 tickUpper = baseTick + 3 * 50;
    uint256 amount1Desired = token1Amt;
    uint256 amount0Desired = amount1Desired * (token1Price / 1e8);

    vm.startPrank(user);
    IERC20(token0).approve(address(nonfungiblePositionManager), type(uint256).max);
    IERC20(token1).approve(address(nonfungiblePositionManager), type(uint256).max);
    INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
      token0: address(token0),
      token1: address(token1),
      fee: fee,
      tickLower: tickLower,
      tickUpper: tickUpper,
      amount0Desired: amount1Desired * (token1Price/token0Price),
      amount1Desired: amount1Desired,
      amount0Min: 0,
      amount1Min: 0,
      recipient: user,
      deadline: block.timestamp + 1 hours
    });
    // Mint LP NFT
    (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
                INonfungiblePositionManager(nonfungiblePositionManager).mint(params);
    vm.stopPrank();
    assertEq(IERC721(nonfungiblePositionManager).ownerOf(tokenId), user);
    assertGt(liquidity, 0);
    // push into tokenIds
    tokenIds.push(tokenId);

    return tokenId;
  }
  // ------------ /Utilities -------------- //
}
