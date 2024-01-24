import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const WETH = await deployments.get("WETH");

  await deploy("WETHFaucet", {
    from: deployer,
    contract: "WETHFaucet",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "Faucet_init",
        args: [
          deployer,
          WETH.address,
          ethers.toBigInt("100000000000000000000"),
        ],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};
func.tags = ["WETHFaucet"];

export default func;
