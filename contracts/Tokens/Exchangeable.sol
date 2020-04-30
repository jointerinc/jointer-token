pragma solidity ^0.5.9;

import "./StandardToken.sol";
import "./RestrictedToken.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IToken.sol";


contract ForceSwap is RestrictedToken {
    // here returnToken means with mainToken
    address public returnToken;

    constructor(address _returnToken) public notZeroAddress(_returnToken) {
        returnToken = _returnToken;
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

        return tokenVault.directTransfer(returnToken, msg.sender, _assignToken);
    }
}


contract Exchangeable is ForceSwap {
    address public exchangeableToken;

    function setExchangeableToken(address _which)
        external
        onlySystem()
        returns (bool)
    {
        require(exchangeableToken == address(0), "ERR_ACTION_NOT_ALLOWED");
        exchangeableToken = _which;
    }

    modifier isConversionAllowed(address _which) {
        require(
            _which == exchangeableToken || _which == returnToken,
            "ERR_TOKEN_IS_NOT_IN_LIST"
        );
        _;
    }

    function buyTokens(address _fromToken, uint256 _amount)
        external
        isConversionAllowed(_fromToken)
        returns (uint256)
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

        _mint(msg.sender, _assignToken);

        return _assignToken;
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

        tokenVault.directTransfer(_toToken, msg.sender, _assignToken);
        _burn(msg.sender, _amount);

        return true;
    }
}
