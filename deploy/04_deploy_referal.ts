import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();
  const Storage = await deployments.get("Storage");

  await deploy("referal", {
    from: deployer,
    contract: "Referrals",
    args: [Storage.address, 25, 25, 25, 25], /// need to change these input values
    log: true,
  });
};
export default func;
func.tags = ["Referrals"];
func.dependencies = ["PairsStorage"];
