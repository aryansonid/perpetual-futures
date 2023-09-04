import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  await deploy("MockGtoken", {
    from: deployer,
    contract: "MockGtoken",
    args : ["gtoken", "G"],
    log: true,
  });
};
export default func;
func.tags = ["MockGtoken"];
