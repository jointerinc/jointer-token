pragma solidity ^0.5.9;

import "./RestrictedToken.sol";
import "../InterFaces/IWhiteList.sol";


contract TokenMinter is RestrictedToken {
    modifier onlyAuthorizedAddress() {
        address auctionAddress = getAddressOf(AUCTION);
        require(msg.sender == auctionAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        _;
    }

    function mintTokens(uint256 _amount)
        external
        onlyAuthorizedAddress()
        returns (bool)
    {
        return _mint(msg.sender, _amount);
    }
}


contract MainToken is TokenMinter {
    constructor(
        string memory _name,
        string memory _symbol,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _tokenMaturityDays,
        uint256 _tokenHoldBackDays,
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

    function() external payable {
        revert();
    }
}
