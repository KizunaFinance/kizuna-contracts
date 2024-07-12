// const { deployments } = require('hardhat')
import { deployments, ethers } from 'hardhat'
import { EndpointId } from '@layerzerolabs/lz-definitions'
import { Options } from '@layerzerolabs/lz-v2-utilities'

const main = async () => {
    // 0xB458B11562646A662AB2Ded927c2e2e8564e0201
    // 0xdfa96d5E31177F182fc95790Be712D238d0d3b83
    const addrA = '0xB4768d706cf13f75844034EDAEcBe5705cd22b22'
    const addrB = '0x9eEeA4611b59df614cC2F111805e21468CDFf4E3'
    const eidA = EndpointId.HOLESKY_V2_TESTNET
    const eidB = EndpointId.SEPOLIA_V2_TESTNET

    // Deployed contract: MyOApp, network: sepolia, address: 0xdfa96d5E31177F182fc95790Be712D238d0d3b83
    // Deployed contract: MyOApp, network: holesky, address: 0xd893ecA437965Aea802b2aB4A10317e67cFB0275

    const [deployer] = await ethers.getSigners()
    console.log('deployer', deployer.address)
    const contractInstance = await ethers.getContractFactory('MyOApp')
    const OApp = contractInstance.attach(addrA)

    // 264762770092939823
    //  144807788747589690898

    // const endpointInstance = await ethers.getContractFactory('EndpointV2')
    // const endpointV2Deployment = endpointInstance.attach('0x6EDCE65403992e310A62460808c4b910D972f10f')

    // const sendExecutorConfigBytes = await endpointV2Deployment.getConfig(
    //     oappAddress,
    //     sendLibAddress,
    //     remoteEid,
    //     executorConfigType,
    //   );
    //   const executorConfigAbi = ['tuple(uint32 maxMessageSize, address executorAddress)'];
    //   const executorConfigArray = ethers.utils.defaultAbiCoder.decode(
    //     executorConfigAbi,
    //     sendExecutorConfigBytes,
    //   );
    //   console.log('Send Library Executor Config:', executorConfigArray);

    // const oapp = await deployments.get('MyOApp')
    // console.log(oapp.address)

    // const endpointV2Deployment = await deployments.get('EndpointV2')
    // endP

    const EndpointV2MockArtifact = await deployments.getArtifact('ILayerZeroEndpointV2')
    const endpointV2Deployment = await ethers.getContractAt(
        EndpointV2MockArtifact.abi,
        '0x6EDCE65403992e310A62460808c4b910D972f10f',
        deployer
    )

    // console.log(endpointV2Deployment)

    // let tr = await endpointV2Deployment.setDestLzEndpoint(
    //     '0xB458B11562646A662AB2Ded927c2e2e8564e0201',
    //     endpointV2Deployment.address
    // )
    // await mockEndpointV2B.setDestLzEndpoint(myOAppA.address, mockEndpointV2A.address)
    // console.log(tr.hash)

    // Setting each MyOApp instance as a peer of the other
    // let tr = await OApp.connect(deployer).setPeer(eidA, ethers.utils.zeroPad(addrA, 32))
    // console.log('tr', tr.hash)
    // return
    // await myOAppB.connect(ownerB).setPeer(eidA, ethers.utils.zeroPad(myOAppA.address, 32))

    // let tr = await OApp.setPeer(EndpointId.SEPOLIA_V2_TESTNET)
    // console.log(tr)
    // return

    // const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()
    // console.log('options: ', options)

    // const message = 'Sepolia2'
    // let nativeFee = 0
    // ;[nativeFee] = await OApp.quote(eidA, message, options, false)
    // console.log('nativeFee:', nativeFee)

    // // Execute send operation from myOAppA
    // let tr = await OApp.send(eidA, message, options, { value: nativeFee.toString() })
    // console.log(tr.hash)
    // await tr.wait()
    // const tr = await OApp.send(EndpointId.SEPOLIA_V2_TESTNET, 'Test string from amoy', '0x')
    // console.log(tr.hash)
    // await tr.wait()
    const recvMessage = await OApp.data()
    console.log(recvMessage)
}

main()
