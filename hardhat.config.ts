import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
// import "@nomiclabs/hardhat-etherscan";
import 'dotenv/config';

import "@nomicfoundation/hardhat-chai-matchers"



const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    goerli: {
      url: `${process.env.INFURA_GOERLI}`,
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : [],
    },
    sepolia: {
      url: `${process.env.INFURA_SEPOLIA}`,
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : [],
    },
    // hardhat: {
    //   forking: {
    //     url:`${process.env.INFURA_GOERLI}`,
    //     blockNumber: 10000 // option block number
    //   }
    // }
  },
  // etherscan: {
  //   apiKey: `${process.env.ETHERSCAN_APIKEY}`
  // }
};

export default config;