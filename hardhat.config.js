require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");

const {
  INFURA_KEY, 
  MNEMONIC,
  ETHERSCAN_API_KEY
  } = process.env;


// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      { 
        version: "0.8.9", 
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },
  networks: {
    hardhat: {
      forking: {
        url: `https://mainnet.infura.io/v3/${INFURA_KEY}`,
      },
      allowUnlimitedContractSize: false,
      timeout: 99999999,
      blockGasLimit: 100_000_000,
      gas: 100_000_000,
      gasMultiplier: 1,
      gasPrice: 500_000_000_000, // 500 gwei
      accounts: {mnemonic: MNEMONIC}
    },
    ropsten: {
      url : `https://ropsten.infura.io/v3/${INFURA_KEY}`,
      accounts : process.env.PRIVATE_KEY
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
