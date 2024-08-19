import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, ContractFactory } from 'ethers'
import { deployments, ethers } from 'hardhat'

import { Options } from '@layerzerolabs/lz-v2-utilities'
import { time, loadFixture, takeSnapshot } from '@nomicfoundation/hardhat-network-helpers'

describe('MyOApp Test', function () {
    // Constant representing a mock Endpoint ID for testing purposes
    const eidA = 1
    const eidB = 2
    // Declaration of variables to be used in the test suite
    let MyOApp: ContractFactory
    let EndpointV2Mock: ContractFactory
    let ownerA: SignerWithAddress
    let ownerB: SignerWithAddress
    let endpointOwner: SignerWithAddress
    let myOAppA: Contract
    let myOAppB: Contract
    let mockEndpointV2A: Contract
    let mockEndpointV2B: Contract
    let Staking: ContractFactory
    let stakingA: Contract
    let stakingB: Contract
    let userA: SignerWithAddress
    let userB: SignerWithAddress
    let userC: SignerWithAddress
    let deployer: SignerWithAddress
    let stakingBridgeA: Contract
    let stakingBridgeB: Contract
    let StakingBridge: ContractFactory

    // Before hook for setup that runs once before all tests in the block
    before(async function () {
        // Contract factory for our tested contract
        MyOApp = await ethers.getContractFactory('KizunaBridge')
        Staking = await ethers.getContractFactory('Staking')
        StakingBridge = await ethers.getContractFactory('StakingBridge')

        // Fetching the first three signers (accounts) from Hardhat's local Ethereum network
        const signers = await ethers.getSigners()

        ownerA = signers.at(0)!
        ownerB = signers.at(1)!
        endpointOwner = signers.at(2)!
        userA = signers.at(3)!
        userB = signers.at(4)!
        userC = signers.at(5)!
        deployer = signers.at(0)!

        // The EndpointV2Mock contract comes from @layerzerolabs/test-devtools-evm-hardhat package
        // and its artifacts are connected as external artifacts to this project
        //
        // Unfortunately, hardhat itself does not yet provide a way of connecting external artifacts,
        // so we rely on hardhat-deploy to create a ContractFactory for EndpointV2Mock
        //
        // See https://github.com/NomicFoundation/hardhat/issues/1040
        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock')
        EndpointV2Mock = new ContractFactory(EndpointV2MockArtifact.abi, EndpointV2MockArtifact.bytecode, endpointOwner)
    })

    // beforeEach hook for setup that runs before each test in the block
    beforeEach(async function () {
        // Deploying a mock LZ EndpointV2 with the given Endpoint ID
        mockEndpointV2A = await EndpointV2Mock.deploy(eidA)
        mockEndpointV2B = await EndpointV2Mock.deploy(eidB)

        stakingA = await Staking.deploy()
        stakingB = await Staking.deploy()
        // Deploying two instances of MyOApp contract and linking them to the mock LZEndpoint
        myOAppA = await MyOApp.deploy(mockEndpointV2A.address, ownerA.address, 300, stakingA.address)
        myOAppB = await MyOApp.deploy(mockEndpointV2B.address, ownerB.address, 300, stakingB.address)

        // Setting destination endpoints in the LZEndpoint mock for each MyOApp instance
        await mockEndpointV2A.setDestLzEndpoint(myOAppB.address, mockEndpointV2B.address)
        await mockEndpointV2B.setDestLzEndpoint(myOAppA.address, mockEndpointV2A.address)

        // await mockEndpointV2A.setDestLzEndpoint(myOAppA.address, mockEndpointV2A.address)
        // await mockEndpointV2B.setDestLzEndpoint(myOAppB.address, mockEndpointV2B.address)

        // Setting each MyOApp instance as a peer of the other
        await myOAppA.connect(ownerA).setPeer(eidB, ethers.utils.zeroPad(myOAppB.address, 32))
        await myOAppB.connect(ownerB).setPeer(eidA, ethers.utils.zeroPad(myOAppA.address, 32))

        await ownerB.sendTransaction({
            to: myOAppB.address,
            value: ethers.utils.parseEther('1'),
        })

        await stakingA.setLiquidityManager(myOAppA.address)
        await stakingB.setLiquidityManager(myOAppB.address)

        // stakingBridgeA = await StakingBridge.deploy();
        stakingBridgeA = await StakingBridge.deploy(mockEndpointV2A.address, ownerA.address, 300, stakingA.address)
        stakingBridgeB = await StakingBridge.deploy(mockEndpointV2B.address, ownerB.address, 300, stakingB.address)

        await stakingA.setStakingBridge(stakingBridgeA.address)
        await stakingB.setStakingBridge(stakingBridgeB.address)
        await stakingA.setLiquidityManager(stakingBridgeA.address)
        await stakingB.setLiquidityManager(stakingBridgeB.address)

        await mockEndpointV2A.setDestLzEndpoint(stakingBridgeB.address, mockEndpointV2B.address)
        await mockEndpointV2B.setDestLzEndpoint(stakingBridgeA.address, mockEndpointV2A.address)

        await stakingBridgeA.connect(ownerA).setPeer(eidB, ethers.utils.zeroPad(stakingBridgeB.address, 32))
        await stakingBridgeB.connect(ownerB).setPeer(eidA, ethers.utils.zeroPad(stakingBridgeA.address, 32))
    })

    it('testing unstake and withdraw', async function () {
        await stakingA.connect(userA).stake({ value: ethers.utils.parseEther('1') })
        await stakingB.connect(userB).stake({ value: ethers.utils.parseEther('1') })

        const stakeTime = await time.latest()
        await stakingA.connect(userA).unstake(ethers.utils.parseEther('1'))

        await expect(stakingA.connect(userA).withdraw(0)).to.be.revertedWith('Cooldown period not yet passed')

        await time.increaseTo(stakeTime + 3600 * 24 * 7)
        try {
            let before = await ethers.provider.getBalance(userA.address)
            let tr = await stakingA.connect(userA).withdraw(0)
            let receipt = await tr.wait()
            let gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice)
            let after = await ethers.provider.getBalance(userA.address)
            let unstake = after.sub(before).add(gasUsed)
            expect(unstake.toString()).eq(ethers.utils.parseEther('1').toString())
        } catch (err) {
            console.log(err)
            expect(false).eq(true)
        }
    })
    it('testing bridge send', async function () {
        // Assert initial state of data in both MyOApp instances
        const adminFeePercent = 300 // 3%
        const sendAmount = ethers.utils.parseEther('1')
        await stakingA.connect(userA).stake({ value: ethers.utils.parseEther('1') })
        await stakingB.connect(userB).stake({ value: ethers.utils.parseEther('1') })

        const options = Options.newOptions().addExecutorLzReceiveOption(600000, 0).toHex().toString()

        const sendAmountWithAdminFee = sendAmount.mul(100000).div(100000 - adminFeePercent)
        // Define native fee and quote for the message send operation
        let nativeFee = 0
        ;[nativeFee] = await myOAppA.quoteAmount(eidB, sendAmountWithAdminFee, ownerB.address, options)

        const startBalanceA = await ethers.provider.getBalance(ownerA.address)
        const startBalanceB = await ethers.provider.getBalance(ownerB.address)

        // Execute send operation from myOAppA
        let tr = await myOAppA.sendAmount(eidB, nativeFee, ownerB.address, options, {
            value: sendAmountWithAdminFee.add(nativeFee).toString(),
        })
        let receipt = await tr.wait()
        let gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice)

        const finalBalanceA = await ethers.provider.getBalance(ownerA.address)
        const finalBalanceB = await ethers.provider.getBalance(ownerB.address)

        expect(finalBalanceB.sub(startBalanceB).toString()).to.equal(sendAmount.toString())
        expect(startBalanceA.sub(finalBalanceA).toString()).to.equal(
            sendAmountWithAdminFee.add(gasUsed).add(nativeFee).toString()
        )
    })

    it('testing withdrawByBridge', async function () {
        await stakingA.connect(userA).stake({ value: ethers.utils.parseEther('1') })
        await stakingB.connect(userB).stake({ value: ethers.utils.parseEther('1') })

        // await stakingB.transferLiquidity(userA.address, ethers.utils.parseEther('1'))
        // Assert initial state of data in both MyOApp instances
        const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()

        await stakingB.connect(userB).unstake(ethers.utils.parseEther('1'))
        const unstakeTime = await time.latest()

        await time.increaseTo(unstakeTime + 60 * 60 * 24 * 7)

        // await expect(stakingB.connect(userB).withdraw(0)).to.be.revertedWith('not enough for direct withdraw')

        // Define native fee and quote for the message send operation
        let nativeFee = ethers.BigNumber.from('0')
        ;[nativeFee] = await stakingBridgeA.quote(eidB, options, false)

        nativeFee = nativeFee.mul(100000).div(100000 - 300)

        let before = await ethers.provider.getBalance(userB.address)

        let tr = await stakingB.connect(userB).withdrawByBridge(0, eidA, userB.address, options, { value: nativeFee })
        let receipt = await tr.wait()
        let gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice)

        let after = await ethers.provider.getBalance(userB.address)

        let unstake = after.sub(before).add(gasUsed).add(nativeFee)

        expect(unstake.toString()).eq(ethers.utils.parseEther('1').toString())
    })

    // Test case for staking functionality
    it('should allow a user to stake ETH', async function () {
        const initialBalance = await ethers.provider.getBalance(userA.address)
        const stakeAmount = ethers.utils.parseEther('1')

        const tx = await stakingA.connect(userA).stake({ value: stakeAmount })
        const receipt = await tx.wait()
        const gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice)

        const finalBalance = await ethers.provider.getBalance(userA.address)
        const stakedBalance = await stakingA.stakedBalances(userA.address)

        expect(stakedBalance.toString()).to.equal(stakeAmount.toString())
        expect(initialBalance.sub(finalBalance).sub(gasUsed).toString()).to.equal(stakeAmount.toString())
    })

    // Test case for unstaking functionality
    it('should allow a user to unstake ETH after cooldown period', async function () {
        const stakeAmount = ethers.utils.parseEther('1')
        await stakingA.connect(userA).stake({ value: stakeAmount })

        await stakingA.connect(userA).unstake(stakeAmount)
        const stakeTime = await time.latest()

        await time.increaseTo(stakeTime + 3600 * 24 * 7) // Increase time by 7 days

        const initialBalance = await ethers.provider.getBalance(userA.address)
        const tx = await stakingA.connect(userA).withdraw(0)
        const receipt = await tx.wait()
        const gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice)

        const finalBalance = await ethers.provider.getBalance(userA.address)
        const unstakeAmount = finalBalance.sub(initialBalance).add(gasUsed)

        expect(unstakeAmount.toString()).to.equal(stakeAmount.toString())
    })

    // Test case for preventing unstake before cooldown period
    it('should not allow a user to withdraw before cooldown period', async function () {
        const stakeAmount = ethers.utils.parseEther('1')
        await stakingA.connect(userA).stake({ value: stakeAmount })

        await stakingA.connect(userA).unstake(stakeAmount)

        await expect(stakingA.connect(userA).withdraw(0)).to.be.revertedWith('Cooldown period not yet passed')
    })

    // Test case for multiple stakes and unstakes
    it('should handle multiple stakes and unstakes correctly', async function () {
        const stakeAmount1 = ethers.utils.parseEther('1')
        const stakeAmount2 = ethers.utils.parseEther('2')

        await stakingA.connect(userA).stake({ value: stakeAmount1 })
        await stakingA.connect(userA).stake({ value: stakeAmount2 })

        let stakedBalance = await stakingA.stakedBalances(userA.address)
        expect(stakedBalance.toString()).to.equal(stakeAmount1.add(stakeAmount2).toString())

        await stakingA.connect(userA).unstake(stakeAmount1)
        const stakeTime = await time.latest()

        await time.increaseTo(stakeTime + 3600 * 24 * 7) // Increase time by 7 days

        const initialBalance = await ethers.provider.getBalance(userA.address)
        const tx = await stakingA.connect(userA).withdraw(0)
        const receipt = await tx.wait()
        const gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice)

        const finalBalance = await ethers.provider.getBalance(userA.address)
        const unstakeAmount = finalBalance.sub(initialBalance).add(gasUsed)

        expect(unstakeAmount.toString()).to.equal(stakeAmount1.toString())

        stakedBalance = await stakingA.stakedBalances(userA.address)
        expect(stakedBalance.toString()).to.equal(stakeAmount2.toString())
    })
})
