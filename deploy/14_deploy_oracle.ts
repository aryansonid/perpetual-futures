import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer, priceSetter } = await getNamedAccounts();
  await deploy("Oracle", {
    from: deployer,
    contract: "Oracle",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "__Oracle_init",
        args: [priceSetter],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
func.tags = ["oracle"];
