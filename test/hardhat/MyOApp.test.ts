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

    // Before hook for setup that runs once before all tests in the block
    before(async function () {
        // Contract factory for our tested contract
        MyOApp = await ethers.getContractFactory('DaikoBridge')
        Staking = await ethers.getContractFactory('Staking')

        // Fetching the first three signers (accounts) from Hardhat's local Ethereum network
        const signers = await ethers.getSigners()

        ownerA = signers.at(0)!
        ownerB = signers.at(1)!
        endpointOwner = signers.at(2)!
        userA = signers.at(3)!
        userB = signers.at(4)!
        userC = signers.at(5)!

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

        stakingA = await Staking.deploy(30000)
        stakingB = await Staking.deploy(30000)
        // Deploying two instances of MyOApp contract and linking them to the mock LZEndpoint
        myOAppA = await MyOApp.deploy(mockEndpointV2A.address, ownerA.address, 300, stakingA.address)
        myOAppB = await MyOApp.deploy(mockEndpointV2B.address, ownerB.address, 300, stakingB.address)

        // Setting destination endpoints in the LZEndpoint mock for each MyOApp instance
        await mockEndpointV2A.setDestLzEndpoint(myOAppB.address, mockEndpointV2B.address)
        await mockEndpointV2B.setDestLzEndpoint(myOAppA.address, mockEndpointV2A.address)

        // Setting each MyOApp instance as a peer of the other
        await myOAppA.connect(ownerA).setPeer(eidB, ethers.utils.zeroPad(myOAppB.address, 32))
        await myOAppB.connect(ownerB).setPeer(eidA, ethers.utils.zeroPad(myOAppA.address, 32))

        await ownerB.sendTransaction({
            to: myOAppB.address,
            value: ethers.utils.parseEther('1'),
        })
        console.log('after send')
        await stakingA.connect(userA).stake({ value: ethers.utils.parseEther('1') })
        await stakingB.connect(userB).stake({ value: ethers.utils.parseEther('1') })
        await stakingA.changeLiquidityManager(myOAppA.address)
        await stakingB.changeLiquidityManager(myOAppB.address)
    })

    // A test case to verify message sending functionality

    it('testing unstake and withdraw', async function () {
        // await stakingA.connect(userA).stake({ value: ethers.utils.parseEther('1') })
        const stakeTime = await time.latest()
        await stakingA.connect(userA).unstake(ethers.utils.parseEther('1'))

        // await expect(stakingA.connect(userA).unstake()).to.revert;
        let revertFlag = false
        try {
            await stakingA.connect(userA).withdraw(ethers.utils.parseEther('1'))
            expect(false).eq(true)
        } catch (err) {
            console.log(err)
            expect(true).eq(true)
        }

        await time.increaseTo(stakeTime + 3600 * 24 * 7)
        try {
            let before = await ethers.provider.getBalance(userA.address)
            let tr = await stakingA.connect(userA).withdraw(ethers.utils.parseEther('1'))
            let receipt = await tr.wait()
            let gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice)
            let after = await ethers.provider.getBalance(userA.address)
            let unstake = after.sub(before).add(gasUsed)
            console.log('unstake: ', unstake.toString())
            expect(unstake.toString()).eq(ethers.utils.parseEther('1').toString())
        } catch (err) {
            console.log(err)
            expect(false).eq(true)
        }
    })
    it('testing bridge send', async function () {
        // Assert initial state of data in both MyOApp instances
        // expect(await myOAppA.data()).to.equal('Nothing received yet.')
        // expect(await myOAppB.data()).to.equal('Nothing received yet.')
        const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()

        // Define native fee and quote for the message send operation
        let nativeFee = 0
        ;[nativeFee] = await myOAppA.quote(eidB, options, false)
        console.log('nativeFee:', nativeFee)

        // uint32 _dstEid,
        // uint256 fee,
        // string memory _message,
        // bytes calldata _options

        console.log('value: ', ethers.utils.parseEther('1').add(nativeFee).toString())
        const startBalanceB = await ethers.provider.getBalance(myOAppA.address)

        // Execute send operation from myOAppA
        await myOAppA.send(eidB, nativeFee, ownerB.address, options, {
            value: ethers.utils.parseEther('1').add(nativeFee).toString(),
        })

        const finalBalanceB = await ethers.provider.getBalance(myOAppA.address)
        console.log(startBalanceB.sub(finalBalanceB).toString())

        // Assert the resulting state of data in both MyOApp instances
        // expect(await myOAppA.data()).to.equal('Nothing received yet.')
        // expect(await myOAppB.data()).to.equal('Test message.')
    })

    it('testing bridge staking reward', async function () {
        // Assert initial state of data in both MyOApp instances
        // expect(await myOAppA.data()).to.equal('Nothing received yet.')
        // expect(await myOAppB.data()).to.equal('Nothing received yet.')
        const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()

        // Define native fee and quote for the message send operation
        let nativeFee = 0
        ;[nativeFee] = await myOAppA.quote(eidB, options, false)
        console.log('nativeFee:', nativeFee)

        // uint32 _dstEid,
        // uint256 fee,
        // string memory _message,
        // bytes calldata _options

        console.log('value: ', ethers.utils.parseUnits('1', 'wei').add(nativeFee).toString())
        const startBalanceB = await ethers.provider.getBalance(myOAppA.address)

        // Execute send operation from myOAppA
        await myOAppA.send(eidB, nativeFee, ownerB.address, options, {
            value: ethers.utils.parseEther('1').add(nativeFee).toString(),
        })

        const finalBalanceB = await ethers.provider.getBalance(myOAppA.address)
        console.log(startBalanceB.sub(finalBalanceB).toString())

        await stakingA.updateReward()

        let before = await ethers.provider.getBalance(userA.address)
        let tr = await stakingA.connect(userA).getRewardForUser()
        let receipt = await tr.wait()
        let gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice)
        let after = await ethers.provider.getBalance(userA.address)
        let reward = after.sub(before).add(gasUsed)
        console.log('before after', before.toString(), after.toString(), gasUsed.toString())
        expect(reward.toString()).eq('2100000000000000')

        await stakingA.connect(userC).stake({ value: ethers.utils.parseEther('3') })

        await myOAppA.send(eidB, nativeFee, ownerB.address, options, {
            value: ethers.utils.parseEther('1').add(nativeFee).toString(),
        })

        await stakingA.updateReward()

        before = await ethers.provider.getBalance(userA.address)
        tr = await stakingA.connect(userA).getRewardForUser()
        receipt = await tr.wait()
        gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice)
        after = await ethers.provider.getBalance(userA.address)
        reward = after.sub(before).add(gasUsed)
        expect(reward.toString()).eq('525000000000000')

        before = await ethers.provider.getBalance(userC.address)
        tr = await stakingA.connect(userC).getRewardForUser()
        receipt = await tr.wait()
        gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice)
        after = await ethers.provider.getBalance(userC.address)
        reward = after.sub(before).add(gasUsed)
        expect(reward.toString()).eq('1575000000000000')
        console.log('rewardC: ', reward)

        // Assert the resulting state of data in both MyOApp instances
        // expect(await myOAppA.data()).to.equal('Nothing received yet.')
        // expect(await myOAppB.data()).to.equal('Test message.')
    })
})
