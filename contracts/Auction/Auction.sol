pragma solidity ^0.5.9;

import "./AuctionStorage.sol";
import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../common/TokenTransfer.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IContributionTrigger.sol";
import "../InterFaces/IBEP20Token.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IAuctionLiquidity.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IToken.sol";
import "../InterFaces/IWhiteList.sol";
import "../InterFaces/IEscrow.sol";
import "../InterFaces/IAuctionProtection.sol";

interface AuctionInitializeInterface {
    function initialize(
        uint256 _startTime,
        uint256 _minAuctionTime,
        uint256 _interval,
        uint256 _mainTokenCheckDay,
        address _primaryOwner,
        address _systemAddress,
        address _multisigAddress,
        address _registryaddress
    ) external;
}

contract RegisteryAuction is ProxyOwnable, AuctionRegisteryContracts,AuctionStorage {
    

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
    
    
    /**@dev updates the address from the registry contract*/

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
        liquidityAddress = getAddressOf(LIQUIDITY);
        companyFundWalletAddress = getAddressOf(COMPANY_FUND_WALLET);
        escrowAddress = getAddressOf(ESCROW);
        auctionProtectionAddress = getAddressOf(AUCTION_PROTECTION);

    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
        return true;
    }
}



contract AuctionUtils is RegisteryAuction{
    
    function initializeStorage() internal {
        auctionDay = 1;
        totalContribution = 2500000 * PRICE_NOMINATOR;
        yesterdayContribution = 500 * PRICE_NOMINATOR;
        allowMaxContribution = 500 * PRICE_NOMINATOR;
        todaySupply = 50000 * DECIMAL_NOMINATOR;
        maxContributionAllowed = 150;
        managementFee = 2;
        staking = 2;
        downSideProtectionRatio = 90;
        fundWalletRatio = 90;
        groupBonusRatio = 2;
        mainTokenRatio = 100;
        averageDay = 10;
        directPushToLiquidity = true;
    }
    
    modifier isAuctionStart(){
        require(now >= LAST_AUCTION_START,"ERR_AUCTION_DAY_NOT_STARTED_YET");
        _;
    }

    function setDirectPushToLiquidity(bool _bool) 
       external 
       onlySystem() 
       returns(bool)
    {
        directPushToLiquidity = _bool;
        return true;
    }

    function setGroupBonusRatio(uint256 _groupBonusRatio)
        external
        onlyOwner()
        returns (bool)
    {
        groupBonusRatio = _groupBonusRatio;
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

    function setMainTokenCheckDay(uint256 _mainTokencheckDay)
        external
        onlyOwner()
        returns (bool)
    {
        mainTokencheckDay = _mainTokencheckDay;
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

    function setstakingPercent(uint256 _staking)
        external
        onlyOwner()
        returns (bool)
    {
        staking = _staking;
        return true;
    }
    
    function setAverageDays(uint256 _averageDay)
        external
        onlyOwner()
        returns (bool)
    {
        averageDay = _averageDay;
        return true;
    }
    
}



contract AuctionFormula is SafeMath, TokenTransfer {
    
    // calculate Funds On each day to see how much the user receives
    // split between  _returnAmount totalAmount which the user receives
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

        // user receives only 10% - downSideProtectionRatio(90) fund receives the other 90% which is locked
        uint256 _userAmount = safeDiv(
            safeMul(_dayWiseSupplyCore, safeSub(100, downSideProtectionRatio)),
            100
        );

        return (_returnAmount, _userAmount);
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
        uint256 _managementFee = safeSub(_tempSupply, _supply);
        return _managementFee;
    }
}


contract IndividualBonus is AuctionFormula,AuctionUtils {
    
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

    function _compareForGroupBonus(address _from) internal {
        address contributor;
        uint256 topContributor;
        bool replaced = false;
        address replaceWith;


            uint256 contributionByUser
         = walletDayWiseContribution[auctionDay][_from];


        uint256 smallestContributionByUser
         = walletDayWiseContribution[auctionDay][topFiveContributor[auctionDay][5]];
        
        if (contributionByUser > smallestContributionByUser) {
            
            for (uint256 x = 1; x <= 5; x++) {
                contributor = topFiveContributor[auctionDay][x];
                topContributor = walletDayWiseContribution[auctionDay][contributor];
                if (
                    contributionByUser >= topContributor && replaced == false
                ) {
                    if (
                        contributor != _from &&
                        contributionByUser > topContributor
                    ) {
                        topFiveContributor[auctionDay][x] = _from;
                        topContributorIndex[auctionDay][_from] = x;
                        replaceWith = contributor;
                        replaced = true;
                    } else if (contributor == _from) {
                        replaceWith = contributor;
                        replaced = true;
                    }
                } else if (replaced && replaceWith != _from) {
                    topFiveContributor[auctionDay][x] = replaceWith;
                    topContributorIndex[auctionDay][replaceWith] = x;
                    replaceWith = contributor;
                }
            }
            
            if (replaceWith != address(0) && replaceWith != _from)
                topContributorIndex[auctionDay][replaceWith] = 0;
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
        return indexReturn[topContributorIndex[_auctionDay][_from]];
    }
}

contract AuctionFundCollector is IndividualBonus {
    
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
        IBEP20Token mainToken = IBEP20Token(mainTokenAddress);
        
        uint256 _mainTokenPrice = currentMarketPrice;

        require(_mainTokenPrice > 0, "ERR_TOKEN_PRICE_NOT_SET");
        
        uint256 lockToken = safeDiv(
            safeMul(safeAdd(
                mainTokenCheckDayWise[auctionDay][_from],
                _contributedAmount
            ),safeExponent(10, mainToken.decimals()))
            ,
            _mainTokenPrice
        );
        
        require(
            mainToken.balanceOf(_from) >= safeDiv(safeMul(lockToken,mainTokenRatio),100),
            "ERR_USER_DOES_NOT_HAVE_EQUAL_BALANCE"
        );
        
        IToken(mainTokenAddress).lockToken(_from, lockToken, now);
        return true;
    }

    // check whether the user sends more funds, if yes
    // revert whatever user send extra revert back to user
    function calculateFund(
        address _token,
        uint256 _amount,
        uint256 _decimal
    ) internal view returns (uint256,uint256) {
        
        uint256 _currencyPrices = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(_token);

        require(_currencyPrices > 0, "ERR_TOKEN_PRICE_NOT_SET");

        uint256 _contributedAmount = safeDiv(
            safeMul(_amount, _currencyPrices),
            safeExponent(10, _decimal)
        );

        if (
            safeAdd(todayContribution, _contributedAmount) >
            allowMaxContribution
        ) {
            uint256 extraAmount = safeSub(
                safeAdd(todayContribution, _contributedAmount),
                allowMaxContribution
            );
            return
                (safeDiv(
                    safeMul(extraAmount, safeExponent(10, _decimal)),
                    _currencyPrices
                ),_currencyPrices);
        }
        return (0,_currencyPrices);
    }

    function fundAdded(
        address _token,
        uint256 _amount,
        uint256 _decimal,
        address _caller,
        address _recipient,
        uint256 _currencyPrice
    ) internal returns (bool){
        

        uint256 _contributedAmount = safeDiv(
            safeMul(_amount, _currencyPrice),
            safeExponent(10, _decimal)
        );
        
        // Here we check caller balance 
        if (auctionDay >= mainTokencheckDay) {
            mainTokenCheck(_caller, _contributedAmount);
        }

        todayContribution = safeAdd(todayContribution, _contributedAmount);
        
        mainTokenCheckDayWise[auctionDay][_caller] = safeAdd(
            walletDayWiseContribution[auctionDay][_caller],
            _contributedAmount
        );
        
        walletDayWiseContribution[auctionDay][_recipient] = safeAdd(
            walletDayWiseContribution[auctionDay][_recipient],
            _contributedAmount
        );

        userTotalFund[_recipient] = safeAdd(
            userTotalFund[_recipient],
            _contributedAmount
        );

        dayWiseContribution[auctionDay] = safeAdd(
            dayWiseContribution[auctionDay],
            _contributedAmount
        );

        _compareForGroupBonus(_recipient);

        emit FundAdded(
            auctionDay,
            todayContribution,
            _recipient,
            _token,
            _amount,
            _contributedAmount,
            walletDayWiseContribution[auctionDay][_recipient],
            currentMarketPrice
        );
        
        if(_caller != _recipient){
            emit FundAddedBehalf(_caller,_recipient);
        }
            
        return true;
    }

    function _contributeWithEther(uint256 _value,address _caller,address payable _recipient)
        internal
        returns (bool)
    {
        (uint256 returnAmount,uint256 _currencyPrice) = calculateFund(address(0), _value, 18);
        
        // transfer Back Extra Amount To the _recipient
        if (returnAmount != 0) {
            _recipient.transfer(returnAmount);
            _value = safeSub(_value, returnAmount);
        }
        
        uint256 downSideAmount = safeDiv(safeMul(_value,dayWiseDownSideProtectionRatio[auctionDay]),100);
        
        IAuctionProtection(auctionProtectionAddress).lockEther.value(downSideAmount)(auctionDay,_recipient);
        if(directPushToLiquidity)
            _pushEthToLiquidity();
        
        return fundAdded(address(0), _value, 18, _caller , _recipient,_currencyPrice);
    }

    // we only start with ether we dont need any token right now
    function contributeWithEther() external payable isAuctionStart() returns (bool) {
        
        require(_checkContribution(msg.sender));
        
        return _contributeWithEther(msg.value,msg.sender,msg.sender);
    }
    
    // This Method For Exchange 
    // Exchange invests on behalf of their users
    // so we check caller maintoken balance 
    function contributeWithEtherBehalf(address payable _whom) external payable isAuctionStart() returns (bool) {
        
        require(IWhiteList(whiteListAddress).isExchangeAddress(msg.sender),ERR_AUTHORIZED_ADDRESS_ONLY);
        
        if(IWhiteList(whiteListAddress).address_belongs(_whom) == address(0)){
            IWhiteList(whiteListAddress).addWalletBehalfExchange(msg.sender,_whom);
        }
        
        require(IWhiteList(whiteListAddress).address_belongs(_whom) == msg.sender);
        
        return _contributeWithEther(msg.value,msg.sender,_whom);
    }
    
    function updateCurrentMarketPrice() external returns (bool){
        currentMarketPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(mainTokenAddress);
        
        return true;
    }
    
    
    function pushEthToLiquidity() external returns(bool){
        return _pushEthToLiquidity();
    }
    
    function _pushEthToLiquidity() internal returns(bool){
        
        uint256 pushToLiquidity = address(this).balance;
        
        if(pushToLiquidity > 0){
            
            uint256 realEstateAmount = safeDiv(safeMul(pushToLiquidity,fundWalletRatio),100);                
            companyFundWalletAddress.transfer(realEstateAmount); 
            uint256 reserveAmount = safeSub(pushToLiquidity,realEstateAmount);
            currentMarketPrice = IAuctionLiquidity(liquidityAddress)
             .contributeWithEther
             .value(reserveAmount)();
             
        }
        return true;
    }
    
}

contract Auction is Upgradeable, AuctionFundCollector, AuctionInitializeInterface {
    

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
        uint256 _mainTokenCheckDay,
        address _primaryOwner,
        address _systemAddress,
        address _multisigAddress,
        address _registryaddress
    ) public {
        super.initialize();
        initializeOwner(_primaryOwner, _systemAddress, _multisigAddress);
        contractsRegistry = IAuctionRegistery(_registryaddress);
        initializeStorage();
        _updateAddresses();
        dayWiseDownSideProtectionRatio[auctionDay] = downSideProtectionRatio;
        LAST_AUCTION_START = _startTime;
        MIN_AUCTION_END_TIME = _minAuctionTime;
        INTERVAL = _interval;
        mainTokencheckDay = _mainTokenCheckDay;
        indexReturn[1] = 50;
        indexReturn[2] = 40;
        indexReturn[3] = 30;
        indexReturn[4] = 20;
        indexReturn[5] = 10;
    }


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
            allowMaxContribution,
            _mainTokenPrice
        );
    }

    // any one can call this method
    
    function auctionEnd() external returns (bool) {
        require(
            now >= safeAdd(LAST_AUCTION_START, MIN_AUCTION_END_TIME),
            "ERR_MIN_TIME_IS_NOT_OVER"
        );

        _pushEthToLiquidity();
        
        uint256 _mainTokenPrice = currentMarketPrice;
        
        if (todayContribution == 0) {
            
            uint256 _ethPrice = ICurrencyPrices(currencyPricesAddress)
                .getCurrencyPrice(address(0));

            uint256 mainReserveAmount = IAuctionLiquidity(liquidityAddress)
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

            _compareForGroupBonus(vaultAddress);

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

        allowMaxContribution = safeDiv(
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

        uint256 _avgDays = averageDay;
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

        if (_avgInvestment > allowMaxContribution) {
            allowMaxContribution = _avgInvestment;
        }

        dayWiseSupplyCore[auctionDay] = todaySupply;
        dayWiseSupplyBonus[auctionDay] = bonusSupply;
        dayWiseSupply[auctionDay] = safeAdd(todaySupply, bonusSupply);

        uint256 stakingAmount = safeDiv(
            safeMul(dayWiseSupply[auctionDay], staking),
            100
        );
        uint256 fee = calculateSupplyPercent(
            safeAdd(stakingAmount, dayWiseSupply[auctionDay]),
            managementFee
        );

        IToken(mainTokenAddress).mintTokens(safeAdd(fee, stakingAmount));
        
        approveTransferFrom(
            IBEP20Token(mainTokenAddress),
            escrowAddress,
            fee
        );
        
        IEscrow(escrowAddress).depositFee(fee);
        
        approveTransferFrom(
            IBEP20Token(mainTokenAddress),
            auctionProtectionAddress,
            stakingAmount
        );
        
        IAuctionProtection(auctionProtectionAddress).stackFund(stakingAmount);
    
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
        IAuctionLiquidity(liquidityAddress).auctionEnded();
        dayWiseDownSideProtectionRatio[auctionDay] = downSideProtectionRatio;
        LAST_AUCTION_START = safeAdd(LAST_AUCTION_START, INTERVAL);
        todayContribution = 0;
        emit AuctionEnded(
            auctionDay,
            todaySupply,
            yesterdaySupply,
            todayContribution,
            yesterdayContribution,
            totalContribution,
            allowMaxContribution,
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
            fee = calculateSupplyPercent(newReturnAmount, managementFee);
        }

        newReturnAmount = safeAdd(returnAmount, newReturnAmount);
        IToken(mainTokenAddress).mintTokens(safeAdd(newReturnAmount, fee));

        // here the last auction is checked because the user can invest after auction starts
        IToken(mainTokenAddress).lockToken(_which, 0, LAST_AUCTION_START);

        approveTransferFrom(
            IBEP20Token(mainTokenAddress),
            escrowAddress,
            fee
        );
        IEscrow(escrowAddress).depositFee(fee);
        
        ensureTransferFrom(
            IBEP20Token(mainTokenAddress),
            address(this),
            _which,
            _userAmount
        );
        
        approveTransferFrom(
            IBEP20Token(mainTokenAddress),
            auctionProtectionAddress,
            safeSub(newReturnAmount, _userAmount)
        );
    
        IAuctionProtection(auctionProtectionAddress).depositToken(dayId,_which,safeSub(newReturnAmount, _userAmount));
        
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
    
    // anyone can call this method 
    function disturbuteTokens(uint256 dayId, address[] calldata _which)
        external
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
        return disturbuteTokenInternal(dayId, msg.sender);
    }
    
    

    //In case if there is other tokens into contract
    function returnFund(
        IBEP20Token _token,
        uint256 _value,
        address payable _which
    ) external onlyAuthorized() returns (bool) {
        
        require(address(_token) != mainTokenAddress ,"ERR_CANT_TAKE_OUT_MAIN_TOKEN");
        ensureTransferFrom(_token, address(this), _which, _value);
        return true;
        
    }

    function() external payable {
         revert("ERR_CAN'T_FORCE_ETH");
    }
    
}