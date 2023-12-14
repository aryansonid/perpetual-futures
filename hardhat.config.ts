import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.23",
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
        version: "0.8.10",
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
      sepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      arbSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    govFund: {
      default: 1,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      sepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      arbSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },

    linkPriceFeed: {
      default: 2,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      sepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      arbSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    linkToken: {
      default: 3,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      sepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      arbSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    tokenWETHLp: {
      default: 4,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      sepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      arbSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    vault: 6,
    trader: {
      default: 7,
      polygon: "0x95C30fb60380175059781d3a730757d254b4485B",
      sepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
      arbSepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
    },
    manager: {
      default: 8,
      polygon: "0x95C30fb60380175059781d3a730757d254b4485B",
      sepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
      arbSepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
    },
    owner: {
      default: 9,
      polygon: "0x9Ced9c76935922089cA1b06a5Eb6D29cA6057Bd1",
      sepolia: "0x9Ced9c76935922089cA1b06a5Eb6D29cA6057Bd1",
      arbSepolia: "0x9Ced9c76935922089cA1b06a5Eb6D29cA6057Bd1",
    },
    priceSetter: {
      default: 10,
      polygon: "0x9Ced9c76935922089cA1b06a5Eb6D29cA6057Bd1",
      sepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
      arbSepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
    },
    feeder: {
      default: 10,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      sepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      arbSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    OraclePriceSetter: {
      default: 11,
      polygon: "0xAa6fA167EdF3012B9e578551bff3242FeE0D00Dd",
      sepolia: "0xAa6fA167EdF3012B9e578551bff3242FeE0D00Dd",
      arbSepolia: "0xAa6fA167EdF3012B9e578551bff3242FeE0D00Dd",
    },
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
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/_wfmnKDlLJth_6N1H0eH4w_uM9ZAfGWO",

      saveDeployments: true,
      accounts: {
        mnemonic:
          "flee slice employ stone audit diary extra elite fiscal mango human curve",
      },
    },
    arbSepolia: {
      url: "https://arb-sepolia.g.alchemy.com/v2/wdB9kBfwbGxtQ2tusOXKe3xvz9BQ5MZV",
      chainId: 421614,
      saveDeployments: true,
      accounts: {
        mnemonic:
          "flee slice employ stone audit diary extra elite fiscal mango human curve",
      },
      verify: {
        etherscan: {
          apiUrl: "https://api-sepolia.arbiscan.io",
          apiKey: "J251F5AR74JKFJC6UHFUVUZ9CB95GYHA5M",
        },
      },
    },
  },
  verify: {
    etherscan: {
      apiKey: "J251F5AR74JKFJC6UHFUVUZ9CB95GYHA5M",
    },
  },
  etherscan: {
    apiKey: {
      arbSepolia: "J251F5AR74JKFJC6UHFUVUZ9CB95GYHA5M",
    },
    customChains: [
      {
        network: "arbSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/api",
        },
      },
    ],
  },
};

export default config;
