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

        require(
            IWhiteList(whiteListAddress).isWhiteListed(_to),
            "ERR_USER_NOT_WHITELISTED"
        );

        if (IWhiteList(whiteListAddress).isRestrictedAddress(_to)) {
            require(
                IWhiteList(whiteListAddress).hasPermission(_from, _to),
                "ERR_NOT_HAVE_PERMISSION_TO_TRANSFER"
            );
        } else if (
            IWhiteList(whiteListAddress).isAddressByPassed(msg.sender) == false
        ) {
            require(
                IWhiteList(whiteListAddress).isTransferAllowed(_from, _to),
                "ERR_NOT_HAVE_PERMISSION_TO_TRANSFER"
            );
            require(
                IWhiteList(whiteListAddress).canReciveToken(_to),
                "ERR_NOT_KYC_AML_EXPIRED"
            );
            require(
                !isTokenMature() && isHoldbackDaysOver(),
                "ERR_ACTION_NOT_ALLOWED"
            );
        }
        return true;
    }
}
