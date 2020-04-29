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

        uint256 _vaultBalance = ERC20(returnToken).balanceOf(returnToken);

        if (_vaultBalance >= _assignToken) {
            tokenVault.directTransfer(returnToken, _which, _assignToken);
        } else {
            tokenVault.directTransfer(returnToken, _which, _vaultBalance);
            _assignToken = safeSub(_assignToken, _vaultBalance);
            IToken(returnToken).mintTokens(_assignToken);
            ERC20(returnToken).transfer(_which, _assignToken);
        }

        return true;
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

        uint256 _vaultBalance = ERC20(returnToken).balanceOf(_toToken);

        _burn(msg.sender, _amount);

        if (_vaultBalance >= _assignToken) {
            tokenVault.directTransfer(_toToken, msg.sender, _assignToken);
        } else {
            tokenVault.directTransfer(_toToken, msg.sender, _vaultBalance);
            _assignToken = safeSub(_assignToken, _vaultBalance);

            if (_toToken == returnToken) {
                IToken(_toToken).mintTokens(_assignToken);

                ERC20(_toToken).transfer(msg.sender, _assignToken);
            } else if (_toToken == exchangeableToken) {
                uint256 _leftToken = safeDiv(
                    safeMul(_assignToken, currentTokenPrice),
                    toTokenPrice
                );

                _mint(address(this), _leftToken);

                ERC20(address(this)).approve(_toToken, _leftToken);

                uint256 transferBalance = IToken(_toToken).buyTokens(
                    address(this),
                    _leftToken
                );

                ERC20(_toToken).transfer(msg.sender, transferBalance);
            }
        }
        return true;
    }
}
