pragma solidity ^0.5.9;


contract IWhiteList {
    function address_belongs(address _who) public view returns (address);

    function isWhiteListed(address _who) public view returns (bool);

    function isAddressByPassed(address _which) public view returns (bool);

    function main_isTransferAllowed(address _from, address _to)
        public
        view
        returns (bool);

    function etn_isTransferAllowed(address _from, address _to)
        public
        view
        returns (bool);

    function stock_isTransferAllowed(address _from, address _to)
        public
        view
        returns (bool);

    function main_isReceiveAllowed(address user) public view returns (bool);

    function etn_isReceiveAllowed(address user) public view returns (bool);

    function stock_isReceiveAllowed(address user) public view returns (bool);
}
