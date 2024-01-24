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
      optimismSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseGoerli: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    govFund: {
      default: 1,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      optimismSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseGoerli: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },

    linkPriceFeed: {
      default: 2,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      optimismSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseGoerli: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    linkToken: {
      default: 3,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      optimismSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseGoerli: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    tokenWETHLp: {
      default: 4,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      optimismSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseGoerli: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    vault: 6,
    trader: {
      default: 7,
      polygon: "0x95C30fb60380175059781d3a730757d254b4485B",
      optimismSepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
      baseSepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
      baseGoerli: "0x95C30fb60380175059781d3a730757d254b4485B",
    },
    manager: {
      default: 8,
      polygon: "0x95C30fb60380175059781d3a730757d254b4485B",
      optimismSepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
      baseSepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
      baseGoerli: "0x95C30fb60380175059781d3a730757d254b4485B",
    },
    owner: {
      default: 9,
      polygon: "0x9Ced9c76935922089cA1b06a5Eb6D29cA6057Bd1",
      optimismSepolia: "0x9Ced9c76935922089cA1b06a5Eb6D29cA6057Bd1",
      baseSepolia: "0x9Ced9c76935922089cA1b06a5Eb6D29cA6057Bd1",
      baseGoerli: "0x9Ced9c76935922089cA1b06a5Eb6D29cA6057Bd1",
    },
    priceSetter: {
      default: 10,
      polygon: "0x9Ced9c76935922089cA1b06a5Eb6D29cA6057Bd1",
      optimismSepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
      baseSepolia: "0x95C30fb60380175059781d3a730757d254b4485B",
      baseGoerli: "0x95C30fb60380175059781d3a730757d254b4485B",
    },
    feeder: {
      default: 10,
      polygon: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      optimismSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseSepolia: "0xa667403454F483dE81A0363Af7FcEE563819D910",
      baseGoerli: "0xa667403454F483dE81A0363Af7FcEE563819D910",
    },
    OraclePriceSetter: {
      default: 11,
      polygon: "0xAa6fA167EdF3012B9e578551bff3242FeE0D00Dd",
      optimismSepolia: "0xAa6fA167EdF3012B9e578551bff3242FeE0D00Dd",
      baseSepolia: "0xAa6fA167EdF3012B9e578551bff3242FeE0D00Dd",
      baseGoerli: "0xAa6fA167EdF3012B9e578551bff3242FeE0D00Dd",
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
    optimismSepolia: {
      url: "https://opt-sepolia.g.alchemy.com/v2/TCOOFkyrcfYvAH9af2L7Gtn-lWDOEV3A",

      saveDeployments: true,
      chainId: 11155420,
      accounts: {
        mnemonic:
          "flee slice employ stone audit diary extra elite fiscal mango human curve",
      },
      verify: {
        etherscan: {
          apiUrl: "https://api-sepolia-optimistic.etherscan.io",
          apiKey: "X75F51KMUNMRWUGPNJ8BWK6MCJBIAI6H5T",
        },
      },
    },
    baseSepolia: {
      url: "https://base-sepolia.g.alchemy.com/v2/wmMCUA6ExlGC3Y4heEUCZK_k6F5rbTHO",
      saveDeployments: true,
      chainId: 84532,
      accounts: {
        mnemonic:
          "flee slice employ stone audit diary extra elite fiscal mango human curve",
      },
      verify: {
        etherscan: {
          apiUrl: "https://api-sepolia.basescan.org",
          apiKey: "YTUDP7IUZPDJ4ZEX7CX6VGXVGYKG8QS5ZI",
        },
      },
    },
    baseGoerli: {
      url: "https://base-goerli.g.alchemy.com/v2/x2Xl3-lEX20p17U8Ri65dRxR_aQjEJmc",
      saveDeployments: true,
      chainId: 84531,
      accounts: {
        mnemonic:
          "flee slice employ stone audit diary extra elite fiscal mango human curve",
      },
      verify: {
        etherscan: {
          apiUrl: "https://api-goerli.basescan.org",
          apiKey: "YTUDP7IUZPDJ4ZEX7CX6VGXVGYKG8QS5ZI",
        },
      },
    },
  },
  etherscan: {
    apiKey: {
      baseSepolia: "YTUDP7IUZPDJ4ZEX7CX6VGXVGYKG8QS5ZI",
      optimismSepolia: "X75F51KMUNMRWUGPNJ8BWK6MCJBIAI6H5T",
      baseGoerli: "X75F51KMUNMRWUGPNJ8BWK6MCJBIAI6H5T",
    },
    customChains: [
      {
        network: "optimismSepolia",
        chainId: 11155420,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io/api",
        },
      },
      {
        network: "baseGoerli",
        chainId: 84531,
        urls: {
          apiURL: "https://api-goerli.basescan.org/api",
          browserURL: "https://api-goerli.basescan.org/api",
        },
      },
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://api-sepolia.basescan.org/api",
        },
      },
    ],
  },
};

export default config;
