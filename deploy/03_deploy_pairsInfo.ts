import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();
  const Storage = await deployments.get("Storage");

  await deploy("pairsInfo", {
    from: deployer,
    contract: "PairInfos",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [Storage.address],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};
export default func;
func.tags = ["PairInfos"];
