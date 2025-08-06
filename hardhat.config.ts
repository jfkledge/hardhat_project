import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@openzeppelin/hardhat-upgrades';
import 'hardhat-deploy';
import 'hardhat-contract-sizer';

const config: HardhatUserConfig = {
  solidity: '0.8.28',
  typechain: {
    outDir: 'typechain-types',
    target: 'ethers-v6',
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true, // 编译时自动打印
    strict: true,
  },
  networks: {
    localhost: {
      url: 'http://127.0.0.1:8545',
    },
    goerli: {
      url: process.env.GOERLI_RPC_URL || '',
      accounts: process.env.GOERLI_DEPLOYER_PRIVATE_KEY
        ? [process.env.GOERLI_DEPLOYER_PRIVATE_KEY]
        : [],
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL || '',
      accounts: process.env.MAINNET_DEPLOYER_PRIVATE_KEY
        ? [process.env.MAINNET_DEPLOYER_PRIVATE_KEY]
        : [],
    },
  },
  namedAccounts: {
    deployer: {
      default: 1,
    },
    admin: {
      default: 2,
    },
  },
};

export default config;
