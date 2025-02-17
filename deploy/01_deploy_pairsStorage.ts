import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const Storage = await deployments.get("Storage");

  const { deployer } = await getNamedAccounts();

  await deploy("pairsStorage", {
    from: deployer,
    contract: "PairsStorage",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [1, Storage.address],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};
export default func;
func.tags = ["PairsStorage"];
