pragma solidity ^0.5.9;


import "../common/SafeMath.sol";
import "../common/ProxyOwnable.sol";
import "../common/TokenTransfer.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionTagAlong.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/IAuction.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IWhiteList.sol";



interface InitializeInterface {
    function initialize(
        address _converter,
        address _baseToken,
        address _mainToken,
        address _relayToken,
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _baseLinePrice
    ) external;
}


interface IBancorNetwork {
    function etherTokens(address _address) external view returns (bool);

    function getReturnByPath(IERC20Token[] calldata _path, uint256 _amount)
        external
        view
        returns (uint256, uint256);
}


interface IContractRegistry {
    function addressOf(bytes32 _contractName) external view returns (address);

    // deprecated, backward compatibility
    function getAddress(bytes32 _contractName) external view returns (address);
}


interface IBancorConverter {
    function registry() external view returns (address);

    function reserves(address _address)
        external
        view
        returns (
            uint256,
            uint32,
            bool,
            bool,
            bool
        );

    function getReturn(
        IERC20Token _fromToken,
        IERC20Token _toToken,
        uint256 _amount
    ) external view returns (uint256, uint256);

    function quickConvert2(
        IERC20Token[] calldata _path,
        uint256 _amount,
        uint256 _minReturn,
        address _affiliateAccount,
        uint256 _affiliateFee
    ) external payable returns (uint256);

    function fund(uint256 _amount) external;

    function liquidate(uint256 _amount) external;

    function getReserveBalance(IERC20Token _reserveToken)
        external
        view
        returns (uint256);
}


contract BancorConverter is ProxyOwnable, SafeMath {
    bytes32 internal constant BANCOR_FORMULA = "BancorFormula";

    bytes32 internal constant BANCOR_NETWORK = "BancorNetwork";

    address public converter;

    // here is base token is bnt
    IERC20Token public baseToken;

    IERC20Token public mainToken;

    IERC20Token public relayToken;

    

    function updateConverter(address _converter)
        public
        onlySystem()
        returns (bool)
    {
        converter = _converter;
        return true;
    }

    function addressOf(bytes32 _contractName) internal view returns (address) {
        address _registry = IBancorConverter(converter).registry();
        IContractRegistry registry = IContractRegistry(_registry);
        return registry.addressOf(_contractName);
    }

    function getTokensReserveBalance()
        internal
        view
        returns (uint256 _baseTokenBalance, uint256 _mainTokenBalance)
    {
        _baseTokenBalance = IBancorConverter(converter).getReserveBalance(
            baseToken
        );
        _mainTokenBalance = IBancorConverter(converter).getReserveBalance(
            mainToken
        );
        return (_baseTokenBalance, _mainTokenBalance);
    }

    function getTokensReserveRatio()
        internal
        view
        returns (uint256 _baseTokenRatio, uint256 _mainTokenRatio)
    {
        uint256 a;
        bool c;
        bool d;
        bool e;
        (a, _baseTokenRatio, c, d, e) = IBancorConverter(converter).reserves(
            address(baseToken)
        );
        (a, _mainTokenRatio, c, d, e) = IBancorConverter(converter).reserves(
            address(mainToken)
        );
        return (_baseTokenRatio, _mainTokenRatio);
    }

    function getReturn(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) public view returns (uint256, uint256) {
        return
            IBancorConverter(converter).getReturn(
                IERC20Token(_fromToken),
                IERC20Token(_toToken),
                _amount
            );
    }

    function etherTokens(address _address) internal view returns (bool) {
        IBancorNetwork network = IBancorNetwork(addressOf(BANCOR_NETWORK));
        return network.etherTokens(_address);
    }

    function getReturnByPath(IERC20Token[] memory _path, uint256 _amount)
        internal
        view
        returns (uint256, uint256)
    {
        IBancorNetwork network = IBancorNetwork(addressOf(BANCOR_NETWORK));
        return network.getReturnByPath(_path, _amount);
    }
}


contract AuctionRegistery is BancorConverter, AuctionRegisteryContracts {
    IAuctionRegistery public contractsRegistry;

    address payable public whiteListAddress;
    address payable public vaultAddress;
    address payable public auctionAddress;
    address payable public tagAlongAddress;
    address payable public currencyPricesAddress;


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
        tagAlongAddress = getAddressOf(TAG_ALONG);
        auctionAddress = getAddressOf(AUCTION);
    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
    }
}


contract LiquadityUtils is AuctionRegistery {
    // _path = 0
    IERC20Token[] public ethToMainToken;

    // _path = 1
    IERC20Token[] public baseTokenToMainToken;

    // _path = 2
    IERC20Token[] public mainTokenTobaseToken;

    // _path = 3
    IERC20Token[] public ethToBaseToken;

    // _path = 4
    IERC20Token[] public baseTokenToEth;

    mapping(address => uint256) lastReedeemDay;

    uint256 public constant PERCENT_NOMINATOR = 10**6;

    uint256 public constant DECIMAL_NOMINATOR = 10**18;

    uint256 public sideReseverRatio;

    uint256 public appreciationLimit;

    uint256 public reductionStartDay;

    uint256 public baseTokenVolatiltyRatio;
    
    uint256 public virtualReserverDivisor;

    uint256 public previousMainReserveContribution;

    uint256 public todayMainReserveContribution;

    uint256 public tokenAuctionEndPrice;

    uint256 public lastReserveBalance;

    uint256 public baseLinePrice;
    
    
    
   

    modifier allowedAddressOnly(address _which) {
        require(_which == auctionAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    function setTokenPath(uint256 _pathNo, IERC20Token[] memory _path)
        public
        onlySystem()
        returns (bool)
    {
        if (_pathNo == 0) ethToMainToken = _path;
        else if (_pathNo == 1) baseTokenToMainToken = _path;
        else if (_pathNo == 2) mainTokenTobaseToken = _path;
        else if (_pathNo == 3) ethToBaseToken = _path;
        else if (_pathNo == 4) baseTokenToEth = _path;
        return true;
    }
    
    
    function setAllPath(
        IERC20Token[] calldata _ethToMainToken,
        IERC20Token[] calldata _baseTokenToMainToken,
        IERC20Token[] calldata _mainTokenTobaseToken,
        IERC20Token[] calldata _ethToBaseToken,
        IERC20Token[] calldata _baseTokenToEth )external onlySystem() {
        
        ethToMainToken = _ethToMainToken;
        baseTokenToMainToken = _baseTokenToMainToken;
        mainTokenTobaseToken = _mainTokenTobaseToken;
        ethToBaseToken = _ethToBaseToken;
        baseTokenToEth = _baseTokenToEth;
        
    }

    function setSideReseverRatio(uint256 _ratio)
        public
        onlyOwner()
        returns (bool)
    {
        require(_ratio < 100, "ERR_RATIO_CANT_BE_GREATER_THAN_100");
        sideReseverRatio = _ratio;
        return true;
    }

    function setAppreciationLimit(uint256 _limit)
        public
        onlyOwner()
        returns (bool)
    {
        appreciationLimit = _limit;
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
    
    function setReductionStartDay(uint256 _reductionStartDay) public onlyOwner() returns(bool){
        reductionStartDay = _reductionStartDay;
    }
}


contract LiquadityFormula is LiquadityUtils{
    
    // current market price calculate according to baseLinePrice
    // if baseToken Price differ from
    function _getCurrentMarketPrice() internal view returns (uint256) {
        (
            uint256 _baseTokenBalance,
            uint256 _mainTokenBalance
        ) = getTokensReserveBalance();

        (
            uint256 _baseTokenRatio,
            uint256 _mainTokenRatio
        ) = getTokensReserveRatio();

        uint256 ratio = safeDiv(
            safeMul(
                safeMul(_baseTokenBalance, _mainTokenRatio),
                PERCENT_NOMINATOR
            ),
            safeMul(_mainTokenBalance, _baseTokenRatio)
        );

        return safeDiv(safeMul(ratio, baseLinePrice), PERCENT_NOMINATOR);
    }

    function calculateLiquadityMainReserve(
        uint256 yesterdayPrice,
        uint256 dayBeforyesterdayPrice,
        uint256 yesterDaycontibution,
        uint256 yesterdayMainReserv
    ) internal pure returns (uint256) {
        // multiply 10**6 so we cant get zero value if amount come in float
        
        uint256 _tempContrbution = safeDiv(
            safeMul(yesterDaycontibution, PERCENT_NOMINATOR),
            yesterdayMainReserv
        );

        uint256 _tempRatio = safeDiv(
            safeMul(yesterdayPrice, PERCENT_NOMINATOR),
            dayBeforyesterdayPrice
        );

        _tempRatio =  safeMul(_tempContrbution, _tempRatio);
        if(_tempRatio > safeMul(PERCENT_NOMINATOR,PERCENT_NOMINATOR)){
            return _tempRatio;
        }else{
            return 0;
        }
    }

    // we dont need divide it by decimal bcz we get
    // return balance into decimal also
    // we calculate how much reserver balance should be there
    // for give price here we return balance of other token
    // that should be balance in token to achive this price
    function calculateRecoverPrice(
        uint256 _reserveTokenBalance,
        uint256 _reserveTokenRatio,
        uint256 _reserveTokenPrice,
        uint256 _findTokenRatio,
        uint256 _findTokenPrice
    ) internal pure returns (uint256) {
        uint256 ratio = safeDiv(
            safeMul(
                safeMul(_reserveTokenBalance, _findTokenRatio),
                PERCENT_NOMINATOR
            ),
            safeMul(_reserveTokenPrice, _reserveTokenRatio)
        );

        return safeDiv(safeMul(ratio, _findTokenPrice), PERCENT_NOMINATOR);
    }

    function calculateRecoverPriceWithMainToken(
        uint256 recoverPrice,
        bool _convert
    ) internal view returns (uint256) {
        (
            uint256 _baseTokenBalance,
            uint256 _mainTokenBalance
        ) = getTokensReserveBalance();

        (
            uint256 _baseTokenRatio,
            uint256 _mainTokenRatio
        ) = getTokensReserveRatio();

        uint256 newReserverBalance = calculateRecoverPrice(
            _baseTokenBalance,
            _baseTokenRatio,
            recoverPrice,
            _mainTokenRatio,
            baseLinePrice
        );

        if (newReserverBalance > _mainTokenBalance) {
            uint256 _reverseBalance = safeSub(
                newReserverBalance,
                _mainTokenBalance
            );

            if (_convert)
                _reverseBalance = safeDiv(
                    safeMul(_reverseBalance, _mainTokenBalance),
                    _baseTokenBalance
                );

            return _reverseBalance;
        }
        return 0;
    }

    function calculateRecoverPriceWithBaseToken(
        uint256 recoverPrice,
        bool _convert
    ) internal view returns (uint256) {
        (
            uint256 _baseTokenBalance,
            uint256 _mainTokenBalance
        ) = getTokensReserveBalance();

        (
            uint256 _baseTokenRatio,
            uint256 _mainTokenRatio
        ) = getTokensReserveRatio();

        uint256 newReserverBalance = calculateRecoverPrice(
            _mainTokenBalance,
            _mainTokenRatio,
            baseLinePrice,
            _baseTokenRatio,
            recoverPrice
        );

        if (newReserverBalance > _baseTokenBalance) {
            uint256 _reverseBalance = safeSub(
                newReserverBalance,
                _baseTokenBalance
            );
            if (_convert)
                _reverseBalance = safeDiv(
                    safeMul(_reverseBalance, _mainTokenBalance),
                    _baseTokenBalance
                );
            return _reverseBalance;
        }
        return 0;
    }
}


contract Liquadity is Upgradeable,LiquadityFormula, TokenTransfer,InitializeInterface {
    
    function initialize(
        address _converter,
        address _baseToken,
        address _mainToken,
        address _relayToken,
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _baseLinePrice) public {
        
        super.initialize();
        initializeOwner(
            _primaryOwner,
            _systemAddress,
            _authorityAddress
        );
        contractsRegistry = IAuctionRegistery(_registeryAddress);
        _updateAddresses();
        converter = _converter;
        baseLinePrice = _baseLinePrice;
        sideReseverRatio = 70;
        appreciationLimit = 120;
        reductionStartDay = 21;
        baseTokenVolatiltyRatio = 5 * PERCENT_NOMINATOR;
        baseToken = IERC20Token(_baseToken);
        mainToken = IERC20Token(_mainToken);
        relayToken = IERC20Token(_relayToken);
        
        tokenAuctionEndPrice = _getCurrentMarketPrice();
        lastReserveBalance = IBancorConverter(converter).getReserveBalance(
            baseToken
        ); 
        
        
    }
    
    

    event Contribution(address _token, uint256 _amount, uint256 returnAmount);

    event RecoverPrice(uint256 _oldPrice, uint256 _newPrice);

    event Redemption(address _token, uint256 _amount, uint256 returnAmount);

    event FundDeposited(address _token, address indexed _from, uint256 _amount);

    function _contributeWithEther(uint256 value) internal returns (uint256) {
        
        uint256 returnAmount = IBancorConverter(converter).quickConvert2.value(value)
        (ethToMainToken, value, 1, address(0), 0);

        ensureTransferFrom(
            ethToMainToken[safeSub(ethToMainToken.length, 1)],
            address(this),
            vaultAddress,
            returnAmount
        );

        todayMainReserveContribution = safeAdd(
            todayMainReserveContribution,
            value
        );

        emit Contribution(address(0), value, returnAmount);

        checkAppeciationLimit();

        lastReserveBalance = IBancorConverter(converter).getReserveBalance(
            baseToken
        );

        return returnAmount;
    }

    //This method return token base on wich is last address
    //If last address is ethtoken it will return ether
    function _convertWithToken(uint256 value, IERC20Token[] memory _path)
        internal
        returns (bool)
    {
        
        approveTransferFrom(_path[0], converter, value);
        
        uint256 returnAmount = IBancorConverter(converter).quickConvert2.value(0)
        (_path, value, 1, address(0), 0);

        IERC20Token returnToken = _path[safeSub(_path.length, 1)];

        if (returnToken == mainToken) {
            
            ensureTransferFrom(
                returnToken,
                address(this),
                vaultAddress,
                returnAmount
            );
            
        } else {
            
            ensureTransferFrom(
                returnToken,
                address(this),
                tagAlongAddress,
                returnAmount
            );
        }

        lastReserveBalance = IBancorConverter(converter).getReserveBalance(
            baseToken
        );

        return true;
    }

    function checkAppeciationLimit()
        internal
        returns (bool _isRedemptionReqiured)
    {
        
        _isRedemptionReqiured = false;

        uint256 tokenCurrentPrice = _getCurrentMarketPrice();

        uint256 _appreciationReached = safeDiv(
            safeMul(tokenCurrentPrice, 100),
            tokenAuctionEndPrice
        );

        if (_appreciationReached > appreciationLimit) {
            
            _isRedemptionReqiured = true;

            uint256 fallBackPrice = safeDiv(
                safeMul(appreciationLimit, tokenAuctionEndPrice),
                100
            );

            _priceRecoveryWithConvertMainToken(fallBackPrice);
        }

        return _isRedemptionReqiured;
    }

    // when we have zero contibution towards auction
    // this method called from auction contarct
    // this method sell 10% realy and convert into ether if there
    // is no ether into tagAlong or side resever
    function contributeTowardMainReserve()
        external
        allowedAddressOnly(msg.sender)
        returns (uint256)
    {
        if ( previousMainReserveContribution > address(this).balance ) {
            
            if (previousMainReserveContribution > tagAlongAddress.balance) {
                
                while (
                    previousMainReserveContribution >= tagAlongAddress.balance
                ) {
                    _liquadate(safeMul(10, PERCENT_NOMINATOR), true);

                    if (
                        tagAlongAddress.balance >=
                        previousMainReserveContribution
                    ) {
                        IAuctionTagAlong(tagAlongAddress)
                            .contributeTowardLiquadity(
                            previousMainReserveContribution
                        );
                        break;
                    }
                }
            } else {
                IAuctionTagAlong(tagAlongAddress).contributeTowardLiquadity(
                    previousMainReserveContribution
                );
            }
        }

        _contributeWithEther(previousMainReserveContribution);
        return previousMainReserveContribution;
    }

    function _getMainReserveAmount(uint256 mainReserverAmount)
        internal
        view
        returns (uint256)
    {
        if (virtualReserverDivisor > 0)
            mainReserverAmount = safeDiv(
                // we need here 10**12
                safeMul(
                    mainReserverAmount,
                    safeMul(PERCENT_NOMINATOR, PERCENT_NOMINATOR)
                ),
                virtualReserverDivisor
            );

        return mainReserverAmount;
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

        mainReserverAmount = _getMainReserveAmount(mainReserverAmount);

        uint256 tagAlongContribution = IAuctionTagAlong(tagAlongAddress)
            .contributeTowardLiquadity(mainReserverAmount);

        mainReserverAmount = safeAdd(tagAlongContribution, mainReserverAmount);

        _contributeWithEther(mainReserverAmount);

        return _getCurrentMarketPrice();
    }

    // contribution with Token is not avilable for bancor
    //bacnor dont have stable coin base conversion
    function contributeWithToken(
        IERC20Token _token,
        address _from,
        uint256 _amount
    ) public allowedAddressOnly(msg.sender) returns (uint256) {
        ensureTransferFrom(_token, _from, address(this), _amount);
        return _getCurrentMarketPrice();
    }

    function recoverPriceVolatility() external returns (bool) {
        
        uint256 baseTokenPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(address(baseToken));

        uint256 volatilty;

        bool isMainToken;

        if (baseTokenPrice > baseLinePrice) {
            volatilty = safeDiv(
                
                safeMul(
                    safeSub(baseTokenPrice, baseLinePrice),
                    safeMul(100, PERCENT_NOMINATOR)
                ),
                
                baseTokenPrice
            );
            isMainToken = true;
        } else if(baseLinePrice > baseTokenPrice) {
            
            volatilty = safeDiv(
                safeMul(
                    safeSub(baseLinePrice, baseTokenPrice),
                    safeMul(100, PERCENT_NOMINATOR)
                ),
                baseLinePrice
            );
            isMainToken = false;
        }

        if (volatilty >= baseTokenVolatiltyRatio) {
            
            (uint256 returnBase, uint256 returnMain) = _liquadate(
                volatilty,
                false
            );

            if (isMainToken) {
                
                ITokenVault(vaultAddress).directTransfer(
                    address(mainToken),
                    converter,
                    returnMain
                );
                
            } else {
                
                IAuctionTagAlong(tagAlongAddress).transferTokenLiquadity(
                    baseToken,
                    converter,
                    returnBase
                );
                
            }
        }
        
        baseLinePrice = baseTokenPrice;
        
        lastReserveBalance = IBancorConverter(converter).getReserveBalance(
            baseToken
        );

        return true;
    }
    
    // someone only can send baseToken 
    // we have to check if there is more base token 
    function recoverPriceDueToManipulation() external returns (bool) {
        uint256 volatilty;
        uint256 _baseTokenBalance = IBancorConverter(converter)
            .getReserveBalance(baseToken);

        bool isMainToken;

        if (_baseTokenBalance > lastReserveBalance) {
            volatilty = safeDiv(
                safeMul(
                    safeSub(_baseTokenBalance, lastReserveBalance),
                    safeMul(100, PERCENT_NOMINATOR)
                ),
                _baseTokenBalance
            );
            isMainToken = true;
        } 

        (uint256 returnBase, uint256 returnMain) = _liquadate(volatilty, false);

        if (isMainToken) {
            ITokenVault(vaultAddress).directTransfer(
                address(mainToken),
                converter,
                returnMain
            );
        } 
        
        lastReserveBalance = IBancorConverter(converter).getReserveBalance(
            baseToken
        );
        return true;
    }

    //recover price from main token
    // if there is not enough main token sell 10% relay
    // this is very rare case where vault dont have balance
    function _priceRecoveryWithConvertMainToken(uint256 recoverPrice)
        internal
        returns (bool)
    {
        uint256 _reverseBalance = calculateRecoverPriceWithMainToken(
            recoverPrice,
            true
        );

        uint256 vaultBalance = mainToken.balanceOf(vaultAddress);

        if (vaultBalance >= _reverseBalance) {
            
            ITokenVault(vaultAddress).directTransfer(
                address(mainToken),
                converter,
                _reverseBalance
            );
                
            return _convertWithToken(_reverseBalance, mainTokenTobaseToken);
        } else {
            
            uint256 converterBalance = mainToken.balanceOf(converter);

            uint256 relayPercent = 10;

            if (converterBalance > _reverseBalance)
                relayPercent = safeDiv(
                    safeMul(
                        safeSub(converterBalance, _reverseBalance),
                        safeMul(100, PERCENT_NOMINATOR)
                    ),
                    _reverseBalance
                );

            _liquadate(safeMul(relayPercent,PERCENT_NOMINATOR), false);
            // recalculate everything bcz resever changed

            return _priceRecoveryWithConvertMainToken(recoverPrice);
        }
    }

    function _recoverAfterRedemption(uint256 _amount)
        internal
        returns (bool)
    {
        (uint256 ethAmount, uint256 fee) = getReturnByPath(
            ethToBaseToken,
            _amount
        );

        uint256 totalEthAmount = safeAdd(ethAmount, fee);

        // if side resever have ether it will convert into bnt

        if (address(this).balance >= totalEthAmount) {
            
            uint256 returnAmount = IBancorConverter(converter)
                .quickConvert2
                .value(totalEthAmount)(
                ethToBaseToken,
                totalEthAmount,
                1,
                address(0),
                0
            );
            
            return _convertWithToken(returnAmount, baseTokenToMainToken);
            
        } else {
            
            // tag alogn transfer remainn eth and recall this function
            if (tagAlongAddress.balance >= safeSub(totalEthAmount, address(this).balance)) {
                
                IAuctionTagAlong(tagAlongAddress).contributeTowardLiquadity(
                    totalEthAmount
                );

                uint256 returnAmount = IBancorConverter(converter)
                    .quickConvert2
                    .value(totalEthAmount)(
                    ethToBaseToken,
                    totalEthAmount,
                    1,
                    address(0),
                    0
                );
            
            return _convertWithToken(returnAmount, baseTokenToMainToken);
                
            } else if (baseToken.balanceOf(tagAlongAddress) >= _amount) {
                
                //if tagAlong dont have eth we check baseToken

                IAuctionTagAlong(tagAlongAddress).transferTokenLiquadity(
                    baseToken,
                    address(this),
                    _amount
                );

                return _convertWithToken(_amount, baseTokenToMainToken);
                
            } else {
                // if taglong dont have that much we sell relay token

                // redemption amount always less then what converter have
                uint256 converterBalance = baseToken.balanceOf(converter);

                uint256 relayPercent = 10;

                if (converterBalance > _amount){
                    
                    relayPercent = safeDiv(
                        safeMul(safeSub(converterBalance, _amount), 100),
                        _amount
                    );
                    
                    if(relayPercent > 99) relayPercent = 99 ;
                }

                _liquadate(safeMul(relayPercent,PERCENT_NOMINATOR), false);

                _amount = safeSub(_amount, safeDiv(_amount, relayPercent));

                IAuctionTagAlong(tagAlongAddress).transferTokenLiquadity(
                    baseToken,
                    address(this),
                    _amount
                );

                return _convertWithToken(_amount, baseTokenToMainToken);
            }
        }
    }

    function redemption(IERC20Token[] memory _path, uint256 _amount)
        public
        returns (bool)
    {
        require(
            address(_path[0]) == address(mainToken),
            "ERR_MAIN_TOKEN"
        );
        
        require(IWhiteList(whiteListAddress).isAllowedBuyBack(
            msg.sender
        ),"ERR_NOT_ALLOWED_BUYBACK");
        
        address primaryWallet = IWhiteList(whiteListAddress).address_belongs(
            msg.sender
        );
        
        require(primaryWallet != address(0), "ERR_WHITELIST");
        
        uint256 auctionDay = IAuction(auctionAddress).auctionDay();

        require(
            auctionDay > lastReedeemDay[primaryWallet],
            "ERR_WALLET_ALREADY_REDEEM"
        );

        ensureTransferFrom(_path[0], msg.sender, address(this), _amount);
        approveTransferFrom(_path[0], converter, _amount);

        uint256 _beforeBalance = baseToken.balanceOf(converter);

        uint256 returnAmount = IBancorConverter(converter).quickConvert2.value(0)
        (_path, _amount, 1, address(0), 0);

        if (etherTokens(address(_path[safeSub(_path.length,1)])))
            msg.sender.transfer(returnAmount);
        else
            ensureTransferFrom(
                _path[safeSub(_path.length, 1)],
                address(this),
                msg.sender,
                returnAmount
            );

        lastReedeemDay[msg.sender] = auctionDay;
        
        uint256 _afterBalance = baseToken.balanceOf(converter);

        emit Redemption(
            address(_path[safeSub(_path.length, 1)]),
            _amount,
            returnAmount
        );
        
        if(_beforeBalance > _afterBalance){
            _recoverAfterRedemption(
                safeSub(_beforeBalance, _afterBalance)
            );
        }
        
        return true;
    }

    function auctionEnded()
        external
        allowedAddressOnly(msg.sender)
        returns (bool)
    {
        (
            uint256 _baseTokenBalance,
            uint256 _mainTokenBalance
        ) = getTokensReserveBalance();

        uint256 yesterdayMainReserv = safeDiv(
            safeMul(_baseTokenBalance, baseLinePrice),
            safeExponent(10, baseToken.decimals())
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

            virtualReserverDivisor = calculateLiquadityMainReserve(
                _yesterdayPrice,
                _dayBeforePrice,
                _yesterdayContribution,
                yesterdayMainReserv
            );
        }
        previousMainReserveContribution = todayMainReserveContribution;
        todayMainReserveContribution = 0;
        tokenAuctionEndPrice = _getCurrentMarketPrice();
        return true;
    }

    function _liquadate(uint256 _relayPercent, bool _convertToEth)
        internal
        returns (uint256, uint256)
    {
        uint256 sellRelay = safeDiv(
            safeMul(
                relayToken.balanceOf(address(tagAlongAddress)),
                _relayPercent
            ),
            safeMul(100, PERCENT_NOMINATOR)
        );

        IAuctionTagAlong(tagAlongAddress).transferTokenLiquadity(
            relayToken,
            address(this),
            sellRelay
        );

        uint256 _mainTokenBalance = mainToken.balanceOf(address(this));
        uint256 _baseTokenBalance = baseToken.balanceOf(address(this));

        //take out both side of token from the reserve
        IBancorConverter(converter).liquidate(sellRelay);

        _mainTokenBalance = safeSub(
            mainToken.balanceOf(address(this)),
            _mainTokenBalance
        );
        
        _baseTokenBalance = safeSub(
            baseToken.balanceOf(address(this)),
            _baseTokenBalance
        );

        ensureTransferFrom(
            mainToken,
            address(this),
            vaultAddress,
            _mainTokenBalance
        );

       

        // if we need ether it covert into eth and sent it to tagalong
        if (_convertToEth) {
            uint256 beforeEthBalance = address(this).balance;

            approveTransferFrom(baseToken, converter, _baseTokenBalance);

            IBancorConverter(converter).quickConvert2.value(0)(
                baseTokenToEth,
                _baseTokenBalance,
                1,
                address(0),
                0
            );
            tagAlongAddress.transfer(
                safeSub(address(this).balance, beforeEthBalance)
            );
        } else {
            ensureTransferFrom(
                baseToken,
                address(this),
                tagAlongAddress,
                _baseTokenBalance
            );
        }
        return (_baseTokenBalance, _mainTokenBalance);
    }

    function getCurrencyPrice() public view returns (uint256) {
        return _getCurrentMarketPrice();
    }
    
    function liquidateFromSystem(uint256 _percent) external returns (bool) {
        _liquadate(safeMul(_percent,PERCENT_NOMINATOR), false);
        return true;
    }

    //return token and ether from here
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

    function depositeToken(
        IERC20Token _token,
        address _from,
        uint256 _amount
    ) external returns (bool) {
        ensureTransferFrom(_token, _from, address(this), _amount);
        emit FundDeposited(address(0), _from, _amount);
        return true;
    }

    function() external payable {
       emit FundDeposited(address(0), msg.sender, msg.value); 
    }

}
