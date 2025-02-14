// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IToken.sol";
import "./interfaces/INft.sol";
import "./interfaces/IOpenTradesPnlFeed.sol";
import "./libraries/ChainUtils.sol";

contract Vault is
    ERC20Upgradeable,
    ERC4626Upgradeable,
    OwnableUpgradeable,
    IToken
{
    using MathUpgradeable for uint;

    // Contracts & Addresses (constant)
    // address public Token;
    INft public lockedDepositNft;

    // Contracts & Addresses (adjustable)
    address public manager; // 3-day timelock contract
    address public admin; // bypasses timelock, access to emergency functions

    address public pnlHandler;
    IOpenTradesPnlFeed public openTradesPnlFeed;
    // PriceProvider public PriceProvider;

    // struct PriceProvider {
    //     address addr;
    //     bytes signature;
    // }

    // Parameters (constant)
    uint constant PRECISION = 1e18; // 18 decimals (acc values & price)
    uint constant PRECISION_2 = 1e40; // 40 decimals (acc block weighted market cap)
    uint constant _PRECISION = 1e10; // 10 decimals (/asset oracle)
    uint constant MIN_WETHLY_ACC_PNL_DELTA = PRECISION / 10; // 0.1 (price delta)
    uint constant MAX_SUPPLY_INCREASE_DAILY_P = 50 * PRECISION; // 50% / day (when under collat)
    uint constant MAX_LOSSES_BURN_P = 25 * PRECISION; // 25% of all losses
    uint constant MAX__SUPPLY_MINT_DAILY_P = PRECISION / 20; // 0.05% / day (18.25% / yr max)
    uint constant MAX_DISCOUNT_P = 10 * PRECISION; // 10%
    uint public MIN_LOCK_DURATION; // min locked asset deposit duration
    uint constant MAX_LOCK_DURATION = 365 days; // max locked asset deposit duration
    uint[] WITHDRAW_EPOCHS_LOCKS; // epochs withdraw locks at over collat thresholds

    // Parameters (adjustable)
    uint public maxAccOpenPnlDelta; // PRECISION (max price delta on new epochs from open pnl)
    uint public maxdailyAccPnlDelta; // PRECISION (max WETHly price delta from closed pnl)
    uint[2] public withdrawLockThresholdsP; // PRECISION (% of over collat, used with WITHDRAW_EPOCHS_LOCKS)
    uint public maxSupplyIncreaseDailyP; // PRECISION (% per day, when under collat)
    uint public lossesBurnP; // PRECISION (% of all losses)
    uint public maxSupplyMintDailyP; // PRECISION (% of  supply)
    uint public maxDiscountP; // PRECISION (%, maximum discount for locked deposits)
    uint public maxDiscountThresholdP; // PRECISION (maximum collat %, for locked deposits)

    // Price state
    uint public shareToAssetsPrice; // PRECISION
    int public accPnlPerTokenUsed; // PRECISION (snapshot of accPnlPerToken)
    int public accPnlPerToken; // PRECISION (updated in real-time)
    uint public accRewardsPerToken; // PRECISION

    // Closed Pnl state
    int public dailyAccPnlDelta; // PRECISION
    uint public lastDailyAccPnlDeltaReset; // timestamp

    // Epochs state (withdrawals)
    uint public currentEpoch; // global id
    uint public currentEpochStart; // timestamp
    uint public currentEpochPositiveOpenPnl; // 1e18

    // Deposit / Withdraw state
    uint public currentMaxSupply; // 1e18
    uint public lastMaxSupplyUpdate; // timestamp
    mapping(address => mapping(uint => uint)) public withdrawRequests; // owner => unlock epoch => shares

    // Locked deposits state
    uint public lockedDepositsCount; // global id
    mapping(uint => LockedDeposit) public lockedDeposits;

    // Deplete / Refill state
    uint public assetsToDeplete; // 1e18
    uint public dailyMinted; // 1e18
    uint public lastdailyMintedReset; // timestamp

    // Statistics (not used for contract logic)
    uint public totalDeposited; // 1e18 (assets)
    int public totalClosedPnl; // 1e18 (assets)
    uint public totalRewards; // 1e18 (assets)
    int public totalLiability; // 1e18 (assets)
    uint public totalLockedDiscounts; // 1e18 (assets)
    uint public totalDiscounts; // 1e18 (assets)
    // uint public totalDepleted; // 1e18 (assets)
    // uint public totalDepleted; // 1e18 ()
    // uint public totalRefilled; // 1e18 (assets)
    // uint public totalRefilled; // 1e18 ()

    // Useful acc values
    uint public accBlockWeightedMarketCap; // 1e40, acc sum of (blocks elapsed / market cap)
    uint public accBlockWeightedMarketCapLastStored; // block

    // Events
    event AddressParamUpdated(string name, address newValue);
    // event PriceProviderUpdated(PriceProvider newValue);
    event NumberParamUpdated(string name, uint newValue);
    event WithdrawLockThresholdsPUpdated(uint[2] newValue);

    event CurrentMaxSupplyUpdated(uint newValue);
    event dailyAccPnlDeltaReset();
    event ShareToAssetsPriceUpdated(uint newValue);
    event OpenTradesPnlFeedCallFailed();

    event WithdrawRequested(
        address indexed sender,
        address indexed owner,
        uint shares,
        uint currEpoch,
        uint indexed unlockEpoch
    );
    event WithdrawCanceled(
        address indexed sender,
        address indexed owner,
        uint shares,
        uint currEpoch,
        uint indexed unlockEpoch
    );

    event DepositLocked(
        address indexed sender,
        address indexed owner,
        uint depositId,
        LockedDeposit d
    );
    event DepositUnlocked(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint depositId,
        LockedDeposit d
    );

    event RewardDistributed(address indexed sender, uint assets);

    event AssetsSent(
        address indexed sender,
        address indexed receiver,
        uint assets
    );
    event AssetsReceived(
        address indexed sender,
        address indexed user,
        uint assets,
        uint assetsLessDeplete
    );

    event Depleted(address indexed sender, uint assets, uint amount);
    event Refilled(address indexed sender, uint assets, uint amount);

    event AccPnlPerTokenUsedUpdated(
        address indexed sender,
        uint indexed newEpoch,
        uint prevPositiveOpenPnl,
        uint newPositiveOpenPnl,
        uint newEpochPositiveOpenPnl,
        int newAccPnlPerTokenUsed
    );

    event AccBlockWeightedMarketCapStored(uint newAccValue);

    // Prevent stack too deep error
    struct ContractAddresses {
        address asset;
        address owner; // 2-week timelock contract
        address manager; // 3-day timelock contract
        address admin; // bypasses timelock, access to emergency functions
        // address Token;
        address lockedDepositNft;
        address pnlHandler;
        address openTradesPnlFeed;
        // PriceProvider PriceProvider;
    }

    // Initializer function called when this contract is deployed
    function initialize(
        string memory _name,
        string memory _symbol,
        ContractAddresses memory _contractAddresses,
        uint _MIN_LOCK_DURATION,
        uint _maxAccOpenPnlDelta,
        uint _maxdailyAccPnlDelta,
        uint[2] memory _withdrawLockThresholdsP,
        uint _maxSupplyIncreaseDailyP,
        uint _lossesBurnP,
        uint _maxSupplyMintDailyP,
        uint _maxDiscountP,
        uint _maxDiscountThresholdP
    ) external initializer {
        require(
            _contractAddresses.asset != address(0) &&
                _contractAddresses.owner != address(0) &&
                _contractAddresses.manager != address(0) &&
                _contractAddresses.admin != address(0) &&
                _contractAddresses.owner != _contractAddresses.manager &&
                _contractAddresses.manager != _contractAddresses.admin &&
                /*_contractAddresses.Token != address(0) &&*/
                _contractAddresses.lockedDepositNft != address(0) &&
                _contractAddresses.pnlHandler != address(0) &&
                _contractAddresses.openTradesPnlFeed != address(0) &&
                /*_contractAddresses.PriceProvider.addr != address(0) &&*/
                /*_contractAddresses.PriceProvider.signature.length > 0 &&*/
                _maxdailyAccPnlDelta >= MIN_WETHLY_ACC_PNL_DELTA &&
                _withdrawLockThresholdsP[1] > _withdrawLockThresholdsP[0] &&
                _maxSupplyIncreaseDailyP <= MAX_SUPPLY_INCREASE_DAILY_P &&
                _lossesBurnP <= MAX_LOSSES_BURN_P &&
                _maxSupplyMintDailyP <= MAX__SUPPLY_MINT_DAILY_P &&
                _maxDiscountP <= MAX_DISCOUNT_P &&
                _maxDiscountThresholdP >= 100 * PRECISION,
            "WRONG_PARAMS"
        );

        __ERC20_init(_name, _symbol);
        __ERC4626_init(IERC20MetadataUpgradeable(_contractAddresses.asset));
        _transferOwnership(_contractAddresses.owner);

        // Token = _contractAddresses.Token;
        lockedDepositNft = INft(_contractAddresses.lockedDepositNft);
        manager = _contractAddresses.manager;
        admin = _contractAddresses.admin;
        pnlHandler = _contractAddresses.pnlHandler;
        openTradesPnlFeed = IOpenTradesPnlFeed(
            _contractAddresses.openTradesPnlFeed
        );
        // PriceProvider = _contractAddresses.PriceProvider;

        MIN_LOCK_DURATION = _MIN_LOCK_DURATION;

        maxAccOpenPnlDelta = _maxAccOpenPnlDelta;
        maxdailyAccPnlDelta = _maxdailyAccPnlDelta;
        withdrawLockThresholdsP = _withdrawLockThresholdsP;
        maxSupplyIncreaseDailyP = _maxSupplyIncreaseDailyP;
        lossesBurnP = _lossesBurnP;
        maxSupplyMintDailyP = _maxSupplyMintDailyP;
        maxDiscountP = _maxDiscountP;
        maxDiscountThresholdP = _maxDiscountThresholdP;

        shareToAssetsPrice = PRECISION;
        currentEpoch = 1;
        currentEpochStart = block.timestamp;
        WITHDRAW_EPOCHS_LOCKS = [3, 2, 1];
    }

    function initializeV2() external reinitializer(2) {
        storeAccBlockWeightedMarketCap();
        totalDeposited += totalRewards; // include all already distributed rewards in totalDeposited
    }

    // Modifiers
    modifier onlyManager() {
        require(_msgSender() == manager, "ONLY_MANAGER");
        _;
    }

    modifier checks(uint assetsOrShares) {
        require(shareToAssetsPrice > 0, "PRICE_0");
        require(assetsOrShares > 0, "VALUE_0");
        _;
    }

    modifier validDiscount(uint lockDuration) {
        require(maxDiscountP > 0, "NO_ACTIVE_DISCOUNT");
        require(lockDuration >= MIN_LOCK_DURATION, "BELOW_MIN_LOCK_DURATION");
        require(lockDuration <= MAX_LOCK_DURATION, "ABOVE_MAX_LOCK_DURATION");
        _;
    }

    // Manage addresses
    function transferOwnership(address newOwner) public override onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        require(newOwner != manager && newOwner != admin, "WRONG_VALUE");
        _transferOwnership(newOwner);
    }

    function updateManager(address newValue) external onlyOwner {
        require(newValue != address(0), "ADDRESS_0");
        require(newValue != owner() && newValue != admin, "WRONG_VALUE");
        manager = newValue;
        emit AddressParamUpdated("manager", newValue);
    }

    function updateAdmin(address newValue) external onlyManager {
        require(newValue != address(0), "ADDRESS_0");
        require(newValue != owner() && newValue != manager, "WRONG_VALUE");
        admin = newValue;
        emit AddressParamUpdated("admin", newValue);
    }

    function updatePnlHandler(address newValue) external onlyOwner {
        require(newValue != address(0), "ADDRESS_0");
        pnlHandler = newValue;
        emit AddressParamUpdated("pnlHandler", newValue);
    }

    // function updatePriceProvider(PriceProvider memory newValue) external onlyManager {
    //     require(newValue.addr != address(0), "ADDRESS_0");
    //     require(newValue.signature.length > 0, "BYTES_0");
    //     PriceProvider = newValue;
    //     emit PriceProviderUpdated(newValue);
    // }

    function updateOpenTradesPnlFeed(address newValue) external onlyOwner {
        require(newValue != address(0), "ADDRESS_0");
        openTradesPnlFeed = IOpenTradesPnlFeed(newValue);
        emit AddressParamUpdated("openTradesPnlFeed", newValue);
    }

    // Manage parameters
    function updateMaxAccOpenPnlDelta(uint newValue) external onlyOwner {
        maxAccOpenPnlDelta = newValue;
        emit NumberParamUpdated("maxAccOpenPnlDelta", newValue);
    }

    function updateMaxdailyAccPnlDelta(uint newValue) external onlyManager {
        require(newValue >= MIN_WETHLY_ACC_PNL_DELTA, "BELOW_MIN");
        maxdailyAccPnlDelta = newValue;
        emit NumberParamUpdated("maxdailyAccPnlDelta", newValue);
    }

    function updateWithdrawLockThresholdsP(
        uint[2] memory newValue
    ) external onlyOwner {
        require(newValue[1] > newValue[0], "WRONG_VALUES");
        withdrawLockThresholdsP = newValue;
        emit WithdrawLockThresholdsPUpdated(newValue);
    }

    function updatemaxSupplyIncreaseDailyP(uint newValue) external onlyManager {
        require(newValue <= MAX_SUPPLY_INCREASE_DAILY_P, "ABOVE_MAX");
        maxSupplyIncreaseDailyP = newValue;
        emit NumberParamUpdated("maxSupplyIncreaseDailyP", newValue);
    }

    function updateLossesBurnP(uint newValue) external onlyManager {
        require(newValue <= MAX_LOSSES_BURN_P, "ABOVE_MAX");
        lossesBurnP = newValue;
        emit NumberParamUpdated("lossesBurnP", newValue);
    }

    function updatemaxSupplyMintDailyP(uint newValue) external onlyManager {
        require(newValue <= MAX__SUPPLY_MINT_DAILY_P, "ABOVE_MAX");
        maxSupplyMintDailyP = newValue;
        emit NumberParamUpdated("maxSupplyMintDailyP", newValue);
    }

    function updateMaxDiscountP(uint newValue) external onlyManager {
        require(newValue <= MAX_DISCOUNT_P, "ABOVE_MAX_DISCOUNT");
        maxDiscountP = newValue;
        emit NumberParamUpdated("maxDiscountP", newValue);
    }

    function updateMaxDiscountThresholdP(uint newValue) external onlyManager {
        require(newValue >= 100 * PRECISION, "BELOW_MIN");
        maxDiscountThresholdP = newValue;
        emit NumberParamUpdated("maxDiscountThresholdP", newValue);
    }

    // View helper functions
    function maxAccPnlPerToken() public view returns (uint) {
        // PRECISION
        return PRECISION + accRewardsPerToken;
    }

    function collateralizationP() public view returns (uint) {
        // PRECISION (%)
        uint _maxAccPnlPerToken = maxAccPnlPerToken();

        return
            ((
                accPnlPerTokenUsed > 0
                    ? (_maxAccPnlPerToken - uint(accPnlPerTokenUsed))
                    : (_maxAccPnlPerToken + uint(accPnlPerTokenUsed * (-1)))
            ) *
                100 *
                PRECISION) / _maxAccPnlPerToken;
    }

    // function TokenToAssetsPrice() public view returns (uint price) {
    //     // _PRECISION
    //     (bool success, bytes memory result) = PriceProvider.addr.staticcall(PriceProvider.signature);

    //     require(success == true, "_PRICE_CALL_FAILED");
    //     (price) = abi.decode(result, (uint));

    //     require(price > 0, "_TOKEN_PRICE_0");
    // }

    function withdrawEpochsTimelock() public view returns (uint) {
        uint collatP = collateralizationP();
        uint overCollatP = (collatP -
            MathUpgradeable.min(collatP, 100 * PRECISION));

        return
            overCollatP > withdrawLockThresholdsP[1]
                ? WITHDRAW_EPOCHS_LOCKS[2]
                : (
                    overCollatP > withdrawLockThresholdsP[0]
                        ? WITHDRAW_EPOCHS_LOCKS[1]
                        : WITHDRAW_EPOCHS_LOCKS[0]
                );
    }

    function lockDiscountP(
        uint collatP,
        uint lockDuration
    ) public view returns (uint) {
        return
            ((
                collatP <= 100 * PRECISION
                    ? maxDiscountP
                    : (
                        collatP <= maxDiscountThresholdP
                            ? (maxDiscountP *
                                (maxDiscountThresholdP - collatP)) /
                                (maxDiscountThresholdP - 100 * PRECISION)
                            : 0
                    )
            ) * lockDuration) / MAX_LOCK_DURATION;
    }

    function totalSharesBeingWithdrawn(
        address owner
    ) public view returns (uint shares) {
        for (
            uint i = currentEpoch;
            i <= currentEpoch + WITHDRAW_EPOCHS_LOCKS[0];
            i++
        ) {
            shares += withdrawRequests[owner][i];
        }
    }

    function sharesBeingWithdrawn(
        address owner
    ) public view returns (uint[4] memory shares, uint[4] memory epochs) {
        uint256 index;
        for (
            uint i = currentEpoch;
            i <= currentEpoch + WITHDRAW_EPOCHS_LOCKS[0];
            i++
        ) {
            if (withdrawRequests[owner][i] > 0) {
                shares[index] = withdrawRequests[owner][i];
                epochs[index] = i;
                index++;
            }
        }
    }

    function getPendingAccBlockWeightedMarketCap(
        uint currentBlock
    ) public view returns (uint) {
        return
            accBlockWeightedMarketCap +
            ((currentBlock - accBlockWeightedMarketCapLastStored) *
                PRECISION_2) /
            MathUpgradeable.max(marketCap(), 1);
    }

    // Public helper functions
    function tryUpdateCurrentMaxSupply() public {
        if (block.timestamp - lastMaxSupplyUpdate >= 24 hours) {
            currentMaxSupply =
                (totalSupply() * (PRECISION * 100 + maxSupplyIncreaseDailyP)) /
                (PRECISION * 100);
            lastMaxSupplyUpdate = block.timestamp;

            emit CurrentMaxSupplyUpdated(currentMaxSupply);
        }
    }

    function tryResetdailyAccPnlDelta() public {
        if (block.timestamp - lastDailyAccPnlDeltaReset >= 24 hours) {
            dailyAccPnlDelta = 0;
            lastDailyAccPnlDeltaReset = block.timestamp;

            emit dailyAccPnlDeltaReset();
        }
    }

    function tryNewOpenPnlRequestOrEpoch() public {
        // Fault tolerance so that activity can continue anyway
        (bool success, ) = address(openTradesPnlFeed).call(
            abi.encodeWithSignature("newOpenPnlRequestOrEpoch()")
        );
        if (!success) {
            emit OpenTradesPnlFeedCallFailed();
        }
    }

    function storeAccBlockWeightedMarketCap() public {
        uint currentBlock = ChainUtils.getBlockNumber();
        accBlockWeightedMarketCap = getPendingAccBlockWeightedMarketCap(
            currentBlock
        );
        accBlockWeightedMarketCapLastStored = currentBlock;

        emit AccBlockWeightedMarketCapStored(accBlockWeightedMarketCap);
    }

    // Private helper functions
    function updateShareToAssetsPrice() private {
        storeAccBlockWeightedMarketCap();

        shareToAssetsPrice =
            maxAccPnlPerToken() -
            (accPnlPerTokenUsed > 0 ? uint(accPnlPerTokenUsed) : uint(0)); // PRECISION
        emit ShareToAssetsPriceUpdated(shareToAssetsPrice);
    }

    function _assetIERC20() private view returns (IERC20Upgradeable) {
        return IERC20Upgradeable(asset());
    }

    // Override ERC-20 functions (prevent sending to address that is withdrawing)
    function transfer(
        address to,
        uint amount
    ) public override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        address sender = _msgSender();
        require(
            totalSharesBeingWithdrawn(sender) <= balanceOf(sender) - amount,
            "PENDING_WITHDRAWAL"
        );
        _transfer(sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint amount
    ) public override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        require(
            totalSharesBeingWithdrawn(from) <= balanceOf(from) - amount,
            "PENDING_WITHDRAWAL"
        );
        _spendAllowance(from, _msgSender(), amount);
        _transfer(from, to, amount);
        return true;
    }

    // Override ERC-4626 view functions
    function decimals()
        public
        view
        override(ERC20Upgradeable, ERC4626Upgradeable)
        returns (uint8)
    {
        return ERC4626Upgradeable.decimals();
    }

    function _convertToShares(
        uint assets,
        MathUpgradeable.Rounding rounding
    ) internal view override returns (uint shares) {
        return assets.mulDiv(PRECISION, shareToAssetsPrice, rounding);
    }

    function _convertToAssets(
        uint shares,
        MathUpgradeable.Rounding rounding
    ) internal view override returns (uint assets) {
        // Prevent overflow when called from maxDeposit with maxMint = uint.max
        if (shares == type(uint).max && shareToAssetsPrice >= PRECISION) {
            return shares;
        }
        return shares.mulDiv(shareToAssetsPrice, PRECISION, rounding);
    }

    function maxMint(address) public view override returns (uint) {
        return
            accPnlPerTokenUsed > 0
                ? currentMaxSupply -
                    MathUpgradeable.min(currentMaxSupply, totalSupply())
                : type(uint).max;
    }

    function maxDeposit(address owner) public view override returns (uint) {
        return _convertToAssets(maxMint(owner), MathUpgradeable.Rounding.Down);
    }

    function maxRedeem(address owner) public view override returns (uint) {
        return
            openTradesPnlFeed.nextEpochValuesRequestCount() == 0
                ? MathUpgradeable.min(
                    withdrawRequests[owner][currentEpoch],
                    totalSupply() - 1
                )
                : 0;
    }

    function maxWithdraw(address owner) public view override returns (uint) {
        return
            _convertToAssets(maxRedeem(owner), MathUpgradeable.Rounding.Down);
    }

    // Override ERC-4626 interactions (call scaleVariables on every deposit / withdrawal)
    function deposit(
        uint assets,
        address receiver
    ) public override checks(assets) returns (uint) {
        require(
            assets <= maxDeposit(receiver),
            "ERC4626: deposit more than max"
        );

        uint shares = previewDeposit(assets);
        scaleVariables(shares, assets, true);

        _deposit(_msgSender(), receiver, assets, shares);
        return shares;
    }

    function mint(
        uint shares,
        address receiver
    ) public override checks(shares) returns (uint) {
        require(shares <= maxMint(receiver), "ERC4626: mint more than max");

        uint assets = previewMint(shares);
        scaleVariables(shares, assets, true);

        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    function withdraw(
        uint assets,
        address receiver,
        address owner
    ) public override checks(assets) returns (uint) {
        require(
            assets <= maxWithdraw(owner),
            "ERC4626: withdraw more than max"
        );

        uint shares = previewWithdraw(assets);
        withdrawRequests[owner][currentEpoch] -= shares;

        scaleVariables(shares, assets, false);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        return shares;
    }

    function redeem(
        uint shares,
        address receiver,
        address owner
    ) public override checks(shares) returns (uint) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        withdrawRequests[owner][currentEpoch] -= shares;

        uint assets = previewRedeem(shares);
        scaleVariables(shares, assets, false);

        _withdraw(_msgSender(), receiver, owner, assets, shares);
        return assets;
    }

    function scaleVariables(uint shares, uint assets, bool isDeposit) private {
        uint supply = totalSupply();

        if (accPnlPerToken < 0) {
            accPnlPerToken =
                (accPnlPerToken * int(supply)) /
                (isDeposit ? int(supply + shares) : int(supply - shares));
        } else if (accPnlPerToken > 0) {
            totalLiability +=
                ((int(shares) * totalLiability) / int(supply)) *
                (isDeposit ? int(1) : int(-1));
        }

        totalDeposited = isDeposit
            ? totalDeposited + assets
            : totalDeposited - assets;

        storeAccBlockWeightedMarketCap();
    }

    // Withdraw requests (need to be done before calling 'withdraw' / 'redeem')
    function makeWithdrawRequest(uint shares, address owner) external {
        require(
            openTradesPnlFeed.nextEpochValuesRequestCount() == 0,
            "END_OF_EPOCH"
        );

        address sender = _msgSender();
        uint allowance = allowance(owner, sender);
        require(
            sender == owner || (allowance > 0 && allowance >= shares),
            "NOT_ALLOWED"
        );

        require(
            totalSharesBeingWithdrawn(owner) + shares <= balanceOf(owner),
            "MORE_THAN_BALANCE"
        );

        uint unlockEpoch = currentEpoch + withdrawEpochsTimelock();
        withdrawRequests[owner][unlockEpoch] += shares;

        emit WithdrawRequested(
            sender,
            owner,
            shares,
            currentEpoch,
            unlockEpoch
        );
    }

    function cancelWithdrawRequest(
        uint shares,
        address owner,
        uint unlockEpoch
    ) external {
        require(
            shares <= withdrawRequests[owner][unlockEpoch],
            "MORE_THAN_WITHDRAW_AMOUNT"
        );

        address sender = _msgSender();
        uint allowance = allowance(owner, sender);
        require(
            sender == owner || (allowance > 0 && allowance >= shares),
            "NOT_ALLOWED"
        );

        withdrawRequests[owner][unlockEpoch] -= shares;

        emit WithdrawCanceled(sender, owner, shares, currentEpoch, unlockEpoch);
    }

    // Locked and discounted deposits
    function depositWithDiscountAndLock(
        uint assets,
        uint lockDuration,
        address receiver
    ) external checks(assets) validDiscount(lockDuration) returns (uint) {
        uint simulatedAssets = (assets *
            (PRECISION *
                100 +
                lockDiscountP(collateralizationP(), lockDuration))) /
            (PRECISION * 100);

        require(
            simulatedAssets <= maxDeposit(receiver),
            "DEPOSIT_MORE_THAN_MAX"
        );

        return
            _executeDiscountAndLock(
                simulatedAssets,
                assets,
                previewDeposit(simulatedAssets),
                lockDuration,
                receiver
            );
    }

    function mintWithDiscountAndLock(
        uint shares,
        uint lockDuration,
        address receiver
    ) external checks(shares) validDiscount(lockDuration) returns (uint) {
        require(shares <= maxMint(receiver), "MINT_MORE_THAN_MAX");
        uint assets = previewMint(shares);

        return
            _executeDiscountAndLock(
                assets,
                (assets * (PRECISION * 100)) /
                    (PRECISION *
                        100 +
                        lockDiscountP(collateralizationP(), lockDuration)),
                shares,
                lockDuration,
                receiver
            );
    }

    function _executeDiscountAndLock(
        uint assets,
        uint assetsDeposited,
        uint shares,
        uint lockDuration,
        address receiver
    ) private returns (uint) {
        require(assets > assetsDeposited, "NO_DISCOUNT");

        uint depositId = ++lockedDepositsCount;
        uint assetsDiscount = assets - assetsDeposited;

        LockedDeposit storage d = lockedDeposits[depositId];
        d.owner = receiver;
        d.shares = shares;
        d.assetsDeposited = assetsDeposited;
        d.assetsDiscount = assetsDiscount;
        d.atTimestamp = block.timestamp;
        d.lockDuration = lockDuration;

        scaleVariables(shares, assetsDeposited, true);
        address sender = _msgSender();
        _deposit(sender, address(this), assetsDeposited, shares);

        totalDiscounts += assetsDiscount;
        totalLockedDiscounts += assetsDiscount;

        lockedDepositNft.mint(receiver, depositId);

        emit DepositLocked(sender, d.owner, depositId, d);
        return depositId;
    }

    function unlockDeposit(uint depositId, address receiver) external {
        LockedDeposit storage d = lockedDeposits[depositId];

        address sender = _msgSender();
        address owner = lockedDepositNft.ownerOf(depositId);

        require(
            owner == sender ||
                lockedDepositNft.getApproved(depositId) == sender ||
                lockedDepositNft.isApprovedForAll(owner, sender),
            "NOT_ALLOWED"
        );
        require(
            block.timestamp >= d.atTimestamp + d.lockDuration,
            "NOT_UNLOCKED"
        );

        int accPnlDelta = int(
            d.assetsDiscount.mulDiv(
                PRECISION,
                totalSupply(),
                MathUpgradeable.Rounding.Up
            )
        );

        accPnlPerToken += accPnlDelta;
        require(
            accPnlPerToken <= int(maxAccPnlPerToken()),
            "NOT_ENOUGH_ASSETS"
        );

        lockedDepositNft.burn(depositId);

        accPnlPerTokenUsed += accPnlDelta;
        updateShareToAssetsPrice();

        totalLiability += int(d.assetsDiscount);
        totalLockedDiscounts -= d.assetsDiscount;

        _transfer(address(this), receiver, d.shares);

        emit DepositUnlocked(sender, receiver, owner, depositId, d);
    }

    // Distributes a reward evenly to all stakers of the vault
    function distributeReward(uint assets) external {
        address sender = _msgSender();
        SafeERC20Upgradeable.safeTransferFrom(
            _assetIERC20(),
            sender,
            address(this),
            assets
        );

        accRewardsPerToken += (assets * PRECISION) / totalSupply();
        updateShareToAssetsPrice();

        totalRewards += assets;
        totalDeposited += assets;

        emit RewardDistributed(sender, assets);
    }

    // PnL interactions (happens often, so also used to trigger other actions)
    function sendAssets(uint assets, address receiver) external {
        address sender = _msgSender();
        require(sender == pnlHandler, "ONLY_TRADING_PNL_HANDLER");

        int accPnlDelta = int(
            assets.mulDiv(PRECISION, totalSupply(), MathUpgradeable.Rounding.Up)
        );

        accPnlPerToken += accPnlDelta;
        require(
            accPnlPerToken <= int(maxAccPnlPerToken()),
            "NOT_ENOUGH_ASSETS"
        );

        tryResetdailyAccPnlDelta();
        dailyAccPnlDelta += accPnlDelta;
        require(dailyAccPnlDelta <= int(maxdailyAccPnlDelta), "MAX_WETHLY_PNL");

        totalLiability += int(assets);
        totalClosedPnl += int(assets);

        tryNewOpenPnlRequestOrEpoch();
        tryUpdateCurrentMaxSupply();

        SafeERC20Upgradeable.safeTransfer(_assetIERC20(), receiver, assets);

        emit AssetsSent(sender, receiver, assets);
    }

    function receiveAssets(uint assets, address user) external {
        address sender = _msgSender();
        SafeERC20Upgradeable.safeTransferFrom(
            _assetIERC20(),
            sender,
            address(this),
            assets
        );

        uint assetsLessDeplete = assets;

        if (accPnlPerTokenUsed < 0 && accPnlPerToken < 0) {
            uint depleteAmount = (assets * lossesBurnP) / PRECISION / 100;
            assetsToDeplete += depleteAmount;
            assetsLessDeplete -= depleteAmount;
        }

        int accPnlDelta = int((assetsLessDeplete * PRECISION) / totalSupply());
        accPnlPerToken -= accPnlDelta;

        tryResetdailyAccPnlDelta();
        dailyAccPnlDelta -= accPnlDelta;

        totalLiability -= int(assetsLessDeplete);
        totalClosedPnl -= int(assetsLessDeplete);

        tryNewOpenPnlRequestOrEpoch();
        tryUpdateCurrentMaxSupply();

        emit AssetsReceived(sender, user, assets, assetsLessDeplete);
    }

    // //  mint / burn mechanism
    // function deplete(uint assets) external {
    //     require(assets <= assetsToDeplete, "AMOUNT_TOO_BIG");
    //     assetsToDeplete -= assets;

    //     uint amount = assets.mulDiv(_PRECISION, TokenToAssetsPrice(), MathUpgradeable.Rounding.Up);

    //     address sender = _msgSender();
    //     IToken(Token).burn(sender, amount);

    //     totalDepleted += assets;
    //     totalDepleted += amount;

    //     SafeERC20Upgradeable.safeTransfer(_assetIERC20(), sender, assets);

    //     emit Depleted(sender, assets, amount);
    // }

    // function refill(uint assets) external {
    //     require(accPnlPerTokenUsed > 0, "NOT_UNDER_COLLATERALIZED");

    //     uint supply = totalSupply();
    //     require(assets <= (uint(accPnlPerTokenUsed) * supply) / PRECISION, "AMOUNT_TOO_BIG");

    //     if (block.timestamp - lastdailyMintedReset >= 24 hours) {
    //         dailyMinted = 0;
    //         lastdailyMintedReset = block.timestamp;
    //     }

    //     uint amount = (assets * _PRECISION) / TokenToAssetsPrice();
    //     dailyMinted += amount;

    //     require(
    //         dailyMinted <= (maxSupplyMintDailyP * IERC20Upgradeable(Token).totalSupply()) / PRECISION / 100,
    //         "ABOVE_INFLATION_LIMIT"
    //     );

    //     address sender = _msgSender();
    //     SafeERC20Upgradeable.safeTransferFrom(_assetIERC20(), sender, address(this), assets);

    //     int accPnlDelta = int((assets * PRECISION) / supply);
    //     accPnlPerToken -= accPnlDelta;
    //     accPnlPerTokenUsed -= accPnlDelta;
    //     updateShareToAssetsPrice();

    //     totalRefilled += assets;
    //     totalRefilled += amount;

    //     IToken(Token).mint(sender, amount);

    //     emit Refilled(sender, assets, amount);
    // }

    // Updates shareToAssetsPrice based on the new PnL and starts a new epoch
    function updateAccPnlPerTokenUsed(
        uint prevPositiveOpenPnl, // 1e18
        uint newPositiveOpenPnl // 1e18
    ) external returns (uint) {
        address sender = _msgSender();
        require(sender == address(openTradesPnlFeed), "ONLY_PNL_FEED");

        int delta = int(newPositiveOpenPnl) - int(prevPositiveOpenPnl); // 1e18
        uint supply = totalSupply();

        int maxDelta = int(
            MathUpgradeable.min(
                (uint(int(maxAccPnlPerToken()) - accPnlPerToken) * supply) /
                    PRECISION,
                (maxAccOpenPnlDelta * supply) / PRECISION
            )
        ); // 1e18

        delta = delta > maxDelta ? maxDelta : delta;

        accPnlPerToken += (delta * int(PRECISION)) / int(supply);
        totalLiability += delta;

        accPnlPerTokenUsed = accPnlPerToken;
        updateShareToAssetsPrice();

        currentEpoch++;
        currentEpochStart = block.timestamp;
        currentEpochPositiveOpenPnl = uint(int(prevPositiveOpenPnl) + delta);

        tryUpdateCurrentMaxSupply();

        emit AccPnlPerTokenUsedUpdated(
            sender,
            currentEpoch,
            prevPositiveOpenPnl,
            newPositiveOpenPnl,
            currentEpochPositiveOpenPnl,
            accPnlPerTokenUsed
        );

        return currentEpochPositiveOpenPnl;
    }

    // Getters
    function getLockedDeposit(
        uint depositId
    ) external view returns (LockedDeposit memory) {
        return lockedDeposits[depositId];
    }

    function tvl() public view returns (uint) {
        return (maxAccPnlPerToken() * totalSupply()) / PRECISION; // 1e18
    }

    function availableAssets() public view returns (uint) {
        return
            (uint(int(maxAccPnlPerToken()) - accPnlPerTokenUsed) *
                totalSupply()) / PRECISION; // 1e18
    }

    // To be compatible with old pairs storage contract v6 (to be used only with gWETH vault)
    function currentBalanceWETH() external view returns (uint) {
        return availableAssets(); // 1e18
    }

    function marketCap() public view returns (uint) {
        return (totalSupply() * shareToAssetsPrice) / PRECISION; // 1e18
    }
}
