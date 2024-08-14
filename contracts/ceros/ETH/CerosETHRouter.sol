// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IETHVault.sol";
import "../interfaces/ICerosETHRouter.sol";
import "../interfaces/ICertToken.sol";
import "../interfaces/IBETH.sol";

contract CerosETHRouter is
ICerosETHRouter,
OwnableUpgradeable,
PausableUpgradeable,
ReentrancyGuardUpgradeable
{
    /**
     * Variables
     */
    IETHVault private _vault;
    // Tokens
    ICertToken private _certToken; // (default ETH)
    IERC20 private _ceToken; // (default cewBETH)
    IBETH private _BETH; // new
    address private _provider;
    address private _referral;
    uint256 private _minStake;
    uint256 private _certTokenRatio; // 20% ETH, wBETH
    using SafeERC20 for IERC20;
    /**
     * Modifiers
     */
    modifier onlyProvider() {
        require(
            msg.sender == owner() || msg.sender == _provider,
            "Provider: not allowed"
        );
        _;
    }
    function initialize(
        address certToken,
        address ceToken,
        address BETH,
        address vault,
        uint256 minStake,
        address referral,
        uint256 certTokenRatio
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        _certToken = ICertToken(certToken);
        _ceToken = IERC20(ceToken);
        _vault = IETHVault(vault);
        _minStake = minStake;
        _referral = referral;
        _certTokenRatio = certTokenRatio;
        _BETH = IBETH(BETH);
        IERC20(certToken).safeApprove(vault, type(uint256).max);
        IERC20(certToken).safeApprove(BETH, type(uint256).max);
        IERC20(BETH).safeApprove(vault, type(uint256).max);
    }
    /**
     * DEPOSIT
     */
    function deposit(uint256 amount)
    external
    override
    onlyProvider
    nonReentrant
    returns (uint256 value)
    {
        require(amount >= _minStake, "amount must be greater than minStake");
        IERC20(_certToken).safeTransferFrom(msg.sender, address(this), amount);
        // keep the ratio as 80%
        uint256 ceTokenPreBalance = _vault.getCeTokenBalanceOf(address(this));
        uint256 certTokenAmountBalance = _certToken.balanceOf(address(_vault));
        uint256 ceTokenPostBalance = ceTokenPreBalance + amount;
        uint256 certTokenAmount;
        if (ceTokenPostBalance * _certTokenRatio / 1e18 >= certTokenAmountBalance) {
            certTokenAmount = ceTokenPostBalance * _certTokenRatio / 1e18 - certTokenAmountBalance;
        }
        uint256 BETHAmount;
        if (amount > certTokenAmount) {
            BETHAmount = (amount - certTokenAmount) * 1e18 / _BETH.exchangeRate();
            if (BETHAmount > 0) {
                _BETH.deposit(amount - certTokenAmount, _referral);
            } else {
                certTokenAmount = amount;
                BETHAmount = 0;
            }
        } else {
            certTokenAmount = amount;
        }

        value = _vault.depositFor(msg.sender, certTokenAmount, BETHAmount);

        emit Deposit(msg.sender, certTokenAmount, BETHAmount);
        return value;
    }
    /**
     * CLAIM
     */
    // claim yields in wBETH and ETH
    function claim(address recipient)
    external
    override
    nonReentrant
    onlyProvider
    returns (uint256 yields)
    {
        yields = _vault.claimYieldsFor(address(this), recipient);
        emit Claim(recipient, address(_certToken), yields);
        return yields;
    }
    /**
     * WITHDRAWAL
     */
    // withdrawal ETH
    /// @param recipient address to receive withdrawan ETH
    /// @param amount in ETH
    function withdrawETH(address recipient, uint256 amount)
    external
    override
    onlyProvider
    nonReentrant
    returns (uint256 realAmount)
    {
        realAmount = _vault.withdrawETHFor(msg.sender, recipient, amount);
        emit Withdrawal(msg.sender, recipient, address(_certToken), realAmount);
        return realAmount;
    }
    /// @param amount in ETH
    /// @return realAmount in wBETH
    function withdrawBETH(address recipient, uint256 amount)
    external
    override
    onlyProvider
    nonReentrant
    returns (uint256 realAmount)
    {
        realAmount = _vault.withdrawBETHFor(msg.sender, recipient, amount);
        emit Withdrawal(msg.sender, recipient, address(_BETH), realAmount);
        return realAmount;
    }
    function liquidation(address recipient, uint256 amount)
    external
    override
    onlyProvider
    nonReentrant
    {
        uint256 totalETHAmount = _vault.getTotalETHAmountInVault();
        if (totalETHAmount >= amount) {
            _vault.withdrawETHFor(msg.sender, recipient, amount);
            return;
        }
        uint256 diff = amount - totalETHAmount;
        _vault.withdrawETHFor(msg.sender, recipient, totalETHAmount);
        _vault.withdrawBETHFor(msg.sender, recipient, diff);
    }
    function changeVault(address vault) external onlyOwner {
        // update allowances
        IERC20(_certToken).safeApprove(address(_vault), 0);
        IERC20(_BETH).safeApprove(vault, 0);
        _vault = IETHVault(vault);
        IERC20(_certToken).safeApprove(address(_vault), type(uint256).max);
        IERC20(_BETH).safeApprove(vault, type(uint256).max);
        emit ChangeVault(vault);
    }
    function changeProvider(address provider) external onlyOwner {
        _provider = provider;
        emit ChangeProvider(provider);
    }
    function changeMinStakeAmount(uint256 minStake) external onlyOwner {
        _minStake = minStake;
        emit ChangeMinStakeAmount(minStake);
    }
    function changeCertTokenRatio(uint256 ratio) external onlyOwner {
        require(ratio >= 0 && ratio <= 1e18, "invalid cert token ratio");
        _certTokenRatio = ratio;
        emit ChangeCertTokenRatio(ratio);
    }
    function getProvider() external view returns(address) {
        return _provider;
    }
    function getCeToken() external view returns(address) {
        return address(_ceToken);
    }
    function getCertToken() external view returns(address) {
        return address(_certToken);
    }
    function getCertTokenRatio() external view returns(uint256) {
        return _certTokenRatio;
    }
    function getReferral() external view returns(address) {
        return _referral;
    }
    function getVaultAddress() external view returns(address) {
        return address(_vault);
    }
    function getMinStake() external view returns(uint256) {
        return _minStake;
    }

    /**
     * @dev Change referral address, onlyOwner
     * @param referral new address
     */
    function changeReferral(address referral) external onlyOwner {
        require(referral != address(0) && referral != _referral, "invalid referral address");
        _referral = referral;
    }
}
