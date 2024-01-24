import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer, priceSetter } = await getNamedAccounts();
  const Storage = await deployments.get("Storage");

  await deploy("Resolver", {
    from: deployer,
    contract: "Resolver",
    args: [Storage.address],
    log: true,
  });
};

export default func;
