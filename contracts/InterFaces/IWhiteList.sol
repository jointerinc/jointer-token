pragma solidity ^0.5.9;


contract IWhiteList {
    function address_belongs(address _who) public view returns (address);

    function isWhiteListed(address _who) public view returns (bool);

    function isAddressByPassed(address _which) public view returns (bool);

    function hasPermission(address _from, address _to)
        public
        view
        returns (bool);

    function canReciveToken(address _which) public view returns (bool);

    function isRestrictedAddress(address _which) public view returns (bool);

    function isTransferAllowed(address _from, address _to)
        public
        view
        returns (bool);
}
