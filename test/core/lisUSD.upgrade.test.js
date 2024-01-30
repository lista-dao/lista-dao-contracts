const {ethers, upgrades, network} = require('hardhat')
const {expect} = require('chai')
const {ether} = require('@openzeppelin/test-helpers')

describe('===LisUSD Upgrade===', function () {
  let deployer, signer1, signer2, signer3

  beforeEach(async function () {

    [deployer, signer1, signer2, signer3] = await ethers.getSigners()

    // Contract factory
    this.Hay = await ethers.getContractFactory('Hay')
    this.LisUSD = await ethers.getContractFactory('LisUSD')
  })
  it('should be able to upgrade', async function () {
    const hay = await upgrades.deployProxy(this.Hay, [97, 'HAY', ethers.utils.parseEther('100')], {
      initializer: 'initialize',
    })
    await hay.deployed()
    await upgrades.validateUpgrade(hay.address, this.Hay)
    const lisUSD = await upgrades.upgradeProxy(hay.address, this.LisUSD)
    expect(lisUSD.address).to.equals(hay.address)
  })

  it('name and symbol should be changed correctly after upgraded', async function () {
    const hay = await upgrades.deployProxy(this.Hay, [97, 'HAY', ethers.utils.parseEther('100')], {
      initializer: 'initialize',
    })
    await hay.deployed()
    expect(await hay.name()).to.equals('Hay Destablecoin')
    expect(await hay.symbol()).to.equals('HAY')
    const lisUSD = await upgrades.upgradeProxy(hay.address, this.LisUSD)
    expect(await lisUSD.name()).to.equals('Lista USD')
    expect(await lisUSD.symbol()).to.equals('HAY')
    await lisUSD.setSymbol('lisUSD')
    expect(await lisUSD.symbol()).to.equals('lisUSD')
  })

  it('the wards shouldn\'t be changed after upgraded and can be changed by any wards after upgraded', async function () {
    const hay = await upgrades.deployProxy(this.Hay, [97, 'HAY', ethers.utils.parseEther('100')], {
      initializer: 'initialize',
    })
    await hay.deployed()
    expect(await hay.wards(deployer.address)).to.equals(1)
    // add ward
    expect(await hay.wards(signer1.address)).to.equals(0)
    await expect(hay.connect(signer1).rely(signer1.address)).to.be.revertedWith('Hay/not-authorized')
    await hay.connect(deployer).rely(signer1.address)
    expect(await hay.wards(signer1.address)).to.equals(1)
    await hay.connect(signer1).rely(signer1.address)
    expect(await hay.wards(signer1.address)).to.equals(1)

    const lisUSD = await upgrades.upgradeProxy(hay.address, this.LisUSD)
    expect(await lisUSD.wards(deployer.address)).to.equals(1)
    expect(await lisUSD.wards(signer1.address)).to.equals(1)
    // remove ward
    await lisUSD.connect(signer1).deny(signer1.address)
    expect(await lisUSD.wards(signer1.address)).to.equals(0)
  })

  it('the wards can mint after upgraded', async function () {
    const hay = await upgrades.deployProxy(this.Hay, [97, 'HAY', ethers.utils.parseEther('100')], {
      initializer: 'initialize',
    })
    await hay.deployed()
    expect(await hay.wards(deployer.address)).to.equals(1)
    // add ward
    expect(await hay.wards(signer1.address)).to.equals(0)
    await hay.connect(deployer).rely(signer1.address)
    expect(await hay.wards(signer1.address)).to.equals(1)

    await hay.connect(signer1).mint(signer1.address, 100)
    await hay.connect(signer1).mint(signer2.address, 10)
    await hay.connect(signer2).burn(signer2.address, 1)

    const [balance1, balance2, balance3] = await Promise.all([
      hay.balanceOf(signer1.address),
      hay.balanceOf(signer2.address),
      hay.balanceOf(signer3.address),
    ])
    expect(balance1).to.equals(100)
    expect(balance2).to.equals(9)
    expect(balance3).to.equals(0)

    const lisUSD = await upgrades.upgradeProxy(hay.address, this.LisUSD)

    const [balanceAfter1, balanceAfter2, balanceAfter3] = await Promise.all([
      lisUSD.balanceOf(signer1.address),
      lisUSD.balanceOf(signer2.address),
      lisUSD.balanceOf(signer3.address),
    ])
    expect(balance1).to.equals(balanceAfter1)
    expect(balance2).to.equals(balanceAfter2)
    expect(balance3).to.equals(balanceAfter3)

    await expect(
      lisUSD.connect(signer2).mint(signer2.address, 1)
    ).to.be.revertedWith('LisUSD/not-authorized')

    await lisUSD.connect(signer1).mint(signer1.address, 100)
    await lisUSD.connect(signer1).mint(signer2.address, 10)
    await lisUSD.connect(signer2).burn(signer2.address, 1)

    const [balanceChanged1, balanceChanged2, balanceChanged3] =
      await Promise.all([
        lisUSD.balanceOf(signer1.address),
        lisUSD.balanceOf(signer2.address),
        lisUSD.balanceOf(signer3.address),
      ])
    expect(balanceChanged1.sub(balanceAfter1)).to.equals(100)
    expect(balanceChanged2.sub(balanceAfter2)).to.equals(9)
    expect(balanceChanged3.sub(balanceAfter3)).to.equals(0)
  })

  it('the allowances shouldn\'t be changed after upgraded and can work well after upgraded', async function () {
    const hay = await upgrades.deployProxy(this.Hay, [97, 'HAY', ethers.utils.parseEther('100')], {
      initializer: 'initialize',
    })
    await hay.deployed()
    await hay.connect(deployer).mint(signer1.address, 100)
    await hay.connect(deployer).mint(signer2.address, 10)
    // approve
    await hay.connect(signer1).approve(signer3.address, 50)

    const lisUSD = await upgrades.upgradeProxy(hay.address, this.LisUSD)

    const [allowance1, allowance2, allowance3] = await Promise.all([
      lisUSD.allowance(signer1.address, signer1.address),
      lisUSD.allowance(signer1.address, signer2.address),
      lisUSD.allowance(signer1.address, signer3.address),
    ])
    expect(allowance1).to.equals(0)
    expect(allowance2).to.equals(0)
    expect(allowance3).to.equals(50)

    await expect(
      lisUSD.connect(signer2).transferFrom(signer1.address, signer2.address, 50)
    ).to.be.revertedWith('LisUSD/insufficient-allowance')

    await expect(
      lisUSD.connect(signer3).transferFrom(signer1.address, signer2.address, 51)
    ).to.be.revertedWith('LisUSD/insufficient-allowance')

    await expect(
      lisUSD.connect(signer3).transferFrom(signer1.address, signer2.address, 50)
    )
      .to.emit(lisUSD, 'Transfer')
      .withArgs(signer1.address, signer2.address, 50)

    expect(await lisUSD.allowance(signer1.address, signer3.address)).to.equals(0)

    const [balance1, balance2, balance3] =
      await Promise.all([
        lisUSD.balanceOf(signer1.address),
        lisUSD.balanceOf(signer2.address),
        lisUSD.balanceOf(signer3.address),
      ])
    expect(balance1).to.equals(50)
    expect(balance2).to.equals(60)
    expect(balance3).to.equals(0)

    // verify approve after upgrade
    await hay.connect(signer2).approve(signer3.address, 50)
    expect(await lisUSD.allowance(signer2.address, signer3.address)).to.equals(50)
    await hay.connect(signer2).increaseAllowance(signer3.address, 10)
    expect(await lisUSD.allowance(signer2.address, signer3.address)).to.equals(60)
    await hay.connect(signer2).decreaseAllowance(signer3.address, 10)
    expect(await lisUSD.allowance(signer2.address, signer3.address)).to.equals(50)
  })

  it('the push/pull/move should work well after upgraded', async function () {
    const hay = await upgrades.deployProxy(this.Hay, [97, 'HAY', ethers.utils.parseEther('100')], {
      initializer: 'initialize',
    })
    await hay.deployed()
    await hay.connect(deployer).mint(signer1.address, 100)
    await hay.connect(deployer).mint(signer2.address, 10)
    // approve
    await hay.connect(signer1).approve(signer3.address, 50)

    const lisUSD = await upgrades.upgradeProxy(hay.address, this.LisUSD)

    await expect(lisUSD.connect(signer1).push(signer2.address, 10))
      .to.emit(lisUSD, 'Transfer')
      .withArgs(signer1.address, signer2.address, 10)
    expect(await lisUSD.balanceOf(signer1.address)).to.equals(90)
    expect(await lisUSD.balanceOf(signer2.address)).to.equals(20)

    await expect(
      lisUSD.connect(signer2).pull(signer1.address, 10)
    ).to.be.revertedWith('LisUSD/insufficient-allowance')

    await expect(lisUSD.connect(signer3).pull(signer1.address, 10))
      .to.emit(lisUSD, 'Transfer')
      .withArgs(signer1.address, signer3.address, 10)
    expect(await lisUSD.allowance(signer1.address, signer3.address)).to.equals(40)
    expect(await lisUSD.balanceOf(signer1.address)).to.equals(80)
    expect(await lisUSD.balanceOf(signer3.address)).to.equals(10)

    await expect(lisUSD.connect(signer3).move(signer1.address, signer2.address, 10))
      .to.emit(lisUSD, 'Transfer')
      .withArgs(signer1.address, signer2.address, 10)
    expect(await lisUSD.allowance(signer1.address, signer3.address)).to.equals(30)
    expect(await lisUSD.balanceOf(signer1.address)).to.equals(70)
    expect(await lisUSD.balanceOf(signer2.address)).to.equals(30)

    await expect(
      lisUSD.connect(signer1).transfer(signer1.address, 71)
    ).to.be.revertedWith('LisUSD/insufficient-balance')

    await expect(
      lisUSD.connect(signer1).transfer(signer2.address, 70)
    )
      .to.emit(lisUSD, 'Transfer')
      .withArgs(signer1.address, signer2.address, 70)
    expect(await lisUSD.balanceOf(signer1.address)).to.equals(0)
    expect(await lisUSD.balanceOf(signer2.address)).to.equals(100)
  })

  it('the setSupplyCap should work well after upgraded', async function () {
    const supplyCap = ethers.utils.parseEther('100')
    const hay = await upgrades.deployProxy(this.Hay, [97, 'HAY', supplyCap], {
      initializer: 'initialize',
    })
    await hay.deployed()

    await hay.connect(deployer).mint(signer1.address, ethers.utils.parseEther('100'))
    expect(await hay.supplyCap()).to.equals(supplyCap)

    const lisUSD = await upgrades.upgradeProxy(hay.address, this.LisUSD)

    const newSupplyCap = ethers.utils.parseEther('101')
    const wrongSupplyCap = ethers.utils.parseEther('99')
    await expect(lisUSD.connect(deployer).setSupplyCap(wrongSupplyCap))
      .to.be.revertedWith('LisUSD/more-supply-than-cap')
    await expect(lisUSD.connect(deployer).setSupplyCap(newSupplyCap))
      .to.emit(lisUSD, 'SupplyCapSet')
      .withArgs(supplyCap, newSupplyCap)
    expect(await hay.supplyCap()).to.equals(newSupplyCap)
  })

  it('the updateDomainSeparator should work well after upgraded', async function () {
    const hay = await upgrades.deployProxy(this.Hay, [97, 'HAY', ethers.utils.parseEther('100')], {
      initializer: 'initialize',
    })
    await hay.deployed()
    let name = await hay.name()
    let version = await hay.version()
    const chainId = 97
    const contractAddress = hay.address

    // generate EIP-712 keccak256 hash
    const EIP712Hash = ethers.utils._TypedDataEncoder.hashDomain({
      name,
      version,
      chainId,
      verifyingContract: contractAddress
    })
    expect(await hay.DOMAIN_SEPARATOR()).to.equals(EIP712Hash)

    const lisUSD = await upgrades.upgradeProxy(hay.address, this.LisUSD)

    const newChainId = 56
    name = await lisUSD.name()
    version = await lisUSD.version()
    await lisUSD.connect(deployer).updateDomainSeparator(newChainId)
    const newEIP712Hash = ethers.utils._TypedDataEncoder.hashDomain({
      name,
      version,
      chainId: newChainId,
      verifyingContract: contractAddress
    })
    expect(await lisUSD.DOMAIN_SEPARATOR()).to.equals(newEIP712Hash)
  })

  it('the permit should work well after upgraded', async function () {
    // get the network chain id
    const chainId = (await ethers.provider.getNetwork()).chainId
    const hay = await upgrades.deployProxy(this.Hay, [chainId, 'HAY', ethers.utils.parseEther('100')], {
      initializer: 'initialize',
    })
    await hay.deployed()
    const lisUSD = await upgrades.upgradeProxy(hay.address, this.LisUSD)
    // update symbol
    await lisUSD.connect(deployer).setSymbol('lisUSD')

    // update domain separator
    await lisUSD.connect(deployer).updateDomainSeparator(chainId)

    await lisUSD.connect(deployer).mint(signer1.address, ethers.utils.parseEther("10"))
    // check signer1 balances
    expect(await lisUSD.balanceOf(signer1.address)).to.equals(ethers.utils.parseEther("10"))

    // set the domain parameters
    const domain = {
      name: await lisUSD.name(),
      version: '1',
      chainId: chainId,
      verifyingContract: lisUSD.address
    }

    // set the Permit type parameters
    const types = {
      Permit: [
        {
          name: 'holder',
          type: 'address'
        },
        {
          name: 'spender',
          type: 'address'
        },
        {
          name: 'nonce',
          type: 'uint256'
        },
        {
          name: 'expiry',
          type: 'uint256'
        },
        {
          name: 'allowed',
          type: 'bool'
        },
      ],
    }

    // set the Permit type values
    const values = {
      holder: signer1.address,
      spender: signer2.address,
      nonce: await lisUSD.nonces(signer1.address),
      expiry: (Math.floor(Date.now() / 1000) + 60 * 60 * 24).toString(),
      allowed: true
    }


    // sign the Permit type data with the deployer's private key
    const signature = await signer1._signTypedData(domain, types, values)

    // split the signature into its components
    const sig = ethers.utils.splitSignature(signature)

    // verify the Permit type data with the signature
    const recovered = ethers.utils.verifyTypedData(
      domain,
      types,
      values,
      sig
    )

    // check that the recovered address matches the signer1 address
    expect(recovered).to.equal(signer1.address)
    // permit the signer2 address to spend tokens on behalf of the tokenOwner
    await expect(lisUSD.connect(signer2).permit(
      signer1.address,
      signer2.address,
      values.nonce,
      values.expiry,
      values.allowed,
      sig.v,
      sig.r,
      sig.s
    ))
      .to.emit(lisUSD, 'Approval')
      .withArgs(signer1.address, signer2.address, ethers.constants.MaxUint256)

    // check that the signer2 address can now spend tokens of the signer1 address
    expect(await lisUSD.allowance(signer1.address, signer2.address)).to.equals(ethers.constants.MaxUint256)

    // transfer tokens from the signer1 to the signer2 and signer3 address
    await expect(lisUSD.connect(signer2).transferFrom(signer1.address, signer2.address, ethers.utils.parseEther("1")))
      .to.emit(lisUSD, 'Transfer')
      .withArgs(signer1.address, signer2.address, ethers.utils.parseEther("1"))
    await expect(lisUSD.connect(signer2).transferFrom(signer1.address, signer3.address, ethers.utils.parseEther("1")))
      .to.emit(lisUSD, 'Transfer')
      .withArgs(signer1.address, signer3.address, ethers.utils.parseEther("1"))

    // check that the signer2 and signer3 address have received the tokens
    expect(await lisUSD.balanceOf(signer2.address)).to.equals(ethers.utils.parseEther("1"))
    expect(await lisUSD.balanceOf(signer3.address)).to.equals(ethers.utils.parseEther("1"))

    // check that the signer1 address has the correct remaining balance
    expect(await lisUSD.balanceOf(signer1.address)).to.equals(ethers.utils.parseEther("8"))

    // check the allowance of the signer2 address
    expect(await lisUSD.allowance(signer1.address, signer2.address)).to.equals(ethers.constants.MaxUint256)
  })
})
