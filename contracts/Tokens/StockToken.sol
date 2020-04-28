pragma solidity ^0.5.9;

import "./StandardToken.sol";
import "./TokenUtils.sol";
import "../InterFaces/IWhiteList.sol";
import "../InterFaces/ICurrencyPrices.sol";
import "../InterFaces/ITokenVault.sol";


contract ForceSwap is TokenUtils {
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


contract StockToken is Exchangeable {
    constructor(
        string memory _name,
        string memory _symbol,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _tokenPrice,
        uint256 _tokenMaturityDays,
        uint256 _tokenHoldBackDays,
        address _returnToken,
        address[] memory _which,
        uint256[] memory _amount
    )
        public
        TokenUtils(
            _name,
            _symbol,
            _systemAddress,
            _authorityAddress,
            _tokenPrice,
            _tokenMaturityDays,
            _tokenHoldBackDays,
            _registeryAddress
        )
        Exchangeable(_returnToken)
    {
        require(_which.length == _amount.length, "ERR_NOT_SAME_LENGTH");
        for (uint256 tempX = 0; tempX < _which.length; tempX++) {
            _mint(_which[tempX], _amount[tempX]);
        }
    }

    function checkBeforeTransfer(address _from, address _to)
        internal
        view
        returns (bool)
    {
        address whiteListAddress = getAddressOf(WHITE_LIST);
        if (
            IWhiteList(whiteListAddress).isAddressByPassed(msg.sender) == false
        ) {
            require(
                IWhiteList(whiteListAddress).checkBeforeTransfer(_from, _to),
                "ERR_TRANSFER_CHECK_WHITELIST"
            );
            require(
                !isTokenMature() && isHoldbackDaysOver(),
                "ERR_ACTION_NOT_ALLOWED"
            );
        }
        return true;
    }

    function transfer(address _to, uint256 _value) public returns (bool ok) {
        require(checkBeforeTransfer(msg.sender, _to));
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value)
        public
        returns (bool)
    {
        require(checkBeforeTransfer(_from, _to));
        return super.transferFrom(_from, _to, _value);
    }

    function() external payable {
        revert();
    }
}
