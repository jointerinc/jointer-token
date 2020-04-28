pragma solidity ^0.5.9;

import "./StandardToken.sol";
import "./TokenUtils.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/ITokenVault.sol";


contract ForceSwap is TokenUtils {
    // here returnToken means with mainToken
    address public returnToken;

    constructor(address _returnToken) public notZeroAddress(_returnToken) {
        returnToken = _returnToken;
    }

    function setReturnToken(address _which)
        external
        onlySystem()
        returns (bool)
    {
        require(returnToken == address(0), "ERR_ACTION_NOT_ALLOWED");
        returnToken = _which;
    }

    function forceSwap(address _which, uint256 _amount)
        external
        onlySystem()
        returns (bool)
    {
        require(returnToken != address(0), "ERR_ACTION_NOT_ALLOWED");

        _burn(_which, _amount);

        ICurrencyPrices currencyPrice = ICurrencyPrices(getAddressOf(CURRENCY));

        ITokenVault tokenVault = ITokenVault(getAddressOf(VAULT));

        uint256 retunTokenPrice = currencyPrice.getCurrencyPrice(returnToken);

        uint256 currentTokenPrice = currencyPrice.getCurrencyPrice(
            address(this)
        );

        uint256 _assignToken = safeDiv(
            safeMul(_amount, currentTokenPrice),
            retunTokenPrice
        );

        tokenVault.directTransfer(returnToken, _which, _assignToken);

        return true;
    }
}


contract Exchangeable is ForceSwap {
    mapping(address => bool) allowedToken;
    mapping(address => uint256) public allowedTokensIndex;
    address[] public allowedTokens;

    constructor(address _returnToken)
        public
        notZeroAddress(_returnToken)
        ForceSwap(_returnToken)
    {
        addAllowedTokenInternal(_returnToken);
    }

    modifier isConversionAllowed(address _which) {
        require(allowedToken[_which], "ERR_TOKEN_IS_NOT_IN_LIST");
        _;
    }

    function buyTokens(address _fromToken, uint256 _amount)
        external
        isConversionAllowed(_fromToken)
        returns (bool)
    {
        ICurrencyPrices currencyPrice = ICurrencyPrices(getAddressOf(CURRENCY));
        uint256 fromTokenPrice = currencyPrice.getCurrencyPrice(_fromToken);
        uint256 currentTokenPrice = currencyPrice.getCurrencyPrice(
            address(this)
        );
        uint256 _assignToken = safeDiv(
            safeMul(_amount, fromTokenPrice),
            currentTokenPrice
        );
        ERC20(_fromToken).transferFrom(
            msg.sender,
            getAddressOf(VAULT),
            _amount
        );
        return _mint(msg.sender, _assignToken);
    }

    function swapTokens(address _toToken, uint256 _amount)
        external
        isConversionAllowed(_toToken)
        returns (bool)
    {
        ICurrencyPrices currencyPrice = ICurrencyPrices(getAddressOf(CURRENCY));
        ITokenVault tokenVault = ITokenVault(getAddressOf(VAULT));
        uint256 toTokenPrice = currencyPrice.getCurrencyPrice(_toToken);
        uint256 currentTokenPrice = currencyPrice.getCurrencyPrice(
            address(this)
        );
        uint256 _assignToken = safeDiv(
            safeMul(_amount, currentTokenPrice),
            toTokenPrice
        );
        _burn(msg.sender, _amount);
        return tokenVault.directTransfer(_toToken, msg.sender, _assignToken);
    }

    function addAllowedTokenInternal(address _which) internal returns (bool) {
        require(!allowedToken[_which], ERR_AUTHORIZED_ADDRESS_ONLY);
        allowedToken[_which] = true;
        allowedTokensIndex[_which] = allowedTokens.length;
        allowedTokens.push(_which);
        return true;
    }

    function addAllowedToken(address _which)
        external
        onlySystem()
        returns (bool)
    {
        return addAllowedTokenInternal(_which);
    }
}
