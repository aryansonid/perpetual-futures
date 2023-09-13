import { expect } from "chai";
import { deployments, ethers, getNamedAccounts } from "hardhat";
import { Signer } from "ethers";

export async function getContract(name: string, signer?: Signer) {
  const c = await deployments.get(name);
  return await ethers.getContractAt(c.abi, c.address, signer);
}

const setupTest = deployments.createFixture(async (hre) => {
  const { deployer, trader } = await getNamedAccounts();
  await deployments.fixture();
  const storage = await getContract(
    "Storage",
    await ethers.getSigner(deployer)
  );
  const aggregator = await getContract(
    "PriceAggregator",
    await ethers.getSigner(deployer)
  );

  await storage.setPriceAggregator(aggregator.target);

  const pairInfo = await getContract(
    "pairsInfo",
    await ethers.getSigner(deployer)
  );

  const trading = await getContract(
    "trading",
    await ethers.getSigner(deployer)
  );

  const pairsStorage = await getContract(
    "pairsStorage",
    await ethers.getSigner(deployer)
  );

  const callback = await getContract(
    "callback",
    await ethers.getSigner(deployer)
  );
  const WETH = await getContract("WETH", await ethers.getSigner(deployer));

  return {
    storage,
    trading,
    pairInfo,
    aggregator,
    pairsStorage,
    WETH,
    trader,
    deployer,
  };
});

describe("test", function () {
  it("trade", async function () {
    const {
      storage,
      trading,
      pairInfo,
      aggregator,
      pairsStorage,
      WETH,
      trader,
    } = await setupTest();
    await WETH.mint(trader, 100);

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      100000
    );

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: 0,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: 10,
        openPrice: 10,
        buy: true,
        leverage: 10,
        tp: 11,
        sl: 9,
      },
      0,
      0,
      3000000000
    );
  });
  it("call back open trade", async function () {
    const {
      storage,
      trading,
      pairInfo,
      aggregator,
      pairsStorage,
      WETH,
      trader,
    } = await setupTest();
    await WETH.mint(trader, 100);

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      100000
    );

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: 0,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: 10,
        openPrice: 10,
        buy: true,
        leverage: 10,
        tp: 12,
        sl: 8,
      },
      0,
      0,
      3000000000
    );
    await aggregator.Mfulfill(1, 10);
  });

  it("call back close trade", async function () {
    const {
      storage,
      trading,
      pairInfo,
      aggregator,
      pairsStorage,
      WETH,
      trader,
    } = await setupTest();
    await WETH.mint(trader, 100);

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      100000
    );

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: 0,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: 10,
        openPrice: 10,
        buy: true,
        leverage: 10,
        tp: 12,
        sl: 8,
      },
      0,
      0,
      3000000000
    );
    await aggregator.Mfulfill(1, 10);

    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 0);

    await aggregator.Mfulfill(2, 11);
  });
});
