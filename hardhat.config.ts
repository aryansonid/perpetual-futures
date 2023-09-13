import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import "@nomicfoundation/hardhat-verify"


const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 125,
          },
        },
      },
      {
        version: "0.8.15",
        settings: {
          optimizer: {
            enabled: true,
            runs: 125,
          },
        },
      },
      {
        version: "0.8.14",
        settings: {
          optimizer: {
            enabled: true,
            runs: 125,
          },
        },
      },
      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 125,
          },
        },
      },
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 125,
          },
        },
      },
      {
        version: "0.4.18",
      },
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    govFund: {
      default: 1,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },

    linkPriceFeed: {
      default: 2,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    linkToken: {
      default: 3,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    tokenWETHLp: {
      default: 4,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    vault: 6,
    trader: 7,
  },

  networks: {
    polygon: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/YUr-WPShQCwt4SehN0n1XPfhnNgQyo5g",

      saveDeployments: true,
      accounts: {
        mnemonic:
          "flee slice employ stone audit diary extra elite fiscal mango human curve",
      },
    },
  },
  etherscan: {
    apiKey: "IE5ATP8BJBRRKYA2BDXYNWXVYWI7YAISH3",
  },
};

export default config;
