// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/UniswapRouterInterface.sol";
import "./interfaces/TokenInterface.sol";
import "./interfaces/NftInterfaceV5.sol";
import "./interfaces/VaultInterface.sol";
import "./interfaces/PairsStorageInterfaceV6.sol";
import "./interfaces/StorageInterface.sol";
import "./interfaces/AggregatorInterfaceV1_2.sol";
import "./interfaces/NftRewardsInterfaceV6.sol";

contract Referrals is Initializable {
    // CONSTANTS
    uint constant PRECISION = 1e10;
    StorageInterface public storageT;

    // ADJUSTABLE PARAMETERS
    uint public allyFeeP; // % (of referrer fees going to allies, eg. 10)
    uint public startReferrerFeeP; // % (of referrer fee when 0 volume referred, eg. 75)
    uint public openFeeP; // % (of opening fee used for referral system, eg. 33)
    uint public targetVolumeWETH; // WETH (to reach maximum referral system fee, eg. 1e8)

    // CUSTOM TYPES
    struct AllyDetails {
        address[] referrersReferred;
        uint volumeReferredWETH; // 1e18
        uint pendingRewardsToken; // 1e18
        uint totalRewardsToken; // 1e18
        uint totalRewardsValueWETH; // 1e18
        bool active;
    }

    struct ReferrerDetails {
        address ally;
        address[] tradersReferred;
        uint volumeReferredWETH; // 1e18
        uint pendingRewardsToken; // 1e18
        uint totalRewardsToken; // 1e18
        uint totalRewardsValueWETH; // 1e18
        bool active;
    }

    // STATE (MAPPINGS)
    mapping(address => AllyDetails) public allyDetails;
    mapping(address => ReferrerDetails) public referrerDetails;

    mapping(address => address) public referrerByTrader;

    // EVENTS
    event UpdatedAllyFeeP(uint value);
    event UpdatedStartReferrerFeeP(uint value);
    event UpdatedOpenFeeP(uint value);
    event UpdatedTargetVolumeWETH(uint value);

    event AllyWhitelisted(address indexed ally);
    event AllyUnwhitelisted(address indexed ally);

    event ReferrerWhitelisted(address indexed referrer, address indexed ally);
    event ReferrerUnwhitelisted(address indexed referrer);
    event ReferrerRegistered(address indexed trader, address indexed referrer);

    event AllyRewardDistributed(
        address indexed ally,
        address indexed trader,
        uint volumeWETH,
        uint amountToken,
        uint amountValueWETH
    );
    event ReferrerRewardDistributed(
        address indexed referrer,
        address indexed trader,
        uint volumeWETH,
        uint amountToken,
        uint amountValueWETH
    );

    event AllyRewardsClaimed(address indexed ally, uint amountToken);
    event ReferrerRewardsClaimed(address indexed referrer, uint amountToken);

    function initialize(
        StorageInterface _storageT,
        uint _allyFeeP,
        uint _startReferrerFeeP,
        uint _openFeeP,
        uint _targetVolumeWETH
    ) external initializer {
        require(
            address(_storageT) != address(0) &&
                _allyFeeP <= 50 &&
                _startReferrerFeeP <= 100 &&
                _openFeeP <= 50 &&
                _targetVolumeWETH > 0,
            "WRONG_PARAMS"
        );

        storageT = _storageT;

        allyFeeP = _allyFeeP;
        startReferrerFeeP = _startReferrerFeeP;
        openFeeP = _openFeeP;
        targetVolumeWETH = _targetVolumeWETH;
    }

    // MODIFIERS
    modifier onlyGov() {
        require(msg.sender == storageT.gov(), "GOV_ONLY");
        _;
    }
    modifier onlyTrading() {
        require(msg.sender == address(storageT.trading()), "TRADING_ONLY");
        _;
    }
    modifier onlyCallbacks() {
        require(msg.sender == address(storageT.callbacks()), "CALLBACKS_ONLY");
        _;
    }

    // MANAGE PARAMETERS
    function updateAllyFeeP(uint value) external onlyGov {
        require(value <= 50, "VALUE_ABOVE_50");

        allyFeeP = value;

        emit UpdatedAllyFeeP(value);
    }

    function updateStartReferrerFeeP(uint value) external onlyGov {
        require(value <= 100, "VALUE_ABOVE_100");

        startReferrerFeeP = value;

        emit UpdatedStartReferrerFeeP(value);
    }

    function updateOpenFeeP(uint value) external onlyGov {
        require(value <= 50, "VALUE_ABOVE_50");

        openFeeP = value;

        emit UpdatedOpenFeeP(value);
    }

    function updateTargetVolumeWETH(uint value) external onlyGov {
        require(value > 0, "VALUE_0");

        targetVolumeWETH = value;

        emit UpdatedTargetVolumeWETH(value);
    }

    // MANAGE ALLIES
    function whitelistAlly(address ally) external onlyGov {
        require(ally != address(0), "ADDRESS_0");

        AllyDetails storage a = allyDetails[ally];
        require(!a.active, "ALLY_ALREADY_ACTIVE");

        a.active = true;

        emit AllyWhitelisted(ally);
    }

    function unwhitelistAlly(address ally) external onlyGov {
        AllyDetails storage a = allyDetails[ally];
        require(a.active, "ALREADY_UNACTIVE");

        a.active = false;

        emit AllyUnwhitelisted(ally);
    }

    // MANAGE REFERRERS
    function whitelistReferrer(
        address referrer,
        address ally
    ) external onlyGov {
        require(referrer != address(0), "ADDRESS_0");

        ReferrerDetails storage r = referrerDetails[referrer];
        require(!r.active, "REFERRER_ALREADY_ACTIVE");

        r.active = true;

        if (ally != address(0)) {
            AllyDetails storage a = allyDetails[ally];
            require(a.active, "ALLY_NOT_ACTIVE");

            r.ally = ally;
            a.referrersReferred.push(referrer);
        }

        emit ReferrerWhitelisted(referrer, ally);
    }

    function unwhitelistReferrer(address referrer) external onlyGov {
        ReferrerDetails storage r = referrerDetails[referrer];
        require(r.active, "ALREADY_UNACTIVE");

        r.active = false;

        emit ReferrerUnwhitelisted(referrer);
    }

    function registerPotentialReferrer(
        address trader,
        address referrer
    ) external onlyTrading {
        ReferrerDetails storage r = referrerDetails[referrer];

        if (
            referrerByTrader[trader] != address(0) ||
            referrer == address(0) ||
            !r.active
        ) {
            return;
        }

        referrerByTrader[trader] = referrer;
        r.tradersReferred.push(trader);

        emit ReferrerRegistered(trader, referrer);
    }

    // REWARDS DISTRIBUTION
    function distributePotentialReward(
        address trader,
        uint volumeWETH,
        uint pairOpenFeeP,
        uint tokenPriceWETH
    ) external onlyCallbacks returns (uint) {
        address referrer = referrerByTrader[trader];
        ReferrerDetails storage r = referrerDetails[referrer];

        if (!r.active) {
            return 0;
        }

        uint referrerRewardValueWETH = (volumeWETH *
            getReferrerFeeP(pairOpenFeeP, r.volumeReferredWETH)) /
            PRECISION /
            100;

        uint referrerRewardToken = (referrerRewardValueWETH * PRECISION) /
            tokenPriceWETH;

        storageT.handleTokens(address(this), referrerRewardToken, true);

        AllyDetails storage a = allyDetails[r.ally];

        uint allyRewardValueWETH;
        uint allyRewardToken;

        if (a.active) {
            allyRewardValueWETH = (referrerRewardValueWETH * allyFeeP) / 100;
            allyRewardToken = (referrerRewardToken * allyFeeP) / 100;

            a.volumeReferredWETH += volumeWETH;
            a.pendingRewardsToken += allyRewardToken;
            a.totalRewardsToken += allyRewardToken;
            a.totalRewardsValueWETH += allyRewardValueWETH;

            referrerRewardValueWETH -= allyRewardValueWETH;
            referrerRewardToken -= allyRewardToken;

            emit AllyRewardDistributed(
                r.ally,
                trader,
                volumeWETH,
                allyRewardToken,
                allyRewardValueWETH
            );
        }

        r.volumeReferredWETH += volumeWETH;
        r.pendingRewardsToken += referrerRewardToken;
        r.totalRewardsToken += referrerRewardToken;
        r.totalRewardsValueWETH += referrerRewardValueWETH;

        emit ReferrerRewardDistributed(
            referrer,
            trader,
            volumeWETH,
            referrerRewardToken,
            referrerRewardValueWETH
        );

        return referrerRewardValueWETH + allyRewardValueWETH;
    }

    // REWARDS CLAIMING
    function claimAllyRewards() external {
        AllyDetails storage a = allyDetails[msg.sender];
        uint rewardsToken = a.pendingRewardsToken;

        require(rewardsToken > 0, "NO_PENDING_REWARDS");

        a.pendingRewardsToken = 0;
        storageT.token().transfer(msg.sender, rewardsToken);

        emit AllyRewardsClaimed(msg.sender, rewardsToken);
    }

    function claimReferrerRewards() external {
        ReferrerDetails storage r = referrerDetails[msg.sender];
        uint rewardsToken = r.pendingRewardsToken;

        require(rewardsToken > 0, "NO_PENDING_REWARDS");

        r.pendingRewardsToken = 0;
        storageT.token().transfer(msg.sender, rewardsToken);

        emit ReferrerRewardsClaimed(msg.sender, rewardsToken);
    }

    // VIEW FUNCTIONS
    function getReferrerFeeP(
        uint pairOpenFeeP,
        uint volumeReferredWETH
    ) public view returns (uint) {
        uint maxReferrerFeeP = (pairOpenFeeP * 2 * openFeeP) / 100;
        uint minFeeP = (maxReferrerFeeP * startReferrerFeeP) / 100;

        uint feeP = minFeeP +
            ((maxReferrerFeeP - minFeeP) * volumeReferredWETH) /
            1e18 /
            targetVolumeWETH;

        return feeP > maxReferrerFeeP ? maxReferrerFeeP : feeP;
    }

    function getPercentOfOpenFeeP(address trader) external view returns (uint) {
        return
            getPercentOfOpenFeeP_calc(
                referrerDetails[referrerByTrader[trader]].volumeReferredWETH
            );
    }

    function getPercentOfOpenFeeP_calc(
        uint volumeReferredWETH
    ) public view returns (uint resultP) {
        resultP =
            (openFeeP *
                (startReferrerFeeP *
                    PRECISION +
                    (volumeReferredWETH *
                        PRECISION *
                        (100 - startReferrerFeeP)) /
                    1e18 /
                    targetVolumeWETH)) /
            100;

        resultP = resultP > openFeeP * PRECISION
            ? openFeeP * PRECISION
            : resultP;
    }

    function getTraderReferrer(address trader) external view returns (address) {
        address referrer = referrerByTrader[trader];

        return referrerDetails[referrer].active ? referrer : address(0);
    }

    function getReferrersReferred(
        address ally
    ) external view returns (address[] memory) {
        return allyDetails[ally].referrersReferred;
    }

    function getTradersReferred(
        address referred
    ) external view returns (address[] memory) {
        return referrerDetails[referred].tradersReferred;
    }
}
