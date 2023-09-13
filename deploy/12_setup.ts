import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getContract } from "../test/test";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const Storage = await deployments.get("Storage");
  const referal = await deployments.get("referal");
  const pairsStorage = await deployments.get("pairsStorage");
  const trading = await deployments.get("trading");
  const callback = await deployments.get("callback");
  const PriceAggregator = await deployments.get("PriceAggregator");
  const borrowing = await getContract("borrowing");
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
    "addTradingContract",
    callback.address
  );

  await execute(
    "pairsInfo",
    { from: deployer, log: true },
    "setManager",
    deployer
  );

  await borrowing.setPairParams(0, {
    groupIndex: 0,
    feePerBlock: 100000000,
    feeExponent: 1,
    maxOi: 10000,
  });

  await execute("pairsStorage", { from: deployer, log: true }, "addPair", {
    from: "0x00000000219ab540356cbb839cbe05303d7705fa",
    to: "0x00000000219ab540356cbb839cbe05303d7705fa",
    feed: {
      feed1: "0x00000000219ab540356cbb839cbe05303d7705fa",
      feed2: "0x00000000219ab540356cbb839cbe05303d7705fa",
      feedCalculation: 1,
      maxDeviationP: 10,
    },
    spreadP: 0,
    groupIndex: 0,
    feeIndex: 0,
  });

  await execute(
    "callback",
    { from: deployer, log: true },
    "setPairMaxLeverage",
    0,
    100
  );
};

export default func;
func.tags = ["setup"];
