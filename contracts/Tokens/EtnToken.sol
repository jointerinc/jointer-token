pragma solidity ^0.5.9;

import "./Exchangeable.sol";
import "../InterFaces/IWhiteList.sol";


contract EtnToken is Exchangeable {
    constructor(
        string memory _name,
        string memory _symbol,
        address _systemAddress,
        address _authorityAddress,
        address _registeryAddress,
        uint256 _tokenMaturityDays,
        uint256 _tokenHoldBackDays,
        address _returnToken
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
    {}

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
