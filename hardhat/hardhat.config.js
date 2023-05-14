// 1. Import the Ethers plugin required to interact with the contract
require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("hardhat-gas-reporter")
require("solidity-coverage")
require("hardhat-contract-sizer")
require("dotenv").config()

// 2. Import your private key from your pre-funded Moonbase Alpha testing account
// const { privateKey } = require("./secrets.json")

const PRIVATE_KEY_DEV = process.env.PRIVATE_KEY_DEV
const ZK_MUMBAI_RPC_URL = process.env.ZK_MUMBAI_RPC_URL_QUICKNODE
// const PRIVATE_KEY = process.env.MUMBAI_PRIVATE_KEY

const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL_QUICKNODE

module.exports = {
    etherscan: {
        apiKey: {
            polygonMumbai: process.env.POLYGONSCAN_API_KEY,
        },
    },

    // 3. Specify the Solidity version
    solidity: {
        compilers: [
            {
                version: "0.8.0",
            },
            {
                version: "0.8.1",
            },
            {
                version: "0.8.9",
                // settings: {},
            },
            {
                version: "0.8.11",
            },
        ],
    },
    // solidity: "0.8.1",
    defaultNetwork: "hardhat",

    networks: {
        // 4. Add the Moonbase Alpha network specification
        moonbase: {
            url: "https://rpc.api.moonbase.moonbeam.network",
            chainId: 1287, // (hex: 0x507),
            accounts: [PRIVATE_KEY_DEV],
        },

        zkmumbai: {
            url: ZK_MUMBAI_RPC_URL,
            accounts: [PRIVATE_KEY_DEV],
            chainId: 1442,
        },

        mumbai: {
            url: MUMBAI_RPC_URL,
            accounts: [PRIVATE_KEY_DEV],
            chainId: 80001,
        },
    },
}