import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "hardhat";
import BigNumber from "bignumber.js";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute } = deployments;
  const { deployer, owner } = await getNamedAccounts();
  const OpenPnlFeed = await deployments.get("OpenPnlFeed");
  const Oracle = await deployments.get("Oracle");
  const vault = await deployments.get("vault");
  const trading = await deployments.get("trading");
  const callback = await deployments.get("callback");
  const PriceAggregator = await deployments.get("PriceAggregator");
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
      maxOi: ethers.toBigInt("10000000000000"),
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
      maxOi: ethers.toBigInt("10000000000000"),
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
    100
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

  console.log("setup done");
};

export default func;
func.tags = ["setup"];
func.dependencies = ["vault"];
