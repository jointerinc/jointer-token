pragma solidity ^0.5.9;

import "./StandardToken.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/ITokenVault.sol";
import "../InterFaces/IToken.sol";
import "./TokenUtils.sol";
import "../InterFaces/IWhiteList.sol";


contract ForceSwap is TokenUtils {
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

    function swapTokens(uint256 _amount) external returns (bool) {
        return _forceSwap(msg.sender, _amount);
    }
}
