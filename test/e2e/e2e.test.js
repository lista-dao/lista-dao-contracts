const {ethers, upgrades} = require("hardhat");
const { expect } = require("chai");
const { parseEther, formatEther } = require("ethers/lib/utils");
const NetworkSnapshotter = require("../helpers/NetworkSnapshotter");
const proxyAdminABI = require("./proxyAdminABI.json");




const networkSnapshotter = new NetworkSnapshotter();




describe("e2e test", () => {
   before("deploy contract", async () => {
       await init();
       await networkSnapshotter.firstSnapshot();
   });
   after("revert", async () => {
       if (networkSnapshotter.snapshotIds.length > 0) {
           // await networkSnapshotter.revert();
       }
   });




   it("test", async () => {
       // [signer0, signer1, signer2, signer3] = await ethers.getSigners();
       // console.log(signer0.address);
       // console.log(signer1.address);


       // const hbnb = await ethers.getContractAt("hBNB", "0xBFE45FDFAb94dd208676C42fb31a00068EfF39a1");
       // const MyContract = await ethers.getContractFactory("hBNB");
       // const contract = await MyContract.attach(
       //   "0xBFE45FDFAb94dd208676C42fb31a00068EfF39a1" // The deployed contract address
       // );
      
       // const name = await contract.total();
       // console.log(name);
   })
  
});


async function init() {
   const [owner, rewards, signer1, signer2] = await ethers.getSigners();


   let cerosStr_allocation = 25 * 10000,  // 25%
   bnbxStr_allocation = 25 * 10000,    // 25%
   pStakeStr_allocation = 25 * 10000;  // 25%
   snbnbStr_allocation = 25 * 10000;  // 25%
   _maxDepositFee = 50 * 10000,       // 50%
   _maxWithdrawalFee = 50 * 10000,  
   _maxStrategies = 10,
   _waitingPoolCap = 50;


  
   let _ceaBNBc, _Pstake_addressStore, _pool, _hbnb, _dao, _helioProvider, _stader_stakeManager, _stader_bnbx, _cerosRouter, _ankrBNB, _ceVault, _bnbJoin;


   const { t_ceaBNBc, t_Pstake_addressStore, t_pool, t_hbnb, t_dao, t_helioProvider, t_stader_stakeManager, t_stader_bnbx, t_cerosRouter, t_ankrBNB, t_ceVault, t_bnbJoin } = require('./deploy.json');
   _ceaBNBc = t_ceaBNBc; _Pstake_addressStore = t_Pstake_addressStore; _pool = t_pool; _hbnb = t_hbnb; _dao = t_dao; _helioProvider = t_helioProvider;
   _stader_stakeManager = t_stader_stakeManager; _stader_bnbx = t_stader_bnbx; _cerosRouter = t_cerosRouter; _ankrBNB = t_ankrBNB; _ceVault = t_ceVault; _bnbJoin = t_bnbJoin;


   // Contracts Fetching
   const CeaBNBc = await ethers.getContractFactory("CeToken");
   const ceaBNBc = await CeaBNBc.attach(_ceaBNBc);
   const CeVault = await ethers.getContractFactory("CeVaultV2", owner);
   const ceVault = await CeVault.attach(_ceVault);
   const helioProviderProxy = await ethers.getContractAt("HelioProvider", _helioProvider);




   // deploy new cerosVault token
   const cerosVaultToken = await upgrades.deployProxy(CeaBNBc, ["CEROS aBNBc Vault Token", "ceABNBc"], {initializer: "initialize"});
   await cerosVaultToken.deployed();
   console.log("cerosVaultToken    : " + cerosVaultToken.address);


   // deploy masterVault
   const MasterVault = await ethers.getContractFactory("MasterVault", owner);
   const masterVault = await upgrades.deployProxy(MasterVault, [_maxDepositFee, _maxWithdrawalFee, _maxStrategies, _ceaBNBc, _pool], {initializer: "initialize"});
   masterVault.deployed();
   let masterVaultImplementation = await upgrades.erc1967.getImplementationAddress(masterVault.address);
   console.log("masterVault    : " + masterVault.address);
   console.log("imp        : " + masterVaultImplementation);


   // deploy waiting pool
   const WaitingPool = await ethers.getContractFactory("WaitingPool");
   waitingPool = await upgrades.deployProxy(WaitingPool, [masterVault.address, _waitingPoolCap], {initializer: "initialize"});
   console.log("waitingPool    : " + waitingPool.address);


   // deploy stk strategy
   const StkBnbStrategy = await ethers.getContractFactory("StkBnbStrategy");  
   let stkBnbStrategy = await upgrades.deployProxy(StkBnbStrategy, [_Pstake_addressStore, rewards.address, masterVault.address, _Pstake_addressStore], {initializer: "initialize"});
   await stkBnbStrategy.deployed();
   console.log("stkBnbStrategy     : " + stkBnbStrategy.address);
  
   // deploy bnbx strategy
   const BnbxYieldConverterStrategy = await ethers.getContractFactory("BnbxYieldConverterStrategy"); 
   let bnbxYieldConverterStrategy = await upgrades.deployProxy(BnbxYieldConverterStrategy, [_stader_stakeManager, rewards.address, _stader_bnbx, masterVault.address], {initializer: "initialize"});
   await bnbxYieldConverterStrategy.deployed();
   console.log("bnbxYieldConverterStrategy     : " + bnbxYieldConverterStrategy.address);


   // deploy ceros strategy


   const CerosYieldConverterStrategy = await ethers.getContractFactory("CerosYieldConverterStrategy");   
   let cerosYieldConverterStrategy = await upgrades.deployProxy(CerosYieldConverterStrategy, [_cerosRouter, rewards.address, _ankrBNB, masterVault.address, _pool, _ceVault], {initializer: "initialize"});
   await cerosYieldConverterStrategy.deployed();
   console.log("cerosYieldConverterStrategy     : " + cerosYieldConverterStrategy.address);


   // deploy snbnb
   const SnBnb = await ethers.getContractFactory("SnBnbMock");
   let snBnb = await upgrades.deployProxy(SnBnb, ["Synclub BNB", "SnBNB"], {initializer: "initialize"});
   await snBnb.deployed();
   console.log("snBnb     : " + snBnb.address);


   // deploy snbnb manager
   const SnBnbStakeManager = await ethers.getContractFactory("SnBnbStakeManagerMock");
   let snBnbStakeManager = await SnBnbStakeManager.deploy();
   await (await snBnbStakeManager.changeER(parseEther("1"))).wait();
   await (await snBnbStakeManager.changeSnBnb(snBnb.address)).wait();
   console.log("snBnbStakeManager     : " + snBnbStakeManager.address);


   // deploy snbnb strategy
   const SnBnbYieldConverterStrategy = await ethers.getContractFactory("SnBnbYieldConverterStrategy");
   let snBnbYieldConverterStrategy = await upgrades.deployProxy(SnBnbYieldConverterStrategy, [snBnbStakeManager.address, rewards.address, snBnb.address, masterVault.address], {initializer: "initialize"});
   await snBnbYieldConverterStrategy.deployed();
   console.log("snBnbYieldConverterStrategy     : " + snBnbYieldConverterStrategy.address);




   // change ceaBNBc MinterRole to MasterVault
   console.log("Configuring MasterVaultToken...");
   let slotNumber = "0x33";  // 51
   await setOwner(ceaBNBc, owner.address, slotNumber);
   await (await ceaBNBc.connect(owner).changeVault(masterVault.address)).wait();


   console.log("Configuring MasterVault...");
   // await (await masterVault.setWaitingPool(waitingPool.address)).wait();
   await (await masterVault.changeProvider(_helioProvider)).wait();
   await (await masterVault.setStrategy(cerosYieldConverterStrategy.address, cerosStr_allocation)).wait();     // 25%
   await (await masterVault.setStrategy(bnbxYieldConverterStrategy.address, bnbxStr_allocation)).wait();       // 25%
   await (await masterVault.setStrategy(stkBnbStrategy.address, pStakeStr_allocation)).wait();                 // 25%
   await (await masterVault.setStrategy(snBnbYieldConverterStrategy.address, snbnbStr_allocation)).wait();     // 25%


   console.log("deploy and upgrade HelioProvider");
   const hProviderImpAddress = await deployImplementatoin("HelioProviderV2");
   await upgradeProxy(_helioProvider, owner, hProviderImpAddress);
   await setOwner(helioProviderProxy, owner.address, slotNumber);


   // deploy and upgrade ceVault
   console.log("Upgrading CeVaultV2...");
   const ceVaultImpAddress = await deployImplementatoin("CeVaultV2");
   await upgradeProxy(_ceVault, owner, ceVaultImpAddress);
   await setOwner(ceVault, owner.address, slotNumber);


   console.log("Updating ceVault and masterVault's storage...");
   // const bnbJoinVaultTokenBalance = await ceaBNBc.balanceOf(_bnbJoin);
   await (await cerosVaultToken.connect(owner).changeVault(ceVault.address)).wait();
   await (await ceVault.connect(owner).updateStorage(cerosVaultToken.address, _helioProvider, cerosYieldConverterStrategy.address, 0)).wait();
   await (await masterVault.connect(owner)._updateCerosStrategyDebt(cerosYieldConverterStrategy.address, 0)).wait();


   console.log("Configuring upgraded HelioProviderV2...");
   const helioProviderV2 = await ethers.getContractAt("HelioProviderV2", _helioProvider);
   await (await helioProviderV2.connect(owner).changeMasterVault(masterVault.address)).wait();




   console.log("Deployment successful");


}


function parseAddress(addressString){
   const buf = Buffer.from(addressString.replace(/^0x/, ''), 'hex');
   if (!buf.slice(0, 12).equals(Buffer.alloc(12, 0))) {
     return undefined;
   }
   const address = '0x' + buf.toString('hex', 12, 32); // grab the last 20 bytes
   return ethers.utils.getAddress(address);
}


async function setOwner(contract, newOwner, slotNumber) {
   // the slot must be a hex string stripped of leading zeros! no padding!
   // https://ethereum.stackexchange.com/questions/129645/not-able-to-set-storage-slot-on-hardhat-network


   expect(contract.address).to.not.equal(ethers.constants.AddressZero);
  
   const orignalOwner = parseAddress(await ethers.provider.send("eth_getStorageAt", [contract.address, slotNumber]));
   // storage value must be a 32 bytes long padded with leading zeros hex string
   const value = ethers.utils.hexlify(ethers.utils.zeroPad(newOwner, 32))
   await ethers.provider.send("hardhat_setStorageAt", [await contract.address, slotNumber, value]);


   const storageOwner = parseAddress(await ethers.provider.send("eth_getStorageAt", [contract.address, slotNumber]));
   expect(storageOwner).to.be.eq(newOwner);


   console.log(`set ${contract.address} owner success, orignal owner ${orignalOwner}, new owner: ${newOwner}`);
}


async function deployImplementatoin(contractName) {
   let contractFactory = await hre.ethers.getContractFactory(contractName);
   let contractImpl = await contractFactory.deploy();
   await contractImpl.deployed();
   console.log(`${contractName}Imp:  `,contractImpl.address)
   return contractImpl.address;
}


async function upgradeProxy(proxyContractAddress, owner, impAddress) {
   // get proxyadmin contract


   // https://eips.ethereum.org/EIPS/eip-1967
   const adminSlot = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";
   const proxyAdminAddressBytes = await ethers.provider.getStorageAt(proxyContractAddress, adminSlot);
   const proxyAdminAddress = parseAddress(proxyAdminAddressBytes);


   // change proxyadmin contract owner
   const ownerSlot = "0x0";
   const proxyAdmin = new ethers.Contract(proxyAdminAddress, proxyAdminABI, ethers.provider);


   await setOwner(proxyAdmin, owner.address, ownerSlot);


   // upgrade imp
   await proxyAdmin.connect(owner).upgrade(proxyContractAddress, impAddress);


   console.log(`upgrade ${proxyContractAddress} success, new Imp: ${impAddress}`);
}
