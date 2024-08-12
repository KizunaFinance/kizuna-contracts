// const { deployments } = require('hardhat')
import { deployments, ethers } from 'hardhat'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import { Options } from '@layerzerolabs/lz-v2-utilities'

const main1 = async () => {
    // 0x98a8f080865a88231Cb4a6E20Bea06A8D2c00fe7

    //     Deployed contract: KizunaBridge, network: holesky, address: 0x92889DF1b03AfB5CAc826d1AF6d55B757D65E3E2
    // Deployed contract: KizunaBridge, network: hekla, address: 0x4fd77fd045c2d88dbC48653a14b08B7d3c730F09

    const addrA = '0x830e7841A70C8cd20dC403dA31f92341Dd4FB4a2'
    const addrB = '0x14A4D992A6d5D5e4Ba9FC6fb11b8DAe4F57B838c'

    const stAddrA = '0x3d523AD54161576614711892723971F371DdE786'
    const stAddrB = '0x5fAA85073B0633e18E72B7738BcCDf61C64C5a2B'

    const stakingA = '0x0a713535De91b3A4755F407213288aEf5E951595'
    const stakingB = '0xA5C72B129a445301C4F28232ba432B9ECCd97F2F'

    //kizuna
    // holesky: 0x92889DF1b03AfB5CAc826d1AF6d55B757D65E3E2
    // hekla: 0x4fd77fd045c2d88dbC48653a14b08B7d3c730F09

    //Staking
    // holesky: 0x3d523AD54161576614711892723971F371DdE786
    // hekla: 0x5fAA85073B0633e18E72B7738BcCDf61C64C5a2B

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
    const Staking = StakingContract.attach(currentStaking)

    // const Staking = await StakingContract.deploy()
    // console.log('Staking', Staking.address)

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

const main = async () => {
    const staking = await ethers.getContractFactory('Staking')
    const Staking = staking.attach('0xA5C72B129a445301C4F28232ba432B9ECCd97F2F')

    const value = await Staking.stakedBalances('0x5fAA85073B0633e18E72B7738BcCDf61C64C5a2B')
    console.log('value: ', value)
}

main()
