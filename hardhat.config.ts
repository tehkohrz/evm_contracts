import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.18', // version paris
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: 'carbon_local',
  networks: {
    hardhat: {},
    carbon_local: {
      url: 'http://localhost:8545',
      accounts: ['12be317113f202f769ae705d75c37f2e9ee7d810e93f2796e44e064a082331b2'],
      blockGasLimit: 100000000,
    },
  },
};

export default config;
