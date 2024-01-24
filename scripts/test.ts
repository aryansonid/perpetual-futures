import hre from "hardhat";
const { deployments, getNamedAccounts, ethers } = hre;
import BigNumber from "bignumber.js";

(async () => {
  getBorrowingFeeForHour = (
    collateral: number,
    leverage: number,
    pairInfo: IPairInfo
  ) => {
    const netOI = getNetOI(
      Number(pairInfo.openingInterestLong),
      Number(pairInfo.openingInterestShort),
      Number(pairInfo.openingInterestLong) >
        Number(pairInfo.openingInterestShort)
    );

    const feeDelta = getDelta(
      BLOCKS_IN_HOUR,
      0,
      Number(pairInfo.feePerBlock),
      Number(pairInfo.feeExponent),
      netOI,
    Number(pairInfo.maxOi)
    );

    const tradeBorrowingFee = getTradingBorrowingFee(
      feeDelta,
      Number(collateral),
      Number(leverage)
    );

    return tradeBorrowingFee;
  };

  getFundingFeeForHour = (
    collateral: Number,
    leverage: Number,
    buy: boolean,
    pairInfo: IPairInfo
  ) => {
    const delta = calculateFundingFeeDelta(
      Number(pairInfo.openingInterestLong),
      Number(pairInfo.openingInterestShort),
      BLOCKS_IN_HOUR,
      0,
      Number(pairInfo.value)
    );

    const fundingFee = getUpdatedFundingFee(
      Number(pairInfo.openingInterestLong),
      Number(pairInfo.openingInterestShort),
      0,
      0,
      delta,
      buy ? true : false
    );

    const tradeFundingFee = calculateFundingFeeForTrade(
      fundingFee,
      0,
      Number(collateral),
      Number(leverage)
    );

    return tradeFundingFee;
  };

  getBorrowingFee = (
    position: IPosition,
    pairInfo: IPairInfo,
    currentBlockNumber: number
  ) => {
    const netOI = getNetOI(
      Number(pairInfo.openingInterestLong),
      Number(pairInfo.openingInterestShort),
      Number(pairInfo.openingInterestLong) >
        Number(pairInfo.openingInterestShort)
    );

    const feeDelta = getDelta(
      currentBlockNumber,
      Number(pairInfo.currentBlock),
      Number(pairInfo.feePerBlock),
      Number(pairInfo.feeExponent),
      netOI,
      Number(pairInfo.maxOi)
    );

    const latestFee = getLatestBorrowingFee(
      Number(pairInfo.accFeeShort),
      Number(pairInfo.accFeeLong),
      Number(pairInfo.openingInterestShort) >
        Number(pairInfo.openingInterestLong),
      feeDelta,
      position.buy ? true : false
    );

    const tradeBorrowingFee = getTradingBorrowingFee(
      latestFee - Number(position.initialPairAccFee),
      Number(position.collateral),
      Number(position.leverage)
    );

    return tradeBorrowingFee;
  };

  getFundingFee = (
    position: IPosition,
    pairInfo: IPairInfo,
    currentBlockNumber: number
  ) => {
    const delta = calculateFundingFeeDelta(
      Number(pairInfo.openingInterestLong),
      Number(pairInfo.openingInterestShort),
      currentBlockNumber,
      Number(pairInfo.accFundingFeesStoredBlockNumber),
      Number(pairInfo.value)
    );

    const updatedFundingFee = getUpdatedFundingFee(
      Number(pairInfo.openingInterestLong),
      Number(pairInfo.openingInterestShort),
      Number(pairInfo.valueLong),
      Number(pairInfo.valueShort),
      delta,
      position.buy ? true : false
    );

    const tradeFundingFee = calculateFundingFeeForTrade(
      updatedFundingFee,
      Number(position.funding),
      Number(position.collateral),
      Number(position.leverage)
    );

    return tradeFundingFee;
  };

  getDelta = (
    currentBlock: number,
    lastUpdateBlock: number,
    feePerBlock: number,
    feeExponent: number,
    pairOpeningInterestDif: number, // short -long oi for pair or vice versa
    maxOi: number
  ) => {
    return Math.floor(
      Number(
        new BigNumber(currentBlock - lastUpdateBlock)
          .times(new BigNumber(feePerBlock))
          .times(
            new BigNumber(
              (pairOpeningInterestDif * 10000000000) ** feeExponent /
                maxOi ** feeExponent
            )
          )
          .div(new BigNumber(1000000000000000000))
      )
    );
  };

  getNetOI = (longOI: number, shortOI: number, moreLong: boolean) => {
    return moreLong ? longOI - shortOI : shortOI - longOI;
  };

  getLatestBorrowingFee = (
    accFeeShort: number,
    accFeeLong: number,
    moreShort: boolean,
    feeDelta: number,
    long: boolean
  ) => {
    let fundingFeeLong;
    let fundingFeeShort;
    if (moreShort) {
      fundingFeeShort = accFeeShort + feeDelta;
      fundingFeeLong = accFeeLong;
    } else {
      fundingFeeLong = accFeeLong + feeDelta;
      fundingFeeShort = accFeeShort;
    }
    return long ? fundingFeeLong : fundingFeeShort;
  };

  getTradingBorrowingFee = (
    fee: number,
    collateral: number,
    leverage: number
  ) => {
    return Math.floor(
      Number(
        new BigNumber(collateral * leverage * fee)
          .div(new BigNumber(10000000000))
          .div(new BigNumber(100))
      )
    );
  };

  calculateFundingFeeDelta = (
    openInterestWETHLong: number,
    openInterestWETHShort: number,
    currentBlock: number,
    lastUpdateBlock: number,
    fundingFeePerBlock: number
  ) => {
    let delta = Number(
      new BigNumber(openInterestWETHLong - openInterestWETHShort)
        .multipliedBy(new BigNumber(currentBlock - lastUpdateBlock))
        .multipliedBy(new BigNumber(fundingFeePerBlock))
        .div(new BigNumber(1e10))
        .div(new BigNumber(100))
        .multipliedBy(new BigNumber(1e18))
    );

    return delta;
  };

  getUpdatedFundingFee = (
    pairOpeningInterestLong: number,
    pairOpeningInterestShort: number,
    fundingFeeLong: number,
    fundingFeeShort: number,
    feeDelta: number,
    long: boolean
  ) => {
    if (pairOpeningInterestLong > 0) {
      let feeUpdate = Number(
        new BigNumber(feeDelta).div(new BigNumber(pairOpeningInterestLong))
      );
      fundingFeeLong += feeUpdate;
    }
    if (pairOpeningInterestShort > 0) {
      let feeUpdate = Number(
        new BigNumber(feeDelta)
          .multipliedBy(new BigNumber(-1))
          .div(new BigNumber(pairOpeningInterestShort))
      );

      fundingFeeShort += feeUpdate;
    }

    return long ? fundingFeeLong : fundingFeeShort;
  };

  calculateFundingFeeForTrade = (
    accFeeNow: number,
    accFeeBefore: number,
    collateral: number,
    leverage: number
  ) => {
    let fee = Number(
      new BigNumber(accFeeNow - accFeeBefore)
        .multipliedBy(new BigNumber(collateral))
        .multipliedBy(new BigNumber(leverage))
        .div(new BigNumber(1e18))
    );

    if (fee < 0) {
      fee = Math.ceil(fee);
    } else {
      fee = Math.floor(fee);
    }
    return fee;
  };
})();
