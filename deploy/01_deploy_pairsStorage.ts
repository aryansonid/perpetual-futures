import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  await deploy("pairsStorage", {
    from: deployer,
    contract: "GNSPairsStorageV6",
    args: [1],
    log: true,
  });
};
export default func;
func.tags = ["GNSPairsStorageV6"];
