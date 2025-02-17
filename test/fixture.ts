import { deployments, ethers, getNamedAccounts } from "hardhat";
import { Signer } from "ethers";
import BigNumber from "bignumber.js";

// test setup
export const setupTest = deployments.createFixture(async (hre) => {
  const { deployer, trader, priceSetter } = await getNamedAccounts();
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

  const openPnlFeed = await getContract(
    "OpenPnlFeed",
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

  const oracle = await getContract(
    "Oracle",
    await ethers.getSigner(priceSetter)
  );

  const borrowing = await getContract(
    "borrowing",
    await ethers.getSigner(deployer)
  );

  const callback = await getContract(
    "callback",
    await ethers.getSigner(deployer)
  );

  const vault = await getContract("vault", await ethers.getSigner(deployer));
  const pairParamsOnBorrowing = {
    groupIndex: 0,
    feePerBlock: 24595,
    feeExponent: 1,
    maxOi: ethers.toBigInt("10000000000000000000"),
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
    oracle,
    openPnlFeed,
    callback,
  };
});

//Helper function for test

export async function getContract(name: string, signer?: Signer) {
  const c = await deployments.get(name);
  return await ethers.getContractAt(c.abi, c.address, signer);
}

export function getDelta(
  blockNumAfter: number,
  blockNumBefore: number,
  feeExponent: number,
  pairOpeningInterest: number, // short -long oi for pair or vice versa
  maxOi: number
) {
  return Math.floor(
    Number(
      new BigNumber(
        (blockNumAfter - blockNumBefore) *
          feeExponent *
          (pairOpeningInterest * 10000000000)
      )
        .div(new BigNumber(maxOi))
        .div(new BigNumber(1000000000000000000))
    )
  );
}

export function getTradingFee(
  delta: number,
  collateral: number,
  leverage: number
) {
  return Math.floor(
    Number(
      new BigNumber(collateral * leverage * delta)
        .div(new BigNumber(10000000000))
        .div(new BigNumber(100))
    )
  );
}

export function getWethToBeSentToTrader(
  currentPrice: number,
  openPrice: number,
  leverage: number,
  long: boolean,
  collateral: number
) {
  let profitP = Number(
    new BigNumber(long ? currentPrice - openPrice : openPrice - currentPrice)
      .multipliedBy(
        new BigNumber(100)
          .multipliedBy(new BigNumber(10000000000))
          .multipliedBy(leverage)
      )
      .div(new BigNumber(openPrice))
  );
  profitP = Math.floor(profitP);
  const maxPnl = 9000000000000;
  const maxNegPnl = -900000000000;
  profitP = profitP > maxPnl ? maxPnl : profitP;
  if (profitP <= maxNegPnl) profitP = -1000000000000;
  return Math.floor(
    Number(
      new BigNumber(collateral * (100 * 10000000000 + profitP))
        .div(new BigNumber(100))
        .div(new BigNumber(10000000000))
    )
  );
}

export function getNetOI(longOI: number, shortOI: number, moreLong: boolean) {
  if (moreLong) {
    return longOI - shortOI;
  } else {
    return shortOI - longOI;
  }
}

export function getTpPercentage(
  value1: number,
  value2: number,
  precision: number,
  leverage: number
) {
  return Number(
    new BigNumber(value1 - value2)
      .times(new BigNumber(precision))
      .times(new BigNumber(leverage))
      .times(new BigNumber(100))
      .div(new BigNumber(value2))
  );
}

export function getNewTp(
  percentage: number,
  value: number,
  precision: number,
  leverage: number
) {
  return Number(
    new BigNumber(value).plus(
      new BigNumber(percentage)
        .times(new BigNumber(value))
        .div(new BigNumber(100))
        .div(new BigNumber(precision))
        .div(new BigNumber(leverage))
    )
  );
}

export function calculateFundingFee(
  openInterestWETHLong: number,
  openInterestWETHShort: number,
  currentBlock: number,
  lastUpdateBlock: number,
  fundingFeePerBlockP: number
) {
  return Math.abs(
    Math.floor(
      Number(
        new BigNumber(openInterestWETHLong - openInterestWETHShort)
          .times(new BigNumber(currentBlock - lastUpdateBlock))
          .times(new BigNumber(fundingFeePerBlockP))
          .div(new BigNumber(1e10))
          .div(new BigNumber(100))
          .times(new BigNumber(1e18))
          .div(new BigNumber(openInterestWETHLong))
      )
    )
  );
}

export function calculateFundingFeeForTrade(
  accFeeNow: number,
  accFeeBefore: number,
  collateral: number,
  leverage: number
) {
  return Math.abs(
    Math.floor(
      Number(
        new BigNumber(accFeeNow - accFeeBefore)
          .times(new BigNumber(collateral))
          .times(new BigNumber(leverage))
          .div(new BigNumber(1e18))
      )
    )
  );
}

export function calculateFundingFeePerBlock(
  newPrice: number,
  oldPrice: number,
  newBlockNumber: number,
  oldBlockNumber: number
) {
  let fundingFee = Number(
    new BigNumber(newPrice - oldPrice)
      .times(new BigNumber(1e10))
      .div(new BigNumber(oldPrice))
      .div(new BigNumber(newBlockNumber - oldBlockNumber))
  );
  fundingFee = fundingFee < 0 ? Math.ceil(fundingFee) : Math.floor(fundingFee);
  return Math.abs(fundingFee);
}

export function updatePosOpening(pos: number, leverage: number) {
  return Math.floor(
    Number(new BigNumber(pos).minus(new BigNumber((pos * leverage * 8) / 1e4)))
  );
}

export function getClosingFee(pos: number, leverage: number) {
  return Math.floor(Number(new BigNumber((pos * leverage * 8) / 1e4)));
}

export function getFundingFee(atr: number, closingPrice: number) {
  return Math.floor((((atr / closingPrice) * 100) ^ ((1.25 * 52) / 60)) * 1e10);
}

