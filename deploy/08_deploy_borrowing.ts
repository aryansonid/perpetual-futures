import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();
  const Storage = await deployments.get("Storage");
  const pairsStorage = await deployments.get("pairsStorage");

  await deploy("borrowing", {
    from: deployer,
    contract: "GNSBorrowingFeesV6_4",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [Storage.address, pairsStorage.address],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
func.tags = ["GNSBorrowingFeesV6_4"];
func.dependencies = ["GFarmTradingStorageV5", "GNSPairsStorageV6"];
