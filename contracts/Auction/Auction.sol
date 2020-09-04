pragma solidity ^0.5.9;

import "./AuctionStorage.sol";
import "../common/ProxyOwnable.sol";
import "../common/SafeMath.sol";
import "../common/TokenTransfer.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionTagAlong.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IAuctionLiquadity.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IToken.sol";
import "../InterFaces/IWhiteList.sol";
import "../InterFaces/IEscrow.sol";

interface AuctionInitializeInterface {
    function initialize(
        uint256 _startTime,
        uint256 _minAuctionTime,
        uint256 _interval,
        uint256 _mainTokenCheckDay,
        address _primaryOwner,
        address _systemAddress,
        address _multisigAddress,
        address _registeryAddress
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
        liquadityAddress = getAddressOf(LIQUADITY);
        companyFundWalletAddress = getAddressOf(COMPANY_FUND_WALLET);
        escrowAddress = getAddressOf(ESCROW);

    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
        return true;
    }
}



contract DownsideUtils is RegisteryAuction,SafeMath{
    
    function setVaultRatio(uint256 _vaultRatio)
        external
        onlyOwner()
        returns (bool)
    {
        require(_vaultRatio < 100);
        vaultRatio = _vaultRatio;
        return true;
    }
    
    function setTokenLockDuration(uint256 _tokenLockDuration)
        external
        onlyOwner()
        returns (bool)
    {
        tokenLockDuration = _tokenLockDuration;
        return true;
    }

    function isTokenLockEndDay(uint256 _LockDay) internal view returns (bool) {
        if (auctionDay > safeAdd(_LockDay, tokenLockDuration)) {
            return true;
        }
        return false;
    }
    
}
contract Stacking is
    DownsideUtils,
    TokenTransfer
{
    
    function addStackReward(uint256 _amount) internal returns (bool){
        
        if (totalTokenAmount > PERCENT_NOMINATOR){
            uint256 ratio = safeDiv(
                safeMul(_amount, safeMul(DECIMAL_NOMINATOR, PERCENT_NOMINATOR)),
                totalTokenAmount
            );
            totalTokenAmount = safeAdd(totalTokenAmount, _amount);
            dayWiseRatio[auctionDay] = ratio;
        }else{
            
            ensureTransferFrom(
                IERC20Token(mainTokenAddress),
                address(this),
                vaultAddress,
                _amount
            );
            
        }
        return true;
        
    }
    
    function addFundToStacking(address _whom, uint256 _amount)
        internal
        returns (bool)
    {
        totalTokenAmount = safeAdd(totalTokenAmount, _amount);

        roundWiseToken[_whom][auctionDay] = safeAdd(
            roundWiseToken[_whom][auctionDay],
            _amount
        );

        stackBalance[_whom] = safeAdd(stackBalance[_whom], _amount);
        if (lastRound[_whom] == 0) {
            lastRound[_whom] = auctionDay;
        }

        emit StackAdded(auctionDay, _whom, _amount);
        return true;
    }
    
    // calulcate token user have
    function calulcateStackFund(address _whom) internal view returns (uint256) {
        uint256 _lastRound = lastRound[_whom];
        uint256 _token;
        uint256 _stackToken = 0;
        if (_lastRound > 0) {
            for (uint256 x = _lastRound; x < auctionDay; x++) {
                _token = safeAdd(_token, roundWiseToken[_whom][x]);
                uint256 _tempStack = safeDiv(
                    safeMul(dayWiseRatio[x], _token),
                    safeMul(DECIMAL_NOMINATOR, PERCENT_NOMINATOR)
                );
                _stackToken = safeAdd(_stackToken, _tempStack);
                _token = safeAdd(_token, _tempStack);
            }
        }
        return _stackToken;
    }
    
    // this method disturbute Tokens
    function _claimTokens(address _which) internal returns (bool) {
        uint256 _stackToken = calulcateStackFund(_which);
        lastRound[_which] = auctionDay;
        stackBalance[_which] = safeAdd(stackBalance[_which], _stackToken);
        return true;
    }
    
    // every 5th Round system call this so token distributed
    // user also can call this
    function distributionStackInBatch(address[] calldata _which)
        external
        returns (bool)
    {
        for (uint8 x = 0; x < _which.length; x++) {
            _claimTokens(_which[x]);
        }
        return true;
    }
    
    // show stack balace with what user get
    function getStackBalance(address _whom) external view returns (uint256) {
        uint256 _stackToken = calulcateStackFund(_whom);
        return safeAdd(stackBalance[_whom], _stackToken);
    }

    // unlocking stack token
    function _unlockTokenFromStack(address _whom) internal returns (bool) {
        uint256 _stackToken = calulcateStackFund(_whom);
        uint256 actulToken = safeAdd(stackBalance[_whom], _stackToken);
        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            address(this),
            _whom,
            actulToken
        );
        totalTokenAmount = safeSub(totalTokenAmount, actulToken);
        stackBalance[_whom] = 0;
        lastRound[_whom] = 0;
        emit StackRemoved(auctionDay,_whom, actulToken);
        return true;
    }
    
    function unlockTokenFromStack() external returns (bool) {
        return _unlockTokenFromStack(msg.sender);
    }
    
    function unlockTokenFromStackBehalf(address _whom) external returns (bool) {
        require(IWhiteList(whiteListAddress).address_belongs(_whom) == msg.sender,ERR_AUTHORIZED_ADDRESS_ONLY);
        return _unlockTokenFromStack(_whom);
    }
}

contract DownsideProtection is Upgradeable, Stacking {
    
     function lockBalance(
        address _token,
        address _which,
        uint256 _amount
    ) internal returns (bool) {
        if (lockedOn[_which] == 0) {
            lockedOn[_which] = auctionDay;
        }
        uint256 currentBalance = currentLockedFunds[_which][auctionDay][_token];
        currentLockedFunds[_which][auctionDay][_token] = safeAdd(currentBalance, _amount);
        totalLocked[_token] = safeAdd(totalLocked[_token],_amount);
        emit FundLocked(_token, _which, _amount);
        return true;
    }
    
    function lockEtherInProtection(address _which,uint256 _amount)
        internal
        returns (bool)
    {
        return lockBalance(address(0), _which, _amount);
    }
    
    function _cancelInvestment(address payable _whom) internal returns (bool) {
        require(
            !isTokenLockEndDay(lockedOn[_whom]),
            "ERR_INVESTMENT_CANCEL_PERIOD_OVER"
        );
        
        uint256 _tokenBalance = lockedFunds[_whom][address(0)];
        
        if (_tokenBalance > 0) {
            _whom.transfer(_tokenBalance);
            totalLocked[address(0)] = safeSub(totalLocked[address(0)],_tokenBalance);
            emit FundTransfer(_whom, address(0), _tokenBalance);
            lockedFunds[_whom][address(0)] = 0;
        }

        _tokenBalance = lockedTokens[_whom];
        
        if (_tokenBalance > 0) {
            
            ensureTransferFrom(
                IERC20Token(mainTokenAddress),
                address(this),
                vaultAddress,
                _tokenBalance
            );
            
            emit FundTransfer(vaultAddress,mainTokenAddress, _tokenBalance);
            
            lockedTokens[_whom] = 0;
        }
        lockedOn[_whom] = 0;
        emit InvestMentCancelled(_whom, _tokenBalance);
        return true;
    }
    
    function cancelInvestment() external returns (bool) {
        return _cancelInvestment(msg.sender);
    }
    
    function cancelInvestmentBehalf(address payable _whom) external returns (bool) {
        require(IWhiteList(whiteListAddress).address_belongs(_whom) == msg.sender,ERR_AUTHORIZED_ADDRESS_ONLY);
        return _cancelInvestment(_whom);
    }
    
   function _unLockTokens(address _which, bool isStacking)
        internal
        returns (bool)
    {
        
        uint256 _tokenBalance = lockedFunds[_which][address(0)];
        
        if (_tokenBalance > 0) {
            
            uint256 walletAmount = safeDiv(
                safeMul(_tokenBalance, vaultRatio),
                100
            );
            
            uint256 liquadityAmount = safeSub(_tokenBalance, walletAmount);

            liquadityAddress.transfer(liquadityAmount);
            
            companyFundWalletAddress.transfer(walletAmount);
            
            emit FundTransfer(liquadityAddress, address(0), liquadityAmount);
            emit FundTransfer(
                companyFundWalletAddress,
                address(0),
                walletAmount
            );
            totalLocked[address(0)] = safeSub(totalLocked[address(0)],_tokenBalance);
            lockedFunds[_which][address(0)] = 0;
        }

        _tokenBalance = lockedTokens[_which];

        if (_tokenBalance > 0) {
            
            IERC20Token _token = IERC20Token(mainTokenAddress);

            if (isStacking) {
                addFundToStacking(_which, _tokenBalance);
            } else {
                ensureTransferFrom(
                    _token,
                    address(this),
                    _which,
                    _tokenBalance
                );
                emit TokenUnLocked(_which, _tokenBalance);
            }
            emit FundTransfer(_which, address(_token), _tokenBalance);
            lockedTokens[_which] = 0;
        }
        lockedOn[_which] = 0;
        return true;
    }
    
    // user unlock tokens and funds goes to compnay wallet
    function unLockTokens() external returns (bool) {
        return _unLockTokens(msg.sender, false);
    }

    function stackToken() external returns (bool) {
        return _unLockTokens(msg.sender, true);
    }
    
    function unLockTokensBehalf(address _whom) external returns (bool) {
        require(IWhiteList(whiteListAddress).address_belongs(_whom) == msg.sender,ERR_AUTHORIZED_ADDRESS_ONLY);
        return _unLockTokens(_whom, false);
    }

    function stackTokenBehalf(address _whom) external returns (bool) {
        require(IWhiteList(whiteListAddress).address_belongs(_whom) == msg.sender,ERR_AUTHORIZED_ADDRESS_ONLY);
        return _unLockTokens(_whom, true);
    }
    
    function unLockFundByAdmin(address _which)
        external
        onlySystem()
        returns (bool)
    {
        require(
            isTokenLockEndDay(lockedOn[_which]),
            "ERR_ADMIN_CANT_UNLOCK_FUND"
        );
        return _unLockTokens(_which, false);
    }
    
    function depositToken(address _which, uint256 auctionDay,uint256 _amount) internal returns (bool) {
        lockedTokens[_which] = safeAdd(lockedTokens[_which], _amount);
        
        if (currentLockedFunds[_which][auctionDay][address(0)] > 0) {
            
            uint256 _currentTokenBalance = currentLockedFunds[_which][auctionDay][address(0)];
            
            lockedFunds[_which][address(0)] = safeAdd(
                lockedFunds[_which][address(0)],
                _currentTokenBalance
            );
        }
        emit FundLocked(mainTokenAddress, _which, _amount);
        return true;
    }
}

contract AuctionUtils is DownsideProtection {
    

    function initializeStorage() internal {
        auctionDay = 1;
        totalContribution = 2500000 * PRICE_NOMINATOR;
        yesterdayContribution = 500 * PRICE_NOMINATOR;
        allowedMaxContribution = 500 * PRICE_NOMINATOR;
        todaySupply = 50000 * DECIMAL_NOMINATOR;
        maxContributionAllowed = 150;
        mangmentFee = 2;
        stacking = 1;
        downSideProtectionRatio = 90;
        fundWalletRatio = 90;
        groupBonusRatio = 2;
        mainTokenRatio = 100;
        averageDay = 10;
        tokenLockDuration = 365;
        vaultRatio = 90;
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

    function setStackingPercent(uint256 _stacking)
        external
        onlyOwner()
        returns (bool)
    {
        stacking = _stacking;
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
                if (
                    contributionByUser >= topContributior && replaced == false
                ) {
                    if (
                        contributor != _from &&
                        contributionByUser > topContributior
                    ) {
                        topFiveContributior[auctionDay][x] = _from;
                        topContributiorIndex[auctionDay][_from] = x;
                        replaceWith = contributor;
                        replaced = true;
                    } else if (contributor == _from) {
                        replaceWith = contributor;
                        replaced = true;
                    }
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

    // check weather user send more fund if yes
    // revert whatever user send extara revert back to user
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
            allowedMaxContribution
        ) {
            uint256 extraAmount = safeSub(
                safeAdd(todayContribution, _contributedAmount),
                allowedMaxContribution
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
        
        // Here we check caller balanace 
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

        _comprareForGroupBonus(_recipient);

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
        
        // Trasnfer Back Extra Amount To the _recipient
        if (returnAmount != 0) {
            _recipient.transfer(returnAmount);
            _value = safeSub(_value, returnAmount);
        }
        uint256 downSideAmount = safeDiv(safeMul(_value,dayWiseDownSideProtectionRatio[auctionDay]),100);
        lockEtherInProtection(_recipient,downSideAmount);
        return fundAdded(address(0), _value, 18, _caller , _recipient,_currencyPrice);
    }

    // we only start with ether we dont need any token right now
    function contributeWithEther() external payable returns (bool) {
        require(_checkContribution(msg.sender));
        return _contributeWithEther(msg.value,msg.sender,msg.sender);
    }
    
    // This Mehtod For Exchange 
    // Exchange invest behalf of their users
    // so we check caller maintoken balanace 
    function contributeWithEtherBehalf(address payable _whom) external payable returns (bool) {
        require(IWhiteList(whiteListAddress).isExchangeAddress(msg.sender),ERR_AUTHORIZED_ADDRESS_ONLY);
        if(IWhiteList(whiteListAddress).address_belongs(_whom) == address(0)){
            IWhiteList(whiteListAddress).addWalletBehalfExchange(msg.sender,_whom);
        }
        require(IWhiteList(whiteListAddress).address_belongs(_whom) == msg.sender);
        return _contributeWithEther(msg.value,msg.sender,_whom);
    }
    
    function updateCurrentMarketPrice() external returns(bool){
        currentMarketPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(mainTokenAddress);
        
        return true;
    }
    
    function pushEthToLiquadity() external returns(bool){
        
        uint256 downSideEther = totalLocked[address(0)];
        
        uint256 currentBalance = address(this).balance;
        
        uint256 pushToLiquadity = safeSub(currentBalance,downSideEther);
        
        if(pushToLiquadity > 0){
            
            uint256 realEstateAmount = safeDiv(safeMul(pushToLiquadity,fundWalletRatio),100);                
            companyFundWalletAddress.transfer(realEstateAmount); 
            uint256 reserveAmount = safeSub(pushToLiquadity,realEstateAmount);
            currentMarketPrice = IAuctionLiquadity(liquadityAddress)
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
        address _registeryAddress
    ) public {
        super.initialize();
        initializeOwner(_primaryOwner, _systemAddress, _multisigAddress);
        initializeStorage();
        contractsRegistry = IAuctionRegistery(_registeryAddress);
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
            allowedMaxContribution,
            _mainTokenPrice
        );
    }

    // any one can call this method
    
    function auctionEnd() external returns (bool) {
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
        
        approveTransferFrom(
            IERC20Token(mainTokenAddress),
            escrowAddress,
            fee
        );
        
        IEscrow(escrowAddress).depositFee(fee);
        
        addStackReward(stackingAmount);

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

        approveTransferFrom(
            IERC20Token(mainTokenAddress),
            escrowAddress,
            fee
        );
        IEscrow(escrowAddress).depositFee(fee);
        
        ensureTransferFrom(
            IERC20Token(mainTokenAddress),
            address(this),
            _which,
            _userAmount
        );

        depositToken(_which,dayId,safeSub(newReturnAmount, _userAmount));
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
        IERC20Token _token,
        uint256 _value,
        address payable _which
    ) external onlyAuthorized() returns (bool) {
        
        require(address(_token) != mainTokenAddress ,"ERR_CANT_TAKE_OUT_MAIN_TOKEN");
        ensureTransferFrom(_token, address(this), _which, _value);
        return true;
        
    }

    function() external payable {
        revert("NOT_ACCEPT_ETHER_DIRECT");
    }
}