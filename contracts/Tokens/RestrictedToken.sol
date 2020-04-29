pragma solidity ^0.5.9;

import "./TokenUtils.sol";
import "../InterFaces/IWhiteList.sol";


contract RestrictedToken is TokenUtils {
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
}
