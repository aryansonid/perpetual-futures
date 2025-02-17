import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "hardhat";
import BigNumber from "bignumber.js";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { execute } = deployments;
  const { deployer, owner, OraclePriceSetter, priceSetter } =
    await getNamedAccounts();
  const OpenPnlFeed = await deployments.get("OpenPnlFeed");
  const Oracle = await deployments.get("Oracle");
  const vault = await deployments.get("vault");
  const trading = await deployments.get("trading");
  const callback = await deployments.get("callback");
  const PriceAggregator = await deployments.get("PriceAggregator");
  const WETHContract = await deployments.get("WETH");
  const WETH = await ethers.getContractAt(
    WETHContract.abi,
    WETHContract.address,
    await ethers.getSigner(deployer)
  );

  const oracleContract = await ethers.getContractAt(
    Oracle.abi,
    Oracle.address,
    await ethers.getSigner(deployer)
  );
  const priceSetterRole = await oracleContract.PRICE_SETTER_ROLE();
  const WETHFaucet = await deployments.get("WETHFaucet");

  const minterRole = await WETH.MINTER_ROLE();

  await execute(
    "WETH",
    { from: deployer, log: true },
    "grantRole",
    minterRole,
    WETHFaucet.address
  );

  await execute(
    "Oracle",
    { from: priceSetter, log: true },
    "grantRole",
    priceSetterRole,
    OraclePriceSetter
  );

  await execute(
    "Storage",
    { from: deployer, log: true },
    "setPriceAggregator",
    PriceAggregator.address
  );

  await execute(
    "Storage",
    { from: deployer, log: true },
    "setCallbacks",
    callback.address
  );

  await execute(
    "Storage",
    { from: deployer, log: true },
    "addTradingContract",
    trading.address
  );

  await execute(
    "Storage",
    { from: deployer, log: true },
    "setTrading",
    trading.address
  );

  await execute(
    "Storage",
    { from: deployer, log: true },
    "setVault",
    vault.address
  );

  await execute(
    "Storage",
    { from: deployer, log: true },
    "addTradingContract",
    callback.address
  );

  await execute(
    "pairsInfo",
    { from: deployer, log: true },
    "setManager",
    deployer
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    0,
    {
      groupIndex: 0,
      feePerBlock: 24595,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    1,
    {
      groupIndex: 0,
      feePerBlock: 83800,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    2,
    {
      groupIndex: 0,
      feePerBlock: 79150,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    3,
    {
      groupIndex: 0,
      feePerBlock: 83800,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    4,
    {
      groupIndex: 0,
      feePerBlock: 79150,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    5,
    {
      groupIndex: 0,
      feePerBlock: 83800,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    6,
    {
      groupIndex: 0,
      feePerBlock: 79150,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    7,
    {
      groupIndex: 0,
      feePerBlock: 83800,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    8,
    {
      groupIndex: 0,
      feePerBlock: 79150,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    9,
    {
      groupIndex: 0,
      feePerBlock: 83800,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    10,
    {
      groupIndex: 0,
      feePerBlock: 79150,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    11,
    {
      groupIndex: 0,
      feePerBlock: 79150,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    12,
    {
      groupIndex: 0,
      feePerBlock: 79150,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    13,
    {
      groupIndex: 0,
      feePerBlock: 79150,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );
  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    1,
    {
      groupIndex: 0,
      feePerBlock: 83800,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  await execute(
    "borrowing",
    { from: deployer, log: true },
    "setPairParams",
    15,
    {
      groupIndex: 0,
      feePerBlock: 79150,
      feeExponent: 1,
      maxOi: ethers.toBigInt("10000000000000000000"),
    }
  );

  // await execute("pairsStorage", { from: deployer, log: true }, "addPair", {
  //   from: "0x00000000219ab540356cbb839cbe05303d7705fa",
  //   to: "0x00000000219ab540356cbb839cbe05303d7705fa",
  //   feed: {
  //     feed1: "0x00000000219ab540356cbb839cbe05303d7705fa",
  //     feed2: "0x00000000219ab540356cbb839cbe05303d7705fa",
  //     feedCalculation: 1,
  //     maxDeviationP: 10,
  //   },
  //   spreadP: 0,
  //   groupIndex: 0,
  //   feeIndex: 0,
  // });

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    0,
    20
  );

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    1,
    20
  );

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    2,
    20
  );
  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    3,
    20
  );

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    4,
    20
  );

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    5,
    20
  );
  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    6,
    20
  );

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    7,
    20
  );

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    8,
    20
  );
  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    9,
    20
  );

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    10,
    20
  );

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    11,
    20
  );

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    12,
    20
  );
  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    13,
    20
  );
  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    14,
    20
  );
  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    15,
    20
  );

  await execute(
    "vault",
    { from: deployer, log: true },
    "updateOpenTradesPnlFeed",
    OpenPnlFeed.address
  );

  await execute(
    "Storage",
    { from: deployer, log: true },
    "setOracle",
    Oracle.address
  );

  await execute("callback", { from: deployer, log: true }, "giveApproval");

  for (let i = 0; i < activeCollections.length; i++) {
    console.log(
      getFundingFee(
        activeCollections[i].delta,
        activeCollections[i].closingPrice
      ) > 10000000,
      getFundingFee(
        activeCollections[i].delta,
        activeCollections[i].closingPrice
      )
    );
    await execute(
      "Oracle",
      { from: priceSetter, log: true },
      "setFundingFee",
      activeCollections[i].index,
      ethers.toBigInt(
        `${getFundingFee(
          activeCollections[i].delta,
          activeCollections[i].closingPrice
        )}`
      )
    );

    await execute(
      "pairsInfo",
      { from: priceSetter, log: true },
      "setFundingFeePerBlockP",
      activeCollections[i].index
    );
  }

  await execute(
    "trading",
    { from: deployer, log: true },
    "setMinLeveragedPosWETH",
    ethers.toBigInt("10000000000000000000")
  );

  console.log("setup done");
};

export function getFundingFee(atr: number, closingPrice: number) {
  return Math.floor(
    (Math.pow(
      Number(
        new BigNumber(atr)
          .dividedBy(new BigNumber(closingPrice))
          .multipliedBy(new BigNumber(100))
      ),
      1.25
    ) *
      52 *
      1e10) /
      60 /
      2102400
  );
}

interface ICollections {
  index: number;
  closingPrice: number;
  delta: number;
}

const activeCollections: Array<ICollections> = [
  {
    index: 1,
    closingPrice: 2.985,
    delta: 0.2,
  },
  {
    index: 2,
    closingPrice: 0.345,
    delta: 0.04,
  },
  {
    index: 3,
    closingPrice: 55.69,
    delta: 1,
  },
  {
    index: 4,
    closingPrice: 29,
    delta: 0.5,
  },
  {
    index: 5,
    closingPrice: 5.66,
    delta: 0.3,
  },
  {
    index: 6,
    closingPrice: 10.9,
    delta: 0.1,
  },
  {
    index: 7,
    closingPrice: 4.85,
    delta: 0.4,
  },
  {
    index: 8,
    closingPrice: 6.6,
    delta: 0.5,
  },
  {
    index: 9,
    closingPrice: 1.9,
    delta: 0.1,
  },
  {
    index: 10,
    closingPrice: 0.62,
    delta: 0.05,
  },
  {
    index: 11,
    closingPrice: 0.43,
    delta: 0.04,
  },
  {
    index: 12,
    closingPrice: 3.1346,
    delta: 0.3,
  },
  {
    index: 13,
    closingPrice: 0.52,
    delta: 0.05,
  },
  {
    index: 14,
    closingPrice: 0.1299,
    delta: 0.01,
  },
  {
    index: 15,
    closingPrice: 0.57,
    delta: 0.05,
  },
];

export default func;
func.tags = ["setup"];
// func.dependencies = ["vault"];
