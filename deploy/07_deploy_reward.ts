import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();
  const Storage = await deployments.get("Storage");

  await deploy("reward", {
    from: deployer,
    contract: "Rewards",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [Storage.address, 5, 5],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
func.tags = ["Rewards"];
func.dependencies = ["Storage"];
