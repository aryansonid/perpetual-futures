import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer, linkPriceFeed, linkToken, tokenWETHLp, token, vault } =
    await getNamedAccounts();
  const Storage = await deployments.get("Storage");
  const referal = await deployments.get("referal");
  const pairsInfo = await deployments.get("pairsInfo");
  const staking = await deployments.get("Staking");
  const reward = await deployments.get("reward");


  await deploy("callback", {
    from: deployer,
    contract: "GNSTradingCallbacksV6_4",
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
          staking.address,
          vault,
          0,
          50,
          50,
          3,
        ],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
func.tags = ["GNSTradingCallbacksV6_4"];
func.dependencies = ["GFarmTradingStorageV5", "GNSPairsStorageV6"];
