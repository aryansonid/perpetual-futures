import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Storage = await deployments.get("Storage");
  const referal = await deployments.get("referal");
  const pairsInfo = await deployments.get("pairsInfo");
  const borrowing = await deployments.get("borrowing");
  const reward = await deployments.get("reward");
  const callback = await deployments.get("callback");
  const PackingUtils = await deploy("PackingUtils", {
    from: deployer,
    contract: "PackingUtils",
    log: true,
  });

  const TradeUtils = await deploy("TradeUtils", {
    from: deployer,
    contract: "TradeUtils",
    log: true,
  });
  const trading = await deploy("trading", {
    from: deployer,
    contract: "Trading",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          Storage.address,
          reward.address,
          pairsInfo.address,
          referal.address,
          borrowing.address,
          callback.address,
          ethers.toBigInt("1500000000000000000000"),
          2,
          ethers.toBigInt("10000000000000000000"),
        ],
      },
      upgradeIndex: 0,
    },
    libraries: {
      TradeUtils: TradeUtils.address,
      PackingUtils: PackingUtils.address,
    },

    log: true,
  });

  const networkName = hre.network.name;
};

export default func;
func.tags = ["Trading"];
