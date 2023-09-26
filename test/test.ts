import { expect } from "chai";
import { ethers } from "hardhat";
import { mine, time } from "@nomicfoundation/hardhat-network-helpers";
import { BigNumber } from "bignumber.js";
import {
  setupTest,
  getDelta,
  getTradingFee,
  getWethToBeSentToTrader,
} from "./fixture";

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

    /// minting WETH for the trader to trade and approving the storage contract.
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000000"));
    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );

    // Trade parameters
    const pairIndex = 0;
    const positionSizeWETH = ethers.toBigInt("10000000000000000000");
    const openPrice = ethers.toBigInt("10000000000000000000");
    const buy = true;
    const leverage = 10;
    const tp = ethers.toBigInt("12000000000000000000");
    const sl = ethers.toBigInt("8000000000000000000");

    //
    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex,
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
      oracle,
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
    await oracle.feedPrice(0, ethers.toBigInt("10000000000000000000"));
    await aggregator.Mfulfill(1);
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
      vault,
      deployer,
      oracle,
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
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );

    await oracle.feedPrice(0, ethers.toBigInt("10000000000000000000"));

    const openPrice = await oracle.getTWAP(0);

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
    const blockNumBefore = await ethers.provider.getBlockNumber();
    await aggregator.Mfulfill(1);
    await mine(1000);
    const tradePairOpeningInterest = await borrowing.getPairOpenInterestWETH(0);

    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 0);

    await oracle.feedPrice(0, ethers.toBigInt("12000000000000000000"));
    const closingPrice = await oracle.getTWAP(0);

    const blockNumAfter = await ethers.provider.getBlockNumber();

    await aggregator.Mfulfill(2);

    let delta = getDelta(
      blockNumAfter,
      blockNumBefore,
      Number(pairParamsOnBorrowing.feeExponent),
      Number(tradePairOpeningInterest[0]) - Number(tradePairOpeningInterest[1]),
      Number(pairParamsOnBorrowing.maxOi)
    );

    const tradingFee = getTradingFee(delta, 10000000000000000000, 10);

    const amount = getWethToBeSentToTrader(
      Number(closingPrice),
      Number(openPrice),
      10,
      true,
      10000000000000000000,
      tradingFee
    );
    const balanceOfTrader = await WETH.balanceOf(trader);

    expect(Number(balanceOfTrader)).to.be.equal(
      Number(new BigNumber(amount).sub(new BigNumber(tradingFee)))
    );
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
      vault,
      deployer,
      oracle,
    } = await setupTest();
    await WETH.mint(deployer, ethers.toBigInt("1000000000000000000000000"));
    await WETH.connect(await ethers.getSigner(deployer)).approve(
      vault.target,
      ethers.toBigInt("1000000000000000000000000")
    );
    const tnx = await vault
      .connect(await ethers.getSigner(deployer))
      .deposit(ethers.toBigInt("1000000000000000000000000"), deployer);
    await tnx.wait();
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );
    await oracle.feedPrice(0, ethers.toBigInt("10000000000000000000"));

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
    await aggregator.Mfulfill(1);

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

    await aggregator.Mfulfill(2);
    await mine(1000);
    await oracle.feedPrice(0, ethers.toBigInt("12000000000000000000"));

    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 0);

    await aggregator.Mfulfill(3);

    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 1);
    await aggregator.Mfulfill(4);
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
  it("Epoch update test ", async function () {
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
      openPnlFeed,
    } = await setupTest();

    await WETH.mint(deployer, ethers.toBigInt("10000000000000000000000"));
    await WETH.connect(await ethers.getSigner(deployer)).approve(
      vault.target,
      ethers.toBigInt("10000000000000000000000")
    );
    await vault
      .connect(await ethers.getSigner(deployer))
      .deposit(ethers.toBigInt("10000000000000000000000"), deployer);
    const tnx = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx.wait();
    const epochValueRequestCount0 =
      await openPnlFeed.nextEpochValuesRequestCount();

    expect(epochValueRequestCount0).to.be.equal(0);
    const currentEpochPositiveOpenPnlStart =
      await vault.currentEpochPositiveOpenPnl();
    await time.increase(7200);

    const tnx1 = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx1.wait();
    const epochValueRequestCount1 =
      await openPnlFeed.nextEpochValuesRequestCount();
    expect(Number(epochValueRequestCount1)).to.be.equal(1);

    await openPnlFeed.fulfill(1, ethers.toBigInt("1000000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(1, 0)).to.be.equal(
      ethers.toBigInt("1000000000000000000000")
    );
    await openPnlFeed.fulfill(2, ethers.toBigInt("1001000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(1, 1)).to.be.equal(
      ethers.toBigInt("1001000000000000000000")
    );

    await openPnlFeed.fulfill(3, ethers.toBigInt("1002000000000000000000")); // 1000 * 1e18

    expect(await openPnlFeed.nextEpochValues(0)).to.be.equal(
      ethers.toBigInt("1001000000000000000000")
    ); // the median of above 3 inputs

    await time.increase(1800);

    const tnx2 = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx2.wait();

    const epochValueRequestCount2 =
      await openPnlFeed.nextEpochValuesRequestCount();
    expect(Number(epochValueRequestCount2)).to.be.equal(2);

    await openPnlFeed.fulfill(7, ethers.toBigInt("1003000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(2, 0)).to.be.equal(
      ethers.toBigInt("1003000000000000000000")
    );
    await openPnlFeed.fulfill(8, ethers.toBigInt("1004000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(2, 1)).to.be.equal(
      ethers.toBigInt("1004000000000000000000")
    );

    await openPnlFeed.fulfill(9, ethers.toBigInt("1005000000000000000000")); // 1000 * 1e18

    expect(await openPnlFeed.nextEpochValues(1)).to.be.equal(
      ethers.toBigInt("1004000000000000000000")
    ); // the median of above 3 inputs

    await time.increase(1800);

    const tnx3 = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx3.wait();

    const epochValueRequestCount3 =
      await openPnlFeed.nextEpochValuesRequestCount();
    expect(Number(epochValueRequestCount3)).to.be.equal(3);

    await openPnlFeed.fulfill(13, ethers.toBigInt("1006000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(3, 0)).to.be.equal(
      ethers.toBigInt("1006000000000000000000")
    );
    await openPnlFeed.fulfill(14, ethers.toBigInt("1007000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(3, 1)).to.be.equal(
      ethers.toBigInt("1007000000000000000000")
    );

    await openPnlFeed.fulfill(15, ethers.toBigInt("1008000000000000000000")); // 1000 * 1e18

    expect(await openPnlFeed.nextEpochValues(2)).to.be.equal(
      ethers.toBigInt("1007000000000000000000")
    ); // the median of above 3 inputs

    await time.increase(1800);

    const tnx4 = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx4.wait();

    const epochValueRequestCount4 =
      await openPnlFeed.nextEpochValuesRequestCount();
    expect(Number(epochValueRequestCount4)).to.be.equal(4);
    await openPnlFeed.fulfill(19, ethers.toBigInt("1009000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(4, 0)).to.be.equal(
      ethers.toBigInt("1009000000000000000000")
    );
    await openPnlFeed.fulfill(20, ethers.toBigInt("1010000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(4, 1)).to.be.equal(
      ethers.toBigInt("1010000000000000000000")
    );

    await openPnlFeed.fulfill(21, ethers.toBigInt("1011000000000000000000")); // 1000 * 1e18

    expect(await openPnlFeed.nextEpochValues(3)).to.be.equal(
      ethers.toBigInt("1010000000000000000000")
    ); // the median of above 3 inputs
    await time.increase(1800);

    const tnx5 = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx5.wait();

    const currentEpochPositiveOpenPnlEnd =
      await vault.currentEpochPositiveOpenPnl();
    const average = new BigNumber(1010000000000000000000)
      .add(
        new BigNumber(1007000000000000000000).add(
          new BigNumber(1004000000000000000000).add(
            new BigNumber(1001000000000000000000)
          )
        )
      )
      .div(new BigNumber(4));
    expect(
      Number(currentEpochPositiveOpenPnlEnd - currentEpochPositiveOpenPnlStart)
    ).to.be.equal(Number(average));
  });
});
