const {ethers, upgrades} = require("hardhat");
//const { upgradeProxy , deployImplementation , verifyImpContract} = require("../upgrades/utils/upgrade_utils");


/*
1. claim yeild
2. Deploy masterVault(using ceaBNBc as vault token) and cerosStrategy contracts
3. Pause helioProvider contract
4. Upgrade helioProviderV2 contract
5. Deploy new cerosVault token and set ceVault as minter. Also, change vault token address in ceVault contract.
6. Mint cerosVault token(eq. to ceaBNBc token balance of gemJoin) to cersoStrategy contract and set totalDebt and strategy.debt in masterVault.
7. Unpause helioProviderV2 contract
*/


async function main() {

    // Variables Declaration
    let [deployer] = await ethers.getSigners();

    let masterVault, waitingPool, _aBNBc, _wBnb, _aBnbb, _dex, _binancePool;
    let _ceaBNBc, _ceVault, _cerosRouter, _bnbJoin, _helioProvider;

    if (hre.network.name == "bsc") {
        const { m_aBNBc, m_wBnb, m_aBnbb, m_dex, m_pool } = require('./1_deploy_all.json'); // mainnet
        const { m_ceaBNBc, m_ceVault, m_cerosRouter, m_bnbJoin, m_helioProvider, m_pStake_addressStore, m_stader_stake_manager, m_bnbxToken, m_synclub_stake_manager, m_snBnbToken } = require('./masterVault_config.json');
        _aBNBc = m_aBNBc; _wBnb = m_wBnb; _aBnbb = m_aBnbb; _dex = m_dex; _binancePool = m_pool;
        _ceaBNBc = m_ceaBNBc, _ceVault = m_ceVault, _cerosRouter = m_cerosRouter, _bnbJoin = m_bnbJoin, _helioProvider = m_helioProvider;
        _pStake_addressStore = m_pStake_addressStore; _stader_stake_manager = m_stader_stake_manager; _bnbxToken = m_bnbxToken; _snBnbToken = m_snBnbToken;
        _synclub_stake_manager = m_synclub_stake_manager;
    } else if (hre.network.name == "bsc_testnet") {
        const { t_aBNBc, t_wBnb, t_aBnbb, t_dex, t_pool } = require('./1_deploy_all.json'); // testnet
        const { t_ceaBNBc, t_ceVault, t_cerosRouter, t_bnbJoin, t_helioProvider, t_pStake_addressStore, t_stader_stake_manager, t_bnbxToken, t_synclub_stake_manager, t_snBnbToken } = require('./masterVault_config.json');
        _aBNBc = t_aBNBc; _wBnb = t_wBnb; _aBnbb = t_aBnbb; _dex = t_dex; _binancePool = t_pool;
        _ceaBNBc = t_ceaBNBc, _ceVault = t_ceVault, _cerosRouter = t_cerosRouter, _bnbJoin = t_bnbJoin, _helioProvider = t_helioProvider;
        _pStake_addressStore = t_pStake_addressStore; _stader_stake_manager = t_stader_stake_manager; _bnbxToken = t_bnbxToken; _snBnbToken = t_snBnbToken;
        _synclub_stake_manager = t_synclub_stake_manager;
    }

    let cerosStr_allocation = 20 * 10000,  // 85%
        bnbxStr_allocation = 20 * 10000,    // 7%
        pStakeStr_allocation = 20 * 10000;  // 3%
        synclubStr_allocation = 40 * 10000; // 40%
        _maxDepositFee = 50 * 10000,       // 50%
        _maxWithdrawalFee = 50 * 10000,
        _maxStrategies = 10,
        _waitingPoolCap = 50;

    // Contracts Fetching
    const CeaBNBc = await hre.ethers.getContractFactory("CeToken");
    const ceaBNBc =  await ethers.getContractAt("CeToken", _ceaBNBc);
    const CeVault = await hre.ethers.getContractFactory("CeVaultV2");
    const ceVault = await CeVault.attach(_ceVault);
    const CerosRouter = await hre.ethers.getContractFactory("CerosRouter");
    const cerosRouter = await CerosRouter.attach(_cerosRouter);
    const MasterVault = await hre.ethers.getContractFactory("MasterVault");
    const WaitingPool = await hre.ethers.getContractFactory("WaitingPool");
    const CerosYieldConverterStrategy = await hre.ethers.getContractFactory("CerosYieldConverterStrategy");

    /*
    // claim yield
    this.HelioProvider = await hre.ethers.getContractFactory("HelioProvider");
    const oldHelioProvider = await this.HelioProvider.attach(_helioProvider);
    const yield = await ceVault.getYieldFor(oldHelioProvider.target);
    if (yield > 0n) {
        await oldHelioProvider.claimInABNBc(deployer.address);
    }

    // deploy new cerosVault token
    cerosVaultToken = await upgrades.deployProxy(CeaBNBc, ["CEROS ankrBNB Vault Token", "ceankrBNB"]);
    await cerosVaultToken.waitForDeployment();
    let cerosVaultTokenImplementation = await upgrades.erc1967.getImplementationAddress(cerosVaultToken.target);
    console.log("Deployed: ceaBNBc    : " + cerosVaultToken.target);
    console.log("Imp                  : " + cerosVaultTokenImplementation);

    // deploy masterVault
    masterVault = await upgrades.deployProxy(MasterVault, [_maxDepositFee, _maxWithdrawalFee, _maxStrategies, ceaBNBc.target]);
    await masterVault.waitForDeployment();
    let masterVaultImplementation = await upgrades.erc1967.getImplementationAddress(masterVault.target);
    console.log("masterVault    : " + masterVault.target);
    console.log("imp        : " + masterVaultImplementation);

    // deploy waiting pool
    waitingPool = await upgrades.deployProxy(WaitingPool, [masterVault.target, _waitingPoolCap]);
    await waitingPool.waitForDeployment();
    let waitingPoolImplementation = await upgrades.erc1967.getImplementationAddress(waitingPool.target);
    console.log("waitingPool    : " + waitingPool.target);
    console.log("imp        : " + waitingPoolImplementation);

    let _destination = cerosRouter.target,
        _rewards = deployer.address,
        _certToken = _aBNBc;

    // deploy ceros strategy
    let cerosYieldConverterStrategy = await upgrades.deployProxy(CerosYieldConverterStrategy, [_destination, _rewards, _certToken, masterVault.target, _binancePool, _ceVault]);
    await cerosYieldConverterStrategy.waitForDeployment();
    let cerosYieldConverterStrategyImp = await upgrades.erc1967.getImplementationAddress(cerosYieldConverterStrategy.target);
    console.log("cerosYieldConverterStrategy    : " + cerosYieldConverterStrategy.target);
    console.log("imp        : " + cerosYieldConverterStrategyImp);

    // deploy ceros strategy
    const StkBnbStrategy = await hre.ethers.getContractFactory("StkBnbStrategy");
    let stkBnbStrategy = await upgrades.deployProxy(StkBnbStrategy, [_pStake_addressStore, _rewards, masterVault.target, _pStake_addressStore]);
    await stkBnbStrategy.waitForDeployment();
    let stkBnbStrategyImp = await upgrades.erc1967.getImplementationAddress(stkBnbStrategy.target);
    console.log("stkBnbStrategy    : " + stkBnbStrategy.target);
    console.log("imp        : " + stkBnbStrategyImp);

    // deploy synclub strategy
    const SnBnbYieldConverterStrategy = await hre.ethers.getContractFactory("SnBnbYieldConverterStrategy");
    let snBnbStrategy = await upgrades.deployProxy(SnBnbYieldConverterStrategy, [_synclub_stake_manager, _rewards, _snBnbToken, masterVault.target]);
    await snBnbStrategy.waitForDeployment();
    let snBnbStrategyImp = await upgrades.erc1967.getImplementationAddress(snBnbStrategy.target);
    console.log("snBnbStrategy    : " + snBnbStrategy.target);
    console.log("imp        : " + snBnbStrategyImp);

    // deploy ceros strategy
    const BnbxYieldConverterStrategy = await hre.ethers.getContractFactory("BnbxYieldConverterStrategy");
    let bnbxYieldConverterStrategy = await upgrades.deployProxy(BnbxYieldConverterStrategy, [_stader_stake_manager, _rewards, _bnbxToken, masterVault.target]);
    await bnbxYieldConverterStrategy.waitForDeployment();
    let bnbxYieldConverterStrategyImp = await upgrades.erc1967.getImplementationAddress(bnbxYieldConverterStrategy.target);
    console.log("bnbxYieldConverterStrategy    : " + bnbxYieldConverterStrategy.target);
    console.log("imp        : " + bnbxYieldConverterStrategyImp);

    // pause helioProvider
    console.log("Pausing HelioProvider...");
    await oldHelioProvider.pause();

    // change ceaBNBc MinterRole to MasterVault
    console.log("Configuring MasterVaultToken...");
    await ceaBNBc.changeVault(masterVault.target);
*/
    console.log("Configuring MasterVault...");
    //await masterVault.setWaitingPool(waitingPool.target);
    await masterVault.changeProvider(_helioProvider);
    await masterVault.setStrategy(cerosYieldConverterStrategy.target, cerosStr_allocation);     // 85%
    await masterVault.setStrategy(bnbxYieldConverterStrategy.target, bnbxStr_allocation);       // 7%
    await masterVault.setStrategy(stkBnbStrategy.target, pStakeStr_allocation);                 // 3%
    await masterVault.setStrategy(snBnbStrategy.target, synclubStr_allocation);                 // 3%

    // deploy and upgrade helioProvider
    console.log("Upgrading HelioProviderV2...");
    //const hProviderImpAddress = await deployImplementation("HelioProviderV2");
    await upgrades.upgradeProxy(_helioProvider, this.HelioProviderV2);

    // deploy and upgrade ceVault
    console.log("Upgrading CeVaultV2...");
    //const ceVaultImpAddress = await deployImplementation("CeVaultV2");
    await upgrades.upgradeProxy(_ceVault, this.CeVaultV2);

    console.log("Updating ceVault and masterVault's storage...");
    const bnbJoinVaultTokenBalance = await ceaBNBc.balanceOf(_bnbJoin);
    await cerosVaultToken.changeVault(ceVault.target);
    // await (await ceVault.updateStorage(cerosVaultToken.target, _helioProvider, cerosYieldConverterStrategy.target, bnbJoinVaultTokenBalance)).wait();
    // await (await masterVault._updateCerosStrategyDebt(cerosYieldConverterStrategy.target, bnbJoinVaultTokenBalance)).wait();

    console.log("Configuring upgraded HelioProviderV2...");
    this.HelioProviderV2 = await ethers.getContractFactory("HelioProviderV2");
    const newHelioProvider = this.HelioProviderV2.attach(_helioProvider);
    await newHelioProvider.changeMasterVault(masterVault.target);

    //unpause helioProvider
    console.log("Unpausing HelioProvider...");
    await newHelioProvider.unPause();

    console.log("Deployment successful");
    // Verify implementations
    console.log("Verifying MasterVault contract...");
    hre.run("verify:verify", {address: masterVault.target}, [_maxDepositFee, _maxWithdrawalFee, _maxStrategies, ceaBNBc.target]);
//    await verifyImpContract(masterVaultImplementation);

    //console.log("Verifying HelioProviderV2 contract...");
    //hre.run("verify:verify", {address: hProviderImpAddress});

    //console.log("Verifying cerosVault contract...");
    //hre.run("verify:verify", {address: ceVaultImpAddress});
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
