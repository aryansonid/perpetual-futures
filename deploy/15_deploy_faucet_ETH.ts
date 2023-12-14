import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("ETHFaucet", {
    from: deployer,
    contract: "ETHFaucet",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "Faucet_init",
        args: [deployer, ethers.toBigInt("50000000000000000"), 60*60*24],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
