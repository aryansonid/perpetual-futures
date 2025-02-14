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
  const borrowingFee = await deployments.get("borrowing");

  await deploy("callback", {
    from: deployer,
    contract: "TradingCallbacks",
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
          borrowingFee.address,
          vault,
          0,
          50,
          50,
          3,
          {
            _vaultFeeP: 50,
            _liquidatorFeeP: 50,
            _liquidationFeeP: 5,
            _parLiquidationFeeP: 3,
            _openingFeeP: 8,
            _closingFeeP: 8,
          },
        ],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
func.tags = ["TradingCallbacksInterface"];
func.dependencies = ["Storage", "PairsStorage"];
