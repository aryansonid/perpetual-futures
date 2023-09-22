import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "ethers";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer, linkPriceFeed, linkToken, tokenWETHLp, token, vault, manager, owner } =
    await getNamedAccounts();
  const WETH = await deployments.get("WETH");
  const callback = await deployments.get("callback");

  await deploy("vault", {
    from: deployer,
    contract: "Vault",
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          "vault",
          "V",
          {
            asset: WETH.address,
            owner: deployer, // 2-week timelock contract should be changed in the future
            manager: manager, // 3-week timelock contract should be changed in the future
            admin: owner,
            lockedDepositNft: "0x00000000219ab540356cbb839cbe05303d7705fa",
            pnlHandler: callback.address,
            openTradesPnlFeed: "0x00000000219ab540356cbb839cbe05303d7705fa",
          },
          25000,
          ethers.toBigInt("100000000000000000000"), // min lock duration
          ethers.toBigInt("1000000000000000000"),
          [
            ethers.toBigInt("10000000000000000000"),
            ethers.toBigInt("20000000000000000000"),
          ],
          ethers.toBigInt("10000000000000000000"),
          ethers.toBigInt("10000000000000000000"),
          ethers.toBigInt("50000000000000000"),
          ethers.toBigInt("1000000000000000000"),
          ethers.toBigInt("100000000000000000000"),
        ],
      },
      upgradeIndex: 0,
    },
    log: true,
  });
};

export default func;
func.tags = ["vault"];
func.dependencies = ["WETH", "callback"];
