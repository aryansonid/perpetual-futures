import { expect } from "chai";
import { deployments, ethers, getNamedAccounts } from "hardhat";
import { Signer } from "ethers";
import { mine } from "@nomicfoundation/hardhat-network-helpers";

export async function getContract(name: string, signer?: Signer) {
  const c = await deployments.get(name);
  return await ethers.getContractAt(c.abi, c.address, signer);
}

function getDelta(
  blockNumAfter: number,
  blockNumBefore: number,
  feeExponent: number,
  pairOpeningInterest: number, // short -long oi for pair or vice versa
  maxOi: number
) {
  return (
    (blockNumAfter - blockNumBefore) *
    feeExponent *
    ((pairOpeningInterest * 10000000000) / maxOi / 100000000000000000)
  );
}

function getTradingFee(delta: number, collateral: number, leverage: number) {
  return (collateral * leverage * delta) / 10000000000 / 100;
}

function getWethToBeSentToTrader(
  currentPrice: number,
  openPrice: number,
  leverage: number,
  long: boolean,
  posWETH: number
) {
  let profitP =
    ((long ? currentPrice - openPrice : openPrice - currentPrice) *
      100 *
      10000000000 *
      leverage) /
    openPrice;

  const maxPnl = 9000000000000;

  profitP = profitP > maxPnl ? maxPnl : profitP;
  return posWETH * (1 + profitP / 100 / 10000000000);
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

  const borrowing = await getContract(
    "borrowing",
    await ethers.getSigner(deployer)
  );

  const vault = await getContract("vault", await ethers.getSigner(deployer));
  const pairParamsOnBorrowing = {
    groupIndex: 0,
    feePerBlock: 10,
    feeExponent: 1,
    maxOi: ethers.toBigInt("10000000000000"),
  };
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
    borrowing,
    pairParamsOnBorrowing,
    vault,
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
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: 0,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: ethers.toBigInt("10000000000000000000"),
        openPrice: ethers.toBigInt("10000000000000000000"),
        buy: true,
        leverage: 10,
        tp: ethers.toBigInt("12000000000000000000"),
        sl: ethers.toBigInt("8000000000000000000"),
      },
      0,
      0,
      3000000000
    );
  });
  it("call back open trade ", async function () {
    const {
      storage,
      trading,
      pairInfo,
      aggregator,
      pairsStorage,
      WETH,
      trader,
    } = await setupTest();
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: 0,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: ethers.toBigInt("10000000000000000000"),
        openPrice: ethers.toBigInt("10000000000000000000"),
        buy: true,
        leverage: 10,
        tp: ethers.toBigInt("12000000000000000000"),
        sl: ethers.toBigInt("8000000000000000000"),
      },
      0,
      0,
      3000000000
    );
    await aggregator.Mfulfill(1, 10);
  });

  it("borrowing fee", async function () {
    const {
      storage,
      trading,
      pairInfo,
      aggregator,
      pairsStorage,
      WETH,
      trader,
      borrowing,
      pairParamsOnBorrowing,
    } = await setupTest();
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );
    const blockNumBefore = await ethers.provider.getBlockNumber();

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: 0,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: ethers.toBigInt("10000000000000000000"),
        openPrice: ethers.toBigInt("10000000000000000000"),
        buy: true,
        leverage: 10,
        tp: ethers.toBigInt("12000000000000000000"),
        sl: ethers.toBigInt("8000000000000000000"),
      },
      0,
      0,
      3000000000
    );
    await aggregator.Mfulfill(1, ethers.toBigInt("10000000000000000000"));
    await mine(1000);
    const tradePairOpeningInterest = await borrowing.getPairOpenInterestWETH(0);

    const blockNumAfter = await ethers.provider.getBlockNumber();

    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 0);

    await aggregator.Mfulfill(2, ethers.toBigInt("11000000000000000000"));

    let delta =
      (blockNumAfter - blockNumBefore) *
      Number(pairParamsOnBorrowing.feeExponent) *
      ((Number(tradePairOpeningInterest[0]) * 10000000000) /
        Number(pairParamsOnBorrowing.maxOi) /
        100000000000000000);

    delta = getDelta(
      blockNumAfter,
      blockNumBefore,
      Number(pairParamsOnBorrowing.feeExponent),
      Number(tradePairOpeningInterest[0]) - Number(tradePairOpeningInterest[1]),
      Number(pairParamsOnBorrowing.maxOi)
    );

    const tradingFee = getTradingFee(delta, 10000000000000000000, 10);

    const amount = getWethToBeSentToTrader(
      11000000000000000000,
      10000000000000000000,
      10,
      true,
      10000000000000000000
    );

    const balanceOfTrader = await WETH.balanceOf(trader);

    expect(Number(balanceOfTrader)).to.be.equal(amount - tradingFee);
  });
  it("call back close trade multiple trade", async function () {
    const {
      storage,
      trading,
      pairInfo,
      aggregator,
      pairsStorage,
      WETH,
      trader,
    } = await setupTest();
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: 0,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: ethers.toBigInt("10000000000000000000"),
        openPrice: ethers.toBigInt("10000000000000000000"),
        buy: true,
        leverage: 10,
        tp: ethers.toBigInt("12000000000000000000"),
        sl: ethers.toBigInt("8000000000000000000"),
      },
      0,
      0,
      3000000000
    );
    await aggregator.Mfulfill(1, ethers.toBigInt("10000000000000000000"));

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: 0,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: ethers.toBigInt("10000000000000000000"),
        openPrice: ethers.toBigInt("10000000000000000000"),
        buy: true,
        leverage: 10,
        tp: ethers.toBigInt("12000000000000000000"),
        sl: ethers.toBigInt("8000000000000000000"),
      },
      0,
      0,
      3000000000
    );

    await aggregator.Mfulfill(2, ethers.toBigInt("10000000000000000000"));
    await mine(1000);
    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 0);

    await aggregator.Mfulfill(3, ethers.toBigInt("10000000000000000000"));

    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 1);

    await aggregator.Mfulfill(4, 10);
  });
  it("deposit and withdraw", async function () {
    const {
      storage,
      trading,
      pairInfo,
      aggregator,
      pairsStorage,
      WETH,
      trader,
      vault,
      deployer,
    } = await setupTest();
    await WETH.mint(deployer, ethers.toBigInt("10000000000000000000000"));
    await WETH.connect(await ethers.getSigner(deployer)).approve(
      vault.target,
      ethers.toBigInt("10000000000000000000000")
    );
    const tnx = await vault
      .connect(await ethers.getSigner(deployer))
      .deposit(ethers.toBigInt("10000000000000000000000"), deployer);
    await tnx.wait();

    await vault
      .connect(await ethers.getSigner(deployer))
      .makeWithdrawRequest(
        ethers.toBigInt("10000000000000000000000"),
        deployer
      );

    await vault.updateEpoch(4);
    await vault
      .connect(await ethers.getSigner(deployer))
      .withdraw(ethers.toBigInt("9999999999999999999999"), deployer, deployer);
  });
});
