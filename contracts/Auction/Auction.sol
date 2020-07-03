pragma solidity ^0.5.9;

import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../common/TokenTransfer.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionTagAlong.sol";
import "../InterFaces/IAuctionProtection.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IAuctionLiquadity.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IToken.sol";
import "../InterFaces/IWhiteList.sol";

interface InitializeInterface {
    function initialize(
        uint256 _startTime,
        uint256 _minAuctionTime,
        uint256 _interval,
        address _primaryOwner,
        address _systemAddress,
        address _multisigAddress,
        address _registeryAddress
    ) external;
}

contract AuctionRegistery is ProxyOwnable, AuctionRegisteryContracts {
    IAuctionRegistery public contractsRegistry;

    address payable public whiteListAddress;
    address payable public smartSwapAddress;
    address payable public currencyPricesAddress;
    address payable public vaultAddress;
    address payable public mainTokenAddress;
    address payable public auctionProtectionAddress;
    address payable public liquadityAddress;
    address payable public companyFundWalletAddress;
    address payable public companyTokenWalletAddress;

    function updateRegistery(address _address)
        external
        onlyAuthorized()
        notZeroAddress(_address)
        returns (bool)
    {
        contractsRegistry = IAuctionRegistery(_address);
        _updateAddresses();
        return true;
    }

    function getAddressOf(bytes32 _contractName)
        internal
        view
        returns (address payable)
    {
        return contractsRegistry.getAddressOf(_contractName);
    }

    /**@dev updates all the address from the registry contract
    this decision was made to save gas that occurs from calling an external view function */

    function _updateAddresses() internal {
        whiteListAddress = getAddressOf(WHITE_LIST);
        smartSwapAddress = getAddressOf(SMART_SWAP);
        currencyPricesAddress = getAddressOf(CURRENCY);
        vaultAddress = getAddressOf(VAULT);
        mainTokenAddress = getAddressOf(MAIN_TOKEN);
        auctionProtectionAddress = getAddressOf(AUCTION_PROTECTION);
        liquadityAddress = getAddressOf(LIQUADITY);
        companyFundWalletAddress = getAddressOf(COMPANY_FUND_WALLET);
        companyTokenWalletAddress = getAddressOf(COMPANY_MAIN_TOKEN_WALLET);
    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
    }
}

contract AuctionUtils is AuctionRegistery {
    uint256 public constant PRICE_NOMINATOR = 10**9;

    uint256 public constant DECIMAL_NOMINATOR = 10**18;

    // allowed contarct limit the contribution
    uint256 public maxContributionAllowed;

    // managment fee to run auction cut from basesupply
    uint256 public mangmentFee;

    uint256 public stacking;

    // fund that will be locked in contacrt
    uint256 public downSideProtectionRatio;

    // Fund goes to companyWallet
    uint256 public fundWalletRatio;

    // if contribution reach above yesterdayContribution groupBonus multiplyer
    uint256 public groupBonusRatio;

    // user neeed this amount of mainToken to contribute
    uint256 public mainTokenRatio;

    // how much buffer we allow to user contribute more
    uint256 public bufferLimit;

    //ByDefault it false
    bool public mainTokencheckOn;

    function initializeUtils() internal {
        maxContributionAllowed = 150;
        mangmentFee = 2;
        stacking = 1;
        downSideProtectionRatio = 90;
        fundWalletRatio = 90;
        groupBonusRatio = 2;
        mainTokenRatio = 100;
        bufferLimit = 105;
    }

    function setGroupBonusRatio(uint256 _groupBonusRatio)
        external
        onlyOwner()
        returns (bool)
    {
        groupBonusRatio = _groupBonusRatio;
        return true;
    }

    function setBufferLimit(uint256 _bufferLimit)
        external
        onlyOwner()
        returns (bool)
    {
        bufferLimit = _bufferLimit;
        return true;
    }

    function setDownSideProtectionRatio(uint256 _ratio)
        external
        onlyOwner()
        returns (bool)
    {
        require(_ratio < 100, "ERR_SHOULD_BE_LESS_THAN_100");
        downSideProtectionRatio = _ratio;
        return true;
    }

    function setfundWalletRatio(uint256 _ratio)
        external
        onlyOwner()
        returns (bool)
    {
        require(_ratio < 100, "ERR_SHOULD_BE_LESS_THAN_100");
        fundWalletRatio = _ratio;
        return true;
    }

    function setMainTokenRatio(uint256 _ratio)
        external
        onlyOwner()
        returns (bool)
    {
        mainTokenRatio = _ratio;
        return true;
    }

    function setMainTokenCheckOn(bool _mainTokencheckOn)
        external
        onlyOwner()
        returns (bool)
    {
        mainTokencheckOn = _mainTokencheckOn;
        return true;
    }

    function setMaxContributionAllowed(uint256 _maxContributionAllowed)
        external
        onlyOwner()
        returns (bool)
    {
        maxContributionAllowed = _maxContributionAllowed;
        return true;
    }
}

contract AuctionFormula is SafeMath, TokenTransfer {
    //calculate Fund On each day how much user get
    // split between to _returnAmount totalAmount which user get
    // _userAmount is which user get other token is locked
    function calcuateAuctionTokenDistrubution(
        uint256 dayWiseContributionByWallet,
        uint256 dayWiseSupplyCore,
        uint256 dayWiseSupplyBonus,
        uint256 dayWiseContribution,
        uint256 downSideProtectionRatio
    ) internal pure returns (uint256, uint256) {
        uint256 _dayWiseSupplyCore = safeDiv(
            safeMul(dayWiseSupplyCore, dayWiseContributionByWallet),
            dayWiseContribution
        );

        uint256 _dayWiseSupplyBonus = 0;
        if (dayWiseSupplyBonus > 0)
            _dayWiseSupplyBonus = safeDiv(
                safeMul(dayWiseSupplyBonus, dayWiseContributionByWallet),
                dayWiseContribution
            );
        uint256 _returnAmount = safeAdd(
            _dayWiseSupplyCore,
            _dayWiseSupplyBonus
        );

        // user get only 100 - downSideProtectionRatio(90) fund only other fund is locked
        uint256 _userAmount = safeDiv(
            safeMul(_dayWiseSupplyCore, safeSub(100, downSideProtectionRatio)),
            100
        );

        return (_returnAmount, _userAmount);
    }

    //this method calculate fund disturbution
    // 90% fund locked in downSideProtection
    // other fund divided into LIQUADITY and companyWallet
    function calcuateAuctionFundDistrubution(
        uint256 _value,
        uint256 downSideProtectionRatio,
        uint256 fundWalletRatio
    )
        internal
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 _downsideAmount = safeDiv(
            safeMul(_value, downSideProtectionRatio),
            100
        );
        uint256 newvalue = safeSub(_value, _downsideAmount);

        uint256 _fundwallet = safeDiv(safeMul(newvalue, fundWalletRatio), 100);

        newvalue = safeSub(newvalue, _fundwallet);

        return (_downsideAmount, _fundwallet, newvalue);
    }

    function calculateNewSupply(
        uint256 todayContribution,
        uint256 tokenPrice,
        uint256 decimal
    ) internal pure returns (uint256) {
        return
            safeDiv(
                safeMul(todayContribution, safeExponent(10, decimal)),
                tokenPrice
            );
    }

    function calculateSupplyPercent(uint256 _supply, uint256 _percent)
        internal
        pure
        returns (uint256)
    {
        uint256 _tempSupply = safeDiv(
            safeMul(_supply, 100),
            safeSub(100, _percent)
        );
        uint256 _managmantFee = safeSub(_tempSupply, _supply);
        return _managmantFee;
    }
}

contract AuctionStorage is AuctionFormula, AuctionUtils {
    uint256 public auctionDay;

    // address how much invested by them in auciton till date
    mapping(address => uint256) public userTotalFund;

    // how much token recived by address in auciton till date
    mapping(address => uint256) public userTotalReturnToken;

    // day wise supply (groupBounus+coreSupply)
    mapping(uint256 => uint256) public dayWiseSupply;

    // day wise  coreSupply
    mapping(uint256 => uint256) public dayWiseSupplyCore;

    // day wise bonusSupply
    mapping(uint256 => uint256) public dayWiseSupplyBonus;

    // daywise contribution
    mapping(uint256 => uint256) public dayWiseContribution;

    // daywise markertPrice
    mapping(uint256 => uint256) public dayWiseMarketPrice;

    // dayWise downsideProtection Ratio
    mapping(uint256 => uint256) public dayWiseDownSideProtectionRatio;

    // address wise contribution each day
    mapping(uint256 => mapping(address => uint256))
        public walletDayWiseContribution;

    // day wiser five top contributor
    mapping(uint256 => mapping(uint256 => address)) public topFiveContributior;

    //contributor Index
    mapping(uint256 => mapping(address => uint256)) public topContributiorIndex;

    // check if daywise token disturbuted
    mapping(uint256 => mapping(address => bool)) public returnToken;

    // total contribution till date
    uint256 public totalContribution;

    uint256 public todayContribution;

    uint256 public yesterdayContribution;

    uint256 public allowedMaxContribution;

    uint256 public yesterdaySupply;

    uint256 public todaySupply;

    bool public auctionSoldOut;

    function initializeStorage() internal {
        auctionDay = 1;
        totalContribution = 2500000 * PRICE_NOMINATOR;
        yesterdayContribution = 500 * PRICE_NOMINATOR;
        allowedMaxContribution = 500 * PRICE_NOMINATOR;
        todaySupply = 50000 * DECIMAL_NOMINATOR;
    }
}

contract IndividualBonus is AuctionStorage {
    mapping(uint256 => uint256) public indexReturn;

    // top five contributor daywise
    mapping(uint256 => mapping(uint256 => address)) public topFiveContributior;

    //contributor Index
    mapping(uint256 => mapping(address => uint256)) public topContributiorIndex;

    function updateIndividualBonusRatio(
        uint256 X1,
        uint256 X2,
        uint256 X3,
        uint256 X4,
        uint256 X5
    ) external onlyAuthorized() returns (bool) {
        indexReturn[1] = X1;
        indexReturn[2] = X2;
        indexReturn[3] = X3;
        indexReturn[4] = X4;
        indexReturn[5] = X5;
        return true;
    }

    function _comprareForGroupBonus(address _from) internal {
        address contributor;
        uint256 topContributior;
        bool replaced = false;
        address replaceWith;


            uint256 contributionByUser
         = walletDayWiseContribution[auctionDay][_from];


            uint256 smallestContributionByUser
         = walletDayWiseContribution[auctionDay][topFiveContributior[auctionDay][5]];
        if (contributionByUser > smallestContributionByUser) {
            for (uint256 x = 1; x <= 5; x++) {
                contributor = topFiveContributior[auctionDay][x];
                topContributior = walletDayWiseContribution[auctionDay][contributor];
                if (contributionByUser > topContributior && replaced == false) {
                    topFiveContributior[auctionDay][x] = _from;
                    topContributiorIndex[auctionDay][_from] = x;
                    replaceWith = contributor;
                    replaced = true;
                } else if (replaced && replaceWith != _from) {
                    topFiveContributior[auctionDay][x] = replaceWith;
                    topContributiorIndex[auctionDay][replaceWith] = x;
                    replaceWith = contributor;
                }
            }
            if (replaceWith != address(0) && replaceWith != _from)
                topContributiorIndex[auctionDay][replaceWith] = 0;
        }
    }

    function calculateBouns(uint256 _auctionDay, address _from)
        external
        view
        returns (uint256)
    {
        return _calculateBouns(_auctionDay, _from);
    }

    function _calculateBouns(uint256 _auctionDay, address _from)
        internal
        view
        returns (uint256)
    {
        return indexReturn[topContributiorIndex[_auctionDay][_from]];
    }
}

contract AuctionFundCollector is IndividualBonus {
    event FundAdded(
        uint256 indexed _auctionDayId,
        uint256 _todayContribution,
        address indexed _fundBy,
        address indexed _fundToken,
        uint256 _fundAmount,
        uint256 _fundValue,
        uint256 _totalFund,
        uint256 _marketPrice
    );

    // check before contribution
    function _checkContribution(address _from) internal view returns (bool) {
        require(
            IWhiteList(whiteListAddress).isAllowedInAuction(_from),
            "ERR_NOT_ALLOWED_IN_AUCTION"
        );
        return true;
    }

    function mainTokenCheck(address _from, uint256 _contributedAmount)
        internal
        returns (bool)
    {
        IERC20Token mainToken = IERC20Token(mainTokenAddress);

        uint256 _mainTokenPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(mainTokenAddress);

        uint256 _tokenAmount = safeDiv(
            safeMul(
                safeDiv(
                    safeMul(mainToken.balanceOf(_from), mainTokenRatio),
                    100
                ),
                _mainTokenPrice
            ),
            safeExponent(10, mainToken.decimals())
        );

        require(
            _tokenAmount >=
                safeAdd(
                    walletDayWiseContribution[auctionDay][_from],
                    _contributedAmount
                ),
            "ERR_USER_DONT_HAVE_EQUAL_BALANCE"
        );

        uint256 lockToken = safeDiv(
            safeAdd(
                walletDayWiseContribution[auctionDay][_from],
                _contributedAmount
            ),
            _mainTokenPrice
        );

        IToken(mainTokenAddress).lockToken(_from, lockToken, now);
    }

    function fundAdded(
        address _token,
        uint256 _amount,
        uint256 _decimal,
        address _from,
        uint256 currentMarketPrice
    ) internal {
        require(auctionSoldOut == false, "ERR_AUCTION_SOLD_OUT");

        uint256 _currencyPrices = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(_token);

        uint256 _contributedAmount = safeDiv(
            safeMul(_amount, _currencyPrices),
            safeExponent(10, _decimal)
        );

        if (mainTokencheckOn) {
            mainTokenCheck(_from, _contributedAmount);
        }

        // allow five percent more for buffer
        // Allow five percent more because of volatility in ether price
        if (
            safeAdd(todayContribution, _contributedAmount) >=
            allowedMaxContribution
        ) {
            require(
                safeDiv(safeMul(allowedMaxContribution, bufferLimit), 100) >=
                    safeAdd(todayContribution, _contributedAmount),
                "ERR_CONTRIBUTION_LIMIT_REACH"
            );

            auctionSoldOut = true;
        }

        todayContribution = safeAdd(todayContribution, _contributedAmount);

        walletDayWiseContribution[auctionDay][_from] = safeAdd(
            walletDayWiseContribution[auctionDay][_from],
            _contributedAmount
        );

        userTotalFund[_from] = safeAdd(
            userTotalFund[_from],
            _contributedAmount
        );

        dayWiseContribution[auctionDay] = safeAdd(
            dayWiseContribution[auctionDay],
            _contributedAmount
        );

        _comprareForGroupBonus(_from);

        emit FundAdded(
            auctionDay,
            todayContribution,
            _from,
            _token,
            _amount,
            _contributedAmount,
            walletDayWiseContribution[auctionDay][_from],
            currentMarketPrice
        );
    }

    function _contributeWithEther(uint256 _value, address _from)
        internal
        returns (bool)
    {
        (
            uint256 downSideAmount,
            uint256 fundWalletamount,
            uint256 reserveAmount
        ) = calcuateAuctionFundDistrubution(
            _value,
            dayWiseDownSideProtectionRatio[auctionDay],
            fundWalletRatio
        );

        IAuctionProtection(auctionProtectionAddress).lockEther.value(
            downSideAmount
        )(_from);

        uint256 currentMarketPrice = IAuctionLiquadity(liquadityAddress)
            .contributeWithEther
            .value(reserveAmount)();

        companyFundWalletAddress.transfer(fundWalletamount);

        fundAdded(address(0), _value, 18, _from, currentMarketPrice);
    }

    function _contributeWithToken(
        IERC20Token _token,
        uint256 _value,
        address _from
    ) internal returns (bool) {
        ensureTransferFrom(_token, _from, address(this), _value);

        (
            uint256 downSideAmount,
            uint256 fundWalletamount,
            uint256 reserveAmount
        ) = calcuateAuctionFundDistrubution(
            _value,
            dayWiseDownSideProtectionRatio[auctionDay],
            fundWalletRatio
        );

        approveTransferFrom(_token, auctionProtectionAddress, downSideAmount);

        IAuctionProtection(auctionProtectionAddress).lockTokens(
            _token,
            address(this),
            _from,
            downSideAmount
        );

        approveTransferFrom(_token, liquadityAddress, reserveAmount);

        uint256 currentMarketPrice = IAuctionLiquadity(liquadityAddress)
            .contributeWithToken(_token, address(this), reserveAmount);

        ensureTransferFrom(
            _token,
            address(this),
            companyFundWalletAddress,
            fundWalletamount
        );

        fundAdded(address(_token), _value, 18, _from, currentMarketPrice);
    }

    function contributeWithEther() external payable returns (bool) {
        require(_checkContribution(msg.sender));
        return _contributeWithEther(msg.value, msg.sender);
    }

    function contributeWithToken(IERC20Token _token, uint256 _value)
        external
        returns (bool)
    {
        require(_checkContribution(msg.sender));
        return _contributeWithToken(_token, _value, msg.sender);
    }
}

contract Auction is Upgradeable, AuctionFundCollector, InitializeInterface {
    uint256 public MIN_AUCTION_END_TIME; //epoch

    uint256 public LAST_AUCTION_START;

    uint256 public INTERVAL;

    function changeTimings(uint256 _flag, uint256 _time)
        external
        onlyAuthorized()
        returns (bool)
    {
        if (_flag == 1) MIN_AUCTION_END_TIME = _time;
        else if (_flag == 2) LAST_AUCTION_START == _time;
        else if (_flag == 3) INTERVAL == _time;
        return true;
    }

    function initialize(
        uint256 _startTime,
        uint256 _minAuctionTime,
        uint256 _interval,
        address _primaryOwner,
        address _systemAddress,
        address _multisigAddress,
        address _registeryAddress
    ) public {
        super.initialize();
        initializeOwner(_primaryOwner, _systemAddress, _multisigAddress);
        initializeStorage();
        initializeUtils();
        contractsRegistry = IAuctionRegistery(_registeryAddress);
        _updateAddresses();

        dayWiseDownSideProtectionRatio[auctionDay] = downSideProtectionRatio;
        LAST_AUCTION_START = _startTime;
        MIN_AUCTION_END_TIME = _minAuctionTime;
        INTERVAL = _interval;
        indexReturn[1] = 50;
        indexReturn[2] = 40;
        indexReturn[3] = 30;
        indexReturn[4] = 20;
        indexReturn[5] = 10;
    }

    event AuctionEnded(
        uint256 indexed _auctionDayId,
        uint256 _todaySupply,
        uint256 _yesterdaySupply,
        uint256 _todayContribution,
        uint256 _yesterdayContribution,
        uint256 _totalContribution,
        uint256 _maxContributionAllowed,
        uint256 _tokenPrice,
        uint256 _tokenMarketPrice
    );

    event FundDeposited(address _token, address indexed _from, uint256 _amount);

    event TokenDistrubuted(
        address indexed _whom,
        uint256 indexed dayId,
        uint256 _totalToken,
        uint256 lockedToken,
        uint256 _userToken
    );

    function getAuctionDetails()
        external
        view
        returns (
            uint256 _todaySupply,
            uint256 _yesterdaySupply,
            uint256 _todayContribution,
            uint256 _yesterdayContribution,
            uint256 _totalContribution,
            uint256 _maxContributionAllowed,
            uint256 _marketPrice
        )
    {
        uint256 _mainTokenPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(mainTokenAddress);

        return (
            todaySupply,
            yesterdaySupply,
            todayContribution,
            yesterdayContribution,
            totalContribution,
            allowedMaxContribution,
            _mainTokenPrice
        );
    }

    function auctionEnd() external onlySystem() returns (bool) {
        require(
            now >= safeAdd(LAST_AUCTION_START, MIN_AUCTION_END_TIME),
            "ERR_MIN_TIME_IS_NOT_OVER"
        );

        uint256 _mainTokenPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(mainTokenAddress);

        if (todayContribution == 0) {
            uint256 _ethPrice = ICurrencyPrices(currencyPricesAddress)
                .getCurrencyPrice(address(0));

            uint256 mainReserveAmount = IAuctionLiquadity(liquadityAddress)
                .contributeTowardMainReserve();

            uint256 mainReserveAmountUsd = safeDiv(
                safeMul(mainReserveAmount, _ethPrice),
                DECIMAL_NOMINATOR
            );

            dayWiseContribution[auctionDay] = mainReserveAmountUsd;

            todayContribution = mainReserveAmountUsd;

            walletDayWiseContribution[auctionDay][vaultAddress] = mainReserveAmountUsd;

            _mainTokenPrice = ICurrencyPrices(currencyPricesAddress)
                .getCurrencyPrice(mainTokenAddress);

            _comprareForGroupBonus(vaultAddress);

            emit FundAdded(
                auctionDay,
                todayContribution,
                vaultAddress,
                address(0),
                mainReserveAmount,
                mainReserveAmountUsd,
                mainReserveAmountUsd,
                _mainTokenPrice
            );
        }

        uint256 bonusSupply = 0;

        allowedMaxContribution = safeDiv(
            safeMul(todayContribution, maxContributionAllowed),
            100
        );

        if (todayContribution > yesterdayContribution) {
            uint256 _groupBonusRatio = safeMul(
                safeDiv(
                    safeMul(todayContribution, DECIMAL_NOMINATOR),
                    yesterdayContribution
                ),
                groupBonusRatio
            );

            bonusSupply = safeSub(
                safeDiv(
                    safeMul(todaySupply, _groupBonusRatio),
                    DECIMAL_NOMINATOR
                ),
                todaySupply
            );
        }

        uint256 _avgDays = 10;
        uint256 _avgInvestment = 0;

        if (auctionDay < 11 && auctionDay > 1) {
            _avgDays = safeSub(auctionDay, 1);
        }

        if (auctionDay > 1) {
            for (uint32 tempX = 1; tempX <= _avgDays; tempX++) {
                _avgInvestment = safeAdd(
                    _avgInvestment,
                    dayWiseContribution[safeSub(auctionDay, tempX)]
                );
            }

            _avgInvestment = safeDiv(
                safeMul(
                    safeDiv(_avgInvestment, _avgDays),
                    maxContributionAllowed
                ),
                100
            );
        }

        if (_avgInvestment > allowedMaxContribution) {
            allowedMaxContribution = _avgInvestment;
        }

        dayWiseSupplyCore[auctionDay] = todaySupply;
        dayWiseSupplyBonus[auctionDay] = bonusSupply;
        dayWiseSupply[auctionDay] = safeAdd(todaySupply, bonusSupply);

        uint256 stackingAmount = safeDiv(
            safeMul(dayWiseSupply[auctionDay], stacking),
            100
        );
        uint256 fee = calculateSupplyPercent(
            safeAdd(stackingAmount, dayWiseSupply[auctionDay]),
            mangmentFee
        );
        IToken(mainTokenAddress).mintTokens(safeAdd(fee, stackingAmount));
        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            address(this),
            companyTokenWalletAddress,
            fee
        );

        approveTransferFrom(
            IERC20Token(mainTokenAddress),
            auctionProtectionAddress,
            stackingAmount
        );

        IAuctionProtection(auctionProtectionAddress).stackFund(stackingAmount);

        uint256 _tokenPrice = safeDiv(
            safeMul(todayContribution, DECIMAL_NOMINATOR),
            dayWiseSupply[auctionDay]
        );

        dayWiseMarketPrice[auctionDay] = _mainTokenPrice;

        todaySupply = safeDiv(
            safeMul(todayContribution, DECIMAL_NOMINATOR),
            _mainTokenPrice
        );

        totalContribution = safeAdd(totalContribution, todayContribution);

        yesterdaySupply = dayWiseSupply[auctionDay];

        yesterdayContribution = todayContribution;

        auctionDay = safeAdd(auctionDay, 1);

        IAuctionLiquadity(liquadityAddress).auctionEnded();

        dayWiseDownSideProtectionRatio[auctionDay] = downSideProtectionRatio;

        LAST_AUCTION_START = safeAdd(LAST_AUCTION_START, INTERVAL);

        auctionSoldOut = false;

        todayContribution = 0;

        emit AuctionEnded(
            auctionDay,
            todaySupply,
            yesterdaySupply,
            todayContribution,
            yesterdayContribution,
            totalContribution,
            allowedMaxContribution,
            _tokenPrice,
            _mainTokenPrice
        );

        return true;
    }

    function disturbuteTokenInternal(uint256 dayId, address _which)
        internal
        returns (bool)
    {
        require(
            returnToken[dayId][_which] == false,
            "ERR_ALREADY_TOKEN_DISTBUTED"
        );


            uint256 dayWiseContributionByWallet
         = walletDayWiseContribution[dayId][_which];

        uint256 dayWiseContribution = dayWiseContribution[dayId];

        (
            uint256 returnAmount,
            uint256 _userAmount
        ) = calcuateAuctionTokenDistrubution(
            dayWiseContributionByWallet,
            dayWiseSupplyCore[dayId],
            dayWiseSupplyBonus[dayId],
            dayWiseContribution,
            dayWiseDownSideProtectionRatio[dayId]
        );

        uint256 _percent = _calculateBouns(dayId, _which);

        uint256 newReturnAmount = 0;

        uint256 fee = 0;

        if (_percent > 0) {
            newReturnAmount = safeDiv(safeMul(returnAmount, _percent), 100);

            fee = calculateSupplyPercent(newReturnAmount, mangmentFee);
        }

        newReturnAmount = safeAdd(returnAmount, newReturnAmount);

        IToken(mainTokenAddress).mintTokens(safeAdd(newReturnAmount, fee));

        // here we check with last auction bcz user can invest after auction start
        IToken(mainTokenAddress).lockToken(_which, 0, LAST_AUCTION_START);

        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            address(this),
            companyTokenWalletAddress,
            fee
        );
        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            address(this),
            _which,
            _userAmount
        );

        approveTransferFrom(
            IERC20Token(mainTokenAddress),
            auctionProtectionAddress,
            safeSub(newReturnAmount, _userAmount)
        );

        IAuctionProtection(auctionProtectionAddress).depositToken(
            address(this),
            _which,
            safeSub(newReturnAmount, _userAmount)
        );

        returnToken[dayId][_which] = true;
        emit TokenDistrubuted(
            _which,
            dayId,
            newReturnAmount,
            safeSub(newReturnAmount, _userAmount),
            _userAmount
        );
        return true;
    }

    function disturbuteTokens(uint256 dayId, address[] calldata _which)
        external
        onlySystem()
        returns (bool)
    {
        require(dayId < auctionDay, "ERR_AUCTION_DAY");
        for (uint256 tempX = 0; tempX < _which.length; tempX++) {
            if (returnToken[dayId][_which[tempX]] == false)
                disturbuteTokenInternal(dayId, _which[tempX]);
        }
        return true;
    }

    function disturbuteTokens(uint256 dayId) external returns (bool) {
        require(dayId < auctionDay, "ERR_AUCTION_DAY");
        disturbuteTokenInternal(dayId, msg.sender);
    }

    //In case if there is other tokens into contract
    function returnFund(
        IERC20Token _token,
        uint256 _value,
        address payable _which
    ) external onlyOwner() returns (bool) {
        if (address(_token) == address(0)) {
            _which.transfer(_value);
        } else {
            ensureTransferFrom(_token, address(this), _which, _value);
        }
        return true;
    }

    function() external payable {
        emit FundDeposited(address(0), msg.sender, msg.value);
    }
}
