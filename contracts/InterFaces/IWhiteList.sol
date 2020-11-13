pragma solidity ^0.5.9;

interface IWhiteList {
    function address_belongs(address _who) external view returns (address);

    function isWhiteListed(address _who) external view returns (bool);

    function isAllowedInAuction(address _which) external view returns (bool);

    function isAddressByPassed(address _which) external view returns (bool);

    function isExchangeAddress(address _which) external view returns (bool);

    function main_isTransferAllowed(
        address _msgSender,
        address _from,
        address _to
    ) external returns (bool);

    function etn_isTransferAllowed(
        address _msgSender,
        address _from,
        address _to
    ) external returns (bool);

    function stock_isTransferAllowed(
        address _msgSender,
        address _from,
        address _to
    ) external returns (bool);

    function addWalletBehalfExchange(address _mainWallet, address _subWallet)
        external
        returns (bool);

    function main_isReceiveAllowed(address user) external view returns (bool);

    function etn_isReceiveAllowed(address user) external view returns (bool);

    function stock_isReceiveAllowed(address user) external view returns (bool);

    /**@dev checks if address is allowed in auction or not */
    function checkRule(address _which, uint256 _condition) external view returns (bool);
}
