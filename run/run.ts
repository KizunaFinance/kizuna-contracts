// const { deployments } = require('hardhat')
import { deployments, ethers } from 'hardhat'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import { Options } from '@layerzerolabs/lz-v2-utilities'

const main = async () => {
    // 0x98a8f080865a88231Cb4a6E20Bea06A8D2c00fe7

    const addrA = '0x4b688345E800e94523bC66D2Be396c1067917475'
    const addrB = '0xD0fD3589Fd90cB19734fe5C1D863c3fA221C3dA7'
    const stAddrA = '0xed3d414D2605b2746A9dA0282F780d001A33e230'
    const stAddrB = '0xd2A421Dca9185D2a5D6D928b18B347805BA653CD'
    const stakingA = '0xd2A421Dca9185D2a5D6D928b18B347805BA653CD'
    const stakingB = '0xed3d414D2605b2746A9dA0282F780d001A33e230'
    const eidA = EndpointId.HOLESKY_V2_TESTNET
    const eidB = EndpointId.TAIKO_V2_TESTNET

    let currentAddr = addrA
    let currentStAddr = stAddrA
    let currentStaking = stakingA
    let opAddr = addrB
    let opStAddr = stAddrB
    let opStaking = stakingB

    // let currentAddr = addrB
    // let currentStAddr = stAddrB
    // let currentStaking = stakingB
    // let opAddr = addrA
    // let opStAddr = stAddrA
    // let opStaking = stakingA

    // Deployed contract: MyOApp, network: sepolia, address: 0xdfa96d5E31177F182fc95790Be712D238d0d3b83
    // Deployed contract: MyOApp, network: holesky, address: 0xd893ecA437965Aea802b2aB4A10317e67cFB0275

    const [deployer] = await ethers.getSigners()
    console.log('deployer', deployer.address)
    const contractInstance = await ethers.getContractFactory('KizunaBridge')
    const KizunaBridge = contractInstance.attach(addrA)

    const stakingBridgeContract = await ethers.getContractFactory('StakingBridge')
    const stakingBridge = stakingBridgeContract.attach(stAddrA)

    let tr = await KizunaBridge.connect(deployer).setPeer(eidB, ethers.utils.zeroPad(addrB, 32))
    console.log('tr', tr.hash)
    await tr.wait()

    tr = await stakingBridge.connect(deployer).setPeer(eidB, ethers.utils.zeroPad(addrB, 32))
    console.log('tr', tr.hash)
    await tr.wait()

    const StakingContract = await ethers.getContractFactory('Staking')
    const Staking = await StakingContract.deploy(30000)
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
