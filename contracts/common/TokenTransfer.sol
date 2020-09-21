pragma solidity ^0.5.9;

import "../InterFaces/IBEP20Token.sol";

contract TokenTransfer {
    function ensureTransferFrom(
        IBEP20Token _token,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if (_from == address(this))
            require(_token.transfer(_to, _amount), "ERR_TOKEN_TRANSFER_FAIL");
        else
            require(
                _token.transferFrom(_from, _to, _amount),
                "ERR_TOKEN_TRANSFER_FAIL"
            );
    }

    function approveTransferFrom(
        IBEP20Token _token,
        address _spender,
        uint256 _amount
    ) internal {
        require(_token.approve(_spender, _amount), "ERR_TOKEN_APPROVAL_FAIL");
    }
}
