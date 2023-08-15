// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IETHVault.sol";
import "../interfaces/ICertToken.sol";
import "../interfaces/IBETH.sol";
import "../interfaces/ICerosETHRouter.sol";

contract CeETHVault is
IETHVault,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable
{
    /**
     * Variables
     */
    string private _name;
    // Tokens
    ICertToken private _ceToken;
    IBETH private _BETH;
    ICertToken private _certToken; // ETH
    address private _router;
    mapping(address => uint256) private _claimed; // in wBETH
    mapping(address => uint256) private _depositors; // track in wBETH
    mapping(address => uint256) private _ceTokenBalances; // in ETH
    address private _strategist;
    uint256 private _withdrawalFee;
    /**
     * Modifiers
     */
    modifier onlyRouter() {
        require(msg.sender == _router, "Router: not allowed");
        _;
    }
    modifier onlyStrategist() {
        require(msg.sender == _strategist, "Router: not allowed");
        _;
    }
    function initialize(
        string memory name,
        address certToken,
        address ceTokenAddress,
        address wBETHAddress,
        uint256 withdrawalFee,
        address strategist
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        _name = name;
        _certToken = ICertToken(certToken);
        _ceToken = ICertToken(ceTokenAddress);
        _BETH = IBETH(wBETHAddress);
        _withdrawalFee = withdrawalFee;
        _strategist = strategist;
    }
    // deposit
    function depositFor(address recipient, uint256 certTokenAmount, uint256 wBETHAmount)
    external
    override
    nonReentrant
    onlyRouter
    returns (uint256)
    {
        return _deposit(recipient, certTokenAmount, wBETHAmount);
    }
    // deposit
    function _deposit(address account, uint256 certTokenAmount, uint256 wBETHAmount)
    private
    returns (uint256)
    {
        uint256 ratio = _BETH.exchangeRate();
        _BETH.transferFrom(msg.sender, address(this), wBETHAmount);
        _certToken.transferFrom(msg.sender, address(this), certTokenAmount);
        uint256 toMint = (wBETHAmount * ratio) / 1e18 + certTokenAmount;
        _depositors[account] += wBETHAmount; // wBETH
        _ceTokenBalances[account] += toMint;
        //  mint ceToken to recipient
        ICertToken(_ceToken).mint(account, toMint);
        emit Deposited(msg.sender, account, toMint);
        return toMint;
    }
    function claimYieldsFor(address owner, address recipient)
    external
    override
    onlyRouter
    nonReentrant
    returns (uint256)
    {
        return _claimYields(owner, recipient);
    }
    function _claimYields(address owner, address recipient)
    private
    returns (uint256)
    {
        uint256 availableYields = this.getYieldFor(owner);
        require(availableYields > 0, "has not got yields to claim");
        // return back BETH to recipient
        _claimed[owner] += availableYields;
        uint256 balance = _BETH.balanceOf(address(this));
        if (balance >= availableYields) {
            _BETH.transfer(recipient, availableYields);
        } else {
            uint256 amountInETH = (availableYields - balance) * _BETH.exchangeRate() / 1e18;
            _BETH.transfer(recipient, balance);
            _certToken.transfer(recipient, amountInETH);
        }
        emit Claimed(owner, recipient, availableYields);
        return availableYields;
    }
    // withdraw
    function withdrawETHFor(
        address owner,
        address recipient,
        uint256 amount
    ) external override nonReentrant onlyRouter returns (uint256) {
        return _withdrawETH(owner, recipient, amount);
    }
    function _withdrawETH(
        address owner,
        address recipient,
        uint256 amount
    ) private returns (uint256) {
        require(
            _certToken.balanceOf(address(this)) >= amount,
            "not such amount in the vault"
        );
        uint256 balance = _ceTokenBalances[owner];
        require(balance >= amount, "insufficient balance");
        _ceTokenBalances[owner] -= amount; // BNB
        // burn ceToken from owner
        ICertToken(_ceToken).burn(owner, amount);
        uint256 feeCharged = amount * _withdrawalFee / 1e18;
        _certToken.transfer(recipient, amount - feeCharged);
        address referral = ICerosETHRouter(_router).getReferral();
        _certToken.transfer(referral, feeCharged);
        emit Withdrawn(owner, recipient, amount - feeCharged);
        return amount - feeCharged;
    }
    function withdrawBETHFor(
        address owner,
        address recipient,
        uint256 amount
    ) external override nonReentrant onlyRouter returns (uint256) {
        return _withdrawBETH(owner, recipient, amount);
    }
    function _withdrawBETH(
        address owner,
        address recipient,
        uint256 amount
    ) private returns (uint256) {
        uint256 ratio = _BETH.exchangeRate();
        uint256 realAmount = (amount * 1e18) / ratio;
        require(
            _BETH.balanceOf(address(this)) >= realAmount,
            "not such BETH amount in the vault"
        );
        uint256 balance = _ceTokenBalances[owner];
        require(balance >= amount, "insufficient balance");
        _ceTokenBalances[owner] -= amount; // ETH
        // burn ceToken from owner
        ICertToken(_ceToken).burn(owner, amount);
        require(_depositors[owner] >= realAmount, "invalid withdraw amount");
        _depositors[owner] -= realAmount; // wBETH
        _BETH.transfer(recipient, realAmount);
        emit Withdrawn(owner, recipient, amount);
        return realAmount;
    }

    function rebalance() external onlyStrategist returns (uint256) {
        ICerosETHRouter router = ICerosETHRouter(_router);
        uint256 ratio = router.getCertTokenRatio();
        uint256 amount = _certToken.balanceOf(address(this)) * (1e8 - ratio) / 1e8;
        uint256 preBalance = _BETH.balanceOf(address(this));
        _BETH.deposit(amount, router.getReferral());
        uint256 postBalance = _BETH.balanceOf(address(this));
        address provider = router.getProvider();
        _depositors[provider] += postBalance - preBalance;

        emit Rebalanced(amount);
        return amount;
    }
    
    function getTotalBETHAmountInVault() external view override returns (uint256) {
        return _BETH.balanceOf(address(this));
    }

    function getTotalETHAmountInVault() external view override returns (uint256) {
        return _certToken.balanceOf(address(this));
    }
    // yield + principal = deposited(before claim)
    // BUT after claim yields: available_yield + principal == deposited - claimed
    // available_yield = yield - claimed;
    // principal = deposited*(current_ratio/init_ratio)=cetoken.balanceOf(account)*current_ratio;
    function getPrincipalOf(address account)
    external
    view
    override
    returns (uint256)
    {
        uint256 ratio = _BETH.exchangeRate();
        return (_ceTokenBalances[account] * 1e18) / ratio; // in aBNBc
    }
    // yield = deposited*(1-current_ratio/init_ratio) = cetoken.balanceOf*init_ratio-cetoken.balanceOf*current_ratio
    // yield = cetoken.balanceOf*(init_ratio-current_ratio) = amount(in aBNBc) - amount(in aBNBc)
    function getYieldFor(address account)
    external
    view
    override
    returns (uint256)
    {
        uint256 principal = this.getPrincipalOf(account);
        if (principal >= _depositors[account]) {
            return 0;
        }
        uint256 totalYields = _depositors[account] - principal;
        if (totalYields <= _claimed[account]) {
            return 0;
        }
        return totalYields - _claimed[account];
    }
    function getCeTokenBalanceOf(address account)
    external
    view
    returns (uint256)
    {
        return _ceTokenBalances[account];
    }
    function getDepositOf(address account) external view returns (uint256) {
        return _depositors[account];
    }
    function getClaimedOf(address account) external view returns (uint256) {
        return _claimed[account];
    }
    function changeRouter(address router) external onlyOwner {
        _router = router;
        emit RouterChanged(router);
    }
    function changeWithdrawalFee(uint256 withdrawalFee) external onlyOwner {
        _withdrawalFee = withdrawalFee;
        emit WithdrawalFeeChanged(withdrawalFee);
    }
    function setStrategist(address strategist) external onlyOwner {
        _strategist = strategist;
        emit SetStrategist(strategist);
    }
    function changeCertToken(address token) external onlyOwner {
        _BETH = IBETH(token);
    }
    function getName() external view returns (string memory) {
        return _name;
    }
    function getCeToken() external view returns(address) {
        return address(_ceToken);
    }
    function getBETHAddress() external view returns(address) {
        return address(_BETH);
    }
    function getRouter() external view returns(address) {
        return address(_router);
    }
}