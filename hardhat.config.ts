// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import 'dotenv/config'

import 'hardhat-deploy'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
import '@layerzerolabs/toolbox-hardhat'
import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'

import { EndpointId } from '@layerzerolabs/lz-definitions'
import '@nomicfoundation/hardhat-verify'

// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
const MNEMONIC = process.env.MNEMONIC

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = process.env.PRIVATE_KEY

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
      ? [PRIVATE_KEY]
      : undefined

if (accounts == null) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: '0.8.22',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        // sepolia: {
        //     eid: EndpointId.SEPOLIA_V2_TESTNET,
        //     url: process.env.RPC_URL_SEPOLIA || 'https://rpc.sepolia.org/',
        //     accounts,
        // },
        holesky: {
            eid: EndpointId.HOLESKY_V2_TESTNET,
            url: 'https://1rpc.io/holesky',
            accounts,
        },
        // fuji: {
        //     eid: EndpointId.AVALANCHE_V2_TESTNET,
        //     url: process.env.RPC_URL_FUJI || 'https://rpc.ankr.com/avalanche_fuji',
        //     accounts,
        // },
        // amoy: {
        //     eid: EndpointId.AMOY_V2_TESTNET,
        //     url: process.env.RPC_URL_AMOY || 'https://polygon-amoy-bor-rpc.publicnode.com',
        //     accounts,
        // },
        hekla: {
            eid: EndpointId.TAIKO_TESTNET,
            url: 'https://rpc.hekla.taiko.xyz',
            accounts,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0, // wallet address of index[0], of the mnemonic in .env
        },
    },
    // sourcify: {
    //     enabled: true,
    // },
    verify: {
        etherscan: {
            // apiKey: 'WGAQCNUDQCFRQJH9D72G94BZ83STGRJCX6',
            // apiKey: 'GCCG77JI6JW3FV93UKE8WQPRXA18T5TN4B',

            //@ts-ignore
            // holesky: {
            apiKey: {
                holesky: 'GCCG77JI6JW3FV93UKE8WQPRXA18T5TN4B',
                hekla: '2CC5WX8SERQ8VJ6NFFSJSIX53QX4626RCR',
            },
            customChains: [
                {
                    network: 'hekla',
                    chainId: 167009,
                    urls: {
                        apiURL: 'https://api-hekla.taikoscan.io/api',
                        browserURL: 'https://hekla.taikoscan.network/',
                    },
                },
            ],
            // },
        },
    },
    etherscan: {
        // apiKey: 'WGAQCNUDQCFRQJH9D72G94BZ83STGRJCX6',
        // apiKey: 'GCCG77JI6JW3FV93UKE8WQPRXA18T5TN4B',

        //@ts-ignore
        apiKey: {
            holesky: 'GCCG77JI6JW3FV93UKE8WQPRXA18T5TN4B',
            hekla: '2CC5WX8SERQ8VJ6NFFSJSIX53QX4626RCR',
        },
        customChains: [
            {
                network: 'hekla',
                chainId: 167009,
                urls: {
                    apiURL: 'https://api-hekla.taikoscan.io/api',
                    browserURL: 'https://hekla.taikoscan.network/',
                },
            },
        ],
    },

    // bscscan: {
    //     apiKey: 'S1PFEYDQ5SXJSKTB2UE6YXAKF2XDV2Y4EV',
    // },
}

export default config
