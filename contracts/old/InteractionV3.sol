// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../hMath.sol";
import "../oracle/libraries/FullMath.sol";
import "../interfaces/VatLike.sol";
import "../interfaces/HayJoinLike.sol";
import "../interfaces/GemJoinLike.sol";
import "../interfaces/JugLike.sol";
import "../interfaces/DogLike.sol";
import "../interfaces/PipLike.sol";
import "../interfaces/SpotLike.sol";
import "../interfaces/IRewards.sol";
import "../interfaces/IAuctionProxy.sol";
import "../interfaces/IBorrowLisUSDListaDistributor.sol";
import "../interfaces/IDynamicDutyCalculator.sol";
import "../ceros/interfaces/IHelioProvider.sol";
import "../ceros/interfaces/IDao.sol";

import "../libraries/AuctionProxy.sol";

uint256 constant WAD = 10 ** 18;
uint256 constant RAD = 10 ** 45;
uint256 constant YEAR = 31556952; //seconds in year (365.2425 * 24 * 3600)

contract InteractionV3 is OwnableUpgradeable, IDao, IAuctionProxy {

    mapping(address => uint) public wards;
    function rely(address usr) external auth {wards[usr] = 1;}
    function deny(address usr) external auth {wards[usr] = 0;}
    modifier auth {
        require(wards[msg.sender] == 1, "Interaction/not-authorized");
        _;
    }

    VatLike public vat;
    SpotLike public spotter;
    IERC20Upgradeable public hay;
    HayJoinLike public hayJoin;
    JugLike public jug;
    address public dog;
    IRewards public helioRewards; // Deprecated

    mapping(address => uint256) public deposits;
    mapping(address => CollateralType) public collaterals;

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => address) public helioProviders; // e.g. Auction purchase from ceabnbc to abnbc

    uint256 public whitelistMode;
    address public whitelistOperator;
    mapping(address => uint) public whitelist;
    mapping(address => uint) public tokensBlacklist;
    bool private _entered;
    IDynamicDutyCalculator public dutyCalculator;
    uint256 public auctionWhitelistMode;

    mapping(address => uint) public auctionWhitelist;

    IBorrowLisUSDListaDistributor public borrowLisUSDListaDistributor;

    function enableWhitelist() external auth {whitelistMode = 1;}
    function disableWhitelist() external auth {whitelistMode = 0;}
    function enableAuctionWhitelist() external auth {auctionWhitelistMode = 1;}
    function disableAuctionWhitelist() external auth {auctionWhitelistMode = 0;}

    function setWhitelistOperator(address usr) external auth {
        whitelistOperator = usr;
    }
    function addToWhitelist(address[] memory usrs) external operatorOrWard {
        for(uint256 i = 0; i < usrs.length; i++)
            whitelist[usrs[i]] = 1;
    }
    function removeFromWhitelist(address[] memory usrs) external operatorOrWard {
        for(uint256 i = 0; i < usrs.length; i++)
            whitelist[usrs[i]] = 0;
    }
    function addToAuctionWhitelist(address[] memory usrs) external operatorOrWard {
        for(uint256 i = 0; i < usrs.length; i++)
            auctionWhitelist[usrs[i]] = 1;
    }
    function removeFromAuctionWhitelist(address[] memory usrs) external operatorOrWard {
        for(uint256 i = 0; i < usrs.length; i++)
            auctionWhitelist[usrs[i]] = 0;
    }
    function addToBlacklist(address[] memory tokens) external auth {
        for(uint256 i = 0; i < tokens.length; i++)
            tokensBlacklist[tokens[i]] = 1;
    }
    function removeFromBlacklist(address[] memory tokens) external auth {
        for(uint256 i = 0; i < tokens.length; i++)
            tokensBlacklist[tokens[i]] = 0;
    }
    function setListaDistributor(address distributor) external auth {
        require(distributor != address(0), "Interaction/lista-distributor-zero-address");
        require(address(borrowLisUSDListaDistributor) != distributor, "Interaction/same-distributor-address");
        borrowLisUSDListaDistributor = IBorrowLisUSDListaDistributor(distributor);
    }
    modifier whitelisted(address participant) {
        if (whitelistMode == 1)
            require(whitelist[participant] == 1, "Interaction/not-in-whitelist");
        _;
    }
    modifier auctionWhitelisted {
        if (auctionWhitelistMode == 1)
            require(auctionWhitelist[msg.sender] == 1, "Interaction/not-in-auction-whitelist");
        _;
    }
    modifier operatorOrWard {
        require(msg.sender == whitelistOperator || wards[msg.sender] == 1, "Interaction/not-operator-or-ward");
        _;
    }
    modifier notInBlacklisted(address token) {
        require (tokensBlacklist[token] == 0, "Interaction/token-in-blacklist");
        _;
    }
    modifier nonReentrant {
        require(!_entered, "re-entrant call");
        _entered = true;
        _;
        _entered = false;
    }
    function initialize(
        address vat_,
        address spot_,
        address hay_,
        address hayJoin_,
        address jug_,
        address dog_,
        address rewards_
    ) public initializer {
        __Ownable_init();

        wards[msg.sender] = 1;

        vat = VatLike(vat_);
        spotter = SpotLike(spot_);
        hay = IERC20Upgradeable(hay_);
        hayJoin = HayJoinLike(hayJoin_);
        jug = JugLike(jug_);
        dog = dog_;
        helioRewards = IRewards(rewards_);

        vat.hope(hayJoin_);

        hay.safeApprove(hayJoin_, type(uint256).max);
    }

    function setCores(address vat_, address spot_, address hayJoin_,
        address jug_) public auth {
        // Reset previous approval
        hay.safeApprove(address(hayJoin), 0);

        vat = VatLike(vat_);
        spotter = SpotLike(spot_);
        hayJoin = HayJoinLike(hayJoin_);
        jug = JugLike(jug_);

        vat.hope(hayJoin_);

        hay.safeApprove(hayJoin_, type(uint256).max);
    }

    function setHayApprove() public auth {
        hay.safeApprove(address(hayJoin), type(uint256).max);
    }

    function setCollateralType(
        address token,
        address gemJoin,
        bytes32 ilk,
        address clip,
        uint256 mat
    ) external auth {
        require(collaterals[token].live == 0, "Interaction/token-already-init");
        vat.init(ilk);
        jug.init(ilk);
        spotter.file(ilk, "mat", mat);
        collaterals[token] = CollateralType(GemJoinLike(gemJoin), ilk, 1, clip);
        IERC20Upgradeable(token).safeApprove(gemJoin, type(uint256).max);
        vat.rely(gemJoin);
        emit CollateralEnabled(token, ilk);
    }

    function setCollateralDuty(address token, uint256 duty) public auth {
        _setCollateralDuty(token, duty);
    }

    function _setCollateralDuty(address token, uint256 duty) private {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);
        jug.drip(collateralType.ilk);
        jug.file(collateralType.ilk, "duty", duty);
    }

    function setHelioProvider(address token, address helioProvider) external auth {
        helioProviders[token] = helioProvider;
    }

    function removeCollateralType(address token) external auth {
        require(collaterals[token].live != 0, "Interaction/token-not-init");
        collaterals[token].live = 2; //STOPPED
        address gemJoin = address(collaterals[token].gem);
        vat.deny(gemJoin);
        IERC20Upgradeable(token).safeApprove(gemJoin, 0);
        emit CollateralDisabled(token, collaterals[token].ilk);
    }

    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    function deposit(
        address participant,
        address token,
        uint256 dink
    ) external whitelisted(participant) notInBlacklisted(token) nonReentrant returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        require(collateralType.live == 1, "Interaction/inactive-collateral");

        if (helioProviders[token] != address(0)) {
            require(
                msg.sender == helioProviders[token],
                "Interaction/only helio provider can deposit for this token"
            );
        }
        require(dink <= uint256(type(int256).max), "Interaction/too-much-requested");
        drip(token);
        uint256 preBalance = IERC20Upgradeable(token).balanceOf(address(this));
        IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), dink);
        uint256 postBalance = IERC20Upgradeable(token).balanceOf(address(this));
        require(preBalance + dink == postBalance, "Interaction/deposit-deflated");

        collateralType.gem.join(participant, dink);
        vat.behalf(participant, address(this));
        vat.frob(collateralType.ilk, participant, participant, participant, int256(dink), 0);

        deposits[token] += dink;

        emit Deposit(participant, token, dink, locked(token, participant));
        return dink;
    }

    function borrow(address token, uint256 hayAmount) external notInBlacklisted(token) nonReentrant returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        require(collateralType.live == 1, "Interaction/inactive-collateral");

        drip(token);
        poke(token);

        (, uint256 rate, , ,) = vat.ilks(collateralType.ilk);
        int256 dart = int256(hayAmount * RAY / rate);
        require(dart >= 0, "Interaction/too-much-requested");

        if (uint256(dart) * rate < hayAmount * RAY) {
            dart += 1; //ceiling
        }

        vat.frob(collateralType.ilk, msg.sender, msg.sender, msg.sender, 0, dart);
        vat.move(msg.sender, address(this), hayAmount * RAY);
        hayJoin.exit(msg.sender, hayAmount);

        (uint256 ink, uint256 art) = vat.urns(collateralType.ilk, msg.sender);
        uint256 liqPrice = liquidationPriceForDebt(collateralType.ilk, ink, art);

        takeSnapshot(token, msg.sender, art);

        emit Borrow(msg.sender, token, ink, hayAmount, liqPrice);
        return uint256(dart);
    }

    // Burn user's HAY.
    // N.B. User collateral stays the same.
    function payback(address token, uint256 hayAmount) external nonReentrant returns (int256) {
        CollateralType memory collateralType = collaterals[token];
        // _checkIsLive(collateralType.live); Checking in the `drip` function

        drip(token);
        poke(token);
        (,uint256 rate,,,) = vat.ilks(collateralType.ilk);
        (,uint256 art) = vat.urns(collateralType.ilk, msg.sender);

        int256 dart;
        uint256 realAmount = hayAmount;

        uint256 debt = rate * art;
        if (realAmount * RAY >= debt) { // Close CDP
            dart = int(art);
            realAmount = debt / RAY;
            realAmount = realAmount * RAY == debt ? realAmount : realAmount + 1;
        } else { // Less/Greater than dust
            dart = int256(FullMath.mulDiv(realAmount, RAY, rate));
        }

        IERC20Upgradeable(hay).safeTransferFrom(msg.sender, address(this), realAmount);
        hayJoin.join(msg.sender, realAmount);

        require(dart >= 0, "Interaction/too-much-requested");

        vat.frob(collateralType.ilk, msg.sender, msg.sender, msg.sender, 0, - dart);

        (uint256 ink, uint256 userDebt) = vat.urns(collateralType.ilk, msg.sender);
        uint256 liqPrice = liquidationPriceForDebt(collateralType.ilk, ink, userDebt);

        takeSnapshot(token, msg.sender, userDebt);

        emit Payback(msg.sender, token, realAmount, userDebt, liqPrice);
        return dart;
    }

    /**
     * @dev take snapshot of user's debt
     * @param token collateral token address
     * @param user user address
     */
    function takeSnapshot(address token, address user, uint256 amount) private {
        // ensure the distributor address is set
        if (address(borrowLisUSDListaDistributor) != address(0)) {
            borrowLisUSDListaDistributor.takeSnapshot(token, user, amount);
        }
    }

    /**
     * @dev synchronize user's debt to the snapshot contract
     * @notice this function can be called by anyone
               it also act as an initialisation function of user's snapshot data
     * @param token collateral token address
     * @param user user address
     */
    function syncSnapshot(address token, address user) external {
        // check user debt is 0?
        (, uint256 userDebt) = vat.urns(collaterals[token].ilk, user);
        // sync user debt only if it is greater than 0
        if (userDebt > 0) {
            takeSnapshot(token, user, userDebt);
        }
    }

    // Unlock and transfer to the user `dink` amount of ceABNBc
    function withdraw(
        address participant,
        address token,
        uint256 dink
    ) external nonReentrant returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        drip(token);
        poke(token);
        if (helioProviders[token] != address(0)) {
            require(
                msg.sender == helioProviders[token],
                "Interaction/Only helio provider can call this function for this token"
            );
        } else {
            require(
                msg.sender == participant,
                "Interaction/Caller must be the same address as participant"
            );
        }

        uint256 unlocked = free(token, participant);
        if (unlocked < dink) {
            int256 diff = int256(dink) - int256(unlocked);
            vat.frob(collateralType.ilk, participant, participant, participant, - diff, 0);
        }
        // move the dink amount of collateral from participant to the current contract
        vat.flux(collateralType.ilk, participant, address(this), dink);
        // Collateral is actually transferred back to user inside `exit` operation.
        // See GemJoin.exit()
        collateralType.gem.exit(msg.sender, dink);
        deposits[token] -= dink;

        emit Withdraw(participant, dink);
        return dink;
    }

    function drip(address token) public {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        bytes32 _ilk = collateralType.ilk;
        (uint256 currentDuty,) = jug.ilks(_ilk);
        uint256 duty = dutyCalculator.calculateDuty(token, currentDuty, true);
        if (duty != currentDuty) {
            _setCollateralDuty(token, duty);
        } else {
            jug.drip(_ilk);
        }
    }

    function poke(address token) public {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        spotter.poke(collateralType.ilk);
    }

    //    /////////////////////////////////
    //    //// VIEW                    ////
    //    /////////////////////////////////

    // Price of the collateral asset(ceABNBc) from Oracle
    function collateralPrice(address token) public view returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        (PipLike pip,) = spotter.ilks(collateralType.ilk);
        (bytes32 price, bool has) = pip.peek();
        require(has, "Interaction/invalid-price");
        return uint256(price);
    }

    // Returns the HAY price in $
    function hayPrice(address token) external view returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        (, uint256 rate,,,) = vat.ilks(collateralType.ilk);
        return rate / 10 ** 9;
    }

    // Returns the collateral ratio in percents with 18 decimals
    function collateralRate(address token) external view returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        (,uint256 mat) = spotter.ilks(collateralType.ilk);
        require(mat != 0, "Interaction/spot-not-init");
        return 10 ** 45 / mat;
    }

    // Total ceABNBc deposited nominated in $
    function depositTVL(address token) external view returns (uint256) {
        return deposits[token] * collateralPrice(token) / WAD;
    }

    // Total HAY borrowed by all users
    function collateralTVL(address token) external view returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        (uint256 Art, uint256 rate,,,) = vat.ilks(collateralType.ilk);
        return FullMath.mulDiv(Art, rate, RAY);
    }

    // Not locked user balance in ceABNBc
    function free(address token, address usr) public view returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        return vat.gem(collateralType.ilk, usr);
    }

    // User collateral in ceABNBc
    function locked(address token, address usr) public view returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        (uint256 ink,) = vat.urns(collateralType.ilk, usr);
        return ink;
    }

    // Total borrowed HAY
    function borrowed(address token, address usr) external view returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        (,uint256 rate,,,) = vat.ilks(collateralType.ilk);
        (, uint256 art) = vat.urns(collateralType.ilk, usr);

        // 100 Wei is added as a ceiling to help close CDP in repay()
        if ((art * rate) / RAY != 0) {
            return ((art * rate) / RAY) + 100;
        }
        else {
            return 0;
        }
    }

    // Collateral minus borrowed. Basically free collateral (nominated in HAY)
    function availableToBorrow(address token, address usr) external view returns (int256 amount) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        (uint256 ink, uint256 art) = vat.urns(collateralType.ilk, usr);
        (, uint256 rate, uint256 spot,,) = vat.ilks(collateralType.ilk);
        uint256 collateral = ink * spot;
        uint256 debt = rate * art;
        amount = (int256(collateral) - int256(debt)) / 1e27;

        if(amount < 0) return 0;
    }

    // Collateral + `amount` minus borrowed. Basically free collateral (nominated in HAY)
    // Returns how much hay you can borrow if provide additional `amount` of collateral
    function willBorrow(address token, address usr, int256 amount) external view returns (int256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        (uint256 ink, uint256 art) = vat.urns(collateralType.ilk, usr);
        (, uint256 rate, uint256 spot,,) = vat.ilks(collateralType.ilk);
        require(amount >= - (int256(ink)), "Cannot withdraw more than current amount");
        if (amount < 0) {
            ink = uint256(int256(ink) + amount);
        } else {
            ink += uint256(amount);
        }
        uint256 collateral = ink * spot;
        uint256 debt = rate * art;
        return (int256(collateral) - int256(debt)) / 1e27;
    }

    function liquidationPriceForDebt(bytes32 ilk, uint256 ink, uint256 art) internal view returns (uint256) {
        if (ink == 0) {
            return 0; // no meaningful price if user has no debt
        }
        (, uint256 rate,,,) = vat.ilks(ilk);
        (,uint256 mat) = spotter.ilks(ilk);
        uint256 backedDebt = (art * rate / 10 ** 36) * mat;
        return backedDebt / ink;
    }

    // Price of ceABNBc when user will be liquidated
    function currentLiquidationPrice(address token, address usr) external view returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        (uint256 ink, uint256 art) = vat.urns(collateralType.ilk, usr);
        return liquidationPriceForDebt(collateralType.ilk, ink, art);
    }

    // Returns borrow APR with 20 decimals.
    // I.e. 10% == 10 ethers
    function borrowApr(address token) public view returns (uint256) {
        CollateralType memory collateralType = collaterals[token];
        _checkIsLive(collateralType.live);

        (uint256 duty,) = jug.ilks(collateralType.ilk);
        uint256 principal = hMath.rpow((jug.base() + duty), YEAR, RAY);
        return (principal - RAY) / (10 ** 7);
    }

    function startAuction(
        address token,
        address user,
        address keeper
    ) external auctionWhitelisted returns (uint256) {

        drip(token);
        poke(token);

        CollateralType memory collateral = collaterals[token];
        (uint256 ink,) = vat.urns(collateral.ilk, user);
        IHelioProvider provider = IHelioProvider(helioProviders[token]);
        uint256 auctionAmount = AuctionProxy.startAuction(
            user,
            keeper,
            hay,
            hayJoin,
            vat,
            DogLike(dog),
            provider,
            collateral
        );
        // after auction started, user's debt of the token becomes 0
        takeSnapshot(token, user, 0);

        emit AuctionStarted(token, user, ink, collateralPrice(token));
        return auctionAmount;
    }

    function buyFromAuction(
        address token,
        uint256 auctionId,
        uint256 collateralAmount,
        uint256 maxPrice,
        address receiverAddress
    ) external auctionWhitelisted {
        CollateralType memory collateral = collaterals[token];
        IHelioProvider helioProvider = IHelioProvider(helioProviders[token]);
        uint256 leftover = AuctionProxy.buyFromAuction(
            auctionId,
            collateralAmount,
            maxPrice,
            receiverAddress,
            hay,
            hayJoin,
            vat,
            helioProvider,
            collateral
        );

        address urn = ClipperLike(collateral.clip).sales(auctionId).usr; // Liquidated address

        emit Liquidation(urn, token, collateralAmount, leftover);
    }

    function getAuctionStatus(address token, uint256 auctionId) external view returns(bool, uint256, uint256, uint256) {
        return ClipperLike(collaterals[token].clip).getStatus(auctionId);
    }

    function upchostClipper(address token) external {
        ClipperLike(collaterals[token].clip).upchost();
    }

    function getAllActiveAuctionsForToken(address token) external view returns (Sale[] memory sales) {
        return AuctionProxy.getAllActiveAuctionsForClip(ClipperLike(collaterals[token].clip));
    }

    function resetAuction(address token, uint256 auctionId, address keeper) external auctionWhitelisted {
        AuctionProxy.resetAuction(auctionId, keeper, hay, hayJoin, vat, collaterals[token]);
    }

    function totalPegLiquidity() external view returns (uint256) {
        return IERC20Upgradeable(hay).totalSupply();
    }

    function _checkIsLive(uint256 live) internal pure {
        require(live != 0, "Interaction/inactive collateral");
    }

    function setDutyCalculator(address _dutyCalculator) external auth {
        require(_dutyCalculator != address(0) && _dutyCalculator != address(dutyCalculator), "Interaction/invalid-dutyCalculator-address");
        dutyCalculator = IDynamicDutyCalculator(_dutyCalculator);
        require(dutyCalculator.interaction() == address(this), "Interaction/invalid-dutyCalculator-interaction");
    }

    /**
     * @dev Returns the next duty for the given collateral. This function is used by the frontend to display the next duty.
     *      Can be accessed as a view from within the UX since no state changes and no events emitted.
     * @param _collateral The address of the collateral
     * @return duty The next duty
     */
    function getNextDuty(address _collateral) external returns (uint256 duty) {
        CollateralType memory collateral = collaterals[_collateral];

        (uint256 currentDuty,) = jug.ilks(collateral.ilk);

        duty = dutyCalculator.calculateDuty(_collateral, currentDuty, false);
    }
}
