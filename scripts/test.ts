import BigNumber from "bignumber.js";
import hre from "hardhat";
const { deployments, getNamedAccounts, ethers } = hre;

(async () => {
  console.log("in the script");
  const { deployer, trader, priceSetter } = await getNamedAccounts();
  const WETH = await getContract("WETH", await ethers.getSigner(deployer));
  const storage = await getContract(
    "Storage",
    await ethers.getSigner(deployer)
  );
  const trading = await getContract(
    "trading",
    await ethers.getSigner(deployer)
  );

  const oracle = await getContract(
    "Oracle",
    await ethers.getSigner(priceSetter)
  );
  let tnx;

  const vault = await getContract("vault", await ethers.getSigner(deployer));

  // tnx = await oracle.feedPriceArray(
  //   [0, 1],
  //   [
  //     ethers.toBigInt("900000000000000000"),
  //     ethers.toBigInt("900000000000000000"),
  //   ]
  // );

  // await tnx.wait();

  // tnx = await oracle.getPrice(0);

  // console.log(tnx);

  // tnx = await WETH.mint(trader, ethers.toBigInt("100000000000000000000000"));
  // await tnx.wait();

  // tnx = await WETH.connect(await ethers.getSigner(trader)).approve(
  //   storage.target,
  //   ethers.toBigInt("100000000000000000000000")
  // );
  // await tnx.wait();

  // // Trade parameters
  // const pairIndex = 1;
  // const positionSizeWETH = ethers.toBigInt("1000000000000000000000");
  // const openPrice = ethers.toBigInt("10000000000000000000");
  // const buy = true;
  // const leverage = 10;
  // const tp = ethers.toBigInt("12000000000000000000");
  // //                          10000000000000000000
  // const sl = 0;

  // for (let i = 0; i < 3; i++) {
  //   tnx = await trading.connect(await ethers.getSigner(trader)).openTrade(
  //     {
  //       trader: trader,
  //       pairIndex: pairIndex,
  //       index: 0,
  //       initialPosToken: 0,
  //       positionSizeWETH: positionSizeWETH,
  //       openPrice: openPrice,
  //       buy: buy,
  //       leverage: leverage,
  //       tp: tp,
  //       sl: sl,
  //     },
  //     0,
  //     0,
  //     3000000000
  //   );
  //   await tnx.wait();
  // }

  tnx = await WETH.mint(deployer, ethers.toBigInt("10000000000000000000000"));
  await tnx.wait();
  tnx = await WETH.connect(await ethers.getSigner(deployer)).approve(
    vault.target,
    ethers.toBigInt("10000000000000000000000")
  );
  await tnx.wait();

  tnx = await vault
    .connect(await ethers.getSigner(deployer))
    .deposit(ethers.toBigInt("10000000000000000000000"), deployer);
  await tnx.wait();
})();

export async function getContract(name: string, signer?: Signer) {
  const c = await deployments.get(name);
  return await ethers.getContractAt(c.abi, c.address, signer);
}

//125437823264000000
//124023884144000000
//500000000000000000
//100
//6201194207200000000
