pragma solidity ^0.5.9;

import "../common/Ownable.sol";
import "../common/SafeMath.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionTagAlong.sol";
import "../InterFaces/IAuctionProtection.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IAuctionLiquadity.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IToken.sol";
import "../InterFaces/IIndividualBonus.sol";
import "../InterFaces/IWhiteList.sol";
import "../InterFaces/Istacking.sol";


contract AuctionRegistery is Ownable, AuctionRegisteryContracts {
    IAuctionRegistery public contractsRegistry;

    function updateRegistery(address _address)
        external
        onlyAuthorized()
        notZeroAddress(_address)
        returns (bool)
    {
        contractsRegistry = IAuctionRegistery(_address);
        return true;
    }

    function getAddressOf(bytes32 _contractName)
        internal
        view
        returns (address payable)
    {
        return contractsRegistry.getAddressOf(_contractName);
    }

    function getAddressOfBatch(bytes32[6] memory _contractName)
        internal
        view
        returns (address payable[] memory)
    {
        return contractsRegistry.getAddressOfBatch(_contractName);
    }
}


contract AuctionUtils is AuctionRegistery {
    // allowed contarct limit the contribution
    uint256 public maxContributionAllowed = 150;

    // managment fee to run auction cut from basesupply
    uint256 public mangmentFee = 2;

    uint256 public stacking = 1;

    // fund that will be locked in contacrt
    uint256 public downSideProtectionRatio = 90;

    // Fund goes to companyWallet
    uint256 public fundWalletRatio = 90;

    // if contribution reach above yesterdayContribution groupBonus multiplyer
    uint256 public groupBonusRatio = 2;

    // user neeed this amount of mainToken to contribute
    uint256 public mainTokenRatio = 100;

    // how much buffer we allow to user contribute more
    uint256 public bufferLimit = 105;

    //ByDefault it false
    bool public mainTokencheckOn;

    function setGroupBonusRatio(uint256 _groupBonusRatio)
        external
        onlyOwner()
        returns (bool)
    {
        groupBonusRatio = _groupBonusRatio;
        return true;
    }

    function setMangmentFee(uint256 _mangmentFee)
        external
        onlyOwner()
        returns (bool)
    {
        mangmentFee = _mangmentFee;
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


contract AuctionFormula is AuctionUtils, SafeMath {
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


contract AuctionStorage is AuctionFormula {
    uint256 public auctionDay = 1;

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
    mapping(uint256 => mapping(address => uint256)) public walletDayWiseContribution;

    // day wiser five top contributor
    mapping(uint256 => mapping(uint256 => address)) public topFiveContributior;

    //contributor Index
    mapping(uint256 => mapping(address => uint256)) public topContributiorIndex;

    // check if daywiser token disturbuted
    mapping(uint256 => mapping(address => bool)) public returnToken;

    // total contribution till date
    uint256 public totalContribution = 2500000000000;

    uint256 public todayContribution = 0;

    uint256 public yesterdayContribution = 500000000;

    uint256 public allowedMaxContribution = 850000000;

    uint256 public yesterdaySupply = 0;

    uint256 public todaySupply = 50000000000000000000000;

    uint256 public tokenAuctionEndPrice = 10000;

    bool public auctionSoldOut = false;
}


contract AuctionFundCollector is AuctionStorage {
    event FundAdded(
        uint256 indexed _auctionDayId,
        uint256 _todayContribution,
        address indexed _fundBy,
        address _fundToken,
        uint256 _fundAmount,
        uint256 _fundValue,
        uint256 _marketPrice
    );

    function ensureTransferFrom(
        IERC20Token _token,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        uint256 prevBalance = _token.balanceOf(_to);
        if (_from == address(this)) _token.transfer(_to, _amount);
        else _token.transferFrom(_from, _to, _amount);
        uint256 postBalance = _token.balanceOf(_to);
        require(postBalance > prevBalance);
    }

    function approveTransferFrom(
        IERC20Token _token,
        address _spender,
        uint256 _amount
    ) internal {
        _token.approve(_spender, _amount);
    }

    // check before contribution
    function _checkContribution(address _from, uint256 _auctionDayId)
        internal
        view
        returns (bool)
    {
        require(_auctionDayId == auctionDay, "ERR_AUCTION_DAY_CHANGED");
        require(
            IWhiteList(getAddressOf(WHITE_LIST)).isWhiteListed(_from),
            "ERR_WHITELIST_CHECK"
        );
        return true;
    }

    function fundAdded(
        address _token,
        uint256 _amount,
        uint256 _decimal,
        address _from,
        uint256 currentMarketPrice
    ) internal {
        require(auctionSoldOut == false, "ERR_AUCTION_SOLD_OUT");

        uint256 _currencyPrices = ICurrencyPrices(getAddressOf(CURRENCY))
            .getCurrencyPrice(_token);

        uint256 _contributedAmount = safeDiv(
            safeMul(_amount, _currencyPrices),
            safeExponent(10, _decimal)
        );

        if (mainTokencheckOn) {
            IERC20Token mainToken = IERC20Token(getAddressOf(MAIN_TOKEN));

            uint256 _mainTokenPrice = ICurrencyPrices(getAddressOf(CURRENCY))
                .getCurrencyPrice(address(mainToken));

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
                "ERR_USER_DONT_HAVE_ENOUGH_TOKEN"
            );

            uint256 lockToken = safeDiv(
                safeAdd(
                    walletDayWiseContribution[auctionDay][_from],
                    _contributedAmount
                ),
                _mainTokenPrice
            );

            IToken(address(mainToken)).lockToken(_from, lockToken, now);
        }

        // allow five percent more for buffer
        // Allow five percent more because of volatility in ether price
        if (
            allowedMaxContribution >=
            safeAdd(todayContribution, _contributedAmount)
        ) {
            require(
                safeDiv(safeMul(allowedMaxContribution, bufferLimit), 100) >=
                    safeAdd(todayContribution, _contributedAmount),
                "ERR_CONTRIBUTION_LIMIT_REACH"
            );

            auctionSoldOut = true;
        }

        require(
            allowedMaxContribution >=
                safeAdd(todayContribution, _contributedAmount),
            "ERR_CONTRIBUTION_LIMIT_REACH"
        );

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

        address contributor;
        uint256 topContributior;


            uint256 contributionByUser
         = walletDayWiseContribution[auctionDay][_from];
        bool replaced = false;
        address replaceWith;

        for (uint256 x = 1; x <= 5; x++) {
            contributor = topFiveContributior[auctionDay][x];
            topContributior = walletDayWiseContribution[auctionDay][contributor];
            if (contributionByUser >= topContributior && replaced == false) {
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

        emit FundAdded(
            auctionDay,
            todayContribution,
            _from,
            _token,
            _amount,
            _contributedAmount,
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

        IAuctionProtection(getAddressOf(AUCTION_PROTECTION)).lockEther.value(
            downSideAmount
        )(_from);

        uint256 currentMarketPrice = IAuctionLiquadity(getAddressOf(LIQUADITY))
            .contributeWithEther
            .value(reserveAmount)();

        address payable fundWallet = getAddressOf(COMPANY_FUND_WALLET);
        fundWallet.transfer(fundWalletamount);

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

        approveTransferFrom(
            _token,
            getAddressOf(AUCTION_PROTECTION),
            downSideAmount
        );

        IAuctionProtection(getAddressOf(AUCTION_PROTECTION)).lockTokens(
            _token,
            address(this),
            _from,
            downSideAmount
        );

        approveTransferFrom(_token, getAddressOf(LIQUADITY), reserveAmount);

        uint256 currentMarketPrice = IAuctionLiquadity(getAddressOf(LIQUADITY))
            .contributeWithToken(_token, address(this), reserveAmount);

        address payable fundWallet = getAddressOf(COMPANY_FUND_WALLET);

        ensureTransferFrom(_token, address(this), fundWallet, fundWalletamount);

        fundAdded(address(_token), _value, 18, _from, currentMarketPrice);
    }

    function contributeWithEther(uint256 _auctionDayId)
        external
        payable
        returns (bool)
    {
        require(_checkContribution(msg.sender, _auctionDayId));
        return _contributeWithEther(msg.value, msg.sender);
    }

    function contributeWithToken(
        IERC20Token _token,
        uint256 _value,
        uint256 _auctionDayId
    ) external returns (bool) {
        require(_checkContribution(msg.sender, _auctionDayId));

        return _contributeWithToken(_token, _value, msg.sender);
    }
}


contract Auction is AuctionFundCollector {
    uint256 public MIN_AUCTION_END_TIME = 0; //epoch

    uint256 public LAST_AUCTION_START = 0;

    constructor(
        uint256 _startTime,
        uint256 _minAuctionTime,
        address _systemAddress,
        address _multisigAddress,
        address _registeryAddress
    ) public Ownable(_systemAddress, _multisigAddress) {
        LAST_AUCTION_START = _startTime;
        MIN_AUCTION_END_TIME = _minAuctionTime;
        contractsRegistry = IAuctionRegistery(_registeryAddress);
        dayWiseDownSideProtectionRatio[auctionDay] = downSideProtectionRatio;
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

    function auctionEnd() external onlySystem() returns (bool) {
        require(
            safeAdd(LAST_AUCTION_START, MIN_AUCTION_END_TIME) > now,
            "ERR_MIN_TIME_IS_NOT_OVER"
        );

        address payable[] memory _contractAddress = getAddressOfBatch(
            [
                VAULT,
                LIQUADITY,
                CURRENCY,
                MAIN_TOKEN,
                COMPANY_MAIN_TOKEN_WALLET,
                STACKING
            ]
        );

        uint256 _mainTokenPrice = ICurrencyPrices(_contractAddress[2])
            .getCurrencyPrice(_contractAddress[3]);

        if (todayContribution == 0) {
            uint256 _ethPrice = ICurrencyPrices(_contractAddress[2])
                .getCurrencyPrice(address(0));

            uint256 mainReserveAmount = IAuctionLiquadity(_contractAddress[1])
                .contributeTowardMainReserve();

            uint256 mainReserveAmountUsd = safeDiv(
                safeMul(mainReserveAmount, _ethPrice),
                safeExponent(10, 18)
            );

            dayWiseContribution[auctionDay] = mainReserveAmountUsd;

            todayContribution = mainReserveAmountUsd;

            walletDayWiseContribution[auctionDay][_contractAddress[0]] = mainReserveAmountUsd;

            _mainTokenPrice = ICurrencyPrices(_contractAddress[2])
                .getCurrencyPrice(address(0));

            emit FundAdded(
                auctionDay,
                todayContribution,
                _contractAddress[0],
                address(0),
                mainReserveAmount,
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
                    safeMul(todayContribution, safeExponent(10, 18)),
                    yesterdayContribution
                ),
                groupBonusRatio
            );

            bonusSupply = safeSub(
                safeDiv(
                    safeMul(todaySupply, _groupBonusRatio),
                    safeExponent(10, 18)
                ),
                todaySupply
            );
        }
        uint256 _avgDays = 10;
        uint256 _avgInvestment = 0;

        if (auctionDay < 11) {
            _avgDays = auctionDay;
        }

        for (uint32 tempX = 1; tempX <= _avgDays; tempX++) {
            _avgInvestment = safeAdd(
                _avgInvestment,
                dayWiseContribution[safeSub(auctionDay, tempX)]
            );
        }

        _avgInvestment = safeDiv(
            safeMul(safeDiv(_avgInvestment, _avgDays), maxContributionAllowed),
            100
        );

        if (_avgInvestment > allowedMaxContribution) {
            allowedMaxContribution = _avgInvestment;
        }

        dayWiseSupplyCore[auctionDay] = todaySupply;
        dayWiseSupplyBonus[auctionDay] = bonusSupply;
        dayWiseSupply[auctionDay] = safeAdd(todaySupply, bonusSupply);

        uint256 fee = calculateSupplyPercent(
            dayWiseSupply[auctionDay],
            mangmentFee
        );
        uint256 stackingAmount = calculateSupplyPercent(
            dayWiseSupply[auctionDay],
            stacking
        );

        IToken(_contractAddress[3]).mintTokens(safeAdd(fee, stackingAmount));

        ensureTransferFrom(
            IERC20Token(_contractAddress[3]),
            address(this),
            _contractAddress[4],
            fee
        );

        approveTransferFrom(
            IERC20Token(_contractAddress[3]),
            _contractAddress[5],
            stackingAmount
        );

        Istacking(_contractAddress[5]).stackFund(stackingAmount);

        uint256 _tokenPrice = safeDiv(
            safeMul(todayContribution, safeExponent(10, 18)),
            dayWiseSupply[auctionDay]
        );

        dayWiseMarketPrice[auctionDay] = _mainTokenPrice;

        todaySupply = safeDiv(
            safeMul(todayContribution, safeExponent(10, 18)),
            _mainTokenPrice
        );

        totalContribution = safeAdd(totalContribution, todayContribution);
        yesterdaySupply = dayWiseSupply[auctionDay];
        yesterdayContribution = todayContribution;
        tokenAuctionEndPrice = _mainTokenPrice;
        auctionDay = safeAdd(auctionDay, 1);
        IAuctionLiquadity(_contractAddress[1]).auctionEnded();
        dayWiseDownSideProtectionRatio[auctionDay] = downSideProtectionRatio;
        LAST_AUCTION_START = now;
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

        returnAmount = IIndividualBonus(getAddressOf(INDIDUAL_BONUS))
            .calucalteBonus(topContributiorIndex[dayId][_which], returnAmount);

        IToken(getAddressOf(MAIN_TOKEN)).mintTokens(returnAmount);
        // here we check with last auction bcz user can invest after auction start
        IToken(getAddressOf(MAIN_TOKEN)).lockToken(
            _which,
            0,
            LAST_AUCTION_START
        );

        ensureTransferFrom(
            IERC20Token(getAddressOf(MAIN_TOKEN)),
            address(this),
            _which,
            _userAmount
        );

        approveTransferFrom(
            IERC20Token(getAddressOf(MAIN_TOKEN)),
            getAddressOf(AUCTION_PROTECTION),
            safeSub(returnAmount, _userAmount)
        );

        IAuctionProtection(getAddressOf(AUCTION_PROTECTION)).depositToken(
            address(this),
            _which,
            safeSub(returnAmount, _userAmount)
        );

        returnToken[dayId][_which] = true;

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
        revert();
    }
}
