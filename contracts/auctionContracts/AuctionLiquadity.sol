pragma solidity ^0.5.9;

import "../common/SafeMath.sol";
import "../common/Ownable.sol";
import "../InterFaces/IAuctionRegistery.sol";
import "../InterFaces/IAuctionTagAlong.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/IAuction.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IWhiteList.sol";


contract IBancorNetwork {
    function etherTokens(address _address) public view returns (bool);

    function getReturnByPath(IERC20Token[] memory _path, uint256 _amount)
        public
        view
        returns (uint256, uint256);
}


contract IContractRegistry {
    function addressOf(bytes32 _contractName) public view returns (address);

    // deprecated, backward compatibility
    function getAddress(bytes32 _contractName) public view returns (address);
}


contract IBancorConverter {
    function registry() public view returns (address);

    function reserves(address _address)
        public
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
    ) public view returns (uint256, uint256);

    function quickConvert2(
        IERC20Token[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        address _affiliateAccount,
        uint256 _affiliateFee
    ) public payable returns (uint256);

    function fund(uint256 _amount) public;

    function liquidate(uint256 _amount) public;

    function getReserveBalance(IERC20Token _reserveToken)
        public
        view
        returns (uint256);
}


contract BancorConverter is Ownable, SafeMath {
    bytes32 internal constant BANCOR_FORMULA = "BancorFormula";

    bytes32 internal constant BANCOR_NETWORK = "BancorNetwork";

    address public converter;

    // here is base token is bnt
    IERC20Token public baseToken;

    IERC20Token public mainToken;

    IERC20Token public relayToken;

    

    constructor(
        address _converter,
        address _baseToken,
        address _mainToken,
        address _relayToken
    ) public {
        converter = _converter;
        baseToken = IERC20Token(_baseToken);
        mainToken = IERC20Token(_mainToken);
        relayToken = IERC20Token(_relayToken);
    }

    function updateConverter(address _converter)
        public
        onlySystem()
        returns (bool)
    {
        converter = _converter;
        return true;
    }

    function addressOf(bytes32 _contractName) public view returns (address) {
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

    function etherTokens(address _address) public view returns (bool) {
        IBancorNetwork network = IBancorNetwork(addressOf(BANCOR_NETWORK));
        return network.etherTokens(_address);
    }
}


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





contract LiquadityUtils is BancorConverter, AuctionRegistery {
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

    mapping(address => bool) public allowedAddress;

    mapping(address => uint256) lastReedeeDay;

    uint256 public sideReseverRatio = 90;

    uint256 public appreciationLimit = 120;

    uint256 public reductionStartDay = 14;

    uint256 public virtualReserverDivisor = 0;

    uint256 public previousMainReserveContribution;

    uint256 public todayMainReserveContribution;
    
    uint256 public tokenAuctionEndPrice;
    
    uint256 public lastTokenPrice;

    modifier allowedAddressOnly(address _which) {
        require(allowedAddress[_which], ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    function setAllowedAddress(address _address, bool _check)
        public
        onlySystem()
        notZeroAddress(_address)
        returns (bool)
    {
        allowedAddress[_address] = _check;
        return true;
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
}


contract LiquadityFormula is LiquadityUtils {
    
    function _getCurrentMarketPrice() internal view returns (uint256) {
        (
            uint256 _baseTokenBalance,
            uint256 _mainTokenBalance
        ) = getTokensReserveBalance();

        (
            uint256 _baseTokenRatio,
            uint256 _mainTokenRatio
        ) = getTokensReserveRatio();

        uint256 _baseTokenPrice = ICurrencyPrices(getAddressOf(CURRENCY))
            .getCurrencyPrice(address(baseToken));
        
        
        uint256 ratio = safeDiv(
            safeMul(
                safeMul(_baseTokenBalance, _mainTokenRatio),
                safeExponent(10, 6)
            ),
            safeMul(_mainTokenBalance, _baseTokenRatio)
        );

        return safeDiv(safeMul(ratio, _baseTokenPrice), safeExponent(10, 6));
        
    }
    
    function calculateLiquadityMainReserve(
        uint256 yesterdayPrice,
        uint256 dayBeforyesterdayPrice,
        uint256 yesterDaycontibution,
        uint256 yesterdayMainReserv
    ) internal pure returns (uint256) {
        
        // multiply 10**6 so we cant get zero value if amount come in float 
        uint256 _tempContrbution = safeDiv(
            safeMul(yesterDaycontibution, safeExponent(10, 6)),
            yesterdayMainReserv
        );
        
        
        uint256 _tempSupply = safeDiv(
            safeMul(yesterdayPrice, safeExponent(10, 6)),
            dayBeforyesterdayPrice
        );
        
        
        return safeMul(_tempContrbution, _tempSupply);
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
                safeExponent(10, 6)
            ),
            safeMul(_reserveTokenPrice, _reserveTokenRatio)
        );

        return safeDiv(safeMul(ratio, _findTokenPrice), safeExponent(10, 6));
    }
    
}


contract Liquadity is LiquadityFormula {
    constructor(
        address _converter,
        address _baseToken,
        address _mainToken,
        address _relayToken,
        address _systemAddress,
        address _multisigAddress,
        address _registeryAddress,
        IERC20Token[] memory _ethToMainToken,
        IERC20Token[] memory _baseTokenToMainToken,
        IERC20Token[] memory _mainTokenTobaseToken,
        IERC20Token[] memory _ethToBaseToken
    )
        public
        notZeroAddress(_systemAddress)
        BancorConverter(_converter, _baseToken, _mainToken, _relayToken)
        Ownable(_systemAddress, _multisigAddress)
    {
        contractsRegistry = IAuctionRegistery(_registeryAddress);
        ethToMainToken = _ethToMainToken;
        baseTokenToMainToken = _baseTokenToMainToken;
        mainTokenTobaseToken = _mainTokenTobaseToken;
        ethToBaseToken = _ethToBaseToken;
    }

    event Contribution(address _token, uint256 _amount, uint256 returnAmount);

    event RecoverPrice(uint256 _oldPrice, uint256 _newPrice);

    event Redemption(address _token, uint256 _amount, uint256 returnAmount);

    event FundDeposited(address _token, address _from, uint256 _amount);

    function ensureTransferFrom(
        IERC20Token _token,
        address _from,
        address _to,
        uint256 _amount
    ) private {
        uint256 prevBalance = _token.balanceOf(_to);

        if (_from == address(this)) _token.transfer(_to, _amount);
        else _token.transferFrom(_from, _to, _amount);
        uint256 postBalance = _token.balanceOf(_to);
        require(postBalance > prevBalance, "ERR_TOKEN_NOT_TRANSFERRED");
    }

    function approveTransferFrom(
        IERC20Token _token,
        address _spender,
        uint256 _amount
    ) private {
        _token.approve(_spender, _amount);
    }

    function _contributeWithEther(uint256 value) internal returns (uint256) {
        uint256 returnAmount = IBancorConverter(converter).quickConvert2.value(
            value
        )(ethToMainToken, value, 1, address(0), 0);

        ensureTransferFrom(
            ethToMainToken[safeSub(ethToMainToken.length, 1)],
            address(this),
            getAddressOf(VAULT),
            returnAmount
        );

        todayMainReserveContribution = safeAdd(
            todayMainReserveContribution,
            value
        );

        emit Contribution(address(0), value, returnAmount);

        checkAppeciationLimit();
        lastTokenPrice = _getCurrentMarketPrice();
        return returnAmount;
    }

    //This method return token base on wich is last address
    //If last address is ethtoken it will return ether
    function _convertWithToken(uint256 value, IERC20Token[] memory _path)
        internal
        returns (bool)
    {
        approveTransferFrom(IERC20Token(mainToken), converter, value);

        uint256 returnAmount = IBancorConverter(converter).quickConvert2.value(
            0
        )(_path, value, 1, address(0), 0);
        
        IERC20Token returnToken = _path[safeSub(_path.length, 1)];
        
        if(returnToken == mainToken){
            ensureTransferFrom(
                returnToken,
                address(this),
                getAddressOf(VAULT),
                returnAmount
            );
        }else{
            ensureTransferFrom(
                returnToken,
                address(this),
                getAddressOf(TAG_ALONG),
                returnAmount
            );
        }

        lastTokenPrice = _getCurrentMarketPrice();

        emit Redemption(address(0), value, returnAmount);

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
            
            _recoverPriceWitMainToken(fallBackPrice,true);
            
        }

        return _isRedemptionReqiured;
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
        address tagAlongAddress = getAddressOf(TAG_ALONG);

        if (address(this).balance < previousMainReserveContribution) {
            if (previousMainReserveContribution > tagAlongAddress.balance) {
                while (
                    previousMainReserveContribution >= tagAlongAddress.balance
                ) {
                    _liquadate(true);

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
                safeMul(mainReserverAmount, safeExponent(10, 12)),
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

        uint256 tagAlongContribution = IAuctionTagAlong(getAddressOf(TAG_ALONG))
            .contributeTowardLiquadity(mainReserverAmount);

        mainReserverAmount = safeAdd(tagAlongContribution, mainReserverAmount);

        _contributeWithEther(mainReserverAmount);

        return lastTokenPrice;
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

    //recover price from main token
    // if there is not enough main token sell 10% relay
    function _recoverPriceWitMainToken(uint256 recoverPrice,bool _isConvert)
        internal
        returns (bool)
    {
        uint256 _baseTokenPrice = ICurrencyPrices(getAddressOf(CURRENCY))
            .getCurrencyPrice(address(baseToken));

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
            _baseTokenPrice
        );

        if (newReserverBalance > _mainTokenBalance) {
            
            address vaultAddress = getAddressOf(VAULT);
            
            uint256 _reverseBalance = safeSub(
                newReserverBalance,
                _baseTokenBalance
            );
            uint256 vaultBalance = mainToken.balanceOf(vaultAddress);
            if (vaultBalance >= _reverseBalance) {
                if(_isConvert){
                   _reverseBalance = safeDiv(safeMul(_reverseBalance,_mainTokenBalance),_baseTokenBalance);
                    return _convertWithToken(_reverseBalance,mainTokenTobaseToken);
                }else{
                  ITokenVault(vaultAddress).directTransfer(
                        address(mainToken),
                        converter,
                        _reverseBalance
                    );
                    lastTokenPrice = _getCurrentMarketPrice();
                    return true;   
                    
                }
                
                
                
            } else {
                _liquadate(false);
                return _recoverPriceWithBaseToken(recoverPrice);
            }
        }
    }

    //recover price from basetoken
    // if there is not enough base token sell 10% relay
    function _recoverPriceWithBaseToken(uint256 recoverPrice)
        internal
        returns (bool)
    {
        uint256 _baseTokenPrice = ICurrencyPrices(getAddressOf(CURRENCY))
            .getCurrencyPrice(address(baseToken));

        (
            uint256 _baseTokenBalance,
            uint256 _mainTokenBalance
        ) = getTokensReserveBalance();

        (
            uint256 _baseTokenRatio,
            uint256 _mainTokenRatio
        ) = getTokensReserveRatio();

        // we here need reverse from apprectiation
        // so what calculation applied on we have to reverse it
        uint256 newReserverBalance = calculateRecoverPrice(
            _mainTokenBalance,
            _mainTokenRatio,
            _baseTokenPrice,
            _baseTokenRatio,
            recoverPrice
        );

        if (newReserverBalance > _baseTokenBalance) {
            address tagAlongAddress = getAddressOf(TAG_ALONG);

            uint256 _reverseBalance = safeSub(
                newReserverBalance,
                _baseTokenBalance
            );

            uint256 tagAlongBalance = baseToken.balanceOf(tagAlongAddress);

            if (tagAlongBalance >= _reverseBalance) {
                IAuctionTagAlong(tagAlongAddress).transferTokenLiquadity(
                    baseToken,
                    converter,
                    _reverseBalance
                );
                lastTokenPrice = _getCurrentMarketPrice();
                return true;
            } else {
                _liquadate(false);
                return _recoverPriceWithBaseToken(recoverPrice);
            }
        }
    }
    
    function _recoverAfterRedemption(uint256 _amount) internal returns(bool){
        
            address tagAlongAddress = getAddressOf(TAG_ALONG);
            
            uint256 tagAlongBalance = baseToken.balanceOf(tagAlongAddress);
            
            if (tagAlongBalance >= _amount) {
                uint256 returnAmount = IBancorConverter(converter).quickConvert2.value(
                0
            )(baseTokenToMainToken, _amount, 1, address(0), 0);
            
            ensureTransferFrom(mainToken, address(this),getAddressOf(VAULT),returnAmount);
            lastTokenPrice = _getCurrentMarketPrice();
            
            return true;
        } else {
            _liquadate(false);
            return _recoverAfterRedemption(_amount);
        }
    }

    // this function recover last price from contrbution or redeemption
    // function recover price against volatilty from basetoken
    function recoverFromManiplution(uint256 _func)
        external
        onlySystem()
        returns (bool)
    {
        if (_func == 1) _recoverPriceWitMainToken(lastTokenPrice,false);
        else if (_func == 2) _recoverPriceWithBaseToken(lastTokenPrice);
    }

    function redemption(IERC20Token[] memory _path, uint256 _amount)
        public
        returns (bool)
    {
        require(
            address(_path[0]) == address(mainToken),
            "Redemption Only With MainToken"
        );

        address primaryWallet = IWhiteList(getAddressOf(WHITE_LIST))
            .address_belongs(msg.sender);
        require(primaryWallet != address(0), "ERR_WHITELIST");

        uint256 auctionDay = IAuction(getAddressOf(AUCTION)).auctionDay();

        require(
            auctionDay > lastReedeeDay[primaryWallet],
            "ERR_WALLET_ALREADY_REDEEM"
        );
    
        
        

        ensureTransferFrom(_path[0], msg.sender, address(this), _amount);
        approveTransferFrom(_path[0], converter, _amount);
        
        uint256 _beforeBalance = baseToken.balanceOf(converter);
        
        uint256 returnAmount = IBancorConverter(converter).quickConvert2.value(
            0
        )(_path, _amount, 1, address(0), 0);

        if (
            IBancorNetwork(addressOf(BANCOR_NETWORK)).etherTokens(
                address(_path[safeSub(_path.length, 1)])
            )
        ) msg.sender.transfer(returnAmount);
        else
            ensureTransferFrom(
                _path[safeSub(_path.length, 1)],
                address(this),
                msg.sender,
                returnAmount
            );

        lastReedeeDay[msg.sender] = auctionDay;
        uint256 _afterBalnace = baseToken.balanceOf(converter);
        
        emit Redemption(
            address(_path[safeSub(_path.length, 1)]),
            _amount,
            returnAmount
        );

        _recoverAfterRedemption(safeSub(_beforeBalance,_afterBalnace));
        return true;
    }

    function auctionEnded() external returns (bool) {
        require(
            msg.sender == getAddressOf(AUCTION),
            ERR_AUTHORIZED_ADDRESS_ONLY
        );
        (
            uint256 _baseTokenBalance,
            uint256 _mainTokenBalance
        ) = getTokensReserveBalance();

      
        uint256 _baseTokenPrice = ICurrencyPrices(getAddressOf(CURRENCY))
            .getCurrencyPrice(address(baseToken));

        uint256 yesterdayMainReserv = safeDiv(
            safeMul(_baseTokenBalance, _baseTokenPrice),
            safeExponent(10, baseToken.decimals())
        );

        IAuction auction = IAuction(getAddressOf(AUCTION));

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

    function _liquadate(bool _convertToEth) internal {
        address vaultAddress = getAddressOf(VAULT);

        address payable tagAlongAddress = getAddressOf(TAG_ALONG);

        uint256 sellRelay = safeDiv(
            safeMul(relayToken.balanceOf(address(tagAlongAddress)), 10),
            100
        );

        IAuctionTagAlong(tagAlongAddress).transferTokenLiquadity(
            relayToken,
            address(this),
            sellRelay
        );

        uint256 _mainTokenBalance = mainToken.balanceOf(address(this));

        //extract ether from BNTETH converter
        uint256 _baseTokenBalance = baseToken.balanceOf(address(this));

        //take out both side of token from the reserve
        IBancorConverter(converter).liquidate(sellRelay);

        ensureTransferFrom(
            mainToken,
            address(this),
            vaultAddress,
            safeSub(mainToken.balanceOf(address(this)), _mainTokenBalance)
        );

        _baseTokenBalance = safeSub(
            baseToken.balanceOf(address(this)),
            _baseTokenBalance
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
            delete beforeEthBalance;
        } else {
            ensureTransferFrom(
                baseToken,
                address(this),
                tagAlongAddress,
                _baseTokenBalance
            );
        }
    }
    
    

    function getCurrencyPrice() public view returns (uint256) {
        return _getCurrentMarketPrice();
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

    function returnTokens(
        IERC20Token _tokens,
        address _to,
        uint256 _value
    ) external onlyOwner() returns (bool) {
        ensureTransferFrom(_tokens, address(this), _to, _value);
        return true;
    }

    function withDraw(uint256 _value) external onlyOwner() returns (bool) {
        msg.sender.transfer(_value);
        return true;
    }

    function() external payable {
        emit FundDeposited(address(0), msg.sender, msg.value);
    }
}
