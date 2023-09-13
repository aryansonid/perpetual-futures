import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();
  const Storage = await deployments.get("Storage");
  const pairsInfo = await deployments.get("pairsInfo");

  await deploy("borrowing", {
    from: deployer,
    contract: "BorrowingFees",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [Storage.address, pairsInfo.address],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
func.tags = ["BorrowingFees"];
func.dependencies = ["Storage", "pairsInfo"];
