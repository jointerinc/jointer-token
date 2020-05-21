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
            _tokenMaturityDays,
            _tokenHoldBackDays,
            _registeryAddress
        )
        ForceSwap(_returnToken)
    {
        require(_which.length == _amount.length, "ERR_NOT_SAME_LENGTH");
        address whiteListAddress = getAddressOf(WHITE_LIST);
        for (uint256 tempX = 0; tempX < _which.length; tempX++) {
            require(
                IWhiteList(whiteListAddress).isWhiteListed(_which[tempX]),
                "ERR_TRANSFER_CHECK_WHITELIST"
            );
            _mint(_which[tempX], _amount[tempX]);
        }
    }

    function transfer(address _to, uint256 _value) external returns (bool ok) {
        require(checkBeforeTransfer(msg.sender, _to));
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value)
        external
        returns (bool)
    {
        require(checkBeforeTransfer(_from, _to));
        return _transferFrom(_from, _to, _value);
    }

    function() external payable {
        revert();
    }
}
