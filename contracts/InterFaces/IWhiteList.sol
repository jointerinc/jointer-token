pragma solidity ^0.5.9;


interface IWhiteList {
    function address_belongs(address _who) external view returns (address);

    function isWhiteListed(address _who) external view returns (bool);

    function isAddressByPassed(address _which) external view returns (bool);

    function isAllowedBuyBack(address _which) external view returns (bool);

    function isBancorAddress(address _which) public view returns (bool);

    function isAllowedBuyBack(address _which) public view returns (bool);

    function main_isTransferAllowed(
        address _msgSender,
        address _from,
        address _to
    ) external view returns (bool);

    function etn_isTransferAllowed(
        address _msgSender,
        address _from,
        address _to
    ) external view returns (bool);

    function stock_isTransferAllowed(
        address _msgSender,
        address _from,
        address _to
    ) external view returns (bool);

    function main_isReceiveAllowed(address user) external view returns (bool);

    function etn_isReceiveAllowed(address user) external view returns (bool);

    function stock_isReceiveAllowed(address user) external view returns (bool);
}
