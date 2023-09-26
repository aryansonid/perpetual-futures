import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "ethers";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const {
    deployer,
    linkPriceFeed,
    linkToken,
    tokenWETHLp,
    token,
    manager,
    owner,
  } = await getNamedAccounts();
  const vault = await deployments.get("vault");
  const callback = await deployments.get("callback");

  const oracles = [
    "0x00000000219ab540356cbb839cbe05303d7705fa",
    "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8",
    "0xda9dfa130df4de4673b89022ee50ff26f6ea73cf",
    "0x40b38765696e3d5d8d9d834d8aad4bb6e418e489",
    "0x40b38765696e3d5d8d9d834d8aad4bb6e418e489",
  ];

  await deploy("OpenPnlFeed", {
    from: deployer,
    contract: "OpenPnlFeed",
    args: [
      1,
      linkToken,
      vault.address,
      oracles,
      "0x0000000000000000000000000000000000000000000000000000000000000004",
      3,
    ],
    log: true,
  });
};

export default func;
func.tags = ["vault"];
func.dependencies = ["WETH", "callback"];
