pragma solidity ^0.5.9;

import "./Exchangeable.sol";
import "../InterFaces/IWhiteList.sol";


contract EtnToken is Exchangeable {
    /**
     *@dev constructs contract and premints tokens
     *@param _name name of the token
     *@param _symbol symbol of the token
     *@param _systemAddress address that acts as an admin of the system
     *@param _authorityAddress address that can change the systemAddress
     *@param _registeryAddress address of the registry contract the keeps track of all the contract Addresses
     *@param _returnToken address of the token user gets back when system forces them to convert(maintoken)
     **/
    constructor(
        string memory _name,
        string memory _symbol,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        address _returnToken
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
    {}

    /**
     *@dev checks before every transfer that takes place(except minting)
     *@param _from address from which tokens are being transferred
     *@param _to address to which tokens are being transfferred
     */
    function checkBeforeTransfer(address _from, address _to)
        internal
        returns (bool)
    {
        require(
            IWhiteList(whiteListAddress).etn_isTransferAllowed(
                msg.sender,
                _from,
                _to
            ),
            "ERR_NOT_HAVE_PERMISSION_TO_TRANSFER"
        );

        return true;
    }

    /** @dev Allows users to buy tokens from other accepteble tokens prices as per prices in currencyPrices contract
     *@param _fromToken the token user wants buy from
     *@param _amount amount of token users wants buy with. It assumes that contract has been approved atleast _amount buy msg.sender
     */
    function buyTokens(address _fromToken, uint256 _amount)
        external
        isConversionAllowed(_fromToken)
        returns (uint256)
    {
        //check if msg.sender is allowed

        require(
            IWhiteList(whiteListAddress).etn_isReceiveAllowed(msg.sender),
            "ERR_CANNOT_RECIEVE"
        );

        ICurrencyPrices currencyPrice = ICurrencyPrices(currencyPricesAddress);

        uint256 fromTokenPrice = currencyPrice.getCurrencyPrice(_fromToken);
        
        require(fromTokenPrice > 0, "ERR_TOKEN_PRICE_NOT_SET");

        uint256 currentTokenPrice = currencyPrice.getCurrencyPrice(
            address(this)
        );

        uint256 _assignToken = safeDiv(
            safeMul(_amount, fromTokenPrice),
            currentTokenPrice
        );

        if (_fromToken == returnToken) {
            IBEP20(_fromToken).transferFrom(msg.sender, vaultAddress, _amount);
        } else {
            IBEP20(_fromToken).transferFrom(msg.sender, address(this), _amount);
            IToken(_fromToken).burn(_amount);
        }

        _mint(msg.sender, _assignToken);

        return _assignToken;
    }

    function transfer(address _to, uint256 _value) external  returns (bool ok) {
        require(checkBeforeTransfer(msg.sender, _to));
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external  returns (bool) {
        require(checkBeforeTransfer(_from, _to));
        return _transferFrom(_from, _to, _value);
    }

    function() external payable {
        revert("ERR_CAN'T_FORCE_ETH");
    }
}
