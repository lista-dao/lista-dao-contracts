// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.6;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IETHVault.sol";
import "../interfaces/ICertToken.sol";
import "../interfaces/IBETH.sol";
import "../interfaces/ICerosETHRouter.sol";
import "../interfaces/IUnwrapETH.sol";

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
    mapping(address => uint256) private _depositors; // track wBETH balance
    mapping(address => uint256) private _ceTokenBalances; // in ETH
    address private _strategist;
    uint256 private _withdrawalFee;
    mapping(address => uint256) private _certTokenValues; // in ETH
    using SafeERC20 for IERC20;

    // added, 2024-08-21
    uint256 public constant MAX_LOOP_NUM = 100; // max loop number
    address private _unwrapEthAddress = 0x79973d557CD9dd87eb61E250cc2572c990e20196; // prod, wBETH unwrap address
    struct UserWithdrawRequest {
        address owner; // owner in request
        address recipient; // user who withdraw
        uint256 ethAmount; // total request ETH amount
        uint256 feeAmount; // fee in ETH
        uint256 triggerTime; // user trigger time
        uint256 userRequestIndex; // index in _withdrawRequests[recipient]
    }
    mapping(uint256 => UserWithdrawRequest) private _withdrawRequests; // all request queue
    mapping(address => uint256[]) private _userWithdrawRequests; // user request withdraw
    uint256 public _nextIndex; // user request index
    uint256 public _startDistributeEthIndex; // if new ETH claimed from Unwrap, just distribute start at this index
    uint256 public _needEthAmount; // the total eth amount that need to be distributed to user
    uint256 public _nextBatchEthAmount; // the eth amount that need to be requested to Unwrap contract in next batch
    uint256 public _lastBatchWithdrawTime; // last time when batchWithdraw was invoked

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
        IERC20(certToken).safeApprove(wBETHAddress, type(uint256).max);
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
        IERC20(_BETH).safeTransferFrom(msg.sender, address(this), wBETHAmount);
        IERC20(_certToken).safeTransferFrom(msg.sender, address(this), certTokenAmount);
        uint256 toMint = (wBETHAmount * ratio) / 1e18 + certTokenAmount;
        _depositors[msg.sender] += wBETHAmount; // wBETH
        _ceTokenBalances[msg.sender] += toMint;
        _certTokenValues[msg.sender] += (wBETHAmount * ratio) / 1e18;
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
        _depositors[owner] -= availableYields;
        uint256 balance = _BETH.balanceOf(address(this));
        if (balance >= availableYields) {
            IERC20(_BETH).safeTransfer(recipient, availableYields);
        } else {
            uint256 amountInETH = (availableYields - balance) * _BETH.exchangeRate() / 1e18;
            IERC20(_BETH).safeTransfer(recipient, balance);
            IERC20(_certToken).safeTransfer(recipient, amountInETH);
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
        require(recipient != address(0), "recipient is the zero address");
        uint256 balance = _ceTokenBalances[msg.sender];
        require(balance >= amount, "insufficient balance");
        _ceTokenBalances[msg.sender] -= amount; // ETH
        // burn ceToken from owner
        ICertToken(_ceToken).burn(owner, amount);

        uint256 feeAmount = amount * _withdrawalFee / 1e18;
        uint256 currentIndex = _nextIndex++;
        uint256 userRequestIndex = _userWithdrawRequests[recipient].length;
        _needEthAmount += amount;
        _nextBatchEthAmount += amount;
        _userWithdrawRequests[recipient].push(
            currentIndex
        );
        _withdrawRequests[currentIndex] = UserWithdrawRequest({
            owner: owner,
            recipient: recipient,
            ethAmount: amount,
            feeAmount: feeAmount,
            triggerTime: block.timestamp,
            userRequestIndex: userRequestIndex
        });

        emit RequestWithdraw(owner, recipient, amount - feeAmount);
        return amount - feeAmount;
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
        uint256 balance = _ceTokenBalances[msg.sender];
        require(balance >= amount, "insufficient balance");
        _ceTokenBalances[msg.sender] -= amount; // ETH
        _certTokenValues[msg.sender] -= amount;
        // burn ceToken from owner
        ICertToken(_ceToken).burn(owner, amount);
        require(_depositors[msg.sender] >= realAmount, "invalid withdraw amount");
        _depositors[msg.sender] -= realAmount; // wBETH
        IERC20(_BETH).safeTransfer(recipient, realAmount);
        emit Withdrawn(owner, recipient, amount);
        return realAmount;
    }

    // @dev actual withdraw request to wBETH, should be called max once a day
    // @dev caller can query eth balance of vault to avoid unnecessary gas fee
    // @param bufferedEthAmount : buffered ETH amount for ETH/wBETH to cover exchange rate loss
    function batchWithdraw(uint256 bufferedEthAmount)
        external
        nonReentrant
        onlyStrategist
    {
        require(bufferedEthAmount <= 1e18, "too big buffer, > 1e18");
        require(_nextBatchEthAmount > 0, "no batch eth amount");
        require(block.timestamp - _lastBatchWithdrawTime >= 24 hours, "allow only once a day");

        uint256 batchEthAmount = _nextBatchEthAmount;
        _lastBatchWithdrawTime = block.timestamp;
        _nextBatchEthAmount = 0; // To prevent reentrancy

        uint256 availableEthBalance = this.getTotalETHAmountInVault();
        uint256 totalNeedAmount = batchEthAmount + bufferedEthAmount;
        if (totalNeedAmount > availableEthBalance) {
            uint256 requestEthAmount = totalNeedAmount - availableEthBalance;
            uint256 wbethAmount = requestEthAmount * 1e18 / _BETH.exchangeRate();
            uint256 wbethBalance = this.getTotalBETHAmountInVault();
            if (wbethAmount > wbethBalance) {
                wbethAmount = wbethBalance;
            }

            _BETH.requestWithdrawEth(wbethAmount);
        }
    }

    // @dev actual withdraw request to wBETH, should be called max once a day
    // @dev caller can query eth balance of vault to avoid unnecessary gas fee
    // @param bufferedEthAmount : buffered ETH amount for ETH/wBETH to cover exchange rate loss
    function batchWithdrawInAmount(uint256 amount)
        external
        nonReentrant
        onlyStrategist
    {
        require(amount > 0 && amount <= _needEthAmount, "invalid amount");
        require(_nextBatchEthAmount > 0, "no batch eth amount");
        require(block.timestamp - _lastBatchWithdrawTime >= 24 hours, "allow only once a day");

        uint256 batchEthAmount = _nextBatchEthAmount;
        _lastBatchWithdrawTime = block.timestamp;
        _nextBatchEthAmount = 0; // To prevent reentrancy

        uint256 wbethAmount = amount * 1e18 / _BETH.exchangeRate();
        uint256 wbethBalance = this.getTotalBETHAmountInVault();
        if (wbethAmount > wbethBalance) {
            wbethAmount = wbethBalance;
        }

        _BETH.requestWithdrawEth(wbethAmount);
    }

    // @dev claims the next available ETH withdraw batch from Unwrap contract with index
    // @dev called should invoke Unwrap contract's query functions for index before calling this function
    // @param index : parameter sent to Unwrap contract
    // @return claimedAmount : successfully claimed amount
    function claimUnwrapETHWithraw(uint256 index)
        external
        nonReentrant
        onlyStrategist
        returns (uint256)
    {
        uint256 claimedAmount = IUnwrapETH(_unwrapEthAddress).claimWithdraw(index);
        return claimedAmount;
    }

    // @dev distribute claimed ETH to users in FIFO order of _withdrawRequests
    // @param maxNumRequests : parameter to control max number of requests to settle
    // @return reqCount : actual number of requests settled
    function distributeETH(uint256 maxNumRequests)
        external
        nonReentrant
        onlyStrategist
        returns (uint256 reqCount)
    {
        return _distributeETH(maxNumRequests);
    }

    function _distributeETH(uint256 maxNumRequests)
        private
        returns (uint256 reqCount)
    {
        require(maxNumRequests <= MAX_LOOP_NUM, "too big number > 100");
        require(_startDistributeEthIndex < _nextIndex, "no withdraw to distribute");

        uint256 availableEthBalance = this.getTotalETHAmountInVault();
        require(_needEthAmount > 0 && availableEthBalance > 0, "no need or no available eth to distribute");

        for (reqCount = 0; reqCount < maxNumRequests
                && _startDistributeEthIndex < _nextIndex
                && _withdrawRequests[_startDistributeEthIndex].ethAmount <= availableEthBalance;
            reqCount++
        ) {
            address owner = _withdrawRequests[_startDistributeEthIndex].owner;
            address recipient = _withdrawRequests[_startDistributeEthIndex].recipient;
            uint256 ethAmount = _withdrawRequests[_startDistributeEthIndex].ethAmount;
            uint256 feeAmount = _withdrawRequests[_startDistributeEthIndex].feeAmount;
            uint256 userReqIdx = _withdrawRequests[_startDistributeEthIndex].userRequestIndex;
            uint256 usrAmount = ethAmount - feeAmount;
            delete _withdrawRequests[_startDistributeEthIndex];

            uint256[] storage userRequests = _userWithdrawRequests[recipient];
            // correct user request index
            if (userRequests.length > 1) {
                userRequests[userReqIdx] = userRequests[userRequests.length - 1];
                UserWithdrawRequest storage lastRequest = _withdrawRequests[userRequests[userRequests.length - 1]];
                lastRequest.userRequestIndex = userReqIdx;
            }
            userRequests.pop();

            availableEthBalance -= ethAmount;
            _needEthAmount -= ethAmount;
            _startDistributeEthIndex++;

            address referral = ICerosETHRouter(_router).getReferral();
            IERC20(_certToken).safeTransfer(referral, feeAmount);
            IERC20(_certToken).safeTransfer(recipient, usrAmount);

            emit Withdrawn(owner, recipient, usrAmount);
        }

        return reqCount;
    }

    /**
     * @dev Retrieves all withdraw requests initiated by the given address
     * @param recipient - Address of an user
     * @return UserWithdrawRequest array of user withdraw requests NO more then 100
     */
    function getUserWithdrawRequests(address recipient)
        external
        view
        returns (UserWithdrawRequest[] memory)
    {
        uint256[] memory _userRequestsIndex = _userWithdrawRequests[recipient];
        uint256 _length = _userRequestsIndex.length;
        if (_length > MAX_LOOP_NUM) {
            _length = MAX_LOOP_NUM;
        }

        UserWithdrawRequest[] memory userDetailRequests = new UserWithdrawRequest[](_length);
        for (uint256 i = 0; i < _length; i++) {
            uint256 _allocateIndex = _userRequestsIndex[i];
            userDetailRequests[i] = _withdrawRequests[_allocateIndex];
        }
        return userDetailRequests;
    }

    /**
     * @dev Retrieves withdraw requests by index
     * @param startIndex - the startIndex
     * @return WithdrawRequest array of user withdraw requests
     */
    function getWithdrawRequests(uint256 startIndex)
        external
        view
        returns (UserWithdrawRequest[] memory)
    {
        require(startIndex < _nextIndex, "wrong start Index");
        uint256 _length = _nextIndex - startIndex;
        if (_length > MAX_LOOP_NUM) {
            _length = MAX_LOOP_NUM;
        }

        UserWithdrawRequest[] memory detailWithdrawRequests = new UserWithdrawRequest[](_length);
        for (uint256 i = 0; i < _length; i++) {
            uint256 index = startIndex + i;
            detailWithdrawRequests[i] = _withdrawRequests[index];
        }
        return detailWithdrawRequests;
    }

    function rebalance() external onlyStrategist returns (uint256) {
        ICerosETHRouter router = ICerosETHRouter(_router);
        uint256 ratio = router.getCertTokenRatio();
        uint256 amount = _certToken.balanceOf(address(this)) * (1e18 - ratio) / 1e18;
        uint256 preBalance = _BETH.balanceOf(address(this));
        _BETH.deposit(amount, router.getReferral());
        uint256 postBalance = _BETH.balanceOf(address(this));
        // address provider = router.getProvider();
        _certTokenValues[address(router)] += amount;
        _depositors[address(router)] += postBalance - preBalance;

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
        return (_certTokenValues[account] * 1e18) / ratio; // in aBNBc
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
        return totalYields;
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
    function changeUnwrapEthAddress(address unwrapEthAddress) external onlyOwner {
        _unwrapEthAddress = unwrapEthAddress;
    }
    function setStrategist(address strategist) external onlyOwner {
        _strategist = strategist;
        emit SetStrategist(strategist);
    }
    function changeCertToken(address token) external onlyOwner {
        IERC20(_certToken).safeApprove(address(_BETH), 0);
        _BETH = IBETH(token);
        IERC20(_certToken).safeApprove(token, type(uint256).max);
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
    function getWithdrawalFee() external view returns(uint256) {
        return _withdrawalFee;
    }
    function getStrategist() external view returns(address) {
        return _strategist;
    }
    function getUnwrapEthAddress() external view returns(address) {
        return _unwrapEthAddress;
    }
}
