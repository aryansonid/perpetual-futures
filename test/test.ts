import { expect } from "chai";
import { ethers } from "hardhat";
import { mine, time } from "@nomicfoundation/hardhat-network-helpers";
import { BigNumber } from "bignumber.js";
import {
  setupTest,
  getDelta,
  getTradingFee,
  getWethToBeSentToTrader,
  getNetOI,
} from "./fixture";

describe("test", function () {
  it("Opening a trade", async function () {
    const { storage, trading, WETH, trader, oracle } = await setupTest();

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

    await oracle.feedPrice(0, openPrice);

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH,
        openPrice: openPrice,
        buy: buy,
        leverage: leverage,
        tp: tp,
        sl: sl,
      },
      0,
      0,
      3000000000
    );
  });

  it("open and close a trade ", async function () {
    const { storage, trading, WETH, trader, oracle, deployer, vault } =
      await setupTest();

    // step to provide liquidity to the vault
    await WETH.mint(deployer, ethers.toBigInt("10000000000000000000000"));
    await WETH.connect(await ethers.getSigner(deployer)).approve(
      vault.target,
      ethers.toBigInt("10000000000000000000000")
    );
    const tnx = await vault
      .connect(await ethers.getSigner(deployer))
      .deposit(ethers.toBigInt("10000000000000000000000"), deployer);
    await tnx.wait();

    //
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
    const closingPrice = ethers.toBigInt("12000000000000000000");
    await oracle.feedPrice(0, openPrice);

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH,
        openPrice: openPrice,
        buy: buy,
        leverage: leverage,
        tp: tp,
        sl: sl,
      },
      0,
      0,
      3000000000
    );

    // minting blocks for substantial Borrowing fee.
    await mine(1000);

    await oracle.feedPrice(0, closingPrice);

    // closing the trade with first arg to be the pair index and second arg the trade index here it is the first trade of trader sir trade index is 0
    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 0);
  });

  it("open and close multiple trades", async function () {
    const { storage, trading, WETH, trader, vault, deployer, oracle } =
      await setupTest();

    /// Steps to deposit liquidity in the vault
    await WETH.mint(deployer, ethers.toBigInt("1000000000000000000000000"));
    await WETH.connect(await ethers.getSigner(deployer)).approve(
      vault.target,
      ethers.toBigInt("1000000000000000000000000")
    );
    const tnx = await vault
      .connect(await ethers.getSigner(deployer))
      .deposit(ethers.toBigInt("1000000000000000000000000"), deployer);
    await tnx.wait();

    // steps to open the trade
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );
    deployer;

    // Trade parameters for first trade
    const pairIndex1 = 0;
    const positionSizeWETH1 = ethers.toBigInt("10000000000000000000");
    const openPrice = ethers.toBigInt("10000000000000000000");
    const buy1 = true;
    const leverage1 = 10;
    const tp1 = ethers.toBigInt("12000000000000000000");
    const sl1 = ethers.toBigInt("8000000000000000000");
    const closingPrice = ethers.toBigInt("8000000000000000000");

    await oracle.feedPrice(0, openPrice);

    // open first trade
    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex1,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH1,
        openPrice: openPrice,
        buy: buy1,
        leverage: leverage1,
        tp: tp1,
        sl: sl1,
      },
      0,
      0,
      3000000000
    );

    // trade parameters for second trade
    const pairIndex2 = 0;
    const positionSizeWETH2 = ethers.toBigInt("10000000000000000000");
    const buy2 = true;
    const leverage2 = 10;
    const tp2 = ethers.toBigInt("12000000000000000000");
    const sl2 = ethers.toBigInt("8000000000000000000");

    // open second trade
    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex2,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH2,
        openPrice: ethers.toBigInt("10000000000000000000"),
        buy: buy2,
        leverage: leverage2,
        tp: tp2,
        sl: sl2,
      },
      0,
      0,
      3000000000
    );

    // mint blocks for trading fee deduction
    await mine(1000);

    await oracle.feedPrice(0, closingPrice);

    // closing the first trade
    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 0);

    // closing the second trade
    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 1);
  });

  it("borrowing fee long dominant Opening interest", async function () {
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
    // step to provide liquidity to the vault
    await WETH.mint(deployer, ethers.toBigInt("10000000000000000000000"));
    await WETH.connect(await ethers.getSigner(deployer)).approve(
      vault.target,
      ethers.toBigInt("10000000000000000000000")
    );
    const tnx = await vault
      .connect(await ethers.getSigner(deployer))
      .deposit(ethers.toBigInt("10000000000000000000000"), deployer);
    await tnx.wait();

    // steps to open a trade
    // mint and approve WETH to the trader
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000"));

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
    const closingPrice = ethers.toBigInt("12000000000000000000");
    await oracle.feedPrice(0, openPrice);

    const openPriceFromOracle = await oracle.getPrice(0);

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH,
        openPrice: openPrice,
        buy: buy,
        leverage: leverage,
        tp: tp,
        sl: sl,
      },
      0,
      0,
      3000000000
    );

    const balanceOfTraderOld = await WETH.balanceOf(trader);

    expect(balanceOfTraderOld).to.be.equal(0);

    const blockNumBefore = await ethers.provider.getBlockNumber();

    // minting blocks for substantial Borrowing fee.
    await mine(1000);

    const tradePairOpeningInterest = await borrowing.getPairOpenInterestWETH(0);

    await oracle.feedPrice(0, closingPrice);

    // closing the trade with first arg to be the pair index and second arg the trade index here it is the first trade of trader sir trade index is 0
    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 0);

    const closingPriceFromOracle = await oracle.getPrice(0);

    const blockNumAfter = await ethers.provider.getBlockNumber();

    // of-chain calculations for borrowing fee

    const netOI = getNetOI(
      Number(tradePairOpeningInterest[0]),
      Number(tradePairOpeningInterest[1]),
      true
    );
    let delta = getDelta(
      blockNumAfter,
      blockNumBefore,
      Number(pairParamsOnBorrowing.feeExponent),
      netOI,
      Number(pairParamsOnBorrowing.maxOi)
    );

    const tradingFee = getTradingFee(delta, Number(positionSizeWETH), leverage);

    const amount = getWethToBeSentToTrader(
      Number(closingPriceFromOracle),
      Number(openPriceFromOracle),
      leverage,
      buy,
      Number(positionSizeWETH)
    );
    const balanceOfTrader = await WETH.balanceOf(trader);

    expect(Number(balanceOfTrader - balanceOfTraderOld)).to.be.equal(
      Number(new BigNumber(amount).sub(new BigNumber(tradingFee)))
    );
  });

  it("borrowing fee short dominant Opening interest", async function () {
    const {
      storage,
      trading,
      WETH,
      trader,
      borrowing,
      pairParamsOnBorrowing,
      vault,
      deployer,
      oracle,
    } = await setupTest();
    // step to provide liquidity to the vault
    await WETH.mint(deployer, ethers.toBigInt("10000000000000000000000"));
    await WETH.connect(await ethers.getSigner(deployer)).approve(
      vault.target,
      ethers.toBigInt("10000000000000000000000")
    );
    const tnx = await vault
      .connect(await ethers.getSigner(deployer))
      .deposit(ethers.toBigInt("10000000000000000000000"), deployer);
    await tnx.wait();

    // steps to open a trade
    // mint and approve WETH to the trader
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );
    // Trade parameters
    const pairIndex = 0;
    const positionSizeWETH = ethers.toBigInt("10000000000000000000");
    const openPrice = ethers.toBigInt("10000000000000000000");
    const buy = false;
    const leverage = 10;
    const tp = ethers.toBigInt("8000000000000000000");
    const sl = ethers.toBigInt("12000000000000000000");
    const closingPrice = ethers.toBigInt("8000000000000000000");
    await oracle.feedPrice(0, openPrice);

    const openPriceFromOracle = await oracle.getPrice(0);

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH,
        openPrice: openPrice,
        buy: buy,
        leverage: leverage,
        tp: tp,
        sl: sl,
      },
      0,
      0,
      3000000000
    );

    const balanceOfTraderOld = await WETH.balanceOf(trader);

    expect(balanceOfTraderOld).to.be.equal(0);

    const blockNumBefore = await ethers.provider.getBlockNumber();

    // minting blocks for substantial Borrowing fee.
    await mine(1000);

    const tradePairOpeningInterest = await borrowing.getPairOpenInterestWETH(0);

    await oracle.feedPrice(0, closingPrice);

    // closing the trade with first arg to be the pair index and second arg the trade index here it is the first trade of trader sir trade index is 0
    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 0);

    const closingPriceFromOracle = await oracle.getPrice(0);

    const blockNumAfter = await ethers.provider.getBlockNumber();

    // of-chain calculations for borrowing fee
    const netOI = getNetOI(
      Number(tradePairOpeningInterest[0]),
      Number(tradePairOpeningInterest[1]),
      false
    );

    let delta = getDelta(
      blockNumAfter,
      blockNumBefore,
      Number(pairParamsOnBorrowing.feeExponent),
      netOI,
      Number(pairParamsOnBorrowing.maxOi)
    );

    const tradingFee = getTradingFee(delta, Number(positionSizeWETH), leverage);

    const amount = getWethToBeSentToTrader(
      Number(closingPriceFromOracle),
      Number(openPriceFromOracle),
      leverage,
      buy,
      Number(positionSizeWETH)
    );
    const balanceOfTrader = await WETH.balanceOf(trader);

    expect(Number(balanceOfTrader - balanceOfTraderOld)).to.be.equal(
      Number(new BigNumber(amount).sub(new BigNumber(tradingFee)))
    );
  });

  it("borrowing fee should not be cut on short trade close when long dominant Opening interest", async function () {
    const {
      storage,
      trading,
      WETH,
      trader,
      borrowing,
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
    await WETH.mint(trader, ethers.toBigInt("30000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );

    // Trade parameters first trade
    const pairIndex1 = 0;
    const positionSizeWETH1 = ethers.toBigInt("10000000000000000000");
    const openPrice = ethers.toBigInt("10000000000000000000");
    const buy1 = true;
    const leverage1 = 10;
    const tp1 = ethers.toBigInt("12000000000000000000");
    const sl1 = ethers.toBigInt("8000000000000000000");
    const closingPrice = ethers.toBigInt("8000000000000000000");
    await oracle.feedPrice(0, openPrice);

    await oracle.feedPrice(0, ethers.toBigInt("10000000000000000000"));

    const openPriceFromOracle = await oracle.getPrice(0);

    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex1,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH1,
        openPrice: openPrice,
        buy: buy1,
        leverage: leverage1,
        tp: tp1,
        sl: sl1,
      },
      0,
      0,
      3000000000
    );
    // trade parameters for second trade
    const pairIndex2 = 0;
    const positionSizeWETH2 = ethers.toBigInt("10000000000000000000");
    const buy2 = true;
    const leverage2 = 10;
    const tp2 = ethers.toBigInt("12000000000000000000");
    const sl2 = ethers.toBigInt("8000000000000000000");
    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex2,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH2,
        openPrice: openPrice,
        buy: buy2,
        leverage: leverage2,
        tp: tp2,
        sl: sl2,
      },
      0,
      0,
      3000000000
    );

    // trade parameters for second trade
    const pairIndex3 = 0;
    const positionSizeWETH3 = ethers.toBigInt("10000000000000000000");
    const buy3 = false;
    const leverage3 = 10;
    const tp3 = ethers.toBigInt("8000000000000000000");
    const sl3 = ethers.toBigInt("12000000000000000000");
    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex3,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH3,
        openPrice: ethers.toBigInt("10000000000000000000"),
        buy: buy3,
        leverage: leverage3,
        tp: tp3,
        sl: sl3,
      },
      0,
      0,
      3000000000
    );
    const balanceOfTraderOld = await WETH.balanceOf(trader);

    expect(balanceOfTraderOld).to.be.equal(0);

    await mine(1000);

    await oracle.feedPrice(0, closingPrice);
    //8000000000000000000

    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 2);

    const closingPriceFromOracle = await oracle.getPrice(0);

    // await aggregator.Mfulfill(2);

    const amount = getWethToBeSentToTrader(
      Number(closingPriceFromOracle),
      Number(openPriceFromOracle),
      leverage3,
      buy3,
      Number(positionSizeWETH3)
    );

    const balanceOfTraderNew = await WETH.balanceOf(trader);

    expect(Number(balanceOfTraderNew - balanceOfTraderOld)).to.be.equal(
      Number(new BigNumber(amount))
    );
  });

  it("borrowing fee should not be cut on long trade close when short dominant Opening interest", async function () {
    const {
      storage,
      trading,
      WETH,
      trader,
      borrowing,
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
    await WETH.mint(trader, ethers.toBigInt("30000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );

    // Trade parameters first trade
    const pairIndex1 = 0;
    const positionSizeWETH1 = ethers.toBigInt("10000000000000000000");
    const openPrice = ethers.toBigInt("10000000000000000000");
    const buy1 = false;
    const leverage1 = 10;
    const tp1 = ethers.toBigInt("8000000000000000000");
    const sl1 = ethers.toBigInt("12000000000000000000");
    const closingPrice = ethers.toBigInt("12000000000000000000");
    await oracle.feedPrice(0, openPrice);

    await oracle.feedPrice(0, ethers.toBigInt("10000000000000000000"));

    const openPriceFromOracle = await oracle.getPrice(0);

    // first trade
    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex1,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH1,
        openPrice: openPrice,
        buy: buy1,
        leverage: leverage1,
        tp: tp1,
        sl: sl1,
      },
      0,
      0,
      3000000000
    );

    // trade parameters for second trade
    const pairIndex2 = 0;
    const positionSizeWETH2 = ethers.toBigInt("10000000000000000000");
    const buy2 = false;
    const leverage2 = 10;
    const tp2 = ethers.toBigInt("8000000000000000000");
    const sl2 = ethers.toBigInt("12000000000000000000");

    // second trade
    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex2,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH2,
        openPrice: openPrice,
        buy: buy2,
        leverage: leverage2,
        tp: tp2,
        sl: sl2,
      },
      0,
      0,
      3000000000
    );

    // trade parameters for third trade
    const pairIndex3 = 0;
    const positionSizeWETH3 = ethers.toBigInt("10000000000000000000");
    const buy3 = true;
    const leverage3 = 10;
    const tp3 = ethers.toBigInt("12000000000000000000");
    const sl3 = ethers.toBigInt("8000000000000000000");

    // third trade
    await trading.connect(await ethers.getSigner(trader)).openTrade(
      {
        trader: trader,
        pairIndex: pairIndex3,
        index: 0,
        initialPosToken: 0,
        positionSizeWETH: positionSizeWETH3,
        openPrice: openPrice,
        buy: buy3,
        leverage: leverage3,
        tp: tp3,
        sl: sl3,
      },
      0,
      0,
      3000000000
    );
    const balanceOfTraderOld = await WETH.balanceOf(trader);

    expect(balanceOfTraderOld).to.be.equal(0);

    await mine(1000);

    await oracle.feedPrice(0, closingPrice);

    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 2);

    const closingPriceFromOracle = await oracle.getPrice(0);

    const amount = getWethToBeSentToTrader(
      Number(closingPriceFromOracle),
      Number(openPriceFromOracle),
      leverage3,
      buy3,
      Number(positionSizeWETH3)
    );

    const balanceOfTraderNew = await WETH.balanceOf(trader);

    expect(Number(balanceOfTraderNew - balanceOfTraderOld)).to.be.equal(
      Number(new BigNumber(amount))
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

    /// Steps to deposit liquidity in the vault
    await WETH.mint(deployer, ethers.toBigInt("1000000000000000000000000"));
    await WETH.connect(await ethers.getSigner(deployer)).approve(
      vault.target,
      ethers.toBigInt("1000000000000000000000000")
    );
    const tnx = await vault
      .connect(await ethers.getSigner(deployer))
      .deposit(ethers.toBigInt("1000000000000000000000000"), deployer);
    await tnx.wait();

    // steps to open the trade
    await WETH.mint(trader, ethers.toBigInt("10000000000000000000000"));

    await WETH.connect(await ethers.getSigner(trader)).approve(
      storage.target,
      ethers.toBigInt("100000000000000000000000")
    );

    await oracle.feedPrice(0, ethers.toBigInt("10000000000000000000"));
    // open first trade
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

    // open second trade
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

    // mint blocks for trading fee deduction
    await mine(1000);

    await oracle.feedPrice(0, ethers.toBigInt("12000000000000000000"));

    // closing the first trade
    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 0);

    // closing the second trade
    await trading
      .connect(await ethers.getSigner(trader))
      .closeTradeMarket(0, 1);
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
  it("Epoch update test", async function () {
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

    // Steps to add liquidity to the vault so that supply could become greater then zero
    await WETH.mint(deployer, ethers.toBigInt("10000000000000000000000"));
    await WETH.connect(await ethers.getSigner(deployer)).approve(
      vault.target,
      ethers.toBigInt("10000000000000000000000")
    );
    await vault
      .connect(await ethers.getSigner(deployer))
      .deposit(ethers.toBigInt("10000000000000000000000"), deployer);

    // checking the current epoch
    const epoch = await vault.currentEpoch();
    expect(epoch).to.be.eq(1);

    // trying to start new epoch request
    const tnx = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx.wait();
    const epochValueRequestCount0 =
      await openPnlFeed.nextEpochValuesRequestCount();

    // the first request failed as the time limit is not yet over for first request.
    expect(epochValueRequestCount0).to.be.equal(0);
    const currentEpochPositiveOpenPnlStart =
      await vault.currentEpochPositiveOpenPnl();

    // increasing the time for 2 hours for first epoch request
    await time.increase(7200);

    // trying for new epoch request
    const tnx1 = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx1.wait();
    const epochValueRequestCount1 =
      await openPnlFeed.nextEpochValuesRequestCount();

    // epoch request success full
    expect(Number(epochValueRequestCount1)).to.be.equal(1);

    // fulfilling the open trade pnl request min 3 request
    await openPnlFeed.fulfill(1, ethers.toBigInt("1000000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(1, 0)).to.be.equal(
      ethers.toBigInt("1000000000000000000000")
    );
    await openPnlFeed.fulfill(2, ethers.toBigInt("1001000000000000000000")); // 1001 * 1e18
    expect(await openPnlFeed.requestAnswers(1, 1)).to.be.equal(
      ethers.toBigInt("1001000000000000000000")
    );

    await openPnlFeed.fulfill(3, ethers.toBigInt("1002000000000000000000")); // 1002 * 1e18

    // checking the open trade pnl value stored for epoch to be median of above three
    expect(await openPnlFeed.nextEpochValues(0)).to.be.equal(
      ethers.toBigInt("1001000000000000000000")
    ); // the median of above 3 inputs

    // increasing time for next request half hour
    await time.increase(1800);

    const tnx2 = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx2.wait();

    // checking new request is successful
    const epochValueRequestCount2 =
      await openPnlFeed.nextEpochValuesRequestCount();
    expect(Number(epochValueRequestCount2)).to.be.equal(2);

    // fulfilling the open trade pnl request min 3 request
    await openPnlFeed.fulfill(7, ethers.toBigInt("1003000000000000000000")); // 1003 * 1e18
    expect(await openPnlFeed.requestAnswers(2, 0)).to.be.equal(
      ethers.toBigInt("1003000000000000000000")
    );
    await openPnlFeed.fulfill(8, ethers.toBigInt("1004000000000000000000")); // 1004 * 1e18
    expect(await openPnlFeed.requestAnswers(2, 1)).to.be.equal(
      ethers.toBigInt("1004000000000000000000")
    );

    await openPnlFeed.fulfill(9, ethers.toBigInt("1005000000000000000000")); // 1005 * 1e18

    // checking the open trade pnl value stored for epoch to be median of above three
    expect(await openPnlFeed.nextEpochValues(1)).to.be.equal(
      ethers.toBigInt("1004000000000000000000")
    ); // the median of above 3 inputs

    // increasing time for next request half hour
    await time.increase(1800);

    const tnx3 = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx3.wait();

    // checking new request is successful
    const epochValueRequestCount3 =
      await openPnlFeed.nextEpochValuesRequestCount();
    expect(Number(epochValueRequestCount3)).to.be.equal(3);

    // fulfilling the open trade pnl request min 3 request
    await openPnlFeed.fulfill(13, ethers.toBigInt("1006000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(3, 0)).to.be.equal(
      ethers.toBigInt("1006000000000000000000")
    );
    await openPnlFeed.fulfill(14, ethers.toBigInt("1007000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(3, 1)).to.be.equal(
      ethers.toBigInt("1007000000000000000000")
    );

    await openPnlFeed.fulfill(15, ethers.toBigInt("1008000000000000000000")); // 1000 * 1e18

    // checking the open trade pnl value stored for epoch to be median of above three
    expect(await openPnlFeed.nextEpochValues(2)).to.be.equal(
      ethers.toBigInt("1007000000000000000000")
    ); // the median of above 3 inputs

    // increasing time for next request half hour
    await time.increase(1800);

    const tnx4 = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx4.wait();

    // checking new request is successful
    const epochValueRequestCount4 =
      await openPnlFeed.nextEpochValuesRequestCount();
    expect(Number(epochValueRequestCount4)).to.be.equal(4);

    // fulfilling the open trade pnl request min 3 request
    await openPnlFeed.fulfill(19, ethers.toBigInt("1009000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(4, 0)).to.be.equal(
      ethers.toBigInt("1009000000000000000000")
    );
    await openPnlFeed.fulfill(20, ethers.toBigInt("1010000000000000000000")); // 1000 * 1e18
    expect(await openPnlFeed.requestAnswers(4, 1)).to.be.equal(
      ethers.toBigInt("1010000000000000000000")
    );

    await openPnlFeed.fulfill(21, ethers.toBigInt("1011000000000000000000")); // 1000 * 1e18

    // checking the open trade pnl value stored for epoch to be median of above three
    expect(await openPnlFeed.nextEpochValues(3)).to.be.equal(
      ethers.toBigInt("1010000000000000000000")
    ); // the median of above 3 inputs

    // as the required 4 open trade pnl request are fulfilled increase the time to set the new epoch
    await time.increase(1800);

    // final request to update the epoch
    const tnx5 = await vault.tryNewOpenPnlRequestOrEpoch();
    await tnx5.wait();

    // checking the current epoch
    const newEpoch = await vault.currentEpoch();
    expect(newEpoch).to.be.eq(2);

    // checking the updated open trade pnl to be increased by the average for 4 median value stored via request
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
