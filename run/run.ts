// const { deployments } = require('hardhat')
import { deployments, ethers } from 'hardhat'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import { Options } from '@layerzerolabs/lz-v2-utilities'

const main1 = async () => {
    const [deployer] = await ethers.getSigners()
    console.log('deployer', deployer.address)
    const STAKING_HOLESKY = '0x29d60738584c7C0254D3233E2EC31C4aba64452F'
    const STAKING_HEKLA = '0x29d60738584c7C0254D3233E2EC31C4aba64452F'
    const BRIDGE_HOLESKY = '0x5A7827849FB04A4C641311599fFDF464dDE7DBd8'
    const BRIDGE_HEKLA = '0x5A7827849FB04A4C641311599fFDF464dDE7DBd8'

    const stakingContract = await ethers.getContractFactory('Staking')
    const staking = stakingContract.attach(STAKING_HEKLA)

    let balance = await ethers.provider.getBalance(staking.address)
    console.log('balance: ', balance)
    // deployer.getBalance()
    let tr = await staking.transferLiquidity(deployer.address, balance)
    console.log('tr', tr.hash)
    await tr.wait()

    balance = await ethers.provider.getBalance(staking.address)
    console.log('balance: ', balance)
}
const main = async () => {
    // 0x98a8f080865a88231Cb4a6E20Bea06A8D2c00fe7

    const addrA = '0x4EA3D529Af38d0aDd01CEF07E573020c374d7825'
    const addrB = '0xA5C72B129a445301C4F28232ba432B9ECCd97F2F'

    const stAddrA = '0x5E4c235fe0CBc5c689A2005c5107acf9C5AbeE82'
    const stAddrB = '0xD0fD3589Fd90cB19734fe5C1D863c3fA221C3dA7'

    const stakingA = '0x356c1eEF5922411D680555325591DB05bE8A9902'
    const stakingB = '0xaf3f3CE84178De19FBbFe672448BBACF52271999'
    const eidA = EndpointId.HOLESKY_V2_TESTNET
    const eidB = EndpointId.TAIKO_V2_TESTNET

    const [deployer] = await ethers.getSigners()
    let currentAddr = addrA
    let currentStAddr = stAddrA
    let currentStaking = stakingA
    let currentEid = eidA
    let opAddr = addrB
    let opStAddr = stAddrB
    let opStaking = stakingB
    let opEid = eidB

    // let currentAddr = addrB
    // let currentStAddr = stAddrB
    // let currentStaking = stakingB
    // let currentEid = eidB
    // let opAddr = addrA
    // let opStAddr = stAddrA
    // let opStaking = stakingA
    // let opEid = eidA

    // Deployed contract: MyOApp, network: sepolia, address: 0xdfa96d5E31177F182fc95790Be712D238d0d3b83
    // Deployed contract: MyOApp, network: holesky, address: 0xd893ecA437965Aea802b2aB4A10317e67cFB0275

    const contractInstance = await ethers.getContractFactory('KizunaBridge')
    const KizunaBridge = contractInstance.attach(currentAddr)

    const stakingBridgeContract = await ethers.getContractFactory('StakingBridge')
    const stakingBridge = stakingBridgeContract.attach(currentStAddr)

    let tr = await KizunaBridge.connect(deployer).setPeer(opEid, ethers.utils.zeroPad(opAddr, 32))
    console.log('tr', tr.hash)
    await tr.wait()

    tr = await stakingBridge.connect(deployer).setPeer(opEid, ethers.utils.zeroPad(opAddr, 32))
    console.log('tr', tr.hash)
    await tr.wait()

    const StakingContract = await ethers.getContractFactory('Staking')
    const Staking = await StakingContract.deploy()
    console.log('Staking', Staking.address)

    const LIQUIDITY_MANAGER_ROLE = await Staking.LIQUIDITY_MANAGER_ROLE()
    tr = await Staking.connect(deployer).grantRole(LIQUIDITY_MANAGER_ROLE, KizunaBridge.address)
    await tr.wait()
    console.log('tr', tr.hash)

    tr = await Staking.connect(deployer).grantRole(LIQUIDITY_MANAGER_ROLE, stakingBridge.address)
    await tr.wait()
    console.log('tr', tr.hash)

    tr = await KizunaBridge.connect(deployer).setEthVaultAddress(Staking.address)
    await tr.wait()
    console.log('tr', tr.hash)

    tr = await stakingBridge.connect(deployer).setEthVaultAddress(Staking.address)
    await tr.wait()
    console.log('tr', tr.hash)

    tr = await Staking.setStakingBridge(stakingBridge.address)
    await tr.wait()
    console.log('tr', tr.hash)
}

main()
