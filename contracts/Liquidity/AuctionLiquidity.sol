pragma solidity ^0.5.9;

import "./LiquidityStorage.sol";
import "../common/SafeMath.sol";
import "../common/ProxyOwnable.sol";
import "../common/TokenTransfer.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IContributionTrigger.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IBEP20Token.sol";
import "../InterFaces/IAuction.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IWhiteList.sol";

interface LiquidityInitializeInterface {
    function initialize(
        address payable _converter,
        address _baseToken,
        address _mainToken,
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registryaddress,
        uint256 _baseLinePrice
    ) external;
}

interface IUniswapV2Factory {
   function mint(address tokenA, address tokenB, uint amountA, uint amountB, address payable to) external payable returns(uint liquidity);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function burn(address payable to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address payable to, bytes calldata data) external payable returns(bool);
    function sync() external payable returns(bool);
}

contract UniConverterLiquidity is ProxyOwnable, SafeMath, LiquidityStorage {
    function updateConverter(address payable _converter)
        public
        onlyOwner()
        returns (bool)
    {
        converter = _converter;
        return true;
    }
    
    // convert base to main token. baseTokenAmount = BNB, mainTokenAmount = JNTR
    function convertBase(uint baseTokenAmount, address payable to) internal  returns(uint256) {
        
        uint amountOut = getReturnAmount(baseTokenAmount, 0);
        
        IUniswapV2Pair(converter).swap.value(baseTokenAmount)(0, amountOut, to, new bytes(0));
        
        lastReserveBalance = converter.balance;
        
        return uint256(amountOut);
        
    }    

    // convert main to base token. baseTokenAmount = BNB, mainTokenAmount = JNTR
    function convertMain(uint mainTokenAmount, address payable to) internal returns(uint256) {
        
        uint amountOut = getReturnAmount(0, mainTokenAmount);
        
        IUniswapV2Pair(converter).swap(amountOut, 0, to, new bytes(0));
        
        lastReserveBalance = converter.balance;
        
        return uint256(amountOut);
    }

    // return amount if we convert base or main token. baseTokenAmount = BNB, mainTokenAmount = JNTR
    function getReturnAmount(uint baseTokenAmount, uint mainTokenAmount) internal view returns(uint amountOut) {
        uint reserveIn;
        uint reserveOut;
        uint amountIn;
        
        if (baseTokenAmount != 0) {
            (reserveIn, reserveOut,) = IUniswapV2Pair(converter).getReserves();
            amountIn = baseTokenAmount;
        }
        else {
            (reserveOut,reserveIn, ) = IUniswapV2Pair(converter).getReserves();
            amountIn = mainTokenAmount;
        }
        
        return getAmountOut(amountIn, reserveIn, reserveOut);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = safeMul(amountIn,1000);  //No fee. 997 - with fee
        uint numerator = safeMul(amountInWithFee,reserveOut);
        uint denominator = safeAdd(safeMul(reserveIn,1000),amountInWithFee);
        amountOut = safeDiv(numerator,denominator);
        return amountOut;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = safeMul(safeMul(reserveIn,amountOut),1000);
        uint denominator = safeMul(safeSub(reserveOut,amountOut),1000);  //No fee. 997 -  with fee
        amountIn = safeAdd(safeDiv(numerator,denominator),1);
        return amountIn;
    }    
}

contract RegisteryLiquidity is
    UniConverterLiquidity,
    AuctionRegisteryContracts
{
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
        currencyPricesAddress = getAddressOf(CURRENCY);
        vaultAddress = getAddressOf(VAULT);
        triggerAddress = getAddressOf(CONTRIBUTION_TRIGGER);
        auctionAddress = getAddressOf(AUCTION);
        escrowAddress = getAddressOf(ESCROW);
    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
        return true;
    }
}

contract LiquidityUtils is RegisteryLiquidity {
    modifier allowedAddressOnly(address _which) {
        require(_which == auctionAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }
  

    function setSideReseverRatio(uint256 _sideReseverRatio)
        public
        onlyOwner()
        returns (bool)
    {
        require(_sideReseverRatio < 100, "ERR_RATIO_CANT_BE_GREATER_THAN_100");
        sideReseverRatio = _sideReseverRatio;
        return true;
    }

    function setTagAlongRatio(uint256 _tagAlongRatio)
        public
        onlyOwner()
        returns (bool)
    {
        tagAlongRatio = _tagAlongRatio;
        return true;
    }

    function setAppreciationLimit(uint256 _limit)
        public
        onlyOwner()
        returns (bool)
    {
        appreciationLimit = _limit;
        appreciationLimitWithDecimal = safeMul(_limit, DECIMAL_NOMINATOR);
        return true;
    }

    function setBaseTokenVolatiltyRatio(uint256 _baseTokenVolatiltyRatio)
        public
        onlyOwner()
        returns (bool)
    {
        baseTokenVolatiltyRatio = _baseTokenVolatiltyRatio;
        return true;
    }

    function setReductionStartDay(uint256 _reductionStartDay)
        public
        onlyOwner()
        returns (bool)
    {
        reductionStartDay = _reductionStartDay;
        return true;
    }

    function setRelayPercent(uint256 _relayPercent)
        public
        onlyOwner()
        returns (bool)
    {
        require(_relayPercent < 99);
        relayPercent = _relayPercent;
        return true;
    }

     function setisBuyBackOpen(bool _isBuyBackOpen)
        public
        onlyOwner()
        returns (bool)
    {
       
        isBuyBackOpen = _isBuyBackOpen;
        return true;
    }


    
}

contract LiquidityFormula is LiquidityUtils {
    // current market price calculate according to baseLinePrice
    // if baseToken Price differ from
    function _getCurrentMarketPrice() internal view returns (uint256) {
        uint256 _mainTokenBalance = IBEP20Token(mainToken).balanceOf(converter);
        uint256 ratio = safeDiv(
            safeMul(
                lastReserveBalance,
                BIG_NOMINATOR
            ),
            _mainTokenBalance
        );
        return safeDiv(safeMul(ratio, baseLinePrice), BIG_NOMINATOR);
    }

    function calculateLiquidityMainReserve(
        uint256 yesterdayPrice,
        uint256 dayBeforyesterdayPrice,
        uint256 yesterDaycontibution,
        uint256 yesterdayMainReserv
    ) internal pure returns (uint256) {
        // multiply 10**9 so we cant get zero value if amount come in float

        uint256 _tempContrbution = safeDiv(
            safeMul(yesterDaycontibution, PRICE_NOMINATOR),
            yesterdayMainReserv
        );

        uint256 _tempRatio = safeDiv(
            safeMul(yesterdayPrice, PRICE_NOMINATOR),
            dayBeforyesterdayPrice
        );

        _tempRatio = safeMul(_tempContrbution, _tempRatio);

        if (_tempRatio > DECIMAL_NOMINATOR) {
            return _tempRatio;
        } else {
            return 0;
        }
    }
}

contract Liquidity is
    Upgradeable,
    LiquidityFormula,
    TokenTransfer,
    LiquidityInitializeInterface
{
    function initialize(
        address payable _converter,
        address payable _factory,
        address _baseToken,
        address _mainToken,
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registryaddress,
        uint256 _baseLinePrice
    ) public {
        super.initialize();
        initializeOwner(_primaryOwner, _systemAddress, _authorityAddress);

        converter = _converter;
        factory = _factory;
        baseLinePrice = _baseLinePrice;
        sideReseverRatio = 70;
        appreciationLimit = 120;
        tagAlongRatio = 100;
        reductionStartDay = 21;
        maxIteration = 35;
        relayPercent = 10;
        appreciationLimitWithDecimal = safeMul(120, DECIMAL_NOMINATOR);
        baseTokenVolatiltyRatio = 5 * PRICE_NOMINATOR;

        baseToken = _baseToken;
        mainToken = _mainToken;
       

        contractsRegistry = IAuctionRegistery(_registryaddress);
        lastReserveBalance = converter.balance;
        tokenAuctionEndPrice = _getCurrentMarketPrice();
        _updateAddresses();
    }

    function _contributeWithEther(uint256 value) internal returns (uint256) {
        uint256 lastBalance = converter.balance;

        if (lastBalance != lastReserveBalance) {
            _recoverPriceDueToManipulation();
        }

        uint256 returnAmount = convertBase(value, vaultAddress);

        todayMainReserveContribution = safeAdd(
            todayMainReserveContribution,
            value
        );

        emit Contribution(address(0), value, returnAmount);
        lastReserveBalance = converter.balance;
        checkAppeciationLimit();
        return returnAmount;
    }


    function checkAppeciationLimit() internal returns (bool) {
        uint256 tokenCurrentPrice = _getCurrentMarketPrice();

        uint256 _appreciationReached = safeDiv(
            safeMul(tokenCurrentPrice, safeMul(100, DECIMAL_NOMINATOR)),
            tokenAuctionEndPrice
        );

        if (_appreciationReached > appreciationLimitWithDecimal) {
            isAppreciationLimitReached = true;
            _priceRecoveryWithConvertMainToken(_appreciationReached);
        }
        return true;
    }

    // when we have zero contibution towards auction
    // this method called from auction contarct
    // this method sell 10% realy and convert into ether if there
    // is no ether into tagAlong
    function contributeTowardMainReserve()
        external
        allowedAddressOnly(msg.sender)
        returns (uint256)
    {
        if (address(this).balance < previousMainReserveContribution) {
            while (previousMainReserveContribution >= address(this).balance) {
                _liquadate(safeMul(relayPercent, PRICE_NOMINATOR));
                if (address(this).balance >= previousMainReserveContribution) {
                    break;
                }
            }
        }
        _contributeWithEther(previousMainReserveContribution);
        return previousMainReserveContribution;
    }

    function contributeWithEther()
        public
        payable
        allowedAddressOnly(msg.sender)
        returns (uint256)
    {
        uint256 _amount = msg.value;

        uint256 sideReseverAmount = safeDiv(
            safeMul(_amount, sideReseverRatio),
            100
        );

        uint256 mainReserverAmount = safeSub(_amount, sideReseverAmount);
        if (virtualReserverDivisor > 0)
            mainReserverAmount = safeDiv(
                safeMul(mainReserverAmount, DECIMAL_NOMINATOR),
                virtualReserverDivisor
            );

        if (isAppreciationLimitReached) {
            return _getCurrentMarketPrice();
        }

        uint256 tagAlongAmount = safeDiv(
            safeMul(mainReserverAmount, tagAlongRatio),
            100
        );

        if (tagAlongAmount > address(this).balance)
            mainReserverAmount = safeAdd(
                mainReserverAmount,
                address(this).balance
            );
        else mainReserverAmount = safeAdd(mainReserverAmount, tagAlongAmount);

        _contributeWithEther(mainReserverAmount);
        return _getCurrentMarketPrice();
    }

    function _recoverReserve(bool isMainToken, uint256 _liquadateRatio)
        internal
    {
        (uint256 returnBase, uint256 returnMain) = _liquadate(_liquadateRatio);

        if (isMainToken) {
            ITokenVault(vaultAddress).directTransfer(
                mainToken,
                converter,
                returnMain
            );
            IUniswapV2Pair(converter).sync.value(0)();
        } else {
            IUniswapV2Pair(converter).sync.value(returnBase)();
        }

        lastReserveBalance = converter.balance;
    }

    function recoverPriceVolatility() external returns (bool) {
        
        _recoverPriceDueToManipulation();

        uint256 baseTokenPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(baseToken);

        uint256 volatilty;

        bool isMainToken;

        if (baseTokenPrice > baseLinePrice) {
            volatilty = safeDiv(
                safeMul(
                    safeSub(baseTokenPrice, baseLinePrice),
                    safeMul(100, PRICE_NOMINATOR)
                ),
                baseTokenPrice
            );
            isMainToken = true;
        } else if (baseLinePrice > baseTokenPrice) {
            volatilty = safeDiv(
                safeMul(
                    safeSub(baseLinePrice, baseTokenPrice),
                    safeMul(100, PRICE_NOMINATOR)
                ),
                baseLinePrice
            );
            isMainToken = false;
        }

        if (volatilty >= baseTokenVolatiltyRatio) {
            _recoverReserve(isMainToken, volatilty);
            baseLinePrice = baseTokenPrice;
        }
        return true;
    }

    function _recoverPriceDueToManipulation() internal returns (bool) {
        uint256 volatilty;

        uint256 _baseTokenBalance = converter.balance;
        bool isMainToken;

        if (_baseTokenBalance > lastReserveBalance) {
            volatilty = safeDiv(
                safeMul(
                    safeSub(_baseTokenBalance, lastReserveBalance),
                    safeMul(100, PRICE_NOMINATOR)
                ),
                _baseTokenBalance
            );

            isMainToken = true;
            _recoverReserve(isMainToken, volatilty);
        }
        return true;
    }

    function recoverPriceDueToManipulation() external returns (bool) {
        return _recoverPriceDueToManipulation();
    }

    // recover price from main token
    // if there is not enough main token sell 10% relay
    // this is very rare case where vault dont have balance
    // At 35th round we get excat value in fraction
    // we dont value in decimal we already provide _percent with decimal
    function _priceRecoveryWithConvertMainToken(uint256 _percent)
        internal
        returns (uint256)
    {
        uint256 tempX = safeDiv(_percent, appreciationLimit);
        uint256 root = nthRoot(tempX, 2, 0, maxIteration);
        uint256 _tempValue = safeSub(root, PRICE_NOMINATOR);
        uint256 _supply = IBEP20Token(mainToken).balanceOf(converter);

        uint256 _reverseBalance = safeDiv(
            safeMul(_supply, _tempValue),
            PRICE_NOMINATOR
        );

        uint256 vaultBalance = IBEP20Token(mainToken).balanceOf(vaultAddress);

        if (vaultBalance >= _reverseBalance) {
            ITokenVault(vaultAddress).directTransfer(
                address(mainToken),
                converter,
                _reverseBalance
            );
            return convertMain(_reverseBalance, address(this));
        } else {
            uint256 converterBalance = IBEP20Token(mainToken).balanceOf(
                converter
            );

            uint256 _tempRelayPercent = relayPercent;

            if (converterBalance > _reverseBalance)
                _tempRelayPercent = safeDiv(
                    safeMul(
                        safeSub(converterBalance, _reverseBalance),
                        safeMul(100, PRICE_NOMINATOR)
                    ),
                    _reverseBalance
                );
            _liquadate(safeMul(_tempRelayPercent, PRICE_NOMINATOR));
            return _priceRecoveryWithConvertMainToken(_percent);
        }
    }
    

    // if not have enough ether we sell relay 
    // exmple reserve have 100 token and we need 25 token to recover 
    // we need to sell 25% relay 
    // _amount*100/reserveBalance
    // (25*100)/100 so we get 25%
    // we multiply it with price PRICE_NOMINATOR so we can get excat amount 
    function _recoverAfterRedemption(uint256 _amount) internal returns (uint256) {
        if (address(this).balance >= _amount) {
            return convertBase(_amount, vaultAddress);
        } else {
            uint256 converterBalance = converter.balance;

            uint256 _tempRelayPercent;
            
            if (converterBalance > _amount) {
                _tempRelayPercent = safeDiv(
                    safeMul(safeMul(_amount, PRICE_NOMINATOR), 100),
                    converterBalance
                );
            } else {
                 _tempRelayPercent = safeDiv(
                    safeMul(safeMul(_amount, PRICE_NOMINATOR), 100),
                    safeAdd(converterBalance,_amount)
                );
            }

            _liquadate(_tempRelayPercent);

            _amount = safeSub(
                _amount,
                safeDiv(safeMul(_amount, _tempRelayPercent),safeMul(100,PRICE_NOMINATOR))
            );

            return convertBase(_amount, vaultAddress);
        }
    }

    function redemptionFromEscrow(
        uint256 _amount,
        address payable _reciver
    ) external returns (bool) {
        require(msg.sender == escrowAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        return _redemption( _amount, msg.sender, _reciver);
    }

    function redemption(uint256 _amount)
        external
        returns (bool)
    {
        return _redemption(_amount, msg.sender, msg.sender);
    }

    function _redemption(
        uint256 _amount,
        address payable _caller,
        address payable _reciver
    ) internal returns (bool) {
        

        require(isBuyBackOpen,"ERR_BUYBACK_IS_CLOSED");

        address primaryWallet = IWhiteList(whiteListAddress).address_belongs(
            _reciver
        );

        uint256 auctionDay = IAuction(auctionAddress).auctionDay();

        require(primaryWallet != address(0), "ERR_WHITELIST");

        require(
            auctionDay > lastReedeemDay[primaryWallet],
            "ERR_WALLET_ALREADY_REDEEM"
        );

        uint256 _beforeBalance = converter.balance;

        if (_beforeBalance != lastReserveBalance) {
            _recoverPriceDueToManipulation();
        }

        ensureTransferFrom(
            IBEP20Token(mainToken),
            _caller,
            converter,
            _amount
        );

        uint256 returnAmount = convertMain(_amount, _reciver);

        lastReedeemDay[primaryWallet] = auctionDay;

        uint256 _afterBalance = converter.balance;

        emit Redemption(
            baseToken,
            _amount,
            returnAmount
        );

        if (_beforeBalance > _afterBalance) {
            _recoverAfterRedemption(safeSub(_beforeBalance, _afterBalance));
        }

        return true;
    }

    function auctionEnded()
        external
        allowedAddressOnly(msg.sender)
        returns (bool)
    {
        uint256 _baseTokenBalance = converter.balance;

        uint256 yesterdayMainReserv = safeDiv(
            safeMul(_baseTokenBalance, baseLinePrice),
            safeExponent(10, 18)
        );

        IAuction auction = IAuction(auctionAddress);

        uint256 auctionDay = auction.auctionDay();

        if (auctionDay > reductionStartDay) {
            uint256 _yesterdayPrice = auction.dayWiseMarketPrice(
                safeSub(auctionDay, 1)
            );

            uint256 _dayBeforePrice = auction.dayWiseMarketPrice(
                safeSub(auctionDay, 2)
            );

            uint256 _yesterdayContribution = auction.dayWiseContribution(
                safeSub(auctionDay, 1)
            );

            virtualReserverDivisor = calculateLiquidityMainReserve(
                _yesterdayPrice,
                _dayBeforePrice,
                _yesterdayContribution,
                yesterdayMainReserv
            );
        }
        previousMainReserveContribution = todayMainReserveContribution;
        todayMainReserveContribution = 0;
        tokenAuctionEndPrice = _getCurrentMarketPrice();
        isAppreciationLimitReached = false;
        return true;
    }

    // _percent should be in 100 multipliction 
    function fundPool(uint _percent) external onlySystem() returns (bool){
        (reserveIn, reserveOut,) = IUniswapV2Pair(converter).getReserves();
        uint bnbAmount = safeDiv(safeMul(reserveIn, _percent),10000);
        uint tokenAmount = safeDiv(safeMul(reserveOut, _percent),10000);
        approveTransferFrom(IBEP20Token(mainToken), factory, tokenAmount);
        IUniswapV2Factory(factory).mint.value(bnbAmount)(baseToken,mainToken,bnbAmount,tokenAmount,triggerAddress);
        return true;
    }

    function _liquadate(uint256 _relayPercent)
        internal
        returns (uint256, uint256)
    {
        uint256 _mainTokenBalance = IBEP20Token(mainToken).balanceOf(
            address(this)
        );

        uint256 _baseTokenBalance = address(this).balance;

        uint256 sellRelay = safeDiv(
            safeMul(
                IBEP20Token(converter).balanceOf(triggerAddress),
                _relayPercent
            ),
            safeMul(100, PRICE_NOMINATOR)
        );

        require(sellRelay > 0, "ERR_RELAY_ZERO");

        IContributionTrigger(triggerAddress).transferTokenLiquidity(
            IBEP20Token(converter),
            converter,
            sellRelay
        );

        //take out both side of token from the reserve
        IUniswapV2Pair(converter).burn(address(this));

        _mainTokenBalance = safeSub(
            IBEP20Token(mainToken).balanceOf(address(this)),
            _mainTokenBalance
        );

        _baseTokenBalance = safeSub(
            address(this).balance,
            _baseTokenBalance
        );

        ensureTransferFrom(
            IBEP20Token(mainToken),
            address(this),
            vaultAddress,
            _mainTokenBalance
        );
        
        lastReserveBalance = converter.balance;
        return (_baseTokenBalance, _mainTokenBalance);
    }

    function returnFundToTagAlong(IBEP20Token _token, uint256 _value)
        external
        onlyOwner()
        returns (bool)
    {
        if (address(_token) == address(0)) {
            triggerAddress.transfer(_value);
        } else {
            ensureTransferFrom(_token, address(this), triggerAddress, _value);
        }
        return true;
    }

    //return token and ether from tagalong to here  as we only need ether
    function takeFundFromTagAlong(IBEP20Token _token, uint256 _value)
        external
        onlyOwner()
        returns (bool)
    {
        if (address(_token) == address(0))
            IContributionTrigger(triggerAddress).contributeTowardLiquidity(
                _value
            );
        else
            IContributionTrigger(triggerAddress).transferTokenLiquidity(
                _token,
                address(this),
                _value
            );
        return true;
    }

    function getCurrencyPrice() public view returns (uint256) {
        return _getCurrentMarketPrice();
    }

    function sendMainTokenToVault() external returns (bool) {
        
        uint256 mainTokenBalance = IBEP20Token(mainToken).balanceOf(
            address(this)
        );
        
        ensureTransferFrom(
            IBEP20Token(mainToken),
            address(this),
            vaultAddress,
            mainTokenBalance
        );
        return true;
    }

  
    function() external payable {}
}