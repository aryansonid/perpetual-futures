import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer, govFund } = await getNamedAccounts();
  const weth = await deployments.get("WETH");
  const token = await deployments.get("MockGtoken");

  const nft = [
    "0x00000000219ab540356cbb839cbe05303d7705fa",
    "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8",
    "0xda9dfa130df4de4673b89022ee50ff26f6ea73cf",
    "0x40b38765696e3d5d8d9d834d8aad4bb6e418e489",
  ];

  const boostSp = [1, 2, 3, 4, 5];

  await deploy("Staking", {
    from: deployer,
    contract: "Staking",
    args: [govFund, token.address, weth.address, nft, boostSp, 25], /// need to change these input values
    log: true,
  });
};
export default func;
func.tags = ["Staking"];
func.dependencies = ["WETH"];
