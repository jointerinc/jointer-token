pragma solidity ^0.5.9;

import "./LiquadityStorage.sol";
import "../common/SafeMath.sol";
import "../common/ProxyOwnable.sol";
import "../common/TokenTransfer.sol";
import "../Proxy/Upgradeable.sol";
import "../InterFaces/IAuctionTagAlong.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/IERC20Token.sol";
import "../InterFaces/IAuction.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IWhiteList.sol";

interface LiquadityInitializeInterface {
    function initialize(
        address _converter,
        address _baseToken,
        address _mainToken,
        address _relayToken,
        address _etherToken,
        address _ethRelayToken,
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _baseLinePrice
    ) external;
}

interface IBancorNetwork {
    function etherTokens(address _address) external view returns (bool);

    function rateByPath(address[] calldata _path, uint256 _amount)
        external
        view
        returns (uint256);

    function convertByPath(
        address[] calldata _path,
        uint256 _amount,
        uint256 _minReturn,
        address payable _beneficiary,
        address _affiliateAccount,
        uint256 _affiliateFee
    ) external payable returns (uint256);
}

interface IContractRegistry {
    function addressOf(bytes32 _contractName) external view returns (address);

    // deprecated, backward compatibility
    function getAddress(bytes32 _contractName) external view returns (address);
}

interface IEtherToken {
    function deposit() external payable;

    function withdraw(uint256 _amount) external;

    function withdrawTo(address _to, uint256 _amount) external;
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

    function removeLiquidity(
        uint256 _amount,
        IERC20Token[] calldata _reserveTokens,
        uint256[] calldata _reserveMinReturnAmounts
    ) external;
}

contract BancorConverterLiquadity is ProxyOwnable, SafeMath, LiquadityStorage {
    function updateConverter(address _converter)
        public
        onlyOwner()
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

    function etherTokens(address _address) internal view returns (bool) {
        IBancorNetwork network = IBancorNetwork(bancorNetwork);
        return network.etherTokens(_address);
    }

    function getReturnByPath(address[] memory _path, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        IBancorNetwork network = IBancorNetwork(bancorNetwork);
        return network.rateByPath(_path, _amount);
    }
}

contract RegisteryLiquadity is
    BancorConverterLiquadity,
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
        tagAlongAddress = getAddressOf(TAG_ALONG);
        auctionAddress = getAddressOf(AUCTION);

        // bancor network
        bancorNetwork = addressOf(BANCOR_NETWORK);
    }

    function updateAddresses() external returns (bool) {
        _updateAddresses();
        return true;
    }
}

contract LiquadityUtils is RegisteryLiquadity {
    modifier allowedAddressOnly(address _which) {
        require(_which == auctionAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    function _updateTokenPath() internal returns (bool) {
        ethToMainToken = [
            etherToken,
            ethRelayToken,
            baseToken,
            relayToken,
            mainToken
        ];
        baseTokenToMainToken = [baseToken, relayToken, mainToken];
        mainTokenTobaseToken = [mainToken, relayToken, baseToken];
        ethToBaseToken = [etherToken, ethRelayToken, baseToken];
        baseTokenToEth = [baseToken, ethRelayToken, etherToken];
        relayPath = [IERC20Token(mainToken), IERC20Token(baseToken)];
        returnAmountRelay = [1, 1];
        return true;
    }

    // this is for bnt an eth token only
    function updateTokenPath() external returns (bool) {
        return _updateTokenPath();
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
}

contract LiquadityFormula is LiquadityUtils {
    // current market price calculate according to baseLinePrice
    // if baseToken Price differ from
    function _getCurrentMarketPrice() internal view returns (uint256) {
        uint256 _mainTokenBalance = IERC20Token(mainToken).balanceOf(converter);

        (
            uint256 _baseTokenRatio,
            uint256 _mainTokenRatio
        ) = getTokensReserveRatio();

        uint256 ratio = safeDiv(
            safeMul(
                safeMul(lastReserveBalance, _mainTokenRatio),
                BIG_NOMINATOR
            ),
            safeMul(_mainTokenBalance, _baseTokenRatio)
        );

        return safeDiv(safeMul(ratio, baseLinePrice), BIG_NOMINATOR);
    }

    function calculateLiquadityMainReserve(
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

contract Liquadity is
    Upgradeable,
    LiquadityFormula,
    TokenTransfer,
    LiquadityInitializeInterface
{
    function initialize(
        address _converter,
        address _baseToken,
        address _mainToken,
        address _relayToken,
        address _etherToken,
        address _ethRelayToken,
        address _primaryOwner,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _baseLinePrice
    ) public {
        super.initialize();
        initializeOwner(_primaryOwner, _systemAddress, _authorityAddress);

        converter = _converter;
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
        relayToken = _relayToken;
        etherToken = _etherToken;
        ethRelayToken = _ethRelayToken;

        contractsRegistry = IAuctionRegistery(_registeryAddress);
        lastReserveBalance = IERC20Token(baseToken).balanceOf(converter);
        tokenAuctionEndPrice = _getCurrentMarketPrice();
        _updateAddresses();
        _updateTokenPath();
    }

    function _contributeWithEther(uint256 value) internal returns (uint256) {
        uint256 lastBalance = IERC20Token(baseToken).balanceOf(converter);

        if (lastBalance != lastReserveBalance) {
            _recoverPriceDueToManipulation();
        }

        uint256 returnAmount = IBancorNetwork(bancorNetwork)
            .convertByPath
            .value(value)(
            ethToMainToken,
            value,
            1,
            vaultAddress,
            address(0),
            0
        );

        todayMainReserveContribution = safeAdd(
            todayMainReserveContribution,
            value
        );

        emit Contribution(address(0), value, returnAmount);
        lastReserveBalance = IERC20Token(baseToken).balanceOf(converter);
        checkAppeciationLimit();
        return returnAmount;
    }

    //convert base token token into ether
    function _convertBaseTokenToEth() internal {
        uint256 _baseTokenBalance = IERC20Token(baseToken).balanceOf(
            address(this)
        );

        if (_baseTokenBalance > 0) {
            if (etherTokens(baseToken)) {
                IEtherToken(baseToken).withdraw(_baseTokenBalance);
            } else {
                approveTransferFrom(
                    IERC20Token(baseToken),
                    bancorNetwork,
                    _baseTokenBalance
                );
                IBancorNetwork(bancorNetwork).convertByPath.value(0)(
                    baseTokenToEth,
                    _baseTokenBalance,
                    1,
                    address(0),
                    address(0),
                    0
                );
            }
        }
    }

    //This method return token base on wich is last address
    //If last address is ethtoken it will return ether
    function _convertWithToken(uint256 value, address[] memory _path)
        internal
        returns (bool)
    {
        approveTransferFrom(IERC20Token(_path[0]), bancorNetwork, value);

        address payable sentBackAddress;

        if (_path[safeSub(_path.length, 1)] == mainToken) {
            sentBackAddress = vaultAddress;
        }
        IBancorNetwork(bancorNetwork).convertByPath.value(0)(
            _path,
            value,
            1,
            sentBackAddress,
            address(0),
            0
        );

        _convertBaseTokenToEth();
        lastReserveBalance = IERC20Token(baseToken).balanceOf(converter);
        return true;
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
                _convertBaseTokenToEth();
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
        } else {
            ensureTransferFrom(
                IERC20Token(baseToken),
                address(this),
                converter,
                returnBase
            );
        }

        lastReserveBalance = IERC20Token(baseToken).balanceOf(converter);
    }

    function recoverPriceVolatility() external onlySystem() returns (bool) {
        uint256 baseTokenPrice = ICurrencyPrices(currencyPricesAddress)
            .getCurrencyPrice(address(baseToken));

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
        }
        baseLinePrice = baseTokenPrice;
        return true;
    }

    function _recoverPriceDueToManipulation() internal returns (bool) {
        uint256 volatilty;

        uint256 _baseTokenBalance = IERC20Token(baseToken).balanceOf(converter);

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
        }
        _recoverReserve(isMainToken, volatilty);
        return true;
    }

    function recoverPriceDueToManipulation()
        external
        onlySystem()
        returns (bool)
    {
        return _recoverPriceDueToManipulation();
    }

    // recover price from main token
    // if there is not enough main token sell 10% relay
    // this is very rare case where vault dont have balance
    // At 35th round we get excat value in fraction
    // we dont value in decimal we already provide _percent with decimal
    function _priceRecoveryWithConvertMainToken(uint256 _percent)
        internal
        returns (bool)
    {
        uint256 tempX = safeDiv(_percent, appreciationLimit);
        uint256 root = nthRoot(tempX, 2, 0, maxIteration);
        uint256 _tempValue = safeSub(root, PRICE_NOMINATOR);
        uint256 _supply = IERC20Token(mainToken).balanceOf(converter);

        uint256 _reverseBalance = safeDiv(
            safeMul(_supply, _tempValue),
            PRICE_NOMINATOR
        );

        uint256 vaultBalance = IERC20Token(mainToken).balanceOf(vaultAddress);

        if (vaultBalance >= _reverseBalance) {
            ITokenVault(vaultAddress).directTransfer(
                address(mainToken),
                address(this),
                _reverseBalance
            );
            return _convertWithToken(_reverseBalance, mainTokenTobaseToken);
        } else {
            uint256 converterBalance = IERC20Token(mainToken).balanceOf(
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

    function _recoverAfterRedemption(uint256 _amount) internal returns (bool) {
        bool isEtherToken = false;

        uint256 totalEthAmount = getReturnByPath(ethToBaseToken, _amount);

        if (etherTokens(baseToken)) {
            isEtherToken = true;
            totalEthAmount = _amount;
        }

        // this change because we convert all base token to ether
        if (totalEthAmount > address(this).balance) {
            IBancorNetwork(bancorNetwork).convertByPath.value(totalEthAmount)(
                ethToMainToken,
                totalEthAmount,
                1,
                vaultAddress,
                address(0),
                0
            );
            return true;
        } else {
            uint256 converterBalance = IERC20Token(baseToken).balanceOf(
                converter
            );

            uint256 _tempRelayPercent = relayPercent;
            if (converterBalance > _amount) {
                _tempRelayPercent = safeDiv(
                    safeMul(safeSub(converterBalance, _amount), 100),
                    _amount
                );
                if (_tempRelayPercent > 99) _tempRelayPercent = 99;
            }
            _liquadate(safeMul(_tempRelayPercent, PRICE_NOMINATOR));
            _amount = safeSub(_amount, safeDiv(_amount, _tempRelayPercent));
            return _convertWithToken(_amount, baseTokenToMainToken);
        }
    }

    function redemptionFromEscrow(
        address[] memory _path,
        uint256 _amount,
        address payable _reciver
    ) public returns (bool) {
        require(msg.sender == escrowAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        return _redemption(_path, _amount, msg.sender, _reciver);
    }

    function redemption(address[] memory _path, uint256 _amount)
        public
        returns (bool)
    {
        return _redemption(_path, _amount, msg.sender, msg.sender);
    }

    function _redemption(
        address[] memory _path,
        uint256 _amount,
        address payable _caller,
        address payable _reciver
    ) internal returns (bool) {
        require(address(_path[0]) == address(mainToken), "ERR_MAIN_TOKEN");

        address primaryWallet = IWhiteList(whiteListAddress).address_belongs(
            _reciver
        );
        require(
            IWhiteList(whiteListAddress).isAllowedBuyBack(primaryWallet),
            "ERR_NOT_ALLOWED_BUYBACK"
        );

        uint256 auctionDay = IAuction(auctionAddress).auctionDay();

        require(primaryWallet != address(0), "ERR_WHITELIST");

        require(
            auctionDay > lastReedeemDay[primaryWallet],
            "ERR_WALLET_ALREADY_REDEEM"
        );

        uint256 _beforeBalance = IERC20Token(baseToken).balanceOf(converter);

        if (_beforeBalance != lastReserveBalance) {
            _recoverPriceDueToManipulation();
        }
        ensureTransferFrom(
            IERC20Token(_path[0]),
            _caller,
            address(this),
            _amount
        );
        approveTransferFrom(IERC20Token(_path[0]), converter, _amount);

        uint256 returnAmount = IBancorNetwork(bancorNetwork)
            .convertByPath
            .value(0)(_path, _amount, 1, _reciver, address(0), 0);

        lastReedeemDay[primaryWallet] = auctionDay;

        uint256 _afterBalance = IERC20Token(baseToken).balanceOf(converter);

        emit Redemption(
            address(_path[safeSub(_path.length, 1)]),
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
        uint256 _baseTokenBalance = IERC20Token(baseToken).balanceOf(converter);

        uint256 yesterdayMainReserv = safeDiv(
            safeMul(_baseTokenBalance, baseLinePrice),
            safeExponent(10, IERC20Token(baseToken).decimals())
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
        isAppreciationLimitReached = false;
        return true;
    }

    function _liquadate(uint256 _relayPercent)
        internal
        returns (uint256, uint256)
    {
        uint256 _mainTokenBalance = IERC20Token(mainToken).balanceOf(
            address(this)
        );
        uint256 _baseTokenBalance = IERC20Token(baseToken).balanceOf(
            address(this)
        );

        uint256 sellRelay = safeDiv(
            safeMul(
                IERC20Token(relayToken).balanceOf(address(tagAlongAddress)),
                _relayPercent
            ),
            safeMul(100, PRICE_NOMINATOR)
        );

        IAuctionTagAlong(tagAlongAddress).transferTokenLiquadity(
            IERC20Token(relayToken),
            address(this),
            sellRelay
        );

        //take out both side of token from the reserve
        IBancorConverter(converter).removeLiquidity(
            sellRelay,
            relayPath,
            returnAmountRelay
        );

        _mainTokenBalance = safeSub(
            IERC20Token(mainToken).balanceOf(address(this)),
            _mainTokenBalance
        );

        _baseTokenBalance = safeSub(
            IERC20Token(baseToken).balanceOf(address(this)),
            _baseTokenBalance
        );

        ensureTransferFrom(
            IERC20Token(mainToken),
            address(this),
            vaultAddress,
            _mainTokenBalance
        );

        // etherToken converted into
        if (etherTokens(baseToken)) {
            IEtherToken(baseToken).withdraw(_baseTokenBalance);
        }
        return (_baseTokenBalance, _mainTokenBalance);
    }

    function returnFundToTagAlong(IERC20Token _token, uint256 _value)
        external
        onlyOwner()
        returns (bool)
    {
        if (address(_token) == address(0)) {
            tagAlongAddress.transfer(_value);
        } else {
            ensureTransferFrom(_token, address(this), tagAlongAddress, _value);
        }
        return true;
    }

    //return token and ether from tagalong to here  as we only need ether
    function takeFundFromTagAlong(IERC20Token _token, uint256 _value)
        external
        onlyOwner()
        returns (bool)
    {
        if (address(_token) == address(0))
            IAuctionTagAlong(tagAlongAddress).contributeTowardLiquadity(_value);
        else
            IAuctionTagAlong(tagAlongAddress).transferTokenLiquadity(
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
        uint256 mainTokenBalance = IERC20Token(mainToken).balanceOf(
            address(this)
        );
        ensureTransferFrom(
            IERC20Token(mainToken),
            address(this),
            vaultAddress,
            mainTokenBalance
        );
    }

    function convertBaseTokenToEth() external returns (bool) {
        _convertBaseTokenToEth();
        return true;
    }

    function() external payable {}
}
