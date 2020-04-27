pragma solidity ^0.5.9;

import "./StandardToken.sol";
import "./TokenUtils.sol";
import "../InterFaces/IWhiteList.sol";


contract TokenMinter is TokenUtils {
    address public auctionAddress;

    modifier onlyAuctionAddress() {
        require(msg.sender == auctionAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    function changeAuctionAddress(address _which)
        external
        onlyAuthorized()
        returns (bool)
    {
        auctionAddress = _which;
        return true;
    }

    function mintTokens(uint256 _amount)
        external
        onlyAuctionAddress()
        returns (bool)
    {
        return _mint(msg.sender, _amount);
    }
}


contract Token is TokenMinter, AuctionRegistery {
    constructor(
        string memory _name,
        string memory _symbol,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _tokenPrice,
        uint256 _tokenMaturityDays,
        uint256 _tokenHoldBackDays,
        address[] memory _which,
        uint256[] memory _amount
    )
        public
        StandardToken(_name, _symbol, _systemAddress, _authorityAddress)
        TokenUtils(_tokenPrice, _tokenMaturityDays, _tokenHoldBackDays)
        AuctionRegistery(_registeryAddress)
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
