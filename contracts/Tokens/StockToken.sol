pragma solidity ^0.5.9;
import "./Exchangeable.sol";
import "../InterFaces/IWhiteList.sol";


contract StockToken is Exchangeable {
    constructor(
        string memory _name,
        string memory _symbol,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
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
            _registeryAddress
        )
        ForceSwap(_returnToken)
    {
        require(_which.length == _amount.length, "ERR_NOT_SAME_LENGTH");
        for (uint256 tempX = 0; tempX < _which.length; tempX++) {
            require(
                IWhiteList(whiteListAddress).isWhiteListed(_which[tempX]),
                "ERR_TRANSFER_CHECK_WHITELIST"
            );
            _mint(_which[tempX], _amount[tempX]);
        }
    }

    function checkBeforeTransfer(address _from, address _to)
        internal
        view
        returns (bool)
    {
        require(
            IWhiteList(whiteListAddress).stock_isTransferAllowed(
                msg.sender,
                _from,
                _to
            ),
            "ERR_NOT_HAVE_PERMISSION_TO_TRANSFER"
        );

        return true;
    }

    // Allows to buyTokens
    function buyTokens(address _fromToken, uint256 _amount)
        external
        isConversionAllowed(_fromToken)
        returns (uint256)
    {
        //check if msg.sender is allowed

        require(
            IWhiteList(whiteListAddress).stock_isReceiveAllowed(msg.sender),
            "ERR_CANNOT_RECIEVE"
        );

        ICurrencyPrices currencyPrice = ICurrencyPrices(currencyPricesAddress);

        uint256 fromTokenPrice = currencyPrice.getCurrencyPrice(_fromToken);

        uint256 currentTokenPrice = currencyPrice.getCurrencyPrice(
            address(this)
        );

        uint256 _assignToken = safeDiv(
            safeMul(_amount, fromTokenPrice),
            currentTokenPrice
        );

        if (_fromToken == returnToken) {
            ERC20(_fromToken).transferFrom(msg.sender, vaultAddress, _amount);
        } else {
            ERC20(_fromToken).transferFrom(msg.sender, address(this), _amount);
            IToken(_fromToken).burn(_amount);
        }

        _mint(msg.sender, _assignToken);

        return _assignToken;
    }

    function transfer(address _to, uint256 _value) external returns (bool ok) {
        require(checkBeforeTransfer(msg.sender, _to));
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        require(checkBeforeTransfer(_from, _to));
        return _transferFrom(_from, _to, _value);
    }

    function() external payable {
        revert();
    }
}
