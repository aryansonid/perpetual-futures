import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();
  const WETH = await deployments.get("WETH");

  const tnx = await deploy("Storage", {
    from: deployer,
    contract: "Storage",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [WETH.address, deployer, deployer],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};
export default func;
func.tags = ["Storage"];
