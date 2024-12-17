import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
// import "@nomiclabs/hardhat-ethers";
// import "@nomiclabs/hardhat-waffle";

const config: HardhatUserConfig = {
  networks: {
    localhost: {
      loggingEnabled: true,
    },
    // ethereum: {
    //   url: `${process.env.ETHEREUM_RPC_URL}`, // Your Ethereum RPC URL
    //   accounts: [`${process.env.PRIVATE_KEY}`], // Your private key
    // },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.26", // Recommended version
      },
    ],
  },
  paths: {
    sources: "./contracts", // Path to your smart contracts
    tests: "./test", // Path to your test files
    cache: "./cache", // Path to cache files
    artifacts: "./artifacts", // Path to compiled artifacts
  },
};

export default config;
