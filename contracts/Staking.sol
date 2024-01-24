// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./interfaces/TokenInterface.sol";
import "./interfaces/NftInterfaceV5.sol";

contract Staking {
    // Contracts & Addresses
    address public govFund;

    TokenInterface public immutable token; // GNS
    TokenInterface public immutable WETH;

    NftInterfaceV5[5] public nfts;

    // Pool state
    uint public accWETHPerToken;
    uint public tokenBalance;

    // Pool parameters
    uint[5] public boostsP;
    uint public maxNftsStaked;

    // Pool stats
    uint public totalRewardsDistributedWETH; // 1e18

    // Mappings
    mapping(address => User) public users;
    mapping(address => mapping(uint => StakedNft)) public userNfts;

    // Structs
    struct StakedNft {
        uint nftId;
        uint nftType;
    }
    struct User {
        uint stakedTokens; // 1e18
        uint debtWETH; // 1e18
        uint stakedNftsCount;
        uint totalBoostTokens; // 1e18
        uint harvestedRewardsWETH; // 1e18
    }

    // Events
    event GovFundUpdated(address value);
    event BoostsUpdated(uint[5] boosts);
    event MaxNftsStakedUpdated(uint value);

    event WETHDistributed(uint amount);

    event WETHHarvested(address indexed user, uint amount);

    event TokensStaked(address indexed user, uint amount);
    event TokensUnstaked(address indexed user, uint amount);

    event NftStaked(address indexed user, uint indexed nftType, uint nftId);
    event NftUnstaked(address indexed user, uint indexed nftType, uint nftId);

    constructor(
        address _govFund,
        TokenInterface _token,
        TokenInterface _WETH,
        NftInterfaceV5[5] memory _nfts,
        uint[5] memory _boostsP,
        uint _maxNftsStaked
    ) {
        require(
            _govFund != address(0) &&
                address(_token) != address(0) &&
                address(_WETH) != address(0) &&
                address(_nfts[4]) != address(0),
            "WRONG_PARAMS"
        );

        checkBoostsP(_boostsP);

        govFund = _govFund;
        token = _token;
        WETH = _WETH;
        nfts = _nfts;

        boostsP = _boostsP;
        maxNftsStaked = _maxNftsStaked;
    }

    // Modifiers
    modifier onlyGov() {
        require(msg.sender == govFund, "GOV_ONLY");
        _;
    }
    modifier notContract() {
        require(tx.origin == msg.sender, "CONTRACT");
        _;
    }

    // Manage addresses
    function setGovFund(address value) external onlyGov {
        require(value != address(0), "ADDRESS_0");

        govFund = value;

        emit GovFundUpdated(value);
    }

    // Manage parameters
    function checkBoostsP(uint[5] memory value) public pure {
        require(
            value[0] < value[1] &&
                value[1] < value[2] &&
                value[2] < value[3] &&
                value[3] < value[4],
            "WRONG_VALUES"
        );
    }

    function setBoostsP(uint[5] memory value) external onlyGov {
        checkBoostsP(value);

        boostsP = value;

        emit BoostsUpdated(value);
    }

    function setMaxNftsStaked(uint value) external onlyGov {
        maxNftsStaked = value;

        emit MaxNftsStakedUpdated(value);
    }

    // Distribute rewards
    function distributeRewardWETH(uint amount) external {
        WETH.transferFrom(msg.sender, address(this), amount);

        if (tokenBalance > 0) {
            accWETHPerToken += (amount * 1e18) / tokenBalance;
            totalRewardsDistributedWETH += amount;
        }

        emit WETHDistributed(amount);
    }

    // Compute user boosts
    function setBoosts() private {
        User storage u = users[msg.sender];

        u.totalBoostTokens = 0;

        for (uint i = 0; i < u.stakedNftsCount; i++) {
            u.totalBoostTokens +=
                (u.stakedTokens *
                    boostsP[userNfts[msg.sender][i].nftType - 1]) /
                100;
        }

        u.debtWETH =
            ((u.stakedTokens + u.totalBoostTokens) * accWETHPerToken) /
            1e18;
    }

    // Rewards to be harvested
    function pendingRewardWETH() public view returns (uint) {
        User storage u = users[msg.sender];

        return
            ((u.stakedTokens + u.totalBoostTokens) * accWETHPerToken) /
            1e18 -
            u.debtWETH;
    }

    // Harvest rewards
    function harvest() public {
        uint pendingWETH = pendingRewardWETH();

        User storage u = users[msg.sender];
        u.debtWETH =
            ((u.stakedTokens + u.totalBoostTokens) * accWETHPerToken) /
            1e18;
        u.harvestedRewardsWETH += pendingWETH;

        WETH.transfer(msg.sender, pendingWETH);

        emit WETHHarvested(msg.sender, pendingWETH);
    }

    // Stake tokens
    function stakeTokens(uint amount) external {
        User storage u = users[msg.sender];

        token.transferFrom(msg.sender, address(this), amount);

        harvest();

        tokenBalance -= (u.stakedTokens + u.totalBoostTokens);

        u.stakedTokens += amount;
        setBoosts();

        tokenBalance += (u.stakedTokens + u.totalBoostTokens);

        emit TokensStaked(msg.sender, amount);
    }

    // Unstake tokens
    function unstakeTokens(uint amount) external {
        User storage u = users[msg.sender];

        harvest();

        tokenBalance -= (u.stakedTokens + u.totalBoostTokens);

        u.stakedTokens -= amount;
        setBoosts();

        tokenBalance += (u.stakedTokens + u.totalBoostTokens);

        token.transfer(msg.sender, amount);

        emit TokensUnstaked(msg.sender, amount);
    }

    // Stake NFT
    // NFT types: 1, 2, 3, 4, 5
    function stakeNft(uint nftType, uint nftId) external notContract {
        User storage u = users[msg.sender];

        require(u.stakedNftsCount < maxNftsStaked, "MAX_NFTS_ALREADY_STAKED");

        nfts[nftType - 1].transferFrom(msg.sender, address(this), nftId);

        harvest();

        tokenBalance -= (u.stakedTokens + u.totalBoostTokens);

        StakedNft storage stakedNft = userNfts[msg.sender][u.stakedNftsCount++];
        stakedNft.nftType = nftType;
        stakedNft.nftId = nftId;

        setBoosts();

        tokenBalance += (u.stakedTokens + u.totalBoostTokens);

        emit NftStaked(msg.sender, nftType, nftId);
    }

    // Unstake NFT
    function unstakeNft(uint nftIndex) external {
        User storage u = users[msg.sender];
        StakedNft memory stakedNft = userNfts[msg.sender][nftIndex];

        harvest();

        tokenBalance -= (u.stakedTokens + u.totalBoostTokens);

        userNfts[msg.sender][nftIndex] = userNfts[msg.sender][
            u.stakedNftsCount - 1
        ];
        delete userNfts[msg.sender][(u.stakedNftsCount--) - 1];

        setBoosts();

        tokenBalance += (u.stakedTokens + u.totalBoostTokens);

        nfts[stakedNft.nftType - 1].transferFrom(
            address(this),
            msg.sender,
            stakedNft.nftId
        );

        emit NftUnstaked(msg.sender, stakedNft.nftType, stakedNft.nftId);
    }
}
