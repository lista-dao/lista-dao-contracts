const { ethers, network } = require('hardhat');
const { expect } = require("chai");

describe('===HelioRewards===', function () {
    let deployer, signer1, signer2;

    let wad = "000000000000000000", // 18 Decimals
        ray = "000000000000000000000000000", // 27 Decimals
        rad = "000000000000000000000000000000000000000000000"; // 45 Decimals

    let collateral = ethers.utils.formatBytes32String("TEST");

    const NULL_ADDRESS = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {

        [deployer, signer1, signer2] = await ethers.getSigners();

        // Contract factory
        this.HelioRewards = await ethers.getContractFactory("HelioRewards");
        this.HelioToken = await ethers.getContractFactory("HelioToken");
        this.Vat = await ethers.getContractFactory("Vat");
        this.HelioOracle = await ethers.getContractFactory("HelioOracle");

        this.Spot = await hre.ethers.getContractFactory("Spotter");
        this.Hay = await hre.ethers.getContractFactory("Hay");
        this.GemJoin = await hre.ethers.getContractFactory("GemJoin");
        this.HayJoin = await hre.ethers.getContractFactory("HayJoin");
        this.Oracle = await hre.ethers.getContractFactory("Oracle");
        this.Jug = await hre.ethers.getContractFactory("Jug");
        this.Vow = await hre.ethers.getContractFactory("Vow");

        this.AuctionProxy = await hre.ethers.getContractFactory("AuctionProxy");

        const auctionProxy = await this.AuctionProxy.deploy();
        await auctionProxy.deployed();
        this.Interaction = await hre.ethers.getContractFactory("Interaction", {
            unsafeAllow: ["external-library-linking"],
            libraries: {
            AuctionProxy: auctionProxy.address,
            },
        });

        // Contract deployment
        heliorewards = await this.HelioRewards.connect(deployer).deploy();
        await heliorewards.deployed();
        heliotoken = await this.HelioToken.connect(deployer).deploy();
        await heliotoken.deployed();
        vat = await this.Vat.connect(deployer).deploy();
        await vat.deployed();
        heliooracle = await this.HelioOracle.connect(deployer).deploy();
        await heliooracle.deployed();

        await vat.initialize();
        spot = await this.Spot.connect(deployer).deploy();
        await spot.deployed(); await spot.initialize(vat.address);
        hay = await this.Hay.connect(deployer).deploy();
        await hay.deployed(); await hay.initialize(97, "HAY", "100" + wad);
        gem = await this.Hay.connect(deployer).deploy();
        await gem.deployed(); await gem.initialize(97, "HAY", "100" + wad);
        gemJoin = await this.GemJoin.connect(deployer).deploy();
        await gemJoin.deployed(); await gemJoin.initialize(vat.address, collateral, gem.address);
        hayJoin = await this.HayJoin.connect(deployer).deploy();
        await hayJoin.deployed(); await hayJoin.initialize(vat.address, hay.address);
        oracle = await this.Oracle.connect(deployer).deploy();
        await oracle.deployed(); await oracle.setPrice("1" + wad);
        jug = await this.Jug.connect(deployer).deploy();
        await jug.deployed(); await jug.initialize(vat.address);
        vow = await this.Vow.connect(deployer).deploy();
        await vow.deployed(); await vow.initialize(vat.address, hayJoin.address, deployer.address);

        

    });

    describe('--- initialize()', function () {
        it('initialize', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            expect(await heliorewards.poolLimit()).to.be.equal("100" + wad);
        });
    });
    describe('--- rely()', function () {
        it('reverts: Rewards/not-authorized', async function () {
            await expect(heliorewards.rely(signer1.address)).to.be.revertedWith("Rewards/not-authorized");
            expect(await heliorewards.wards(signer1.address)).to.be.equal("0");
        });
        it('reverts: Rewards/not-live', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.cage();
            await expect(heliorewards.rely(signer1.address)).to.be.revertedWith("Rewards/not-live");
        });
        it('relies on address', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.rely(signer1.address);
            expect(await heliorewards.wards(signer1.address)).to.be.equal("1");
        });
    });
    describe('--- deny()', function () {
        it('reverts: Rewards/not-authorized', async function () {
            await expect(heliorewards.deny(signer1.address)).to.be.revertedWith("Rewards/not-authorized");
        });
        it('reverts: Rewards/not-live', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.cage();
            await expect(heliorewards.deny(NULL_ADDRESS)).to.be.revertedWith("Rewards/not-live");
        });
        it('denies an address', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.rely(signer1.address);
            expect(await heliorewards.wards(signer1.address)).to.be.equal("1");
            await heliorewards.deny(signer1.address);
            expect(await heliorewards.wards(signer1.address)).to.be.equal("0");
        });
    });
    describe('--- cage()', function () {
        it('disables the live flag', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.cage();
            expect(await heliorewards.live()).to.be.equal("0");
        });
    });
    describe('--- uncage()', function () {
        it('enables the live flag', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliorewards.cage();
            expect(await heliorewards.live()).to.be.equal("0");

            await heliorewards.uncage();
            expect(await heliorewards.live()).to.be.equal("1");
        });
    });
    describe('--- initPool()', function () {
        it('reverts: Reward/not-enough-reward-token', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await expect(heliorewards.initPool(gem.address, collateral, "1" + ray)).to.be.revertedWith("Reward/not-enough-reward-token");
        });
        it('reverts: Reward/pool-existed', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(gem.address, collateral, "1" + ray)

            await expect(heliorewards.initPool(gem.address, collateral, "1" + ray)).to.be.revertedWith("Reward/pool-existed");
        });
        it('reverts: Reward/invalid-token', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await expect(heliorewards.initPool(NULL_ADDRESS, collateral, "1" + ray)).to.be.revertedWith("Reward/invalid-token");
        });
        it('inits a pool', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(gem.address, collateral, "1" + ray);
            expect(await (await heliorewards.pools(gem.address)).rewardRate).to.be.equal("1" + ray);
        });
    });
    describe('--- setHelioToken()', function () {
        it('reverts: Reward/invalid-token', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await expect(heliorewards.setHelioToken(NULL_ADDRESS)).to.be.revertedWith("Reward/invalid-token");
        });
        it('sets helio token address', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);

            expect(await heliorewards.helioToken()).to.be.equal(heliotoken.address);
        });
    });
    describe('--- setRewardsMaxLimit()', function () {
        it('reverts: Reward/not-enough-reward-token', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await expect(heliorewards.setRewardsMaxLimit("110" + wad)).to.be.revertedWith("Reward/not-enough-reward-token");
        });
        it('sets rewards max limit', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.setRewardsMaxLimit("100" + wad);
            expect(await heliorewards.poolLimit()).to.be.equal("100" + wad);
        });
    });
    describe('--- setOracle()', function () {
        it('reverts: Reward/invalid-oracle', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await expect(heliorewards.setOracle(NULL_ADDRESS)).to.be.revertedWith("Reward/invalid-oracle");
        });
        it('sets oracle', async function () {
            await heliorewards.initialize(vat.address, "100" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliooracle.initialize("1" + wad);
            await heliorewards.setOracle(heliooracle.address);
            expect(await heliorewards.oracle()).to.be.equal(heliooracle.address);
        });
    });
    describe('--- setRate()', function () {
        it('reverts: Reward/pool-existed', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(gem.address, collateral, "1" + ray);
            await expect(heliorewards.setRate(gem.address, "1" + ray)).to.be.revertedWith("Reward/pool-existed");
        });
        it('reverts: Reward/invalid-token', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(gem.address, collateral, "1" + ray);
            await expect(heliorewards.setRate(NULL_ADDRESS, "1" + ray)).to.be.revertedWith("Reward/invalid-token");
        });
        it('reverts: Reward/negative-rate', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await expect(heliorewards.setRate(gem.address, "1" + wad)).to.be.revertedWith("Reward/negative-rate");
        });
        it('reverts: Reward/high-rate', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await expect(heliorewards.setRate(gem.address, "3" + ray)).to.be.revertedWith("Reward/high-rate");
        });
        it('sets rate', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliotoken.initialize("90" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.setRate(gem.address, "1" + ray);
            expect(await (await heliorewards.pools(gem.address)).rewardRate).to.be.equal("1" + ray);
        });
    });
    describe('--- helioPrice()', function () {
        it('returns helio price', async function () {
            await heliorewards.initialize(vat.address, "50" + wad);
            await heliorewards.setOracle(heliooracle.address);
            await heliooracle.initialize("2" + wad);
            expect(await heliorewards.helioPrice()).to.be.equal("2" + wad);
        });
    });
    describe('--- rewardsRate()', function () {
        it('returns token  rate', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(gem.address, collateral, "1" + ray);
            expect(await heliorewards.rewardsRate(gem.address)).to.be.equal("1" + ray);
        });
    });
    describe('--- drop()', function () {
        it('returns if rho is 0', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.drop(heliotoken.address, deployer.address);
            expect(await (await heliorewards.pools(heliotoken.address)).rewardRate).to.be.equal("0");
        });
        it('drops rewards', async function () {
            const interaction = await upgrades.deployProxy(this.Interaction, [vat.address, spot.address, hay.address, hayJoin.address, jug.address, NULL_ADDRESS, heliorewards.address],
                {
                  initializer: "initialize",
                  unsafeAllowLinkedLibraries: true,
                }
              );
            await interaction.deployed();
    
            // Initialize Core
            await vat.rely(gemJoin.address);
            await vat.rely(spot.address);
            await vat.rely(hayJoin.address);
            await vat.rely(jug.address);
            await vat.rely(interaction.address);
            await vat["file(bytes32,uint256)"](ethers.utils.formatBytes32String("Line"), "5000000" + rad);
            await vat["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("line"), "5000000" + rad);
            await vat["file(bytes32,bytes32,uint256)"](collateral, ethers.utils.formatBytes32String("dust"), "100" + ray);

            await hay.rely(hayJoin.address);

            await spot.rely(interaction.address);
            await spot["file(bytes32,bytes32,address)"](collateral, ethers.utils.formatBytes32String("pip"), oracle.address);
            await spot["file(bytes32,uint256)"](ethers.utils.formatBytes32String("par"), "1" + ray); // Pegged to 1$

            await gemJoin.rely(interaction.address);

            await hayJoin.rely(interaction.address);
            await hayJoin.rely(vow.address);
    
            await jug.rely(interaction.address);
            // 1000000000315522921573372069 1% Borrow Rate
            // 1000000000627937192491029810 2% Borrow Rate
            // 1000000000937303470807876290 3% Borrow Rate
            // 1000000003022266000000000000 10% Borrow Rate
            await jug["file(bytes32,address)"](ethers.utils.formatBytes32String("vow"), vow.address);

            await vow["file(bytes32,address)"](ethers.utils.formatBytes32String("hay"), hay.address);
    
            // Initialize Interaction
            await interaction.setCollateralType(gem.address, gemJoin.address, collateral, NULL_ADDRESS, "1333333333333333333333333333", {gasLimit: 700000}); // 1.333.... <- 75% borrow ratio
            await interaction.poke(gem.address, {gasLimit: 200000});
            await interaction.drip(gem.address, {gasLimit: 200000});

            // Initialize HelioRewards
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(gem.address, collateral, "1000000000627937192491029810");
            await heliooracle.initialize("1" + wad);
            await heliorewards.setOracle(heliooracle.address);
            await heliorewards.rely(interaction.address);

            expect(await (await heliorewards.piles(signer1.address, gem.address)).ts).to.be.equal("0");

            // Mint collateral to User, deposit and borrow from that user
            await gem.mint(signer1.address, "10" + wad);
            await gem.connect(signer1).approve(interaction.address, "10" + wad);
            await interaction.connect(signer1).deposit(signer1.address, gem.address, "10" + wad);
            await interaction.connect(signer1).borrow(gem.address, "5" + wad);

            expect(await (await heliorewards.piles(signer1.address, gem.address)).ts).not.to.be.equal("0");
            expect(await (await heliorewards.piles(signer1.address, gem.address)).amount).to.be.equal("0");

            tau = (await ethers.provider.getBlock()).timestamp;
            await network.provider.send("evm_setNextBlockTimestamp", [tau + 100]);
            await network.provider.send("evm_mine");

            await heliorewards.drop(gem.address, signer1.address);

            expect(await (await heliorewards.piles(signer1.address, gem.address)).amount).to.be.equal("317108292164");
        });
    });
    describe('--- distributionApy()', function () {
        it('returns token APY', async function () {
            await heliorewards.initialize(vat.address, "40" + wad);
            await heliotoken.initialize("100" + wad, heliorewards.address);
            await heliorewards.setHelioToken(heliotoken.address);
            await heliorewards.initPool(gem.address, collateral, "1" + ray);
            expect(await heliorewards.distributionApy(gem.address)).to.be.equal("0");
        });
    });
});