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

    function _forceSwap(address _which, uint256 _amount)
        internal
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

    function forceSwap(address _which, uint256 _amount)
        external
        onlySystem()
        returns (bool)
    {
        return _forceSwap(_which, _amount);
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

    // we are currently developing whitelist with this change
    function buyTokens(address _fromToken, uint256 _amount)
        external
        isConversionAllowed(_fromToken)
        returns (uint256)
    {
        address whiteListAddress = getAddressOf(WHITE_LIST);

        require(
            IWhiteList(whiteListAddress).canBuyToken(address(this), msg.sender),
            "ERR_NOT_HAVE_PERMISSION_TO_BUY"
        );

        ICurrencyPrices currencyPrice = ICurrencyPrices(getAddressOf(CURRENCY));

        uint256 fromTokenPrice = currencyPrice.getCurrencyPrice(_fromToken);

        uint256 currentTokenPrice = currencyPrice.getCurrencyPrice(
            address(this)
        );

        uint256 _assignToken = safeDiv(
            safeMul(_amount, fromTokenPrice),
            currentTokenPrice
        );

        if (_fromToken == returnToken) {
            ERC20(_fromToken).transferFrom(
                msg.sender,
                getAddressOf(VAULT),
                _amount
            );
        } else {
            ERC20(_fromToken).transferFrom(msg.sender, address(this), _amount);
            IToken(_fromToken).burn(_amount);
        }

        _mint(msg.sender, _assignToken);

        return _assignToken;
    }

    function swapTokens(uint256 _amount) external returns (bool) {
        return _forceSwap(msg.sender, _amount);
    }
}
