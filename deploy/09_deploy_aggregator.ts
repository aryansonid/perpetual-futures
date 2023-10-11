import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer, linkPriceFeed, linkToken, tokenWETHLp } =
    await getNamedAccounts();
  const Storage = await deployments.get("Storage");
  const pairsStorage = await deployments.get("pairsStorage");
  const token = await deployments.get("MockGtoken");

  const nodes = [
    "0x00000000219ab540356cbb839cbe05303d7705fa",
    "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8",
    "0xda9dfa130df4de4673b89022ee50ff26f6ea73cf",
  ];

  const jobIds = [
    "0x0000000000000000000000000000000000000000000000000000000000000004",
    "0x0000000000000000000000000000000000000000000000000000000000000001",
  ];

  const PackingUtils = await deploy("PackingUtils", {
    from: deployer,
    contract: "PackingUtils",
    log: true,
  });

  const lpPool = await deploy("lpPool", {
    from: deployer,
    contract: "MockLiqPool",
    args: [token.address],
    log: true,
  });

  const PriceAggregator = await deploy("PriceAggregator", {
    from: deployer,
    contract: "PriceAggregator",
    args: [
      linkToken,
      lpPool.address,
      1900,
      Storage.address,
      pairsStorage.address,
      linkPriceFeed,
      3,
      nodes,
      jobIds,
    ],
    libraries: { PackingUtils: PackingUtils.address },
    log: true,
  });
  const networkName = hre.network.name;

  if (networkName != "hardhat") {
    await hre.run("verify:verify", {
      address: PriceAggregator.address,
      constructorArguments: [
        linkToken,
        lpPool.address,
        1900,
        Storage.address,
        pairsStorage.address,
        linkPriceFeed,
        3,
        nodes,
        jobIds,
      ],
      // libraries: { PackingUtils: PackingUtils.address },
    });
  }
};

export default func;
func.tags = ["PriceAggregator"];
func.dependencies = ["Storage", "PairsStorage"];
