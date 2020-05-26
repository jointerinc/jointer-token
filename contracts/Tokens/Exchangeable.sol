pragma solidity ^0.5.9;

import "./StandardToken.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IToken.sol";
import "./TokenUtils.sol";
import "../InterFaces/IWhiteList.sol";


/**
@dev ForeceSwap contains functionality for system to be able to convert tokens of anyone into returnToken at setted price
 */
contract ForceSwap is TokenUtils {
    // here returnToken means with mainToken
    address public returnToken;

    constructor(address _returnToken) public notZeroAddress(_returnToken) {
        returnToken = _returnToken;
    }

    /**
    @dev converts _which's _amount of tokens into returnTokens as per the price
    @param _which address which tokens are being converted
    @param _amount amount of tokens being converted */
    function _forceSwap(address _which, uint256 _amount)
        internal
        returns (bool)
    {
        require(returnToken != address(0), "ERR_ACTION_NOT_ALLOWED");

        _burn(_which, _amount);

        ICurrencyPrices currencyPrice = ICurrencyPrices(currencyPricesAddress);

        ITokenVault tokenVault = ITokenVault(vaultAddress);

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

    /**
    @dev converts _which's _amount of tokens into returnTokens as per the price, can be called only by the system
    @param _which address which tokens are being converted
    @param _amount amount of tokens being converted */
    function forceSwap(address _which, uint256 _amount)
        external
        onlySystem()
        returns (bool)
    {
        return _forceSwap(_which, _amount);
    }
}


/**@dev Exchangeble keeps track of token with which users are allowed to buy 'this' token from*/
contract Exchangeable is ForceSwap {
    //address of the token with which user can buy 'this' token from
    address public exchangeableToken;

    /**@dev sets the address of the token with which user can buy 'this' token from by system only */
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

    /**@dev allows user to convert tokens into returnTokens at setted price
    @param _amount amount of token being converted
     */
    function swapTokens(uint256 _amount) external returns (bool) {
        return _forceSwap(msg.sender, _amount);
    }
}
