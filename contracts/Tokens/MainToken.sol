pragma solidity ^0.5.9;

import "../InterFaces/IWhiteList.sol";
import "./TokenUtils.sol";


contract TokenMinter is TokenUtils {
    modifier onlyAuthorizedAddress() {
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
    mapping(address => uint256) lockedToken;
    mapping(address => uint256) lastLock;

    constructor(
        string memory _name,
        string memory _symbol,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
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
        address whiteListAddress = whiteListAddress;

        if (_to != smartSwapAddress) {
            require(
                IWhiteList(whiteListAddress).main_isTransferAllowed(_from, _to),
                "ERR_NOT_HAVE_PERMISSION_TO_TRANSFER"
            );
        }
        return true;
    }

    function transfer(address _to, uint256 _value) external returns (bool ok) {
        uint256 senderBalance = safeSub(
            balances[msg.sender],
            lockedToken[msg.sender]
        );
        require(senderBalance >= _value, "ERR_NOT_ENOUGH_BALANCE");
        require(checkBeforeTransfer(msg.sender, _to));
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        uint256 senderBalance = safeSub(
            balances[msg.sender],
            lockedToken[msg.sender]
        );
        require(senderBalance >= _value, "ERR_NOT_ENOUGH_BALANCE");
        require(checkBeforeTransfer(_from, _to));
        return _transferFrom(_from, _to, _value);
    }

    // we need lock time
    // becuse we can check if user invest after new auction start
    // if user invest before token distrubution we dont change anything
    // ex ->user invest  at 11:35 and token distrubution happened at 11:40
    // if in between user invest we dont unlock user token we keep as it as
    // to unlock token set _amount = 0
    function lockToken(
        address _which,
        uint256 _amount,
        uint256 _locktime
    ) external returns (bool) {
        require(msg.sender == auctionAddress, ERR_AUTHORIZED_ADDRESS_ONLY);
        if (_locktime > lastLock[_which]) {
            lockedToken[_which] = _amount;
            lastLock[_which] = _locktime;
        }
        return true;
    }

    // user can unlock their token after 1 day of locking
    // user dont need to call this function as conatcrt set 0 after token distrubution
    // It is failsafe function for user that their token not locked all the time if AUCTION distrubution dont happened
    function unlockToken() external returns (bool) {
        require(
            safeAdd(lastLock[msg.sender], 86400) > now,
            "ERR_TOKEN_UNLCOK_AFTER_DAY"
        );
        lockedToken[msg.sender] = 0;
        return true;
    }

    function() external payable {
        revert();
    }
}
