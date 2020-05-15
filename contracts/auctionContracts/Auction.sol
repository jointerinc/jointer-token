pragma solidity ^0.5.9;

import "../common/Ownable.sol";
import "../common/SafeMath.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionTagAlong.sol";
import "../InterFaces/IAuctionFormula.sol";
import "../InterFaces/IAuctionProtection.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IAuctionLiquadity.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IToken.sol";
import "../InterFaces/IIndividualBonus.sol";
import "../InterFaces/IWhiteList.sol";


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
}


contract AuctionUtils is AuctionRegistery {
    
    uint256 public maxContributionAllowed = 150;

    uint256 public mangmentFee = 2;

    uint256 public downSideProtectionRatio = 90;

    uint256 public fundWalletRatio = 90;

    uint256 public groupBonusRatio = 2;
    
    uint256 public mainTokenRatio = 100;
    
    bool public mainTokencheckOn = false;
    
    

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
    
    function setMainTokenCheckOn(bool _mainTokencheckOn)  external
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


contract AuctionStorage is AuctionUtils {
    uint256 public auctionDay = 1;

    mapping(address => uint256) public userTotalFund;

    mapping(address => uint256) public userTotalReturnToken;

    mapping(uint256 => uint256) public dayWiseSupply;

    mapping(uint256 => uint256) public dayWiseSupplyCore;

    mapping(uint256 => uint256) public dayWiseSupplyBonus;

    mapping(uint256 => uint256) public dayWiseContribution;

    mapping(uint256 => uint256) public dayWiseMarketPrice;

    mapping(uint256 => uint256) public dayWiseAuctionPrice;
    
    mapping(uint256 => uint256) public dayWiseDownSideProtectionRatio;

    mapping(uint256 => mapping(address => uint256)) public walletDayWiseContribution;
    
    mapping(uint256 => mapping(uint256 => address)) public topFiveContributior;
    
    mapping(uint256 => mapping(address => uint256)) public topContributiorIndex;
    
    // mapping(uint256 =>)

    mapping(uint256 => mapping(address => bool)) public returnToken;

    uint256 public totalContribution = 2500000000000;

    uint256 public todayContribution = 0;

    uint256 public yesterdayContribution = 500000000;

    uint256 public allowedMaxContribution = 850000000;

    uint256 public yesterdaySupply = 0;

    uint256 public todaySupply = 50000000000000000000000;

    uint256 public tokenAuctionEndPrice = 10000;
    
    
}


contract AuctionFundCollector is AuctionStorage, SafeMath {
    event FundAdded(
        uint256 indexed _auctionDayId,
        uint256 _todayContribution,
        address _fundBy,
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

    function _checkContribution(address _from,uint256 _auctionDayId) internal view returns(bool) {
        require(_auctionDayId == auctionDay,"ERR_AUCTION_DAY");
        require(IWhiteList(getAddressOf(WHITE_LIST)).isWhiteListed(_from),"ERR_WHITELIST_CHECK");
        return true;
    }
    

    function fundAdded(
        address _token,
        uint256 _amount,
        uint256 _decimal,
        address _from,
        uint256 currentMarketPrice
    ) internal {
        
         uint256 _currencyPrices = ICurrencyPrices(getAddressOf(CURRENCY))
            .getCurrencyPrice(_token);
        
        

        uint256 _contributedAmount = safeDiv(
            safeMul(_amount, _currencyPrices),
            safeExponent(10,_decimal)
        );
        
        
        if(mainTokencheckOn){
            
            uint256 _tokenBalance = IERC20Token(getAddressOf(MAIN_TOKEN)).balanceOf(_from);
            
            uint256 _tokenDecimal = IERC20Token(getAddressOf(MAIN_TOKEN)).decimals();
            
            uint256 _mainTokenPrice = ICurrencyPrices(getAddressOf(CURRENCY))
            .getCurrencyPrice(getAddressOf(MAIN_TOKEN));
            
            uint256 _tokenAmount = safeDiv(safeMul(safeDiv(safeMul(_tokenBalance,mainTokenRatio),100), _mainTokenPrice),safeExponent(10,_tokenDecimal));
            
            require(_tokenAmount >= safeAdd(userTotalFund[_from],_contributedAmount),"ERR_USER_DONT_HAVE_ENOUGH_TOKEN");
            
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
        
        address contributor ;
        uint256 topContributior;
        uint256 contributionByUser = walletDayWiseContribution[auctionDay][_from];
        bool replaced = false;
        address replaceWith ;
        
        for(uint x= 1 ; x <= 5 ; x++){
          contributor = topFiveContributior[auctionDay][x];
          topContributior = walletDayWiseContribution[auctionDay][contributor];
            if(contributionByUser >= topContributior && replaced == false){
                topFiveContributior[auctionDay][x] = _from;
                topContributiorIndex[auctionDay][_from] = x;
                replaceWith = contributor;
                replaced = true;
            }else if(replaced && replaceWith != _from){
                topFiveContributior[auctionDay][x] = replaceWith;
                topContributiorIndex[auctionDay][replaceWith] = x;
                replaceWith= contributor;  
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
        IAuctionFormula formula = IAuctionFormula(
            getAddressOf(AUCTION_FORMULA)
        );

        (
            uint256 downSideAmount,
            uint256 fundWalletamount,
            uint256 reserveAmount
        ) = formula.calcuateAuctionFundDistrubution(
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

        IAuctionFormula formula = IAuctionFormula(
            getAddressOf(AUCTION_FORMULA)
        );

        (
            uint256 downSideAmount,
            uint256 fundWalletamount,
            uint256 reserveAmount
        ) = formula.calcuateAuctionFundDistrubution(
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
        
        ensureTransferFrom(
            _token,
            address(this),
            fundWallet,
            fundWalletamount
        );

        fundAdded(address(_token), _value, 18, _from, currentMarketPrice);
    }

    function contributeWithEther(uint256 _auctionDayId) external payable returns (bool) {
        require(_checkContribution(msg.sender,_auctionDayId));
        return _contributeWithEther(msg.value, msg.sender);
    }

    function contributeWithToken(
        IERC20Token _token,
        uint256 _value,
        uint256 _auctionDayId
    ) external returns (bool) {
         require(
            _checkContribution(
                msg.sender,
                _auctionDayId
        ));

        return _contributeWithToken(_token, _value, msg.sender);
    }
}


contract Auction is AuctionFundCollector {
    
    uint256 public MIN_AUCTION_END_TIME = 0; //epoch

    uint256 public LAST_AUCTION_START = 0;

    constructor(uint256 _startTime,
                uint256 _minAuctionTime,address _registeryAddress) public {
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

        IAuctionFormula formula = IAuctionFormula(
            getAddressOf(AUCTION_FORMULA)
        );

        if (todayContribution == 0) {
            (
                uint256 _ethAmount,
                address[] memory _token,
                uint256[] memory _amount
            ) = IAuctionTagAlong(getAddressOf(TAG_ALONG))
                .contributeTowardAuction(yesterdayContribution);

            _contributeWithEther(_ethAmount, getAddressOf(TAG_ALONG));

            for (uint32 tempX = 0; tempX < _token.length; tempX++) {
                _contributeWithToken(
                    IERC20Token(_token[tempX]),
                    _amount[tempX],
                    getAddressOf(TAG_ALONG)
                );
            }
        }

        uint256 bonusSupply = 0;

        allowedMaxContribution = safeDiv(
            safeMul(todayContribution, maxContributionAllowed),
            100
        );

        if (todayContribution > yesterdayContribution) {
            
            uint256 _groupBonusRatio = safeMul(
                safeDiv(
                    safeMul(todayContribution, safeExponent(10,18)),
                    yesterdayContribution
                ),
                groupBonusRatio
            );

            bonusSupply = safeSub(
                safeDiv(safeMul(todaySupply, _groupBonusRatio), safeExponent(10,18)),
                todaySupply
            );
            
        } else {
            uint256 _avgDays = 10;
            
            uint256 _avgInvestment = 0;
            
            if (auctionDay < 11) {
                _avgDays = auctionDay;
            }
            
            for (uint32 tempX = 1; tempX <= _avgDays; tempX++) {
                uint256 _tempDay = safeSub(auctionDay, tempX);
                _avgInvestment = safeAdd(
                    _avgInvestment,
                    dayWiseContribution[_tempDay]
                );
            }
            
            _avgInvestment = safeDiv(safeMul(safeDiv(_avgInvestment, _avgDays),maxContributionAllowed),100);
            
            if (_avgInvestment > allowedMaxContribution) {
                allowedMaxContribution = _avgInvestment;
            }
        }

        dayWiseSupplyCore[auctionDay] = todaySupply;
        dayWiseSupplyBonus[auctionDay] = bonusSupply;
        uint256 _tempSupply = safeAdd(todaySupply, bonusSupply);
        dayWiseSupply[auctionDay] = _tempSupply;
        uint256 fee = formula.calculateMangmentFee(_tempSupply, mangmentFee);
        address token = getAddressOf(MAIN_TOKEN);
        IToken(token).mintTokens(fee);
        
        address payable companyMainTokenWallet = getAddressOf(COMPANY_MAIN_TOKEN_WALLET);
        
        ensureTransferFrom(
            IERC20Token(token),
            address(this),
            companyMainTokenWallet,
            fee
        );

        uint256 _tokenPrice = safeDiv(
            safeMul(todayContribution, safeExponent(10,18)),
            _tempSupply
        );

        uint256 _tokenMarketPrice = IAuctionLiquadity(getAddressOf(LIQUADITY))
            .getCurrentMarketPrice();

        dayWiseAuctionPrice[auctionDay] = _tokenPrice;

        dayWiseMarketPrice[auctionDay] = _tokenMarketPrice;
    
        
        todaySupply = safeDiv(
            safeMul(todayContribution, safeExponent(10,18)),
            _tokenMarketPrice
        );

        totalContribution = safeAdd(totalContribution, todayContribution);

        yesterdaySupply = _tempSupply;

        yesterdayContribution = todayContribution;

        tokenAuctionEndPrice = _tokenMarketPrice;
    
        
        IAuctionLiquadity(getAddressOf(LIQUADITY)).auctionEnded(auctionDay);
        
        
        auctionDay = safeAdd(auctionDay, 1);
        
        dayWiseDownSideProtectionRatio[auctionDay] = downSideProtectionRatio;
        
        LAST_AUCTION_START = now;
        
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
            _tokenMarketPrice
        );

        return true;
    }

    function disturbuteTokenInternal(uint256 dayId, address _which)
        internal
        returns (bool)
    {
        require(dayId < auctionDay, "ERR_AUCTION_DAY");

        require(
            returnToken[dayId][_which] == false,
            "ERR_ALREADY_TOKEN_DISTBUTED"
        );

            uint256 dayWiseContributionByWallet
         = walletDayWiseContribution[dayId][_which];

        uint256 dayWiseContribution = dayWiseContribution[dayId];

        (uint256 returnAmount, uint256 _userAmount) = IAuctionFormula(
            getAddressOf(AUCTION_FORMULA)
        )
            .calcuateAuctionTokenDistrubution(
            dayWiseContributionByWallet,
            dayWiseSupplyCore[dayId],
            dayWiseSupplyBonus[dayId],
            dayWiseContribution,
            dayWiseDownSideProtectionRatio[dayId]
        );
        
        
        
        returnAmount = IIndividualBonus(getAddressOf(INDIDUAL_BONUS))
            .calucalteBonus(topContributiorIndex[dayId][_which],returnAmount);

        IToken(getAddressOf(MAIN_TOKEN)).mintTokens(returnAmount);

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
        for (uint256 tempX = 0; tempX < _which.length; tempX++) {
            if (returnToken[dayId][_which[tempX]] == false)
                disturbuteTokenInternal(dayId, _which[tempX]);
        }
        return true;
    }

    function disturbuteTokens(uint256 dayId) external returns (bool) {
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

    function() external payable {}
}
