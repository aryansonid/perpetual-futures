import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  await deploy("WETH", {
    from: deployer,
    contract: "WETH",
    log: true,
  });
};
export default func;
func.tags = ["WETH"];
